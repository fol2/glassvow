#define _GNU_SOURCE
#include "godot_runtime_ptrace_io.h"
#include <errno.h>
#include <fcntl.h>
#include <inttypes.h>
#include <linux/audit.h>
#include <linux/netlink.h>
#include <linux/sched.h>
#include <signal.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ptrace.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/syscall.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>
#if !defined(__linux__) || !defined(__x86_64__)
#error "The Godot runtime tracer supports Linux x86_64 only."
#endif
#define MAX_TASKS 16
#define MAX_CAPTURE (12U * 1024U * 1024U)
#define MAX_TOTAL_CAPTURE (32U * 1024U * 1024U)
#define PROC_CAPTURE 65536U
#define MAX_SYSCALLS 16384U
#define MAX_PATH_EVENTS 8192U
#define MAX_READ_EVENTS 1024U
#define MAX_WRITE_EVENTS 256U
#define MAX_MMAP_EVENTS 512U
#define MAX_OPEN_FDS 64U
#define MAX_OPEN_EVENTS 2048U
#define MAX_CLOSE_EVENTS 2048U
#define MAX_SOCKET_EVENTS 2U
#define MAX_BIND_EVENTS 2U
#define MAX_EXEC_EVENTS 4U
#define MAX_LINEAGE_EVENTS 9U
#define MAX_DUP_EVENTS 5U
#define MAX_ADDRESS_SPACE (1152ULL * 1024ULL * 1024ULL)
#define MAX_INITIAL_STACK (16ULL * 1024ULL * 1024ULL)
#define MAX_SEMANTIC_READ_BYTES (16U * 1024U * 1024U)
#define MAX_TRACE_BYTES (64U * 1024U * 1024U)
#define MAX_ADMISSION_POLICY_BYTES (384U * 1024U)
#define TRACE_END_RESERVE 32768U
#define GV_PTRACE_GET_SYSCALL_INFO 0x420e
#define GV_SYSCALL_INFO_ENTRY 1
#define GV_SYSCALL_INFO_EXIT 2
struct gv_syscall_info {
    uint8_t op, pad[3];
    uint32_t arch;
    uint64_t instruction_pointer, stack_pointer;
    union {
        struct { uint64_t nr, args[6]; } entry;
        struct { int64_t rval; uint8_t is_error; } exit;
    } data;
};
struct syscall_name { long number; const char *name; };
static const struct syscall_name allowed_syscalls[] = {
    {SYS_access,"access"},{SYS_arch_prctl,"arch_prctl"},{SYS_bind,"bind"},
    {SYS_brk,"brk"},{SYS_chdir,"chdir"},{SYS_clock_nanosleep,"clock_nanosleep"},
    {SYS_clone3,"clone3"},{SYS_close,"close"},{SYS_dup2,"dup2"},
    {SYS_execve,"execve"},{SYS_exit,"exit"},{SYS_exit_group,"exit_group"},
    {SYS_faccessat2,"faccessat2"},{SYS_fadvise64,"fadvise64"},
    {SYS_fcntl,"fcntl"},{SYS_fstat,"fstat"},{SYS_fstatfs,"fstatfs"},
    {SYS_futex,"futex"},{SYS_getcwd,"getcwd"},{SYS_getdents64,"getdents64"},
    {SYS_getegid,"getegid"},{SYS_geteuid,"geteuid"},{SYS_getgid,"getgid"},
    {SYS_getpid,"getpid"},{SYS_getppid,"getppid"},{SYS_getrandom,"getrandom"},
    {SYS_getresgid,"getresgid"},{SYS_getresuid,"getresuid"},
    {SYS_getsockname,"getsockname"},{SYS_getsockopt,"getsockopt"},
    {SYS_getuid,"getuid"},{SYS_lseek,"lseek"},{SYS_lstat,"lstat"},
    {SYS_madvise,"madvise"},{SYS_mkdir,"mkdir"},{SYS_mmap,"mmap"},
    {SYS_mprotect,"mprotect"},{SYS_munmap,"munmap"},{SYS_newfstatat,"newfstatat"},
    {SYS_openat,"openat"},{SYS_pipe2,"pipe2"},{SYS_poll,"poll"},
    {SYS_prctl,"prctl"},{SYS_pread64,"pread64"},{SYS_prlimit64,"prlimit64"},
    {SYS_read,"read"},{SYS_readlink,"readlink"},{SYS_readlinkat,"readlinkat"},
    {SYS_rseq,"rseq"},{SYS_rt_sigaction,"rt_sigaction"},
    {SYS_rt_sigprocmask,"rt_sigprocmask"},{SYS_rt_sigreturn,"rt_sigreturn"},
    {SYS_set_robust_list,"set_robust_list"},{SYS_set_tid_address,"set_tid_address"},
    {SYS_setsockopt,"setsockopt"},{SYS_socket,"socket"},{SYS_stat,"stat"},
    {SYS_statx,"statx"},{SYS_vfork,"vfork"},{SYS_wait4,"wait4"},
    {SYS_write,"write"},
};
struct task {
    pid_t pid;
    bool active, options_set, have_entry, resumed_entry, expected_attach_stop;
    long number;
    uint64_t args[6], clone_flags, clone_exit_signal;
    int64_t read_offset;
    char path[4096], resolved[4096];
    struct gv_object_identity closing_object;
    bool have_closing_object;
    sa_family_t bind_family;
    uint32_t bind_pid, bind_groups;
    socklen_t bind_length;
};
enum lineage_preparation {
    LINEAGE_PREPARE_INVALID,
    LINEAGE_PREPARE_TASK_CAP,
    LINEAGE_WAITING_ATTACH,
    LINEAGE_HELD_ATTACH,
};
static FILE *trace;
static int sidecar_fd = -1;
static struct gv_admission_policy admission_policy;
static struct task tasks[MAX_TASKS];
static pid_t pending_attach[MAX_LINEAGE_EVENTS];
static size_t task_count, active_count, captured_bytes;
static size_t pending_attach_count;
static uint64_t sequence, stops, entries, exits, resumed_exits, lineage_events;
static uint64_t path_events, read_events, write_events, mmap_events, open_events;
static uint64_t close_events, socket_events, bind_events, exec_events;
static uint64_t semantic_read_bytes, dup_events;
static uint64_t start_ns;
static pid_t root_pid;
static int root_exit = 255;
static const char *violation;
static bool terminating;
static char product_root[4096], packet_root[4096], home_root[4096], output_root[4096];
static char observation_path[4096], godot_log_path[4096], sentry_path[4096];
static char identity_exception[4096];
static const char *challenge;
static int decode_syscall_fd(uint64_t raw) {
    return (int32_t)(uint32_t)raw;
}
static void hex(const char *value) {
    static const char digits[] = "0123456789abcdef";
    for (const unsigned char *p = (const unsigned char *)value; *p; p += 1) {
        fputc(digits[*p >> 4], trace); fputc(digits[*p & 15], trace);
    }
}
static void fail(pid_t pid, const char *reason) {
    if (violation == NULL) {
        violation = reason;
        fprintf(trace, "VIOLATION\t%" PRIu64 "\t%d\t%s\n", ++sequence, pid, reason);
        fflush(trace);
    }
    if (terminating) return;
    terminating = true;
    for (size_t i = 0; i < task_count; i += 1) {
        if (tasks[i].active) {
            kill(tasks[i].pid, SIGKILL);
            ptrace(PTRACE_CONT, tasks[i].pid, 0, SIGKILL);
        }
    }
    for (size_t i = 0; i < pending_attach_count; i += 1) {
        kill(pending_attach[i], SIGKILL);
        ptrace(PTRACE_CONT, pending_attach[i], 0, SIGKILL);
    }
}
static const char *syscall_name(long number) {
    for (size_t i = 0; i < sizeof(allowed_syscalls) / sizeof(*allowed_syscalls); i += 1)
        if (allowed_syscalls[i].number == number) return allowed_syscalls[i].name;
    return NULL;
}
static struct task *find_task(pid_t pid) {
    for (size_t i = 0; i < task_count; i += 1) if (tasks[i].pid == pid) return &tasks[i];
    return NULL;
}
static struct task *add_task(pid_t pid) {
    struct task *known = find_task(pid);
    if (known != NULL) return known;
    if (task_count == MAX_TASKS) return NULL;
    struct task *task = &tasks[task_count++];
    memset(task, 0, sizeof(*task));
    task->pid = pid; task->active = true; active_count += 1;
    return task;
}
static bool defer_attach_stop(pid_t pid, int status) {
    if (pid <= 0 || !WIFSTOPPED(status) || WSTOPSIG(status) != SIGSTOP
            || (unsigned int)status >> 16 != 0
            || task_count + pending_attach_count >= MAX_TASKS
            || lineage_events + pending_attach_count >= MAX_LINEAGE_EVENTS) return false;
    for (size_t i = 0; i < pending_attach_count; i += 1)
        if (pending_attach[i] == pid) return false;
    pending_attach[pending_attach_count++] = pid;
    return true;
}
static bool take_pending_attach(pid_t pid) {
    for (size_t i = 0; i < pending_attach_count; i += 1) {
        if (pending_attach[i] != pid) continue;
        pending_attach[i] = pending_attach[--pending_attach_count];
        return true;
    }
    return false;
}
static bool consume_expected_attach_stop(
        struct task *task, int signal_number, unsigned int event) {
    if (!task->expected_attach_stop || signal_number != SIGSTOP || event != 0)
        return false;
    task->expected_attach_stop = false;
    return true;
}
static bool set_options(struct task *task) {
    if (task->options_set) return true;
    long options = PTRACE_O_TRACESYSGOOD | PTRACE_O_TRACEFORK | PTRACE_O_TRACEVFORK
        | PTRACE_O_TRACEVFORKDONE | PTRACE_O_TRACECLONE | PTRACE_O_TRACEEXEC
        | PTRACE_O_TRACEEXIT | PTRACE_O_EXITKILL;
    if (ptrace(PTRACE_SETOPTIONS, task->pid, 0, options) != 0) {
        fail(task->pid, "UNTRACEABLE_TASK"); return false;
    }
    task->options_set = true; return true;
}
#define classify(path) gv_path_category(path, product_root, packet_root, identity_exception, \
    observation_path, godot_log_path, sentry_path)
