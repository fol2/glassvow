#define _GNU_SOURCE

#include "godot_runtime_ptrace_io.h"

#include <errno.h>
#include <fcntl.h>
#include <inttypes.h>
#include <limits.h>
#include <dirent.h>
#include <linux/landlock.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/prctl.h>
#include <sys/stat.h>
#include <sys/resource.h>
#include <sys/syscall.h>
#include <sys/uio.h>
#include <time.h>
#include <unistd.h>

#ifndef LANDLOCK_ACCESS_FS_TRUNCATE
#define LANDLOCK_ACCESS_FS_TRUNCATE (1ULL << 14)
#endif

#define GV_WRITE_ACCESS_FS ( \
    LANDLOCK_ACCESS_FS_WRITE_FILE | LANDLOCK_ACCESS_FS_REMOVE_DIR | \
    LANDLOCK_ACCESS_FS_REMOVE_FILE | LANDLOCK_ACCESS_FS_MAKE_CHAR | \
    LANDLOCK_ACCESS_FS_MAKE_DIR | LANDLOCK_ACCESS_FS_MAKE_REG | \
    LANDLOCK_ACCESS_FS_MAKE_SOCK | LANDLOCK_ACCESS_FS_MAKE_FIFO | \
    LANDLOCK_ACCESS_FS_MAKE_BLOCK | LANDLOCK_ACCESS_FS_MAKE_SYM | \
    LANDLOCK_ACCESS_FS_REFER | LANDLOCK_ACCESS_FS_TRUNCATE)
#define GV_KERNEL_ACCESS_FS (GV_WRITE_ACCESS_FS | LANDLOCK_ACCESS_FS_EXECUTE | \
    LANDLOCK_ACCESS_FS_READ_FILE)
#define GV_POLICY_SCHEMA "GODOTACCESSv1"

static bool add_access_rule(
        int ruleset, const char *path, uint64_t allowed_access) {
    int parent = open(path, O_PATH | O_CLOEXEC);
    if (parent < 0) {
        return false;
    }
    struct landlock_path_beneath_attr rule = {
        .allowed_access = allowed_access,
        .parent_fd = parent,
    };
    bool added = syscall(
        SYS_landlock_add_rule, ruleset, LANDLOCK_RULE_PATH_BENEATH,
        &rule, 0) == 0;
    close(parent);
    return added;
}

static bool add_regular_file_rule(
        int ruleset, const char *path, uint64_t allowed_access) {
    int parent = open(path, O_PATH | O_CLOEXEC | O_NOFOLLOW);
    struct stat status;
    if (parent < 0 || fstat(parent, &status) != 0 || !S_ISREG(status.st_mode)) {
        if (parent >= 0) close(parent);
        return false;
    }
    struct landlock_path_beneath_attr rule = {
        .allowed_access = allowed_access,
        .parent_fd = parent,
    };
    bool added = syscall(
        SYS_landlock_add_rule, ruleset, LANDLOCK_RULE_PATH_BENEATH,
        &rule, 0) == 0;
    close(parent);
    return added;
}

int gv_landlock_abi(void) {
    return (int)syscall(
        SYS_landlock_create_ruleset, NULL, 0,
        LANDLOCK_CREATE_RULESET_VERSION);
}

uint64_t gv_kernel_admission_access_fs(void) {
    return GV_KERNEL_ACCESS_FS;
}

static int hex_value(char value) {
    if (value >= '0' && value <= '9') return value - '0';
    if (value >= 'a' && value <= 'f') return value - 'a' + 10;
    return -1;
}

static char *decode_path(const char *hex_path) {
    size_t length = strlen(hex_path);
    if (length < 2 || length % 2 != 0 || length / 2 >= PATH_MAX) return NULL;
    char *path = malloc(length / 2 + 1);
    if (path == NULL) return NULL;
    for (size_t index = 0; index < length; index += 2) {
        int high = hex_value(hex_path[index]);
        int low = hex_value(hex_path[index + 1]);
        if (high < 0 || low < 0 || (high == 0 && low == 0)) {
            free(path); return NULL;
        }
        path[index / 2] = (char)((high << 4) | low);
    }
    path[length / 2] = '\0';
    if (path[0] != '/') { free(path); return NULL; }
    return path;
}

