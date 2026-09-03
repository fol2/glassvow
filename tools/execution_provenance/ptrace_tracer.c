#define _GNU_SOURCE

#include <errno.h>
#include <fcntl.h>
#include <inttypes.h>
#include <linux/audit.h>
#include <linux/sched.h>
#include <signal.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ptrace.h>
#include <sys/stat.h>
#include <sys/syscall.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

#if !defined(__linux__) || !defined(__x86_64__)
#error "The ptrace backend supports Linux x86_64 only."
#endif

#define MAX_PROCESSES 64
#define MAX_READ_BYTES 4096
#define INPUT_FD 3
#define OUTPUT_FD 4
#define GV_PTRACE_GET_SYSCALL_INFO 0x420e
#define GV_SYSCALL_INFO_ENTRY 1
#define GV_SYSCALL_INFO_EXIT 2

struct gv_syscall_info {
    uint8_t op;
    uint8_t pad[3];
    uint32_t arch;
    uint64_t instruction_pointer;
    uint64_t stack_pointer;
    union {
        struct {
            uint64_t nr;
            uint64_t args[6];
        } entry;
        struct {
            int64_t rval;
            uint8_t is_error;
        } exit;
    } data;
};

struct process_state {
    pid_t pid;
    bool active;
    bool options_set;
    bool after_exec;
    bool have_entry;
    long syscall_number;
    uint64_t arguments[6];
};

static FILE *trace_file;
static struct process_state processes[MAX_PROCESSES];
static size_t process_count;
static size_t active_count;
static uint64_t sequence_number;
static uint64_t started_ns;
static const char *violation_reason;
static bool terminating;
static pid_t root_pid;
static int root_exit_code = 255;
static int input_fd = -1;
static struct stat input_stat;
static char expected_executable[4096];

static uint64_t monotonic_raw_ns(void) {
    struct timespec value;
    if (clock_gettime(CLOCK_MONOTONIC_RAW, &value) != 0) {
        perror("clock_gettime");
        exit(2);
    }
    return (uint64_t)value.tv_sec * UINT64_C(1000000000)
        + (uint64_t)value.tv_nsec;
}

static void print_hex(const unsigned char *bytes, size_t count) {
    static const char digits[] = "0123456789abcdef";
    for (size_t index = 0; index < count; index += 1) {
        fputc(digits[bytes[index] >> 4], trace_file);
        fputc(digits[bytes[index] & 15], trace_file);
    }
}

static void print_text_hex(const char *text) {
    print_hex((const unsigned char *)text, strlen(text));
}

static void flush_trace(void) {
    if (fflush(trace_file) != 0) {
        perror("fflush trace");
        exit(2);
    }
}

static struct process_state *find_process(pid_t pid) {
    for (size_t index = 0; index < process_count; index += 1) {
        if (processes[index].pid == pid) {
            return &processes[index];
        }
    }
    return NULL;
}

static struct process_state *add_process(pid_t pid) {
    struct process_state *existing = find_process(pid);
    if (existing != NULL) {
        return existing;
    }
    if (process_count >= MAX_PROCESSES) {
        return NULL;
    }
    struct process_state *state = &processes[process_count++];
    memset(state, 0, sizeof(*state));
    state->pid = pid;
    state->active = true;
    active_count += 1;
    return state;
}

static void log_violation(pid_t pid, const char *reason) {
    if (violation_reason != NULL) {
        return;
    }
    violation_reason = reason;
    sequence_number += 1;
    fprintf(trace_file, "VIOLATION\t%" PRIu64 "\t%d\t%s\n",
            sequence_number, pid, reason);
    flush_trace();
}

static void terminate_all(void) {
    if (terminating) {
        return;
    }
    terminating = true;
    for (size_t index = 0; index < process_count; index += 1) {
        if (!processes[index].active) {
            continue;
        }
        kill(processes[index].pid, SIGKILL);
        ptrace(PTRACE_CONT, processes[index].pid, 0, SIGKILL);
    }
}

static void fail_policy(pid_t pid, const char *reason) {
    log_violation(pid, reason);
    terminate_all();
}

static bool set_options(struct process_state *state) {
    if (state->options_set) {
        return true;
    }
    long options = PTRACE_O_TRACESYSGOOD | PTRACE_O_TRACEFORK
        | PTRACE_O_TRACEVFORK | PTRACE_O_TRACEVFORKDONE
        | PTRACE_O_TRACECLONE | PTRACE_O_TRACEEXEC
        | PTRACE_O_TRACEEXIT | PTRACE_O_EXITKILL;
    if (ptrace(PTRACE_SETOPTIONS, state->pid, 0, options) != 0) {
        fail_policy(state->pid, "UNTRACEABLE_DESCENDANT");
        return false;
    }
    state->options_set = true;
    return true;
}

