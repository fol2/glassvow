#ifndef DD1_POLICY_H
#define DD1_POLICY_H
#define _GNU_SOURCE
#include <stdint.h>
#include "capabilities.h"
/* Linux x86-64 LP64 only. Internal helper interface; never game authority. */
int dd1_listener(void);
int dd1_notify(int listener, uint64_t cap, uint64_t *used,
               unsigned *threads, unsigned max_threads, unsigned *execs,
               unsigned *denied, int *last_denied, unsigned *clone3,
               struct dd1_capabilities *capabilities);
int dd1_isolate(const char *root, const char *output);
void dd1_die(const char *step);
#endif
