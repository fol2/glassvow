#define _GNU_SOURCE
#include "policy.h"
#include <errno.h>
#include <fcntl.h>
#include <linux/audit.h>
#include <linux/filter.h>
#include <linux/seccomp.h>
#include <sched.h>
#include <stddef.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <sys/prctl.h>
#include <sys/syscall.h>
#include <unistd.h>

/* Unknown syscalls notify-and-deny. No tracee pointer is read by the mediator.
 * CONTINUE is used only for scalar counts/flags, never a pathname/iovec check.
 * Filesystem access is independently bounded by the immutable chroot mount.
 */
#define ALLOW(n) BPF_JUMP(BPF_JMP|BPF_JEQ|BPF_K, __NR_##n,0,1), \
                 BPF_STMT(BPF_RET|BPF_K,SECCOMP_RET_ALLOW)
int dd1_listener(void) {
    struct sock_filter code[] = {
        BPF_STMT(BPF_LD|BPF_W|BPF_ABS,offsetof(struct seccomp_data,arch)),
        BPF_JUMP(BPF_JMP|BPF_JEQ|BPF_K,AUDIT_ARCH_X86_64,1,0),
        BPF_STMT(BPF_RET|BPF_K,SECCOMP_RET_KILL_PROCESS),
        BPF_STMT(BPF_LD|BPF_W|BPF_ABS,offsetof(struct seccomp_data,nr)),
        BPF_JUMP(BPF_JMP|BPF_JGE|BPF_K,0x40000000U,0,1),
        BPF_STMT(BPF_RET|BPF_K,SECCOMP_RET_KILL_PROCESS),
        /* Trusted bootstrap exports the listener over fd 3, then closes it.
         * No workload socket survives; socket/socketpair/recvmsg are denied. */
        BPF_JUMP(BPF_JMP|BPF_JEQ|BPF_K,__NR_sendmsg,0,4),
        BPF_STMT(BPF_LD|BPF_W|BPF_ABS,offsetof(struct seccomp_data,args[0])),
        BPF_JUMP(BPF_JMP|BPF_JEQ|BPF_K,3,0,1),
        BPF_STMT(BPF_RET|BPF_K,SECCOMP_RET_ALLOW),
        BPF_STMT(BPF_RET|BPF_K,SECCOMP_RET_USER_NOTIF),
        ALLOW(read), ALLOW(pread64), ALLOW(readv), ALLOW(preadv),
        ALLOW(close), ALLOW(lseek), ALLOW(fstat), ALLOW(newfstatat),
        ALLOW(stat), ALLOW(lstat), ALLOW(statx), ALLOW(access), ALLOW(faccessat),
        ALLOW(faccessat2), ALLOW(getdents64), ALLOW(readlink), ALLOW(readlinkat),
        ALLOW(dup), ALLOW(dup2), ALLOW(dup3),
        ALLOW(fsync), ALLOW(fdatasync), ALLOW(chdir), ALLOW(fchdir), ALLOW(getcwd),
        ALLOW(brk), ALLOW(munmap), ALLOW(mprotect), ALLOW(madvise),
        ALLOW(futex), ALLOW(set_tid_address), ALLOW(set_robust_list),
        ALLOW(rseq), ALLOW(arch_prctl), ALLOW(rt_sigaction), ALLOW(rt_sigprocmask),
        ALLOW(rt_sigreturn), ALLOW(sigaltstack), ALLOW(clock_gettime),
        ALLOW(clock_getres), ALLOW(clock_nanosleep), ALLOW(nanosleep),
        ALLOW(gettimeofday), ALLOW(time), ALLOW(getpid), ALLOW(getppid), ALLOW(gettid),
        ALLOW(getuid), ALLOW(geteuid), ALLOW(getgid), ALLOW(getegid),
        ALLOW(getrandom), ALLOW(uname), ALLOW(sched_yield), ALLOW(sched_getaffinity),
        ALLOW(getrlimit), ALLOW(getrusage), ALLOW(sysinfo),
        ALLOW(poll), ALLOW(ppoll), ALLOW(select), ALLOW(pselect6),
        ALLOW(epoll_create1), ALLOW(epoll_ctl), ALLOW(epoll_wait), ALLOW(epoll_pwait),
        ALLOW(eventfd2), ALLOW(pipe), ALLOW(pipe2),
        ALLOW(exit), ALLOW(exit_group),
        BPF_STMT(BPF_RET|BPF_K,SECCOMP_RET_USER_NOTIF)
    };
    struct sock_fprog p = {.len=sizeof(code)/sizeof(code[0]),.filter=code};
    if (prctl(PR_SET_NO_NEW_PRIVS,1,0,0,0)) return -1;
    return syscall(SYS_seccomp,SECCOMP_SET_MODE_FILTER,
                   SECCOMP_FILTER_FLAG_NEW_LISTENER,&p);
}

