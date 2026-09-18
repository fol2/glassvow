#define _GNU_SOURCE
#include "policy.h"
#include <errno.h>
#include <fcntl.h>
#include <linux/seccomp.h>
#include <poll.h>
#include <sched.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/prctl.h>
#include <sys/resource.h>
#include <sys/socket.h>
#include <sys/syscall.h>
#include <sys/time.h>
#include <sys/utsname.h>
#include <sys/wait.h>
#include <unistd.h>

static volatile sig_atomic_t stopped;
static void stop(int s) {stopped=s;}
static void limit(int id,rlim_t n) {
    struct rlimit r={n,n}; if(setrlimit(id,&r)) dd1_die("setrlimit");
}
static void parent_death(pid_t parent) {
    if(prctl(PR_SET_PDEATHSIG,SIGKILL)||getppid()!=parent) _exit(121);
}
static void sendfd(int fd) {
    char c='L',buf[CMSG_SPACE(sizeof(int))]={0};struct iovec io={&c,1};
    struct msghdr m={.msg_iov=&io,.msg_iovlen=1,.msg_control=buf,.msg_controllen=sizeof(buf)};
    struct cmsghdr *h=CMSG_FIRSTHDR(&m);h->cmsg_level=SOL_SOCKET;
    h->cmsg_type=SCM_RIGHTS;h->cmsg_len=CMSG_LEN(sizeof(int));
    memcpy(CMSG_DATA(h),&fd,sizeof(fd));if(sendmsg(3,&m,0)!=1) _exit(122);
}
static int recvfd(int sock) {
    char c,buf[CMSG_SPACE(sizeof(int))]={0};struct iovec io={&c,1};
    struct msghdr m={.msg_iov=&io,.msg_iovlen=1,.msg_control=buf,.msg_controllen=sizeof(buf)};
    if(recvmsg(sock,&m,MSG_CMSG_CLOEXEC)!=1) return -1;
    struct cmsghdr *h=CMSG_FIRSTHDR(&m);int fd=-1;
    if(!h||h->cmsg_type!=SCM_RIGHTS||h->cmsg_len!=CMSG_LEN(sizeof(int))) return -1;
    memcpy(&fd,CMSG_DATA(h),sizeof(fd));return fd;
}
static double cpu(struct rusage *r) {
    return r->ru_utime.tv_sec+r->ru_stime.tv_sec+
           (r->ru_utime.tv_usec+r->ru_stime.tv_usec)/1e6;
}
static uint64_t number(const char *s) {
    char *e; errno=0; unsigned long long n=strtoull(s,&e,10);
    if(errno||!*s||*e||s[0]=='-') dd1_die("numeric argument");
    return n;
}
int main(int argc,char **argv) {
    /* root output raw-cap workload-cpu wall-ms thread-cap controller-pid
     * lease-fd executable [argv...]. All supplied by the fixed Python backend. */
    if(argc<10) return 2;
    struct utsname u;if(uname(&u)||strcmp(u.machine,"x86_64")||sizeof(void*)!=8) return 3;
    struct seccomp_notif_sizes sizes;
    if(syscall(SYS_seccomp,SECCOMP_GET_NOTIF_SIZES,0,&sizes) ||
       sizes.seccomp_notif!=sizeof(struct seccomp_notif) ||
       sizes.seccomp_notif_resp!=sizeof(struct seccomp_notif_resp) ||
       sizes.seccomp_data!=sizeof(struct seccomp_data)) return 6;
    uint64_t cap=number(argv[3]),used=0,wall=number(argv[5]);
    unsigned workcpu=number(argv[4]),maxthreads=number(argv[6]);
    pid_t controller=number(argv[7]);int lease=number(argv[8]);
    if(!cap||workcpu<1||workcpu>290||wall<100||wall>3600000||maxthreads<1||maxthreads>4||lease<3) return 4;
    parent_death(controller);
    struct sigaction sa={.sa_handler=stop};sigemptyset(&sa.sa_mask);
    sigaction(SIGTERM,&sa,0);sigaction(SIGINT,&sa,0);sigaction(SIGHUP,&sa,0);
    sigaction(SIGALRM,&sa,0);sigaction(SIGXCPU,&sa,0);
    struct itimerval timer={.it_value={wall/1000,(wall%1000)*1000}};
    if(setitimer(ITIMER_REAL,&timer,0)) dd1_die("wall timer");
    /* Pin to ONE allowed CPU. Kernel process CPU limits include all workload
     * threads. No scheduler/affinity/priority-changing syscall is permitted. */
    cpu_set_t allowed,one;CPU_ZERO(&allowed);CPU_ZERO(&one);
    if(sched_getaffinity(0,sizeof(allowed),&allowed)) dd1_die("affinity read");
    int c;for(c=0;c<CPU_SETSIZE;c++) if(CPU_ISSET(c,&allowed)) break;
    if(c==CPU_SETSIZE) return 5;
    CPU_SET(c,&one);
    if(sched_setaffinity(0,sizeof(one),&one)) dd1_die("affinity set");
    int s[2];if(socketpair(AF_UNIX,SOCK_STREAM|SOCK_CLOEXEC,0,s)) dd1_die("control socket");
    pid_t supervisor=getpid(),pid=fork();if(pid<0) dd1_die("fork workload");
    if(!pid) {
        parent_death(supervisor);close(s[0]);
        limit(RLIMIT_CPU,workcpu);limit(RLIMIT_CORE,0);limit(RLIMIT_AS,2ULL<<30);
        limit(RLIMIT_NOFILE,128);limit(RLIMIT_FSIZE,cap);
        /* Open streams before chroot; ONLY these and bootstrap socket survive.
         * Root and output are fresh private owned snapshots, never source aliases. */
        char p[4096];snprintf(p,sizeof(p),"%s/stdout.bin",argv[2]);
        int out=open(p,O_WRONLY|O_CREAT|O_EXCL|O_NOFOLLOW,0600);if(out<0) dd1_die("stdout");
        snprintf(p,sizeof(p),"%s/stderr.bin",argv[2]);
        int err=open(p,O_WRONLY|O_CREAT|O_EXCL|O_NOFOLLOW,0600);if(err<0) dd1_die("stderr");
        int in=open("/dev/null",O_RDONLY);if(in<0) dd1_die("stdin");
        if(dup2(in,0)<0||dup2(out,1)<0||dup2(err,2)<0) dd1_die("streams");
        int sock=fcntl(s[1],F_DUPFD_CLOEXEC,64);if(sock<0) dd1_die("socket dup");
        /* NOFILE does not close inherited high fds. Place socket before closing. */
        if(dup2(sock,3)<0) dd1_die("control fd");
        if(syscall(SYS_close_range,4U,~0U,0)) dd1_die("close inherited descriptors");
        dd1_isolate(argv[1],argv[2]);
        parent_death(supervisor); /* credentials/setup cannot erase the guard */
        int listener=dd1_listener();if(listener<0) dd1_die("seccomp listener");
        sendfd(listener);close(listener);close(3);
        char *env[]={"HOME=/out","TMPDIR=/out","LANG=C","LC_ALL=C",
             "XDG_DATA_HOME=/out/data","XDG_CACHE_HOME=/out/cache",
             "DD1_RESERVED_UNIT_PATH=/grant.json",
             "DD1_NATIVE_LAUNCH_RECEIPT=/launch-receipt.json",NULL};
        execve(argv[9],&argv[9],env);_exit(123);
    }
    limit(RLIMIT_CPU,2);limit(RLIMIT_CORE,0);
    close(s[1]);
    /* Small bounded bootstrap receipt enables parent/subreaper crash controls. */
    printf("{\"phase\":\"started\",\"supervisor\":%d,\"workload\":%d}\n",getpid(),pid);fflush(stdout);
    int listener=recvfd(s[0]);close(s[0]);
    unsigned threads=1,execs=0,denied=0,clone3=0,requests=0;int last=-1,status=0,channel=0;
    if(listener<0) {channel=1;kill(pid,SIGKILL);}
    struct rusage wr={0},sr={0};int reaped=0;
    while(listener>=0&&!stopped) {
        pid_t w=wait4(pid,&status,WNOHANG,&wr);
        if(w==pid) {reaped=1;break;}
        if(w<0) {channel=1;break;}
        struct pollfd p={.fd=listener,.events=POLLIN};
        int ready=poll(&p,1,50);
        if(ready<0&&errno!=EINTR) {channel=1;break;}
        if(ready>0&&(p.revents&POLLIN)) {
            ++requests;
            if(dd1_notify(listener,cap,&used,&threads,maxthreads,&execs,&denied,&last,&clone3)) {channel=1;break;}
        }
    }
    if(!reaped) {
        kill(pid,SIGKILL);
        while(wait4(pid,&status,0,&wr)<0) {if(errno!=EINTR) dd1_die("wait workload");}
        reaped=1;
    }
    if(listener>=0) close(listener);
    getrusage(RUSAGE_SELF,&sr);
    int exitcode=WIFEXITED(status)?WEXITSTATUS(status):-1;
    int sig=WIFSIGNALED(status)?WTERMSIG(status):0;
    int success=!stopped&&!channel&&!denied&&execs==1&&exitcode==0;
    printf("{\"phase\":\"result\",\"success\":%s,\"reserved_before_writes\":%llu,"
       "\"raw_cap\":%llu,\"denied\":%u,\"last_denied_syscall\":%d,\"clone3_denied\":%u,"
       "\"thread_births_including_main\":%u,\"execs\":%u,\"requests\":%u,"
       "\"exit\":%d,\"signal\":%d,\"stop_signal\":%d,\"channel_failure\":%d,"
       "\"workload_cpu_seconds\":%.6f,\"supervisor_cpu_seconds\":%.6f,\"cleanup_confirmed\":true}\n",
       success?"true":"false",(unsigned long long)used,(unsigned long long)cap,denied,last,clone3,
       threads,execs,requests,exitcode,sig,(int)stopped,channel,cpu(&wr),cpu(&sr));
    close(lease);return success?0:1;
}