static void log_exec(pid_t pid) {
    char proc_path[64];
    char executable[4096];
    struct stat executable_stat;
    snprintf(proc_path, sizeof(proc_path), "/proc/%d/exe", pid);
    ssize_t count = readlink(proc_path, executable, sizeof(executable) - 1);
    if (count < 0 || (size_t)count >= sizeof(executable) - 1
            || stat(proc_path, &executable_stat) != 0) {
        fail_policy(pid, "EXECUTABLE_IDENTITY_UNAVAILABLE");
        return;
    }
    executable[count] = '\0';
    sequence_number += 1;
    fprintf(trace_file, "EXEC\t%" PRIu64 "\t%d\t%ju\t%ju\t",
            sequence_number, pid, (uintmax_t)executable_stat.st_dev,
            (uintmax_t)executable_stat.st_ino);
    print_text_hex(executable);
    fputc('\n', trace_file);
    flush_trace();
    if (strcmp(executable, expected_executable) != 0) {
        fail_policy(pid, "EXECUTABLE_MISMATCH");
    }
}

static void log_fork(pid_t parent, pid_t child, const char *kind) {
    sequence_number += 1;
    fprintf(trace_file, "FORK\t%" PRIu64 "\t%d\t%d\t%s\n",
            sequence_number, parent, child, kind);
    flush_trace();
}

static void log_exit(pid_t pid, int code) {
    sequence_number += 1;
    fprintf(trace_file, "EXIT\t%" PRIu64 "\t%d\t%d\n",
            sequence_number, pid, code);
    flush_trace();
}

static void record_read(
        struct process_state *state,
        const char *operation,
        int64_t returned) {
    if (returned <= 0) {
        return;
    }
    uint64_t requested = state->arguments[2];
    if ((uint64_t)returned > requested || returned > MAX_READ_BYTES) {
        fail_policy(state->pid, "READ_SIZE_UNSUPPORTED");
        return;
    }
    unsigned char bytes[MAX_READ_BYTES];
    size_t copied = 0;
    while (copied < (size_t)returned) {
        errno = 0;
        long word = ptrace(
            PTRACE_PEEKDATA, state->pid,
            (void *)(uintptr_t)(state->arguments[1] + copied), 0);
        if (word == -1 && errno != 0) {
            fail_policy(state->pid, "ACTUAL_BYTES_UNAVAILABLE");
            return;
        }
        size_t remaining = (size_t)returned - copied;
        size_t width = remaining < sizeof(word) ? remaining : sizeof(word);
        memcpy(bytes + copied, &word, width);
        copied += width;
    }

    char proc_path[64];
    char actual_path[4096];
    struct stat actual_stat;
    snprintf(proc_path, sizeof(proc_path), "/proc/%d/fd/%d", state->pid, INPUT_FD);
    ssize_t path_count = readlink(
        proc_path, actual_path, sizeof(actual_path) - 1);
    if (path_count < 0 || (size_t)path_count >= sizeof(actual_path) - 1
            || stat(proc_path, &actual_stat) != 0) {
        fail_policy(state->pid, "ACTUAL_INPUT_IDENTITY_UNAVAILABLE");
        return;
    }
    actual_path[path_count] = '\0';
    if (actual_stat.st_dev != input_stat.st_dev
            || actual_stat.st_ino != input_stat.st_ino) {
        fail_policy(state->pid, "ACTUAL_INPUT_OBJECT_MISMATCH");
        return;
    }

    int64_t offset;
    if (state->syscall_number == SYS_read) {
        off_t after = lseek(input_fd, 0, SEEK_CUR);
        if (after < returned) {
            fail_policy(state->pid, "READ_OFFSET_UNAVAILABLE");
            return;
        }
        offset = (int64_t)after - returned;
    } else {
        offset = (int64_t)state->arguments[3];
    }
    sequence_number += 1;
    fprintf(trace_file,
            "READ\t%" PRIu64 "\t%d\t%s\t%d\t%" PRId64
            "\t%" PRIu64 "\t%" PRId64 "\t%ju\t%ju\t",
            sequence_number, state->pid, operation, INPUT_FD, offset,
            requested, returned, (uintmax_t)actual_stat.st_dev,
            (uintmax_t)actual_stat.st_ino);
    print_text_hex(actual_path);
    fputc('\t', trace_file);
    print_hex(bytes, (size_t)returned);
    fputc('\n', trace_file);
    flush_trace();
}

