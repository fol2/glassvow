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

#define GV_MAX_ADMISSION_FILE_RULES 192
#define GV_MAX_ADMISSION_PATH_RULES 2304

struct gv_admission_file_rule {
    uint64_t allowed_access;
    char *path;
};

struct gv_admission_path_rule {
    char operation[16];
    uint64_t parameter;
    bool has_parameter;
    char *path;
};

struct gv_admission_policy {
    size_t byte_count;
    size_t file_count;
    size_t path_count;
    struct gv_admission_file_rule files[GV_MAX_ADMISSION_FILE_RULES];
    struct gv_admission_path_rule paths[GV_MAX_ADMISSION_PATH_RULES];
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
int gv_landlock_abi(void);
uint64_t gv_kernel_admission_access_fs(void);
bool gv_load_admission_policy(
    const char *path, size_t maximum_bytes, struct gv_admission_policy *policy);
void gv_free_admission_policy(struct gv_admission_policy *policy);
bool gv_policy_allows_path(
    const struct gv_admission_policy *policy, const char *operation,
    const char *path, bool has_parameter, uint64_t parameter);
bool gv_sanitise_descriptors(void);
bool gv_restrict_access(
    const char *home_root, const char *output_root,
    const struct gv_admission_policy *policy);
bool gv_fd_access_mode(pid_t pid, int fd, int *access_mode);
bool gv_resolve_path(pid_t pid, int dirfd, const char *path, bool follow_final,
                     char *resolved, size_t capacity);
bool gv_path_within(const char *path, const char *root);
bool gv_path_is_strict_ancestor(const char *path, const char *descendant);
bool gv_existing_directory(const char *path);
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