#define named_write_path(path) gv_named_write_path( \
    path, observation_path, godot_log_path, sentry_path)
#define named_output_ancestor(path) gv_named_output_ancestor( \
    path, observation_path, godot_log_path, sentry_path)
static bool append_blob(pid_t pid, const void *bytes, size_t count, uint64_t *offset) {
    if (count > MAX_CAPTURE || captured_bytes + count > MAX_TOTAL_CAPTURE) {
        fail(pid, "BYTE_CAPTURE_CAP_EXCEEDED"); return false;
    }
    *offset = captured_bytes;
    if (!gv_write_all(sidecar_fd, bytes, count)) {
        fail(pid, "SIDECAR_WRITE_FAILED"); return false;
    }
    captured_bytes += count; return true;
}
static void capture_exec(pid_t pid) {
    if (++exec_events > MAX_EXEC_EVENTS) { fail(pid, "EXEC_EVENT_CAP_EXCEEDED"); return; }
    unsigned char *buffer = malloc(PROC_CAPTURE);
    struct gv_object_identity object;
    pid_t tgid;
    char proc_exe[64];
    snprintf(proc_exe, sizeof(proc_exe), "/proc/%d/exe", pid);
    struct stat status;
    ssize_t path_count = readlink(proc_exe, object.path, sizeof(object.path) - 1);
    if (buffer == NULL || path_count < 0 || stat(proc_exe, &status) != 0
            || !gv_process_tgid(pid, &tgid)) {
        free(buffer); fail(pid, "EXEC_IDENTITY_UNAVAILABLE"); return;
    }
    object.path[path_count] = '\0'; object.device = status.st_dev; object.inode = status.st_ino;
    ssize_t argc = gv_read_proc_file(pid, "cmdline", buffer, PROC_CAPTURE);
    uint64_t argv_offset, env_offset;
    if (argc <= 0 || argc == PROC_CAPTURE
            || !append_blob(pid, buffer, (size_t)argc, &argv_offset)) {
        free(buffer); fail(pid, "EXEC_ARGV_UNAVAILABLE"); return;
    }
    ssize_t envc = gv_read_proc_file(pid, "environ", buffer, PROC_CAPTURE);
    if (envc < 0 || envc == PROC_CAPTURE
            || !append_blob(pid, buffer, (size_t)envc, &env_offset)) {
        free(buffer); fail(pid, "EXEC_ENV_UNAVAILABLE"); return;
    }
    fprintf(trace, "EXEC\t%" PRIu64 "\t%d\t%d\t%" PRIu64 "\t%zd\t%" PRIu64
        "\t%zd\t%ju\t%ju\t", ++sequence, pid, tgid, argv_offset, argc,
        env_offset, envc, (uintmax_t)object.device, (uintmax_t)object.inode);
    hex(object.path); fputc('\n', trace); free(buffer);
}
static void path_entry(struct task *task, const char *name) {
    int dirfd = AT_FDCWD; uint64_t address = task->args[0];
    if (!strcmp(name,"openat") || !strcmp(name,"newfstatat")
            || !strcmp(name,"faccessat2") || !strcmp(name,"readlinkat")
            || !strcmp(name,"statx")) {
        dirfd = (int)task->args[0]; address = task->args[1];
    }
    bool follow_final = true;
    if (!strcmp(name, "lstat") || !strcmp(name, "mkdir")
            || !strcmp(name, "readlink") || !strcmp(name, "readlinkat"))
        follow_final = false;
    else if (!strcmp(name, "openat") && (task->args[2] & O_NOFOLLOW))
        follow_final = false;
    else if ((!strcmp(name, "newfstatat") || !strcmp(name, "faccessat2"))
            && (task->args[3] & AT_SYMLINK_NOFOLLOW))
        follow_final = false;
    else if (!strcmp(name, "statx") && (task->args[2] & AT_SYMLINK_NOFOLLOW))
        follow_final = false;
    if (!gv_copy_string(task->pid, address, task->path, sizeof(task->path))
            || !gv_resolve_path(task->pid, dirfd, task->path, follow_final,
                               task->resolved, sizeof(task->resolved))) {
        fail(task->pid, "PATH_RESOLUTION_FAILED"); return;
    }
    if (++path_events > MAX_PATH_EVENTS) { fail(task->pid, "PATH_EVENT_CAP_EXCEEDED"); return; }
    fprintf(trace, "PATH\t%" PRIu64 "\t%d\t%s\t", ++sequence, task->pid, name);
    hex(task->path); fputc('\t', trace); hex(task->resolved); fputc('\n', trace);
    bool has_parameter = !strcmp(name, "openat") || !strcmp(name, "mkdir");
    uint64_t parameter = !strcmp(name, "openat") ? task->args[2] : task->args[1];
    if (!gv_policy_allows_path(
            &admission_policy, name, task->resolved, has_parameter, parameter)) {
        fail(task->pid, "UNDECLARED_PATH_PRE_EFFECT"); return;
    }
    bool writes = !strcmp(name, "mkdir");
    bool stderr_sink_open = false;
    if (!strcmp(name, "openat")) {
        uint64_t flags = task->args[2];
        writes = (flags & (O_WRONLY | O_RDWR | O_CREAT | O_TRUNC | O_APPEND)) != 0;
        stderr_sink_open = !strcmp(task->resolved, "/dev/null")
            && flags == (O_WRONLY | O_CREAT | O_TRUNC);
    }
    if (!strcmp(name, "mkdir")) {
        bool named_fresh_ancestor =
            (gv_path_within(task->resolved, home_root)
                || gv_path_within(task->resolved, output_root))
            && named_output_ancestor(task->resolved);
        bool existing_home_ancestor =
            gv_path_is_strict_ancestor(task->resolved, home_root)
            && gv_existing_directory(task->resolved);
        if (!named_fresh_ancestor && !existing_home_ancestor)
            fail(task->pid, "UNDECLARED_MKDIR_PATH");
    } else if (writes && !named_write_path(task->resolved) && !stderr_sink_open)
        fail(task->pid, "UNDECLARED_WRITE_PATH");
}
static void syscall_entry(struct task *task, struct gv_syscall_info *info) {
    task->number = (long)info->data.entry.nr;
    memcpy(task->args, info->data.entry.args, sizeof(task->args));
    task->have_entry = true; task->resumed_entry = false; task->path[0] = '\0';
    task->have_closing_object = false;
    const char *name = syscall_name(task->number);
    fprintf(trace, "SYSCALL_E\t%" PRIu64 "\t%d\t%ld\t%s", ++sequence,
            task->pid, task->number, name == NULL ? "-" : name);
    for (int i = 0; i < 6; i += 1) fprintf(trace, "\t%" PRIu64, task->args[i]);
    fputc('\n', trace); entries += 1;
    if (name == NULL) { fail(task->pid, "UNSUPPORTED_SYSCALL"); return; }
    if (task->number == SYS_clone3) {
        struct clone_args clone = {0};
        size_t clone_size = task->args[1] < sizeof(clone) ? task->args[1] : sizeof(clone);
        if (task->args[1] < sizeof(uint64_t)
                || !gv_copy_memory(task->pid, task->args[0], &clone, clone_size)) {
            fail(task->pid, "CLONE3_ARGUMENTS_UNAVAILABLE"); return;
        }
        task->clone_flags = clone.flags;
        task->clone_exit_signal = clone.exit_signal;
        if ((clone.flags & CLONE_UNTRACED) != 0) fail(task->pid, "UNTRACEABLE_CLONE_FLAG");
    }
    if (task->number == SYS_socket) {
        if ((int)task->args[0] != AF_NETLINK
                || (int)task->args[1] != (SOCK_RAW | SOCK_CLOEXEC | SOCK_NONBLOCK)
                || (int)task->args[2] != NETLINK_KOBJECT_UEVENT)
            fail(task->pid, "EXTERNAL_NETWORK_SOCKET");
    }
    if (task->number == SYS_bind) {
        struct sockaddr_nl address = {0}; task->bind_length = (socklen_t)task->args[2];
        if (task->args[2] != sizeof(address)
                || !gv_copy_memory(task->pid, task->args[1], &address, sizeof(address))
                || address.nl_family != AF_NETLINK) fail(task->pid, "EXTERNAL_NETWORK_BIND");
        task->bind_family = address.nl_family; task->bind_pid = address.nl_pid;
        task->bind_groups = address.nl_groups;
    }
    if (task->number == SYS_fcntl && task->args[1] != F_GETFD
            && task->args[1] != F_SETFD && task->args[1] != F_DUPFD)
        fail(task->pid, "UNSUPPORTED_FCNTL_COMMAND");
    if (task->number == SYS_fcntl && ((task->args[1] == F_SETFD
            && task->args[2] != 0 && task->args[2] != FD_CLOEXEC)
            || (task->args[1] == F_DUPFD && task->args[2] != 10)))
        fail(task->pid, "UNSUPPORTED_FCNTL_ARGUMENT");
    if (task->number == SYS_pipe2 && task->args[1] != O_CLOEXEC)
        fail(task->pid, "UNDECLARED_PIPE_FLAGS");
    if (task->number == SYS_close)
        task->have_closing_object = gv_fd_identity(
            task->pid, (int)task->args[0], &task->closing_object);
    if (task->number == SYS_read || task->number == SYS_write) {
        if (!gv_fd_offset(task->pid, (int)task->args[0], &task->read_offset))
            task->read_offset = -1;
    } else if (task->number == SYS_pread64) task->read_offset = (int64_t)task->args[3];
    if (task->number == SYS_access || task->number == SYS_chdir
            || task->number == SYS_execve || task->number == SYS_lstat
            || task->number == SYS_mkdir || task->number == SYS_readlink
            || task->number == SYS_stat || task->number == SYS_faccessat2
            || task->number == SYS_newfstatat || task->number == SYS_openat
            || task->number == SYS_readlinkat || task->number == SYS_statx)
        path_entry(task, name);
}
static bool object_for_fd(pid_t pid, int fd, struct gv_object_identity *object) {
    if (gv_fd_identity(pid, fd, object)) return true;
    memset(object, 0, sizeof(*object)); strcpy(object->path, "-"); return false;
}
static void record_io(struct task *task, const char *name, int64_t returned) {
    if (returned <= 0) return;
    if ((uint64_t)returned > task->args[2] || (uint64_t)returned > MAX_CAPTURE) {
        fail(task->pid, "INVALID_IO_LENGTH"); return;
    }
    void *bytes = malloc((size_t)returned); uint64_t blob_offset;
    if (bytes == NULL || !gv_copy_memory(task->pid, task->args[1], bytes, (size_t)returned)
            || !append_blob(task->pid, bytes, (size_t)returned, &blob_offset)) {
        free(bytes); fail(task->pid, "ACTUAL_BYTES_UNAVAILABLE"); return;
    }
    int fd = (int)task->args[0]; struct gv_object_identity object;
    bool identified = object_for_fd(task->pid, fd, &object);
    char category = identified ? classify(object.path) : 'U';
    if (strcmp(name, "write") && identified && !strncmp(object.path, "socket:[", 8))
        fail(task->pid, "NETWORK_PAYLOAD_FORBIDDEN");
    if (!strcmp(name, "write")) {
        if (++write_events > MAX_WRITE_EVENTS) fail(task->pid, "WRITE_EVENT_CAP_EXCEEDED");
    } else {
        if (++read_events > MAX_READ_EVENTS) fail(task->pid, "READ_EVENT_CAP_EXCEEDED");
        if (category == 'S') {
            semantic_read_bytes += (uint64_t)returned;
            if (semantic_read_bytes > MAX_SEMANTIC_READ_BYTES)
                fail(task->pid, "SEMANTIC_READ_CAP_EXCEEDED");
        }
    }
    if (!strcmp(name, "write") && fd != STDOUT_FILENO && fd != STDERR_FILENO
            && (!identified || category != 'W')) fail(task->pid, "UNDECLARED_OUTPUT_WRITE");
    if (strcmp(name, "write") && category == 'S' && task->read_offset < 0)
        fail(task->pid, "SEMANTIC_READ_OFFSET_UNAVAILABLE");
    fprintf(trace, "IO\t%" PRIu64 "\t%d\t%s\t%d\t%" PRId64 "\t%" PRIu64
        "\t%" PRId64 "\t%c\t%ju\t%ju\t%" PRIu64 "\t", ++sequence,
        task->pid, name, fd, task->read_offset, task->args[2], returned, category,
        (uintmax_t)object.device, (uintmax_t)object.inode, blob_offset);
    hex(object.path); fputc('\n', trace); free(bytes);
}
static void syscall_exit(struct task *task, struct gv_syscall_info *info) {
    if (!task->have_entry) { fail(task->pid, "UNMATCHED_SYSCALL_EXIT"); return; }
    int64_t returned = info->data.exit.rval;
    const char *name = syscall_name(task->number);
    fprintf(trace, "SYSCALL_X\t%" PRIu64 "\t%d\t%ld\t%s\t%" PRId64 "\t%u\t%d\n",
        ++sequence, task->pid, task->number, name, returned,
        info->data.exit.is_error, task->resumed_entry ? 1 : 0);
    exits += 1; if (task->resumed_entry) resumed_exits += 1;
    if (task->path[0] != '\0') {
        fprintf(trace, "PATH_X\t%" PRIu64 "\t%d\t%s\t%" PRId64 "\t",
                ++sequence, task->pid, name, returned);
        hex(task->resolved); fputc('\n', trace);
    }
    if (returned >= 0 && (task->number == SYS_openat || task->number == SYS_pipe2
            || task->number == SYS_dup2 || task->number == SYS_socket
            || (task->number == SYS_fcntl && task->args[1] == F_DUPFD))) {
        size_t open_fds;
        if (!gv_fd_count(task->pid, &open_fds)) fail(task->pid, "OPEN_FD_COUNT_UNAVAILABLE");
        else if (open_fds > MAX_OPEN_FDS) fail(task->pid, "OPEN_FD_CAP_EXCEEDED");
    }
    if (task->number == SYS_read) record_io(task, "read", returned);
    else if (task->number == SYS_pread64) record_io(task, "pread64", returned);
    else if (task->number == SYS_write) record_io(task, "write", returned);
    else if (task->number == SYS_close && returned == 0) {
        if (!task->have_closing_object) fail(task->pid, "CLOSE_OBJECT_UNAVAILABLE");
        else if (++close_events > MAX_CLOSE_EVENTS) fail(task->pid, "CLOSE_EVENT_CAP_EXCEEDED");
        else {
            fprintf(trace, "CLOSE\t%" PRIu64 "\t%d\t%" PRIu64 "\t%c\t%ju\t%ju\t",
                ++sequence, task->pid, task->args[0], classify(task->closing_object.path),
                (uintmax_t)task->closing_object.device,
                (uintmax_t)task->closing_object.inode);
            hex(task->closing_object.path); fputc('\n', trace);
        }
    }
    else if (task->number == SYS_openat && returned >= 0) {
        struct gv_object_identity object;
        char actual_path[4096];
        bool follow_final = (task->args[2] & O_NOFOLLOW) == 0;
        if (!gv_fd_identity(task->pid, (int)returned, &object)
                || !gv_resolve_path(
                    task->pid, AT_FDCWD, object.path, follow_final,
                    actual_path, sizeof(actual_path))) {
            fail(task->pid, "OPEN_OBJECT_UNAVAILABLE"); return;
        }
        if (strcmp(actual_path, task->resolved)
                || !gv_policy_allows_path(
                    &admission_policy, "openat", actual_path, true, task->args[2])) {
            fail(task->pid, "OPEN_IDENTITY_PATH_MISMATCH"); return;
        }
        if (++open_events > MAX_OPEN_EVENTS) {
            fail(task->pid, "OPEN_EVENT_CAP_EXCEEDED"); return;
        }
        fprintf(trace, "OPEN\t%" PRIu64 "\t%d\t%" PRId64 "\t%" PRIu64
            "\t%c\t%ju\t%ju\t", ++sequence, task->pid, returned, task->args[2],
            classify(actual_path), (uintmax_t)object.device, (uintmax_t)object.inode);
        hex(actual_path); fputc('\n', trace);
    } else if (task->number == SYS_pipe2 && returned == 0) {
        int fds[2]; struct gv_object_identity object;
        if (!gv_pipe_identity(task->pid, task->args[0], fds, &object))
            fail(task->pid, "PIPE_OBJECT_UNAVAILABLE");
        else {
            fprintf(trace, "PIPE\t%" PRIu64 "\t%d\t%d\t%d\t%ju\t%ju\t",
                ++sequence, task->pid, fds[0], fds[1], (uintmax_t)object.device,
                (uintmax_t)object.inode);
            hex(object.path); fputc('\n', trace);
        }
    } else if (task->number == SYS_mmap && returned >= 0
            && decode_syscall_fd(task->args[4]) >= 0) {
        if (++mmap_events > MAX_MMAP_EVENTS) { fail(task->pid, "MMAP_EVENT_CAP_EXCEEDED"); }
        struct gv_object_identity object;
        if (!gv_fd_identity(task->pid, decode_syscall_fd(task->args[4]), &object))
            fail(task->pid, "MMAP_OBJECT_UNAVAILABLE");
        else {
            char category = classify(object.path);
            fprintf(trace, "MMAP\t%" PRIu64 "\t%d\t%" PRId64 "\t%" PRIu64
                "\t%" PRIu64 "\t%" PRIu64 "\t%" PRIu64 "\t%" PRIu64
                "\t%c\t%ju\t%ju\t", ++sequence, task->pid, returned,
                task->args[1], task->args[2], task->args[3], task->args[4],
                task->args[5], category,
                (uintmax_t)object.device, (uintmax_t)object.inode);
            hex(object.path); fputc('\n', trace);
            if (category == 'S') fail(task->pid, "SEMANTIC_MAPPING_DENIED");
        }
    } else if (task->number == SYS_socket) {
        if (++socket_events > MAX_SOCKET_EVENTS) fail(task->pid, "SOCKET_EVENT_CAP_EXCEEDED");
        else fprintf(trace, "SOCKET\t%" PRIu64 "\t%d\t%" PRId64 "\t%" PRIu64
            "\t%" PRIu64 "\t%" PRIu64 "\n", ++sequence, task->pid, returned,
            task->args[0], task->args[1], task->args[2]);
    } else if (task->number == SYS_bind) {
        if (++bind_events > MAX_BIND_EVENTS)
            fail(task->pid, "BIND_EVENT_CAP_EXCEEDED");
        else fprintf(trace, "BIND\t%" PRIu64 "\t%d\t%" PRIu64 "\t%u\t%u\t%u\t%u\t%" PRId64 "\n",
            ++sequence, task->pid, task->args[0], task->bind_family, task->bind_pid,
            task->bind_groups, task->bind_length, returned);
    } else if (returned >= 0 && (task->number == SYS_dup2
            || (task->number == SYS_fcntl && task->args[1] == F_DUPFD))) {
        struct gv_object_identity object;
        if (++dup_events > MAX_DUP_EVENTS) fail(task->pid, "DUP_EVENT_CAP_EXCEEDED");
        else if (!gv_fd_identity(task->pid, (int)returned, &object))
            fail(task->pid, "DUP_OBJECT_UNAVAILABLE");
        else {
            fprintf(trace, "DUP\t%" PRIu64 "\t%d\t%s\t%" PRIu64 "\t%" PRId64
                "\t0\t%c\t%ju\t%ju\t", ++sequence, task->pid,
                task->number == SYS_dup2 ? "dup2" : "fcntl", task->args[0],
                returned, classify(object.path), (uintmax_t)object.device,
                (uintmax_t)object.inode);
            hex(object.path); fputc('\n', trace);
        }
    }
    task->have_entry = false;
}
static void handle_syscall(struct task *task) {
    struct gv_syscall_info info = {0};
    long result = ptrace((enum __ptrace_request)GV_PTRACE_GET_SYSCALL_INFO,
                         task->pid, sizeof(info), &info);
    if (result < 0 || info.arch != AUDIT_ARCH_X86_64) {
        fail(task->pid, "SYSCALL_OBSERVATION_UNAVAILABLE"); return;
    }
    if (info.op == GV_SYSCALL_INFO_ENTRY) {
        if (entries >= MAX_SYSCALLS) fail(task->pid, "SYSCALL_CAP_EXCEEDED");
        else syscall_entry(task, &info);
    }
    else if (info.op == GV_SYSCALL_INFO_EXIT) syscall_exit(task, &info);
    else fail(task->pid, "UNKNOWN_SYSCALL_STOP");
}
static bool decode_lineage(const struct task *parent, unsigned int event,
                           const char **kind, uint64_t *flags) {
    *flags = 0;
    if (parent->number == SYS_clone3) {
        unsigned int expected_event;
        if ((parent->clone_flags & CLONE_VFORK) != 0)
            expected_event = PTRACE_EVENT_VFORK;
        else if ((parent->clone_flags & CLONE_THREAD) != 0
                || parent->clone_exit_signal != SIGCHLD)
            expected_event = PTRACE_EVENT_CLONE;
        else
            expected_event = PTRACE_EVENT_FORK;
        if (event != expected_event) return false;
        *kind = (parent->clone_flags & CLONE_THREAD) != 0
            ? "clone_thread" : "clone_process";
        *flags = parent->clone_flags;
        return true;
    }
    if (parent->number == SYS_vfork && event == PTRACE_EVENT_VFORK) {
        *kind = "vfork_process";
        return true;
    }
    return false;
}
static enum lineage_preparation prepare_lineage(
        struct task *parent, unsigned int event, pid_t child_pid,
        struct task **child, const char **kind, uint64_t *flags) {
    if (!decode_lineage(parent, event, kind, flags)) return LINEAGE_PREPARE_INVALID;
    *child = add_task(child_pid);
    if (*child == NULL) return LINEAGE_PREPARE_TASK_CAP;
    bool attach_stop_received = take_pending_attach((*child)->pid);
    (*child)->number = parent->number;
    memcpy((*child)->args, parent->args, sizeof((*child)->args));
    (*child)->have_entry = true;
    (*child)->resumed_entry = true;
    (*child)->expected_attach_stop = !attach_stop_received;
    return attach_stop_received ? LINEAGE_HELD_ATTACH : LINEAGE_WAITING_ATTACH;
}
static void reset_lineage_self_test_state(void) {
    memset(tasks, 0, sizeof(tasks));
    task_count = 0;
    active_count = 0;
    pending_attach_count = 0;
    lineage_events = 0;
}
static bool pending_attach_self_test(void) {
    const pid_t parent_pid = 7000, child_pid = 7001;
    int stop_status = (SIGSTOP << 8) | 0x7f;
    int trap_status = (SIGTRAP << 8) | 0x7f;
    int event_status = stop_status | (PTRACE_EVENT_VFORK << 16);
    struct task parent = {.pid = parent_pid, .number = SYS_vfork,
        .have_entry = true, .args = {11, 12, 13, 14, 15, 16}};
    struct task *child = NULL;
    const char *kind = NULL;
    uint64_t flags = UINT64_MAX;

    reset_lineage_self_test_state();
    bool child_first = defer_attach_stop(child_pid, stop_status)
        && prepare_lineage(&parent, PTRACE_EVENT_VFORK, child_pid,
                           &child, &kind, &flags) == LINEAGE_HELD_ATTACH
        && pending_attach_count == 0 && task_count == 1 && active_count == 1
        && child != NULL && child->active && child->number == SYS_vfork
        && child->have_entry && child->resumed_entry && !child->expected_attach_stop
        && !memcmp(child->args, parent.args, sizeof(child->args))
        && !strcmp(kind, "vfork_process") && flags == 0;

    reset_lineage_self_test_state(); child = NULL; kind = NULL; flags = UINT64_MAX;
    enum lineage_preparation parent_first = prepare_lineage(
        &parent, PTRACE_EVENT_VFORK, child_pid, &child, &kind, &flags);
    bool parent_first_once = parent_first == LINEAGE_WAITING_ATTACH
        && child != NULL && child->expected_attach_stop
        && consume_expected_attach_stop(child, SIGSTOP, 0)
        && !child->expected_attach_stop
        && !consume_expected_attach_stop(child, SIGSTOP, 0);

    reset_lineage_self_test_state(); child = NULL; kind = NULL; flags = UINT64_MAX;
    bool wrong_event = defer_attach_stop(child_pid, stop_status)
        && prepare_lineage(&parent, PTRACE_EVENT_CLONE, child_pid,
                           &child, &kind, &flags) == LINEAGE_PREPARE_INVALID
        && child == NULL && pending_attach_count == 1 && task_count == 0;

    reset_lineage_self_test_state(); child = NULL; kind = NULL; flags = UINT64_MAX;
    bool wrong_pid = defer_attach_stop(child_pid, stop_status)
        && prepare_lineage(&parent, PTRACE_EVENT_VFORK, child_pid + 1,
                           &child, &kind, &flags) == LINEAGE_WAITING_ATTACH
        && pending_attach_count == 1 && child != NULL
        && child->expected_attach_stop;

    reset_lineage_self_test_state();
    bool malformed = !defer_attach_stop(child_pid, trap_status)
        && !defer_attach_stop(child_pid, event_status)
        && defer_attach_stop(child_pid, stop_status)
        && !defer_attach_stop(child_pid, stop_status)
        && pending_attach_count == 1;

    reset_lineage_self_test_state();
    bool filled = true;
    for (size_t i = 0; i < MAX_LINEAGE_EVENTS; i += 1)
        filled = filled && defer_attach_stop(child_pid + (pid_t)i, stop_status);
    bool capped = filled
        && !defer_attach_stop(child_pid + MAX_LINEAGE_EVENTS, stop_status)
        && pending_attach_count == MAX_LINEAGE_EVENTS;
    reset_lineage_self_test_state();
    return child_first && parent_first_once && wrong_event && wrong_pid
        && malformed && capped;
}
static void handle_event(struct task *parent, unsigned int event) {
    if (event == PTRACE_EVENT_EXEC) { capture_exec(parent->pid); return; }
    if (event != PTRACE_EVENT_FORK && event != PTRACE_EVENT_VFORK
            && event != PTRACE_EVENT_CLONE) return;
    unsigned long child_value;
    if (ptrace(PTRACE_GETEVENTMSG, parent->pid, 0, &child_value) != 0) {
        fail(parent->pid, "DESCENDANT_IDENTITY_UNAVAILABLE"); return;
    }
    const char *kind = NULL;
    uint64_t flags = 0;
    struct task *child = NULL;
    enum lineage_preparation preparation = prepare_lineage(
        parent, event, (pid_t)child_value, &child, &kind, &flags);
    if (preparation == LINEAGE_PREPARE_INVALID) {
        fail(parent->pid, "LINEAGE_EVENT_MISMATCH"); return;
    }
    if (preparation == LINEAGE_PREPARE_TASK_CAP) {
        fail(parent->pid, "TASK_CAP_EXCEEDED"); return;
    }
    if (lineage_events >= MAX_LINEAGE_EVENTS) {
        fail(parent->pid, "LINEAGE_EVENT_CAP_EXCEEDED"); return;
    }
    fprintf(trace, "LINEAGE\t%" PRIu64 "\t%d\t%d\t%s\t%" PRIu64 "\n",
            ++sequence, parent->pid, child->pid, kind, flags);
    lineage_events += 1;
    if (preparation == LINEAGE_HELD_ATTACH) {
        if (!set_options(child)) return;
        if (ptrace(PTRACE_SYSCALL, child->pid, 0, 0) != 0)
            fail(child->pid, "TRACE_RESUME_FAILED");
    }
}
static bool canonical_root(const char *input, char *output) { return realpath(input, output) != NULL; }
static bool canonical_pipe(const struct gv_object_identity *object) {
    char expected[64];
    int count = snprintf(expected, sizeof(expected), "pipe:[%ju]", (uintmax_t)object->inode);
    return count > 0 && (size_t)count < sizeof(expected) && !strcmp(object->path, expected);
}
static bool record_initial_fds(pid_t pid) {
    struct gv_object_identity objects[3];
    int modes[3];
    size_t count;
    if (!gv_fd_count(pid, &count) || count != 3) return false;
    for (int fd = 0; fd <= 2; fd += 1) {
        if (!gv_fd_identity(pid, fd, &objects[fd])
                || !gv_fd_access_mode(pid, fd, &modes[fd])) return false;
    }
    if (strcmp(objects[0].path, "/dev/null") || modes[0] != O_RDONLY
            || !canonical_pipe(&objects[1]) || modes[1] != O_WRONLY
            || !canonical_pipe(&objects[2]) || modes[2] != O_WRONLY
            || (objects[1].device == objects[2].device
                && objects[1].inode == objects[2].inode)) return false;
    for (int fd = 0; fd <= 2; fd += 1) {
        fprintf(trace, "INITIAL_FD\t%" PRIu64 "\t%d\t%d\t%d\t%ju\t%ju\t",
                ++sequence, pid, fd, modes[fd],
                (uintmax_t)objects[fd].device, (uintmax_t)objects[fd].inode);
        hex(objects[fd].path); fputc('\n', trace);
    }
    return true;
}
static void usage(const char *program) {
    fprintf(stderr, "usage: %s --challenge 64_HEX --trace FILE --sidecar FILE --policy FILE --product-root DIR "
        "--packet-root DIR --home-root DIR --output-root DIR "
        "--godot FILE --script FILE --corpus FILE --index DECIMAL\n", program);
}
int main(int argc, char **argv) {
    if (argc == 2 && !strcmp(argv[1], "--self-test")) {
        char resolved[64];
        const char *kind = NULL;
        uint64_t flags = 0;
        struct task process = {.number = SYS_clone3,
            .clone_flags = CLONE_VM | CLONE_VFORK | CLONE_CLEAR_SIGHAND,
            .clone_exit_signal = SIGCHLD};
        struct task thread = {.number = SYS_clone3,
            .clone_flags = CLONE_VM | CLONE_THREAD, .clone_exit_signal = 0};
        struct task vfork = {.number = SYS_vfork};
        bool lineage_ok = decode_lineage(&process, PTRACE_EVENT_VFORK, &kind, &flags)
            && !strcmp(kind, "clone_process") && flags == process.clone_flags
            && decode_lineage(&thread, PTRACE_EVENT_CLONE, &kind, &flags)
            && !strcmp(kind, "clone_thread") && flags == thread.clone_flags
            && decode_lineage(&vfork, PTRACE_EVENT_VFORK, &kind, &flags)
            && !strcmp(kind, "vfork_process") && flags == 0
            && !decode_lineage(&process, PTRACE_EVENT_CLONE, &kind, &flags);
        int landlock_abi = gv_landlock_abi();
        bool passed = sizeof(allowed_syscalls) / sizeof(*allowed_syscalls) == 61
            && lineage_ok
            && pending_attach_self_test()
            && decode_syscall_fd(UINT32_MAX) == -1
            && decode_syscall_fd(UINT64_MAX) == -1
            && decode_syscall_fd(3) == 3
            && landlock_abi >= 3
            && gv_kernel_admission_access_fs() == 32759
            && gv_resolve_path(getpid(), AT_FDCWD, "/.__glassvow_absent_path__", true,
                               resolved, sizeof(resolved))
            && !strcmp(resolved, "/.__glassvow_absent_path__");
        if (passed) {
            printf("{\"schema\":\"glassvow.godot-runtime-kernel-admission/v1\","
                "\"landlockAbi\":%d,\"minimumAbi\":3,\"handledAccessFs\":32759,"
                "\"policySchema\":\"GODOTACCESSv1\","
                "\"fileRuleCapacity\":192,\"pathRuleCapacity\":2304,"
                "\"policyByteCapacity\":393216,"
                "\"writeSubtrees\":2,\"namedWriteFiles\":1,"
                "\"descriptorSanitisation\":true,"
                "\"noNewPrivileges\":true}\n", landlock_abi);
        }
        return passed ? 0 : 1;
    }
    const char *trace_path = NULL, *sidecar_path = NULL;
    char policy_path[4096] = "";
    char godot_path[4096] = "", script_path[4096] = "", corpus_path[4096] = "";
    const char *index_value = NULL;
    for (int i = 1; i < argc; i += 1) {
        if (i + 1 >= argc) { usage(argv[0]); return 64; }
        const char *value = argv[++i];
        if (!strcmp(argv[i - 1], "--challenge")) challenge = value;
        else if (!strcmp(argv[i - 1], "--trace")) trace_path = value;
        else if (!strcmp(argv[i - 1], "--sidecar")) sidecar_path = value;
        else if (!strcmp(argv[i - 1], "--policy")) {
            if (!canonical_root(value, policy_path)) return 64;
        }
        else if (!strcmp(argv[i - 1], "--product-root")) {
            if (!canonical_root(value, product_root)) return 64;
        } else if (!strcmp(argv[i - 1], "--packet-root")) {
            if (!canonical_root(value, packet_root)) return 64;
        } else if (!strcmp(argv[i - 1], "--home-root")) {
            if (!canonical_root(value, home_root)) return 64;
        } else if (!strcmp(argv[i - 1], "--output-root")) {
            if (!canonical_root(value, output_root)) return 64;
        } else if (!strcmp(argv[i - 1], "--godot")) {
            if (!canonical_root(value, godot_path)) return 64;
        } else if (!strcmp(argv[i - 1], "--script")) {
            if (!canonical_root(value, script_path)) return 64;
        } else if (!strcmp(argv[i - 1], "--corpus")) {
            if (!canonical_root(value, corpus_path)) return 64;
        } else if (!strcmp(argv[i - 1], "--index")) {
            index_value = value;
        } else { usage(argv[0]); return 64; }
    }
    if (challenge == NULL || strlen(challenge) != 64
            || strspn(challenge, "0123456789abcdef") != 64
            || trace_path == NULL || sidecar_path == NULL || !policy_path[0]
            || !product_root[0] || !packet_root[0]
            || !home_root[0] || !output_root[0] || !godot_path[0] || !script_path[0]
            || !corpus_path[0] || index_value == NULL || !index_value[0]
            || strlen(index_value) > 20 || strspn(index_value, "0123456789") != strlen(index_value)
            || !gv_path_within(script_path, packet_root)
            || !gv_path_within(corpus_path, packet_root)
            || !gv_path_has_suffix(script_path, ".gd")
            || !gv_path_has_suffix(corpus_path, ".json")
            || !gv_regular_file(godot_path, true) || !gv_regular_file(script_path, false)
            || !gv_regular_file(corpus_path, false)
            || gv_path_within(home_root, product_root) || gv_path_within(product_root, home_root)
            || gv_path_within(output_root, product_root) || gv_path_within(product_root, output_root)
            || gv_path_within(home_root, packet_root) || gv_path_within(packet_root, home_root)
            || gv_path_within(output_root, packet_root) || gv_path_within(packet_root, output_root)
            || gv_path_within(home_root, output_root) || gv_path_within(output_root, home_root)) {
        usage(argv[0]); return 64;
    }
    if (!gv_load_admission_policy(
            policy_path, MAX_ADMISSION_POLICY_BYTES, &admission_policy)) return 64;
    char identity_raw[4096];
    if (snprintf(observation_path, sizeof(observation_path), "%s/observation.json", output_root)
            >= (int)sizeof(observation_path)
            || snprintf(godot_log_path, sizeof(godot_log_path),
                "%s/.local/share/godot/app_userdata/Glassvow/logs/godot.log", home_root)
                >= (int)sizeof(godot_log_path)
            || snprintf(sentry_path, sizeof(sentry_path),
                "%s/.local/share/godot/app_userdata/Glassvow/sentry.dat", home_root)
                >= (int)sizeof(sentry_path)
            || snprintf(identity_raw, sizeof(identity_raw),
                "%s/addons/sentry/bin/linux/x86_64/libsentry.linux.debug.x86_64.so",
                product_root) >= (int)sizeof(identity_raw)
            || !canonical_root(identity_raw, identity_exception)) return 64;
    int trace_fd = open(trace_path, O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC, 0600);
    sidecar_fd = open(sidecar_path, O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC, 0600);
    if (trace_fd < 0 || sidecar_fd < 0 || (trace = fdopen(trace_fd, "w")) == NULL) {
        perror("create trace outputs"); return 2;
    }
    fprintf(trace, "GODOTTRACEv1\n");
    char home_environment[4102];
    if (snprintf(home_environment, sizeof(home_environment), "HOME=%s", home_root)
            >= (int)sizeof(home_environment)) return 64;
    char *const launch_arguments[] = {
        "/usr/bin/env", "-i", home_environment, "PATH=/usr/bin:/bin", "LANG=C.UTF-8",
        godot_path, "--headless", "--path", product_root, "-s", script_path, "--",
        "--input", corpus_path, "--index", (char *)index_value,
        "--output", observation_path, NULL,
    };
    char *const launch_environment[] = {NULL};
    if (fflush(trace) != 0 || (start_ns = gv_monotonic_raw_ns()) == 0) return 2;
    root_pid = fork();
    if (root_pid < 0) { perror("fork tracee"); return 2; }
    if (root_pid == 0) {
        if (!gv_limit_address_space(MAX_ADDRESS_SPACE)
                || !gv_limit_initial_stack(MAX_INITIAL_STACK)) _exit(125);
        if (!gv_sanitise_descriptors()
                || !gv_restrict_access(home_root, output_root, &admission_policy)) _exit(124);
        if (ptrace(PTRACE_TRACEME, 0, 0, 0) != 0) _exit(126);
        raise(SIGSTOP);
        execve("/usr/bin/env", launch_arguments, launch_environment);
        _exit(127);
    }
    fprintf(trace, "START\t%" PRIu64 "\t%" PRIu64 "\t%s"
        "\t16\t%" PRIu64 "\t%" PRIu64 "\t%u\t%u\t%u\t%u\t%u\t%u\t%u\t%u\t%u\t%u"
        "\t%u\t%u\t%u\t%u\t%u\t%u\t%u\n",
        ++sequence, start_ns, challenge, (uint64_t)MAX_ADDRESS_SPACE,
        (uint64_t)MAX_INITIAL_STACK,
        MAX_CAPTURE, MAX_TOTAL_CAPTURE, MAX_SYSCALLS,
        MAX_PATH_EVENTS, MAX_READ_EVENTS, MAX_WRITE_EVENTS, MAX_MMAP_EVENTS,
        MAX_OPEN_FDS, MAX_SEMANTIC_READ_BYTES, MAX_TRACE_BYTES, MAX_OPEN_EVENTS,
        MAX_CLOSE_EVENTS, MAX_SOCKET_EVENTS, MAX_BIND_EVENTS, MAX_EXEC_EVENTS,
        MAX_DUP_EVENTS, MAX_LINEAGE_EVENTS);
    fprintf(trace, "POLICY\t%" PRIu64 "\t%d\t%zu\t%zu\t%zu\n",
            ++sequence, root_pid, admission_policy.byte_count,
            admission_policy.file_count, admission_policy.path_count);
    int status;
    if (waitpid(root_pid, &status, 0) != root_pid || !WIFSTOPPED(status)) return 2;
    struct task *root = add_task(root_pid);
    if (root == NULL || !set_options(root) || !record_initial_fds(root_pid)
            || ptrace(PTRACE_SYSCALL, root_pid, 0, 0) != 0)
        return 2;
    while (active_count > 0) {
        pid_t pid = waitpid(-1, &status, __WALL);
        if (pid < 0) { if (errno == EINTR) continue; fail(root_pid, "WAIT_FAILED"); break; }
        stops += 1; struct task *task = find_task(pid);
        if (task == NULL) {
            if (!terminating && defer_attach_stop(pid, status)) continue;
            fail(root_pid, "UNMATCHED_TASK");
            kill(pid, SIGKILL); ptrace(PTRACE_CONT, pid, 0, SIGKILL); continue;
        }
        if (WIFEXITED(status) || WIFSIGNALED(status)) {
            int code = WIFEXITED(status) ? WEXITSTATUS(status) : 128 + WTERMSIG(status);
            fprintf(trace, "EXIT\t%" PRIu64 "\t%d\t%d\n", ++sequence, pid, code);
            if (pid == root_pid) root_exit = code;
            if (task->active) { task->active = false; active_count -= 1; }
            continue;
        }
        if (!WIFSTOPPED(status)) { fail(pid, "UNKNOWN_WAIT_STATE"); continue; }
        if (!set_options(task)) continue;
        int signal_number = WSTOPSIG(status); unsigned int event = (unsigned int)status >> 16;
        bool attach_stop = consume_expected_attach_stop(task, signal_number, event);
        if (signal_number == (SIGTRAP | 0x80)) handle_syscall(task);
        else if (signal_number == SIGTRAP && event != 0) handle_event(task, event);
        else if (!attach_stop)
            fprintf(trace, "SIGNAL\t%" PRIu64 "\t%d\t%d\n", ++sequence, pid, signal_number);
        long current_trace_bytes = ftell(trace);
        if (current_trace_bytes < 0
                || (uint64_t)current_trace_bytes > MAX_TRACE_BYTES - TRACE_END_RESERVE)
            fail(pid, "TRACE_SIZE_CAP_EXCEEDED");
        if (terminating) { ptrace(PTRACE_CONT, pid, 0, SIGKILL); continue; }
        int deliver = attach_stop || signal_number == (SIGTRAP | 0x80)
            || (signal_number == SIGTRAP && event != 0) ? 0 : signal_number;
        if (ptrace(PTRACE_SYSCALL, pid, 0, deliver) != 0) fail(pid, "TRACE_RESUME_FAILED");
    }
    if (pending_attach_count != 0) fail(root_pid, "UNMATCHED_TASK");
    for (size_t i = 0; i < task_count; i += 1)
        if (tasks[i].have_entry && tasks[i].active) fail(tasks[i].pid, "UNMATCHED_SYSCALL_ENTRY");
    uint64_t end_ns = gv_monotonic_raw_ns();
    if (end_ns == 0) fail(root_pid, "MONOTONIC_CLOCK_UNAVAILABLE");
    long trace_bytes = ftell(trace);
    if (trace_bytes < 0 || (uint64_t)trace_bytes + 1024U > MAX_TRACE_BYTES)
        fail(root_pid, "TRACE_SIZE_CAP_EXCEEDED");
    fprintf(trace, "END\t%" PRIu64 "\t%" PRIu64 "\t%" PRIu64 "\t%" PRIu64
        "\t%" PRIu64 "\t%zu\t%" PRIu64 "\t%" PRIu64 "\t%" PRIu64 "\t%zu"
        "\t%" PRIu64 "\t%" PRIu64 "\t%" PRIu64 "\t%" PRIu64
        "\t%" PRIu64 "\t%" PRIu64 "\t%" PRIu64 "\t%" PRIu64
        "\t%" PRIu64 "\t%" PRIu64 "\t%" PRIu64 "\t0\t%d\t%s\t%s\n",
        ++sequence, start_ns, end_ns, end_ns - start_ns, stops, task_count,
        lineage_events, entries, exits, resumed_exits, captured_bytes,
        path_events, read_events, write_events,
        mmap_events, open_events, close_events, socket_events, bind_events,
        exec_events, semantic_read_bytes, root_exit,
        violation == NULL ? "-" : violation, challenge);
    if (fflush(trace) != 0 || fsync(fileno(trace)) != 0 || fsync(sidecar_fd) != 0) {
        perror("flush trace outputs"); return 2;
    }
    fclose(trace); close(sidecar_fd); gv_free_admission_policy(&admission_policy);
    return violation == NULL && root_exit == 0 ? 0 : 40;
}