static bool canonical_absolute_path(const char *path) {
    size_t length = strlen(path);
    if (length == 0 || path[0] != '/' || (length > 1 && path[length - 1] == '/'))
        return false;
    const char *cursor = path;
    while ((cursor = strchr(cursor, '/')) != NULL) {
        cursor += 1;
        if (*cursor == '/' || (!strncmp(cursor, ".", 1)
                && (cursor[1] == '/' || cursor[1] == '\0'))
                || (!strncmp(cursor, "..", 2)
                && (cursor[2] == '/' || cursor[2] == '\0'))) return false;
    }
    return true;
}

static bool valid_operation(const char *operation) {
    static const char *const operations[] = {
        "access", "chdir", "execve", "faccessat2", "lstat", "mkdir",
        "newfstatat", "openat", "readlink", "readlinkat", "stat", "statx",
    };
    for (size_t index = 0; index < sizeof(operations) / sizeof(*operations); index += 1)
        if (!strcmp(operation, operations[index])) return true;
    return false;
}

void gv_free_admission_policy(struct gv_admission_policy *policy) {
    if (policy == NULL) return;
    for (size_t index = 0; index < policy->file_count; index += 1)
        free(policy->files[index].path);
    for (size_t index = 0; index < policy->path_count; index += 1)
        free(policy->paths[index].path);
    memset(policy, 0, sizeof(*policy));
}

