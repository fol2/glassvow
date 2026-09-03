#include <stdint.h>

#if !defined(__linux__) || !defined(__x86_64__)
#error "The bounded provenance workload supports Linux x86_64 only."
#endif

enum {
    SYS_READ = 0,
    SYS_WRITE = 1,
    SYS_MMAP = 9,
    SYS_PREAD64 = 17,
    SYS_NANOSLEEP = 35,
    SYS_CLONE = 56,
    SYS_FORK = 57,
    SYS_EXIT = 60,
    SYS_WAIT4 = 61,
    SYS_OPENAT = 257,
};

enum {
    INPUT_FD = 3,
    OUTPUT_FD = 4,
    PROT_READ = 1,
    MAP_PRIVATE = 2,
    CLONE_UNTRACED = 0x00800000,
    SIGCHLD_VALUE = 17,
    AT_FDCWD_VALUE = -100,
};

static long raw_syscall6(
        long number,
        long first,
        long second,
        long third,
        long fourth,
        long fifth,
        long sixth) {
    register long r10 __asm__("r10") = fourth;
    register long r8 __asm__("r8") = fifth;
    register long r9 __asm__("r9") = sixth;
    long result;
    __asm__ volatile(
        "syscall"
        : "=a"(result)
        : "a"(number), "D"(first), "S"(second), "d"(third),
          "r"(r10), "r"(r8), "r"(r9)
        : "rcx", "r11", "memory");
    return result;
}

static long raw_syscall3(long number, long first, long second, long third) {
    return raw_syscall6(number, first, second, third, 0, 0, 0);
}

static int text_equal(const char *left, const char *right) {
    while (*left != '\0' && *left == *right) {
        left += 1;
        right += 1;
    }
    return *left == *right;
}

__attribute__((noreturn)) static void finish(long code) {
    raw_syscall3(SYS_EXIT, code, 0, 0);
    __builtin_unreachable();
}

static void write_fd(long descriptor, const unsigned char *bytes, long count) {
    long written = raw_syscall3(
        SYS_WRITE, descriptor, (long)(uintptr_t)bytes, count);
    if (written != count) {
        finish(21);
    }
}

static void write_exact(const unsigned char *bytes, long count) {
    write_fd(OUTPUT_FD, bytes, count);
}

static void consume_input(unsigned char *buffer) {
    long child = raw_syscall3(SYS_FORK, 0, 0, 0);
    if (child < 0) {
        finish(10);
    }
    if (child == 0) {
        long count = raw_syscall3(
            SYS_READ, INPUT_FD, (long)(uintptr_t)buffer, 16);
        if (count != 16) {
            finish(11);
        }
        write_exact(buffer, count);
        finish(0);
    }
    if (raw_syscall6(SYS_WAIT4, child, 0, 0, 0, 0, 0) != child) {
        finish(12);
    }
    long count = raw_syscall6(
        SYS_PREAD64, INPUT_FD, (long)(uintptr_t)buffer, 16, 16, 0, 0);
    if (count != 16) {
        finish(13);
    }
    write_exact(buffer, count);
}

static int consumes_normally(const char *mode) {
    return text_equal(mode, "valid")
        || text_equal(mode, "post-freeze-replacement")
        || text_equal(mode, "same-name-different-bytes")
        || text_equal(mode, "different-executable")
        || text_equal(mode, "request-expected")
        || text_equal(mode, "request-substitute")
        || text_equal(mode, "replay")
        || text_equal(mode, "timing-replaced")
        || text_equal(mode, "drop-event");
}

__attribute__((noreturn)) void workload_start(long *stack) {
    long argument_count = stack[0];
    const char **arguments = (const char **)&stack[1];
    const char *mode = argument_count > 1 ? arguments[1] : "valid";
    const char *extra = argument_count > 2 ? arguments[2] : "";
    unsigned char buffer[16];

    if (consumes_normally(mode)) {
        consume_input(buffer);
        finish(0);
    }

    if (text_equal(mode, "mmap-input")) {
        long address = raw_syscall6(
            SYS_MMAP, 0, 4096, PROT_READ, MAP_PRIVATE, INPUT_FD, 0);
        if (address >= 0) {
            buffer[0] = *(const volatile unsigned char *)(uintptr_t)address;
            write_exact(buffer, 1);
        }
        finish(0);
    }

    if (text_equal(mode, "clone-untraced")) {
        long child = raw_syscall6(
            SYS_CLONE, CLONE_UNTRACED | SIGCHLD_VALUE, 0, 0, 0, 0, 0);
        if (child == 0) {
            finish(0);
        }
        if (child > 0) {
            raw_syscall6(SYS_WAIT4, child, 0, 0, 0, 0, 0);
        }
        finish(0);
    }

    if (text_equal(mode, "slow-claim")) {
        static const unsigned char claim[] = "CHILD_ELAPSED_NS=1\n";
        const int64_t request[2] = {0, 500 * 1000 * 1000};
        consume_input(buffer);
        write_fd(1, claim, sizeof(claim) - 1);
        raw_syscall3(SYS_NANOSLEEP, (long)(uintptr_t)request, 0, 0);
        finish(0);
    }

    if (text_equal(mode, "no-io")) {
        finish(0);
    }

    if (text_equal(mode, "alternative-path") && extra[0] != '\0') {
        raw_syscall6(
            SYS_OPENAT, AT_FDCWD_VALUE, (long)(uintptr_t)extra, 0, 0, 0, 0);
        finish(0);
    }

    finish(64);
}

__asm__(
    ".global _start\n"
    ".type _start,@function\n"
    "_start:\n"
    "mov %rsp,%rdi\n"
    "andq $-16,%rsp\n"
    "call workload_start\n");
