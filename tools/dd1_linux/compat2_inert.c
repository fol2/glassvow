#define _GNU_SOURCE
/* Harmless, code-pinned COMPAT-2 controls. Never an engine or native authority. */
#include <errno.h>
#include <fcntl.h>
#include <pthread.h>
#include <sched.h>
#include <signal.h>
#include <spawn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/prctl.h>
#include <sys/resource.h>
#include <sys/syscall.h>
#include <time.h>
#include <unistd.h>

static int repeat_name,skip_name,worker_spawn;
static void die(const char *s) {perror(s);exit(91);}
static void write_file(const char *p,const char *s) {
    int f=open(p,O_WRONLY|O_CREAT|O_TRUNC,0600);if(f<0)die(p);
    size_t n=strlen(s);if(write(f,s,n)!=(ssize_t)n||fsync(f)||close(f))die("write/fsync");
}
static void save(void) {
    write_file("/out/save.tmp","COMPAT2\n");
    if(rename("/out/save.tmp","/out/save.bin"))die("rename");
    char b[9]={0};int f=open("/out/save.bin",O_RDONLY);if(f<0)die("readback open");
    if(read(f,b,8)!=8||strcmp(b,"COMPAT2\n")||close(f))die("readback bytes");
    puts("SAVE_READBACK_OK");fflush(stdout);
}
static void spawn_refusal(int direct) {
    errno=0;
    if(direct) {
        pid_t pid=-1;char *a[]={"unrelated",NULL};char *e[]={NULL};
        int rc=posix_spawn(&pid,"/unrelated",NULL,NULL,a,e);
        printf("SPAWN rc=%d pid=%d\n",rc,pid);
        if(rc!=EOPNOTSUPP||pid!=-1)die("expected refused spawn");
    } else {
        FILE *f=popen("printf BAD > /out/descendant-marker","r");int err=errno;
        printf("POPEN null=%d errno=%d\n",f==NULL,err);
        if(f||err!=EOPNOTSUPP)die("expected refused popen");
    }
}
static void *worker(void *unused) {
    (void)unused;
    if(worker_spawn)spawn_refusal(0);
    if(!skip_name) {
        int rc=pthread_setname_np(pthread_self(),"compat2-worker");
        printf("NAME rc=%d tid=%ld\n",rc,syscall(SYS_gettid));
        if(rc!=EOPNOTSUPP)die("expected refused name");
        if(repeat_name) {
            rc=pthread_setname_np(pthread_self(),"again");
            printf("NAME_REPEAT rc=%d\n",rc);if(rc!=EOPNOTSUPP)die("repeat name");
        }
    }
    return NULL;
}
static void thread(void) {
    pthread_t t;int rc=pthread_create(&t,NULL,worker,NULL);
    printf("THREAD_CREATE rc=%d\n",rc);if(rc)die("thread create");
    if(pthread_join(t,NULL))die("thread join");
}
static double process_cpu(void) {
    struct timespec t;if(clock_gettime(CLOCK_PROCESS_CPUTIME_ID,&t))die("clock");
    return t.tv_sec+t.tv_nsec/1e9;
}
static void burn(double seconds) {
    volatile unsigned long k=1;double until=process_cpu()+seconds;
    while(process_cpu()<until)for(unsigned i=0;i<100000;i++)k=k*1664525+1013904223;
    printf("CPU_DONE %.3f %lu\n",process_cpu(),k);fflush(stdout);
}
static void prepare(const char *mode) {
    errno=0;int f=open("/source/inputs/frozen.txt",O_WRONLY|O_TRUNC);
    int err=errno;printf("FROZEN_WRITE fd=%d errno=%d\n",f,err);
    if(f>=0||(err!=EROFS&&err!=EACCES))die("frozen input not protected");
    if(!strcmp(mode,"prep-symlink")) {
        if(symlink("/source/inputs/frozen.txt","/source/.godot/cache.bin"))die("symlink");
    } else {
        write_file("/source/.godot/cache.tmp","DERIVED-INERT\n");
        if(rename("/source/.godot/cache.tmp","/source/.godot/cache.bin"))die("derived rename");
    }
    if(strcmp(mode,"prep-missing"))write_file("/source/inputs/demo.uid","INERT-UID\n");
    if(!strcmp(mode,"prep-extra"))write_file("/source/.godot/unexpected.bin","UNDECLARED\n");
    if(!strcmp(mode,"prep-hardlink")&&link("/source/.godot/cache.bin","/source/.godot/cache2.bin"))die("hardlink");
    if(!strcmp(mode,"prep-escape")) {
        if(symlink("/../../source/inputs/frozen.txt","/source/.godot/cache2.bin"))die("escape symlink");
    }
    errno=0;int backing=open("/out/generated/0/cache.bin",O_WRONLY|O_TRUNC);
    printf("BACKING_ALIAS fd=%d errno=%d\n",backing,errno);
    if(backing>=0)die("writable preparation backing alias");
    puts("DERIVED_OUTPUT_READY");fflush(stdout);
}
int main(int argc,char **argv) {
    if(argc!=2)return 92;
    const char *m=argv[1];
    struct rlimit lim;if(getrlimit(RLIMIT_CPU,&lim))die("getrlimit");
    printf("LIMIT %llu %llu\n",(unsigned long long)lim.rlim_cur,(unsigned long long)lim.rlim_max);fflush(stdout);
    if(!strcmp(m,"plain")){save();return 0;}
    if(!strcmp(m,"refusal-overflow")) {
        for(int i=0;i<40;i++)syscall(SYS_prctl,PR_SET_DUMPABLE,0,0,0,0);
        return 99;
    }
    if(!strcmp(m,"later-exec")) {
        char *a[]={"again",NULL},*e[]={NULL};
        errno=0;execve("/workload",a,e);
        printf("LATER_EXEC errno=%d\n",errno);save();return 0;
    }
    if(!strcmp(m,"unnamed")){skip_name=1;thread();save();return 0;}
    if(!strcmp(m,"worker-process")) {
        worker_spawn=1;thread();
    } else if(!strcmp(m,"wrong-process")) {
        errno=0;long rc=syscall(SYS_clone,SIGCHLD,0,0,0,0);
        printf("WRONG_PROCESS rc=%ld errno=%d\n",rc,errno);if(rc!=-1||errno!=EOPNOTSUPP)return 93;
    } else if(!strcmp(m,"late-process")) {
        thread();spawn_refusal(0);
    } else if(!strcmp(m,"clone3-excess")) {
        for(int i=0;i<6;i++) {
            errno=0;long rc=syscall(SYS_clone3,0,0);printf("CLONE3 rc=%ld errno=%d\n",rc,errno);
            if(rc!=-1||errno!=ENOSYS)return 94;
        }
    } else {
        spawn_refusal(!strcmp(m,"same-signature"));
        if(!strcmp(m,"repeat-process"))spawn_refusal(0);
        if(!strcmp(m,"repeat-name"))repeat_name=1;
        thread();
    }
    if(!strcmp(m,"wrong-prctl")) {
        errno=0;long rc=syscall(SYS_prctl,PR_SET_DUMPABLE,0,0,0,0);
        printf("WRONG_PRCTL rc=%ld errno=%d\n",rc,errno);
    }
    if(!strcmp(m,"unknown-syscall")) {
        errno=0;long rc=syscall(SYS_getpriority,0,0);printf("UNKNOWN rc=%ld errno=%d\n",rc,errno);
    }
    if(!strcmp(m,"max-threads")||!strcmp(m,"extra-thread")) {
        thread();thread();
        if(!strcmp(m,"extra-thread")) {
            pthread_t t;int rc=pthread_create(&t,NULL,worker,NULL);
            printf("EXTRA_THREAD rc=%d\n",rc);if(rc!=EOPNOTSUPP)return 95;
        } else {
            int rc=pthread_setname_np(pthread_self(),"initial");printf("MAIN_NAME rc=%d\n",rc);
            if(rc!=EOPNOTSUPP)return 96;
        }
    }
    if(!strncmp(m,"prep",4))prepare(m);
    if(!strcmp(m,"sealed-runtime")) {
        char b[15]={0};int f=open("/source/.godot/cache.bin",O_RDONLY);if(f<0)die("sealed cache open");
        if(read(f,b,14)!=14||strcmp(b,"DERIVED-INERT\n"))die("sealed cache bytes");
        close(f);
        errno=0;f=open("/source/.godot/cache.bin",O_WRONLY);int err=errno;
        printf("SEALED_WRITE fd=%d errno=%d\n",f,err);if(f>=0||(err!=EROFS&&err!=EACCES))return 97;
    }
    save();
    if(!strcmp(m,"raw-exhaust")) {
        int f=open("/out/overwritten",O_WRONLY|O_CREAT,0600);if(f<0)die("overwrite");
        char b[1024]={0};int failed=0;
        for(int i=0;i<1000;i++){lseek(f,0,SEEK_SET);if(write(f,b,sizeof(b))<0){failed=errno;break;}}
        close(f);printf("RAW_CAUGHT errno=%d\n",failed);if(failed!=EFBIG)return 98;
    }
    if(!strcmp(m,"task-fail")||!strcmp(m,"prep-fail"))return 7;
    if(!strcmp(m,"cpu-above-three"))burn(4.2);
    if(!strcmp(m,"cpu-exhaust"))burn(12);
    if(!strcmp(m,"block")||!strcmp(m,"prep-block"))for(;;){struct timespec t={.tv_sec=0,.tv_nsec=10000000};nanosleep(&t,NULL);}
    return 0;
}