bool gv_load_admission_policy(
        const char *path, size_t maximum_bytes, struct gv_admission_policy *policy) {
    memset(policy, 0, sizeof(*policy));
    int fd = open(path, O_RDONLY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK);
    struct stat before, after;
    if (fd < 0 || fstat(fd, &before) != 0 || !S_ISREG(before.st_mode)
            || before.st_size <= 0 || (uint64_t)before.st_size > maximum_bytes) {
        if (fd >= 0) close(fd);
        return false;
    }
    size_t count = (size_t)before.st_size;
    char *data = malloc(count + 1);
    if (data == NULL) { close(fd); return false; }
    size_t offset = 0;
    while (offset < count) {
        ssize_t read_count = read(fd, data + offset, count - offset);
        if (read_count < 0 && errno == EINTR) continue;
        if (read_count <= 0) { free(data); close(fd); return false; }
        offset += (size_t)read_count;
    }
    bool stable = fstat(fd, &after) == 0
        && (before.st_dev == after.st_dev && before.st_ino == after.st_ino
            && before.st_size == after.st_size && before.st_mode == after.st_mode);
    close(fd);
    if (!stable || data[count - 1] != '\n' || memchr(data, '\r', count) != NULL
            || memchr(data, '\0', count) != NULL
            || (count > 1 && memmem(data, count, "\n\n", 2) != NULL)) {
        free(data); return false;
    }
    data[count] = '\0'; policy->byte_count = count;
    char *save = NULL;
    char *line = strtok_r(data, "\n", &save);
    if (line == NULL || strcmp(line, GV_POLICY_SCHEMA)) { free(data); return false; }
    char *previous = NULL;
    while ((line = strtok_r(NULL, "\n", &save)) != NULL) {
        char *original = strdup(line);
        if (original == NULL || (previous != NULL && strcmp(previous, original) >= 0)) {
            free(original); free(previous); free(data);
            gv_free_admission_policy(policy); return false;
        }
        free(previous); previous = original;
        char *cursor = line;
        char *kind = strsep(&cursor, "\t");
        if (kind == NULL || cursor == NULL) goto invalid_line;
        if (!strcmp(kind, "F")) {
            char *rights = strsep(&cursor, "\t");
            char *hex_path = strsep(&cursor, "\t");
            if (rights == NULL || hex_path == NULL || cursor != NULL
                    || (strcmp(rights, "R") && strcmp(rights, "RX"))
                    || policy->file_count >= GV_MAX_ADMISSION_FILE_RULES) goto invalid_line;
            struct gv_admission_file_rule *rule = &policy->files[policy->file_count];
            rule->path = decode_path(hex_path);
            char canonical[PATH_MAX];
            struct stat status;
            if (rule->path == NULL || !canonical_absolute_path(rule->path)
                    || realpath(rule->path, canonical) == NULL
                    || strcmp(rule->path, canonical)
                    || lstat(rule->path, &status) != 0 || !S_ISREG(status.st_mode)) {
                free(rule->path); rule->path = NULL; goto invalid_line;
            }
            for (size_t index = 0; index < policy->file_count; index += 1)
                if (!strcmp(policy->files[index].path, rule->path)) {
                    free(rule->path); rule->path = NULL; goto invalid_line;
                }
            rule->allowed_access = LANDLOCK_ACCESS_FS_READ_FILE;
            if (!strcmp(rights, "RX")) rule->allowed_access |= LANDLOCK_ACCESS_FS_EXECUTE;
            policy->file_count += 1;
        } else if (!strcmp(kind, "P")) {
            char *operation = strsep(&cursor, "\t");
            char *parameter = strsep(&cursor, "\t");
            char *hex_path = strsep(&cursor, "\t");
            if (operation == NULL || parameter == NULL || hex_path == NULL || cursor != NULL
                    || !valid_operation(operation)
                    || strlen(operation) >= sizeof(policy->paths[0].operation)
                    || policy->path_count >= GV_MAX_ADMISSION_PATH_RULES) goto invalid_line;
            struct gv_admission_path_rule *rule = &policy->paths[policy->path_count];
            strcpy(rule->operation, operation); rule->path = decode_path(hex_path);
            if (rule->path == NULL || !canonical_absolute_path(rule->path)) {
                free(rule->path); rule->path = NULL; goto invalid_line;
            }
            if (!strcmp(parameter, "-")) {
                rule->has_parameter = false;
            } else {
                errno = 0; char *end = NULL;
                unsigned long long value = strtoull(parameter, &end, 10);
                char canonical[32];
                snprintf(canonical, sizeof(canonical), "%llu", value);
                if (errno != 0 || end == NULL || *end != '\0' || strcmp(canonical, parameter)) {
                    free(rule->path); rule->path = NULL;
                    goto invalid_line;
                }
                rule->has_parameter = true; rule->parameter = (uint64_t)value;
            }
            policy->path_count += 1;
        } else goto invalid_line;
        continue;
invalid_line:
        free(previous); free(data); gv_free_admission_policy(policy); return false;
    }
    free(previous); free(data);
    if (policy->file_count == 0 || policy->path_count == 0) {
        gv_free_admission_policy(policy); return false;
    }
    return true;
}

bool gv_policy_allows_path(
        const struct gv_admission_policy *policy, const char *operation,
        const char *path, bool has_parameter, uint64_t parameter) {
    for (size_t index = 0; index < policy->path_count; index += 1) {
        const struct gv_admission_path_rule *rule = &policy->paths[index];
        if (!strcmp(rule->operation, operation) && !strcmp(rule->path, path)
                && rule->has_parameter == has_parameter
                && (!has_parameter || rule->parameter == parameter)) return true;
    }
    return false;
}

bool gv_sanitise_descriptors(void) {
    int source = open("/dev/null", O_RDONLY | O_CLOEXEC);
    if (source < 0 || dup2(source, STDIN_FILENO) != STDIN_FILENO
            || fcntl(STDIN_FILENO, F_SETFD, 0) != 0) {
        if (source >= 0) close(source);
        return false;
    }
    if (source > STDERR_FILENO) close(source);
    return syscall(SYS_close_range, 3U, UINT_MAX, 0U) == 0;
}