static bool syscall_allowed(struct process_state *state) {
    long number = state->syscall_number;
    if (!state->after_exec) {
        return number == SYS_execve;
    }
    if (number == SYS_read || number == SYS_pread64) {
        if ((int)state->arguments[0] != INPUT_FD) {
            fail_policy(state->pid, "UNDECLARED_INPUT_READ");
            return false;
        }
        return true;
    }
    if (number == SYS_write) {
        int fd = (int)state->arguments[0];
        if (fd != STDOUT_FILENO && fd != STDERR_FILENO && fd != OUTPUT_FD) {
            fail_policy(state->pid, "UNDECLARED_OUTPUT_WRITE");
            return false;
        }
        return true;
    }
    if (number == SYS_mmap) {
        fail_policy(state->pid,
                    (int64_t)state->arguments[4] >= 0
                        ? "UNSUPPORTED_MMAP_INPUT"
                        : "UNSUPPORTED_SYSCALL");
        return false;
    }
    if (number == SYS_clone) {
        if ((state->arguments[0] & CLONE_UNTRACED) != 0) {
            fail_policy(state->pid, "UNTRACEABLE_CLONE_FLAG");
            return false;
        }
        return true;
    }
#ifdef SYS_clone3
    if (number == SYS_clone3) {
        fail_policy(state->pid, "UNSUPPORTED_CLONE3");
        return false;
    }
#endif
    if (number == SYS_fork || number == SYS_vfork || number == SYS_wait4
            || number == SYS_exit || number == SYS_exit_group) {
        return true;
    }
    fail_policy(state->pid, "UNSUPPORTED_SYSCALL");
    return false;
}

static void handle_syscall_stop(struct process_state *state) {
    struct gv_syscall_info info;
    memset(&info, 0, sizeof(info));
    long result = ptrace(
        (enum __ptrace_request)GV_PTRACE_GET_SYSCALL_INFO,
        state->pid, sizeof(info), &info);
    if (result < 0) {
        fail_policy(state->pid, "SYSCALL_OBSERVATION_UNAVAILABLE");
        return;
    }
    if (info.arch != AUDIT_ARCH_X86_64) {
        fail_policy(state->pid, "SYSCALL_ARCHITECTURE_MISMATCH");
        return;
    }
    if (info.op == GV_SYSCALL_INFO_ENTRY) {
        state->syscall_number = (long)info.data.entry.nr;
        memcpy(state->arguments, info.data.entry.args, sizeof(state->arguments));
        state->have_entry = true;
        syscall_allowed(state);
        return;
    }
    if (info.op != GV_SYSCALL_INFO_EXIT || !state->have_entry) {
        return;
    }
    int64_t returned = info.data.exit.rval;
    if (state->syscall_number == SYS_read) {
        record_read(state, "read", returned);
    } else if (state->syscall_number == SYS_pread64) {
        record_read(state, "pread64", returned);
    }
    state->have_entry = false;
}

static void handle_ptrace_event(
        struct process_state *state,
        unsigned int event) {
    if (event == PTRACE_EVENT_EXEC) {
        state->after_exec = true;
        log_exec(state->pid);
        return;
    }
    if (event == PTRACE_EVENT_FORK || event == PTRACE_EVENT_VFORK
            || event == PTRACE_EVENT_CLONE) {
        unsigned long child_value = 0;
        if (ptrace(PTRACE_GETEVENTMSG, state->pid, 0, &child_value) != 0) {
            fail_policy(state->pid, "DESCENDANT_IDENTITY_UNAVAILABLE");
            return;
        }
        pid_t child = (pid_t)child_value;
        struct process_state *child_state = add_process(child);
        if (child_state == NULL) {
            fail_policy(state->pid, "PROCESS_CAP_EXCEEDED");
            return;
        }
        child_state->after_exec = state->after_exec;
        const char *kind = event == PTRACE_EVENT_FORK ? "fork"
            : (event == PTRACE_EVENT_VFORK ? "vfork" : "clone");
        log_fork(state->pid, child, kind);
    }
}

static void usage(const char *program) {
    fprintf(stderr,
            "usage: %s --input PATH --output PATH --trace PATH --exec PATH MODE\n",
            program);
}

