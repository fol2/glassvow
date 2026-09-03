#ifndef GODOT_RUNTIME_PTRACE_IO_H
#define GODOT_RUNTIME_PTRACE_IO_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <sys/types.h>

struct gv_object_identity {
    dev_t device;
    ino_t inode;
    char path[4096];
};

bool gv_copy_memory(pid_t pid, uint64_t address, void *destination, size_t count);
bool gv_copy_string(pid_t pid, uint64_t address, char *destination, size_t capacity);
bool gv_fd_identity(pid_t pid, int fd, struct gv_object_identity *identity);
bool gv_pipe_identity(pid_t pid, uint64_t address, int fds[2],
                      struct gv_object_identity *identity);
bool gv_fd_offset(pid_t pid, int fd, int64_t *offset);
bool gv_fd_count(pid_t pid, size_t *count);
bool gv_process_tgid(pid_t pid, pid_t *tgid);
bool gv_limit_address_space(uint64_t bytes);
bool gv_limit_initial_stack(uint64_t bytes);
bool gv_resolve_path(pid_t pid, int dirfd, const char *path,
                     char *resolved, size_t capacity);
bool gv_path_within(const char *path, const char *root);
bool gv_path_is_strict_ancestor(const char *path, const char *descendant);
bool gv_path_has_suffix(const char *path, const char *suffix);
bool gv_regular_file(const char *path, bool executable);
char gv_path_category(
    const char *path, const char *product, const char *packet,
    const char *identity, const char *observation, const char *log,
    const char *sentry);
bool gv_named_write_path(
    const char *path, const char *observation, const char *log, const char *sentry);
bool gv_named_output_ancestor(
    const char *path, const char *observation, const char *log, const char *sentry);
uint64_t gv_monotonic_raw_ns(void);
bool gv_write_all(int fd, const void *bytes, size_t count);
ssize_t gv_read_proc_file(pid_t pid, const char *leaf, void *bytes, size_t capacity);

#endif