bool gv_restrict_access(
        const char *home_root, const char *output_root,
        const struct gv_admission_policy *policy) {
    if (gv_landlock_abi() < 3) {
        return false;
    }
    struct landlock_ruleset_attr ruleset_attr = {
        .handled_access_fs = GV_KERNEL_ACCESS_FS,
    };
    int ruleset = (int)syscall(
        SYS_landlock_create_ruleset, &ruleset_attr, sizeof(ruleset_attr), 0);
    if (ruleset < 0) {
        return false;
    }
    uint64_t fresh_access = GV_WRITE_ACCESS_FS | LANDLOCK_ACCESS_FS_READ_FILE;
    uint64_t sink_access = LANDLOCK_ACCESS_FS_WRITE_FILE | LANDLOCK_ACCESS_FS_TRUNCATE;
    bool configured = add_access_rule(ruleset, home_root, fresh_access) &&
        add_access_rule(ruleset, output_root, fresh_access) &&
        add_access_rule(ruleset, "/dev/null", sink_access);
    for (size_t index = 0; configured && index < policy->file_count; index += 1)
        configured = add_regular_file_rule(
            ruleset, policy->files[index].path, policy->files[index].allowed_access);
    configured = configured && prctl(PR_SET_NO_NEW_PRIVS, 1, 0, 0, 0) == 0
        && syscall(SYS_landlock_restrict_self, ruleset, 0) == 0;
    close(ruleset);
    return configured;
}

bool gv_copy_memory(pid_t pid, uint64_t address, void *destination, size_t count) {
    struct iovec local = {.iov_base = destination, .iov_len = count};
    struct iovec remote = {
        .iov_base = (void *)(uintptr_t)address,
        .iov_len = count,
    };
    if (count == 0) {
        return true;
    }
    ssize_t copied = process_vm_readv(pid, &local, 1, &remote, 1, 0);
    return copied >= 0 && (size_t)copied == count;
}

bool gv_copy_string(pid_t pid, uint64_t address, char *destination, size_t capacity) {
    if (capacity < 2) {
        return false;
    }
    for (size_t offset = 0; offset < capacity - 1; offset += 1) {
        if (!gv_copy_memory(pid, address + offset, destination + offset, 1)) {
            return false;
        }
        if (destination[offset] == '\0') {
            return true;
        }
    }
    destination[capacity - 1] = '\0';
    return false;
}

bool gv_fd_identity(pid_t pid, int fd, struct gv_object_identity *identity) {
    char proc_path[64];
    snprintf(proc_path, sizeof(proc_path), "/proc/%d/fd/%d", pid, fd);
    ssize_t count = readlink(proc_path, identity->path, sizeof(identity->path) - 1);
    struct stat status;
    if (count < 0 || (size_t)count >= sizeof(identity->path) - 1
            || stat(proc_path, &status) != 0) {
        return false;
    }
    identity->path[count] = '\0';
    identity->device = status.st_dev;
    identity->inode = status.st_ino;
    return true;
}

bool gv_pipe_identity(pid_t pid, uint64_t address, int fds[2],
                      struct gv_object_identity *identity) {
    struct gv_object_identity peer;
    if (!gv_copy_memory(pid, address, fds, sizeof(int) * 2)
            || fds[0] < 0 || fds[1] < 0
            || !gv_fd_identity(pid, fds[0], identity)
            || !gv_fd_identity(pid, fds[1], &peer)
            || identity->device != peer.device || identity->inode != peer.inode
            || strcmp(identity->path, peer.path) != 0) {
        return false;
    }
    char canonical[64];
    int count = snprintf(canonical, sizeof(canonical), "pipe:[%ju]",
                         (uintmax_t)identity->inode);
    return count > 0 && (size_t)count < sizeof(canonical)
        && strcmp(identity->path, canonical) == 0;
}

bool gv_fd_offset(pid_t pid, int fd, int64_t *offset) {
    char proc_path[64];
    snprintf(proc_path, sizeof(proc_path), "/proc/%d/fdinfo/%d", pid, fd);
    FILE *stream = fopen(proc_path, "re");
    if (stream == NULL) {
        return false;
    }
    char line[128];
    bool found = false;
    while (fgets(line, sizeof(line), stream) != NULL) {
        long long parsed;
        if (sscanf(line, "pos:\t%lld", &parsed) == 1) {
            *offset = parsed;
            found = true;
            break;
        }
    }
    fclose(stream);
    return found;
}

