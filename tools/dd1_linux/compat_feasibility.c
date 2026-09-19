#define _GNU_SOURCE
/* Harmless source-feasibility controls. NOT an engine or launch authority.
 * Execute only through check_compat_feasibility.py and the pinned strict B1.
 * No errno is suppressed and the strict supervisor verdict is never changed. */
#include <errno.h>
#include <fcntl.h>
#include <pthread.h>
#include <spawn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <sys/sysinfo.h>
#include <unistd.h>

static int name_result = -1;
static void *named_worker(void *unused) {
    (void)unused;
    name_result = pthread_setname_np(pthread_self(), "DD1-inert");
    return NULL;
}
static int save_readback(void) {
    const char payload[] = "INERT byte-identical atomic save\n";
    char readback[sizeof(payload)] = {0};
    int f = open("/out/save.tmp", O_WRONLY | O_CREAT | O_EXCL, 0600);
    if (f < 0 || write(f, payload, sizeof(payload)-1) != sizeof(payload)-1 ||
        fsync(f) || close(f) || rename("/out/save.tmp", "/out/save.txt")) return 10;
    f = open("/out/save.txt", O_RDONLY);
    if (f < 0 || read(f, readback, sizeof(readback)) != sizeof(payload)-1 || close(f)) return 11;
    return memcmp(payload, readback, sizeof(payload)-1) ? 12 : 0;
}
static int refuse_popen(void) {
    errno = 0;
    FILE *pipe = popen("printf SHOULD_NOT_RUN > /out/descendant-marker", "r");
    int error = errno;
    printf("{\"action\":\"popen\",\"null\":%s,\"errno\":%d}\n", pipe ? "false" : "true", error);
    if (pipe) { pclose(pipe); return 20; }
    return error == EOPNOTSUPP ? 0 : 21;
}
int main(int argc, char **argv) {
    if (argc != 2 || !getenv("DD1_RESERVED_UNIT_PATH") || access("/grant.json", R_OK)) return 90;
    setvbuf(stdout, NULL, _IONBF, 0);
    int processors = get_nprocs();
    printf("{\"action\":\"get_nprocs\",\"count\":%d}\n", processors);
    if (processors < 1) return 91;
    const char *mode = argv[1];
    if (!strcmp(mode,"popen") || !strcmp(mode,"popen_twice") || !strcmp(mode,"popen_named")) {
        if (refuse_popen()) return 22;
        if (!strcmp(mode,"popen_twice") && refuse_popen()) return 23;
    }
    if (!strcmp(mode,"other_spawn")) {
        pid_t pid = -1;
        char *args[] = {"missing-harmless", NULL};
        char *env[] = {NULL};
        int error = posix_spawn(&pid, "/missing-harmless", NULL, NULL, args, env);
        printf("{\"action\":\"other_spawn\",\"error\":%d,\"pid\":%d}\n",error,pid);
        if (error != EOPNOTSUPP || pid != -1) return 24;
    }
    if (!strcmp(mode,"named") || !strcmp(mode,"popen_named") || !strcmp(mode,"thread")) {
        pthread_t thread;
        /* 'thread' uses the same function but skips naming, as a matched control. */
        if (!strcmp(mode,"thread")) {
            /* Kept separate below to avoid a worker reading mutable global mode. */
            extern void *unnamed_worker(void *);
            if (pthread_create(&thread,NULL,unnamed_worker,NULL) || pthread_join(thread,NULL)) return 25;
        } else if (pthread_create(&thread,NULL,named_worker,NULL) || pthread_join(thread,NULL)) return 26;
        printf("{\"action\":\"thread\",\"name_result\":%d}\n",name_result);
        if (strcmp(mode,"thread") && name_result != EOPNOTSUPP) return 27;
    }
    int error = save_readback();
    if (error) return error;
    fputs("INERT stderr retained\n",stderr);
    printf("{\"action\":\"save_readback\",\"ok\":true}\n");
    if (!strcmp(mode,"block")) {
        const struct timespec wait = {.tv_sec=0,.tv_nsec=20000000};
        for (;;) nanosleep(&wait,NULL);
    }
    return 0;
}
void *unnamed_worker(void *unused) { (void)unused; return NULL; }