int dd1_notify(int fd,uint64_t cap,uint64_t *used,unsigned *threads,
               unsigned max_threads,unsigned *execs,unsigned *denied,
               int *last_denied,unsigned *clone3,struct dd1_capabilities *capabilities) {
    struct seccomp_notif q;
    struct seccomp_notif_resp a;
    memset(&q,0,sizeof(q)); memset(&a,0,sizeof(a));
    if (ioctl(fd,SECCOMP_IOCTL_NOTIF_RECV,&q)) {
        if (errno==EINTR || errno==ENOENT) return 0;
        return -1;
    }
    a.id=q.id; a.error=-EOPNOTSUPP;
    uint64_t n=0; int scalar=0;
    switch (q.data.nr) {
    case __NR_open: case __NR_openat: {
        uint64_t flags=q.data.args[q.data.nr==__NR_open?1:2];
        n=(flags&(O_CREAT|O_TMPFILE))?4096:0; scalar=1; break;
    }
    /* Path strings themselves are not inspected. Kernel path length is
     * bounded by PATH_MAX; charge worst-case metadata before every mutation. */
    case __NR_rename: case __NR_renameat: case __NR_renameat2:
    case __NR_symlink: case __NR_symlinkat: case __NR_link: case __NR_linkat:
        n=8192; scalar=1; break;
    case __NR_unlink: case __NR_unlinkat: case __NR_mkdir: case __NR_mkdirat: case __NR_rmdir:
        n=4096; scalar=1; break;
    case __NR_fcntl:
        if (q.data.args[1]==F_GETFD || q.data.args[1]==F_GETFL ||
            q.data.args[1]==F_SETFD || q.data.args[1]==F_DUPFD || q.data.args[1]==F_DUPFD_CLOEXEC)
            a.flags=SECCOMP_USER_NOTIF_FLAG_CONTINUE;
        break;
    case __NR_write: case __NR_pwrite64: n=q.data.args[2]; scalar=1; break;
    case __NR_ftruncate: case __NR_truncate: n=q.data.args[1]; scalar=1; break;
    case __NR_mmap:
        /* No shared mapping exists, so later mprotect cannot enable an
         * unmetered file write. Reject MAP_SHARED_VALIDATE and unknown bits. */
        if ((q.data.args[3] & MAP_TYPE)==MAP_PRIVATE &&
            !(q.data.args[3] & ~(uint64_t)(MAP_PRIVATE|MAP_ANONYMOUS|MAP_FIXED|
                  MAP_DENYWRITE|MAP_EXECUTABLE|MAP_STACK|MAP_NORESERVE|MAP_FIXED_NOREPLACE)))
            a.flags=SECCOMP_USER_NOTIF_FLAG_CONTINUE;
        break;
    case __NR_clone: {
        const uint64_t flags=CLONE_VM|CLONE_FS|CLONE_FILES|CLONE_SIGHAND|
            CLONE_THREAD|CLONE_SYSVSEM|CLONE_SETTLS|CLONE_PARENT_SETTID|CLONE_CHILD_CLEARTID;
        if (*execs==1 && q.data.args[0]==flags && *threads<max_threads) {
            ++*threads; /* attempted thread births never refunded */
            a.flags=SECCOMP_USER_NOTIF_FLAG_CONTINUE;
        }
        break;
    }
    case __NR_clone3:
        /* glibc's documented fallback to the scalar clone ABI. Never inspect
         * and CONTINUE a mutable clone_args pointer. No process is created. */
        ++*clone3; a.error=-ENOSYS; break;
    case __NR_execve:
        /* Only trusted single-threaded bootstrap can reach the FIRST exec.
         * No tracee/untrusted handler exists before it. All later execs deny. */
        if (*execs==0 && *threads==1) {++*execs; a.flags=SECCOMP_USER_NOTIF_FLAG_CONTINUE;}
        break;
    case __NR_prlimit64:
        /* Read-only own-process limits; altering CPU ceilings is forbidden. */
        if (q.data.args[0]==0 && q.data.args[2]==0)
            a.flags=SECCOMP_USER_NOTIF_FLAG_CONTINUE;
        break;
    default: break;
    }
    if (scalar) {
        if (n<=cap-*used) { *used+=n; a.flags=SECCOMP_USER_NOTIF_FLAG_CONTINUE; }
        else a.error=-EFBIG;
    }
    if (a.flags) a.error=0;
    else if (q.data.nr!=__NR_clone3) {++*denied; *last_denied=q.data.nr;}
    uint64_t start=a.flags?0:dd1_task_start(capabilities->workload,(pid_t)q.pid);
    int sent=ioctl(fd,SECCOMP_IOCTL_NOTIF_SEND,&a)==0;
    int error=errno;
    if (!a.flags) dd1_refusal(capabilities,&q,&a,*threads,*execs,*clone3,sent,start);
    if (!sent && error!=ENOENT) return -1;
    return 0;
}