bool gv_fd_access_mode(pid_t pid, int fd, int *access_mode) {
    char proc_path[64];
    snprintf(proc_path, sizeof(proc_path), "/proc/%d/fdinfo/%d", pid, fd);
    FILE *stream = fopen(proc_path, "re");
    if (stream == NULL) return false;
    char line[128]; bool found = false;
    while (fgets(line, sizeof(line), stream) != NULL) {
        unsigned long flags;
        if (sscanf(line, "flags:\t%lo", &flags) == 1) {
            *access_mode = (int)(flags & O_ACCMODE); found = true; break;
        }
    }
    fclose(stream); return found;
}

bool gv_fd_count(pid_t pid, size_t *count) {
    char proc_path[64];
    snprintf(proc_path, sizeof(proc_path), "/proc/%d/fd", pid);
    DIR *directory = opendir(proc_path);
    if (directory == NULL) {
        return false;
    }
    size_t observed = 0;
    struct dirent *entry;
    while ((entry = readdir(directory)) != NULL) {
        if (entry->d_name[0] >= '0' && entry->d_name[0] <= '9') {
            observed += 1;
        }
    }
    closedir(directory);
    *count = observed;
    return true;
}

bool gv_process_tgid(pid_t pid, pid_t *tgid) {
    char proc_path[64];
    snprintf(proc_path, sizeof(proc_path), "/proc/%d/status", pid);
    FILE *stream = fopen(proc_path, "re");
    if (stream == NULL) {
        return false;
    }
    char line[128];
    bool found = false;
    while (fgets(line, sizeof(line), stream) != NULL) {
        int parsed;
        if (sscanf(line, "Tgid:\t%d", &parsed) == 1) {
            *tgid = parsed;
            found = true;
            break;
        }
    }
    fclose(stream);
    return found;
}

static bool limit_resource(int resource, uint64_t bytes) {
    struct rlimit limit = {.rlim_cur = (rlim_t)bytes, .rlim_max = (rlim_t)bytes};
    return (uint64_t)limit.rlim_cur == bytes && setrlimit(resource, &limit) == 0;
}

bool gv_limit_address_space(uint64_t bytes) {
    return limit_resource(RLIMIT_AS, bytes);
}

bool gv_limit_initial_stack(uint64_t bytes) {
    return limit_resource(RLIMIT_STACK, bytes);
}

static bool proc_link(pid_t pid, const char *leaf, char *value, size_t capacity) {
    char proc_path[96];
    snprintf(proc_path, sizeof(proc_path), "/proc/%d/%s", pid, leaf);
    ssize_t count = readlink(proc_path, value, capacity - 1);
    if (count < 0 || (size_t)count >= capacity - 1) {
        return false;
    }
    value[count] = '\0';
    return true;
}

bool gv_resolve_path(pid_t pid, int dirfd, const char *path,
                     char *resolved, size_t capacity) {
    char combined[PATH_MAX];
    if (path[0] == '/') {
        if (!strncmp(path, "/proc/self/", 11)) {
            if (snprintf(combined, sizeof(combined), "/proc/%d/%s", pid, path + 11)
                    >= (int)sizeof(combined)) {
                return false;
            }
        } else if (!strncmp(path, "/proc/thread-self/", 18)) {
            if (snprintf(combined, sizeof(combined), "/proc/%d/%s", pid, path + 18)
                    >= (int)sizeof(combined)) {
                return false;
            }
        } else if (strlen(path) >= sizeof(combined)) {
            return false;
        } else {
            strcpy(combined, path);
        }
    } else {
        char base[PATH_MAX];
        char leaf[64];
        if (dirfd == AT_FDCWD) {
            strcpy(leaf, "cwd");
        } else {
            snprintf(leaf, sizeof(leaf), "fd/%d", dirfd);
        }
        if (!proc_link(pid, leaf, base, sizeof(base))
                || (path[0] != '\0'
                    && snprintf(combined, sizeof(combined), "%s/%s", base, path)
                        >= (int)sizeof(combined))) {
            return false;
        }
        if (path[0] == '\0') strcpy(combined, base);
    }
    char probe[PATH_MAX], canonical[PATH_MAX], suffix[PATH_MAX] = "";
    strcpy(probe, combined);
    size_t probe_length = strlen(probe);
    while (probe_length > 1 && probe[probe_length - 1] == '/')
        probe[--probe_length] = '\0';
    for (;;) {
        if (realpath(probe, canonical) != NULL) {
            const char *separator = !strcmp(canonical, "/") || !suffix[0] ? "" : "/";
            return snprintf(resolved, capacity, "%s%s%s", canonical, separator, suffix)
                < (int)capacity;
        }
        char *slash = strrchr(probe, '/');
        if (slash == NULL || !slash[1] || !strcmp(slash + 1, ".")
                || !strcmp(slash + 1, "..")) return false;
        char next[PATH_MAX];
        if (snprintf(next, sizeof(next), "%s%s%s", slash + 1,
                     suffix[0] ? "/" : "", suffix) >= (int)sizeof(next)) return false;
        strcpy(suffix, next);
        if (slash == probe) strcpy(probe, "/");
        else *slash = '\0';
    }
}