int main(int argc, char **argv) {
    if (argc != 10 || strcmp(argv[1], "--input") != 0
            || strcmp(argv[3], "--output") != 0
            || strcmp(argv[5], "--trace") != 0
            || strcmp(argv[7], "--exec") != 0) {
        usage(argv[0]);
        return 64;
    }
    const char *input_path = argv[2];
    const char *output_path = argv[4];
    const char *trace_path = argv[6];
    const char *executable_path = argv[8];
    const char *mode = argv[9];
    if (realpath(executable_path, expected_executable) == NULL) {
        perror("realpath executable");
        return 2;
    }
    input_fd = open(input_path, O_RDONLY | O_NOFOLLOW);
    if (input_fd < 0 || fstat(input_fd, &input_stat) != 0) {
        perror("open input");
        return 2;
    }
    int output_fd = open(
        output_path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0600);
    if (output_fd < 0) {
        perror("open output");
        return 2;
    }
    trace_file = fopen(trace_path, "wx");
    if (trace_file == NULL) {
        perror("open trace");
        return 2;
    }
    fprintf(trace_file, "TRACEv1\n");
    started_ns = monotonic_raw_ns();
    fprintf(trace_file, "START\t%" PRIu64 "\n", started_ns);
    fprintf(trace_file, "INPUT\t%ju\t%ju\t%jd\t",
            (uintmax_t)input_stat.st_dev, (uintmax_t)input_stat.st_ino,
            (intmax_t)input_stat.st_size);
    char resolved_input[4096];
    if (realpath(input_path, resolved_input) == NULL) {
        perror("realpath input");
        return 2;
    }
    print_text_hex(resolved_input);
    fputc('\n', trace_file);
    flush_trace();

    root_pid = fork();
    if (root_pid < 0) {
        perror("fork tracee");
        return 2;
    }
    if (root_pid == 0) {
        if ((input_fd != INPUT_FD && dup2(input_fd, INPUT_FD) < 0)
                || (output_fd != OUTPUT_FD && dup2(output_fd, OUTPUT_FD) < 0)) {
            _exit(125);
        }
        if (input_fd != INPUT_FD) {
            close(input_fd);
        }
        if (output_fd != OUTPUT_FD) {
            close(output_fd);
        }
#ifdef SYS_close_range
        syscall(SYS_close_range, 5U, ~0U, 0U);
#else
        for (int fd = 5; fd < 1024; fd += 1) {
            close(fd);
        }
#endif
        if (ptrace(PTRACE_TRACEME, 0, 0, 0) != 0) {
            _exit(126);
        }
        raise(SIGSTOP);
        char *const child_arguments[] = {
            expected_executable, (char *)mode, NULL};
        char *const child_environment[] = {NULL};
        execve(expected_executable, child_arguments, child_environment);
        _exit(127);
    }
    close(output_fd);
    int status = 0;
    if (waitpid(root_pid, &status, 0) != root_pid || !WIFSTOPPED(status)) {
        fprintf(stderr, "root tracee did not enter the initial stop\n");
        return 2;
    }
    struct process_state *root = add_process(root_pid);
    if (root == NULL || !set_options(root)
            || ptrace(PTRACE_SYSCALL, root_pid, 0, 0) != 0) {
        perror("start tracee");
        return 2;
    }

    while (active_count > 0) {
        pid_t pid = waitpid(-1, &status, __WALL);
        if (pid < 0) {
            if (errno == EINTR) {
                continue;
            }
            perror("waitpid tracee");
            return 2;
        }
        struct process_state *state = find_process(pid);
        if (state == NULL) {
            fail_policy(root_pid, "UNMATCHED_TRACEE");
            kill(pid, SIGKILL);
            continue;
        }
        if (WIFEXITED(status) || WIFSIGNALED(status)) {
            int code = WIFEXITED(status)
                ? WEXITSTATUS(status) : 128 + WTERMSIG(status);
            log_exit(pid, code);
            if (pid == root_pid) {
                root_exit_code = code;
            }
            if (state->active) {
                state->active = false;
                active_count -= 1;
            }
            continue;
        }
        if (!WIFSTOPPED(status)) {
            continue;
        }
        if (!set_options(state) || terminating) {
            ptrace(PTRACE_CONT, pid, 0, SIGKILL);
            continue;
        }
        int signal_number = WSTOPSIG(status);
        unsigned int event = (unsigned int)status >> 16;
        if (signal_number == (SIGTRAP | 0x80)) {
            handle_syscall_stop(state);
        } else if (signal_number == SIGTRAP && event != 0) {
            handle_ptrace_event(state, event);
        }
        if (terminating) {
            ptrace(PTRACE_CONT, pid, 0, SIGKILL);
            continue;
        }
        int deliver = (signal_number == SIGSTOP || signal_number == SIGTRAP
                || signal_number == (SIGTRAP | 0x80)
                || signal_number == SIGCHLD)
            ? 0 : signal_number;
        if (ptrace(PTRACE_SYSCALL, pid, 0, deliver) != 0) {
            fail_policy(pid, "TRACE_RESUME_FAILED");
        }
    }

    uint64_t finished_ns = monotonic_raw_ns();
    fprintf(trace_file,
            "END\t%" PRIu64 "\t%" PRIu64 "\t%" PRIu64
            "\t%" PRIu64 "\t0\t%d\t%s\n",
            sequence_number, started_ns, finished_ns,
            finished_ns - started_ns, root_exit_code,
            violation_reason == NULL ? "-" : violation_reason);
    flush_trace();
    fclose(trace_file);
    close(input_fd);
    return violation_reason == NULL && root_exit_code == 0 ? 0 : 40;
}
