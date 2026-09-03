#define _GNU_SOURCE

#include "godot_runtime_ptrace_io.h"

#include <errno.h>
#include <fcntl.h>
#include <inttypes.h>
#include <limits.h>
#include <dirent.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/resource.h>
#include <sys/uio.h>
#include <time.h>
#include <unistd.h>

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