bool gv_path_within(const char *path, const char *root) {
    size_t length = strlen(root);
    return strncmp(path, root, length) == 0
        && (path[length] == '\0' || path[length] == '/');
}

bool gv_path_is_strict_ancestor(const char *path, const char *descendant) {
    size_t length = strlen(path);
    return length < strlen(descendant) && strncmp(path, descendant, length) == 0
        && descendant[length] == '/';
}

bool gv_path_has_suffix(const char *path, const char *suffix) {
    size_t length = strlen(path), suffix_length = strlen(suffix);
    return length >= suffix_length && !strcmp(path + length - suffix_length, suffix);
}

bool gv_regular_file(const char *path, bool executable) {
    struct stat status;
    return stat(path, &status) == 0 && S_ISREG(status.st_mode)
        && (!executable || access(path, X_OK) == 0);
}

bool gv_named_write_path(
        const char *path, const char *observation, const char *log, const char *sentry) {
    return !strcmp(path, observation) || !strcmp(path, log) || !strcmp(path, sentry);
}

bool gv_named_output_ancestor(
        const char *path, const char *observation, const char *log, const char *sentry) {
    return gv_path_is_strict_ancestor(path, observation)
        || gv_path_is_strict_ancestor(path, log)
        || gv_path_is_strict_ancestor(path, sentry);
}

char gv_path_category(
        const char *path, const char *product, const char *packet,
        const char *identity, const char *observation, const char *log,
        const char *sentry) {
    if (gv_named_write_path(path, observation, log, sentry)) return 'W';
    if (!strcmp(path, identity)) return 'I';
    if (gv_path_within(path, product) || gv_path_within(path, packet)) return 'S';
    return 'I';
}

uint64_t gv_monotonic_raw_ns(void) {
    struct timespec value;
    if (clock_gettime(CLOCK_MONOTONIC_RAW, &value) != 0) return 0;
    return (uint64_t)value.tv_sec * UINT64_C(1000000000) + value.tv_nsec;
}

bool gv_write_all(int fd, const void *bytes, size_t count) {
    const unsigned char *cursor = bytes;
    while (count > 0) {
        ssize_t written = write(fd, cursor, count);
        if (written < 0 && errno == EINTR) {
            continue;
        }
        if (written <= 0) {
            return false;
        }
        cursor += written;
        count -= (size_t)written;
    }
    return true;
}

ssize_t gv_read_proc_file(pid_t pid, const char *leaf, void *bytes, size_t capacity) {
    char proc_path[96];
    snprintf(proc_path, sizeof(proc_path), "/proc/%d/%s", pid, leaf);
    int fd = open(proc_path, O_RDONLY | O_CLOEXEC);
    if (fd < 0) {
        return -1;
    }
    ssize_t count = read(fd, bytes, capacity);
    int saved_errno = errno;
    close(fd);
    errno = saved_errno;
    return count;
}
