#ifndef DD1_CAPABILITIES_H
#define DD1_CAPABILITIES_H
#include <stdint.h>
#include <sys/types.h>
#include <linux/seccomp.h>
/* COMPAT-2 classifies denied effects; it never authenticates a C caller. */
#define DD1_FIT_THREADS 14
#define DD1_REFUSAL_RECORDS 32
_Static_assert(2 * DD1_FIT_THREADS + 2 <= DD1_REFUSAL_RECORDS - 2, "refusal storage bound");
struct dd1_task {pid_t tid; uint64_t start;};
struct dd1_capabilities {
    pid_t workload;
    unsigned enabled, naming_cap, clone3_cap, process_refusals, naming_refusals;
    unsigned unexpected, refused_requests, fatal, preparation;
    struct dd1_task named[DD1_FIT_THREADS];
};
uint64_t dd1_task_start(pid_t group,pid_t tid);
void dd1_refusal(struct dd1_capabilities *c, const struct seccomp_notif *q,
                 const struct seccomp_notif_resp *a, unsigned threads,
                 unsigned execs, unsigned clone3, int sent, uint64_t start);
#endif
