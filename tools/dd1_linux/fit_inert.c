#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <pthread.h>
#include <sched.h>
#include <signal.h>
#include <stdatomic.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/prctl.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/syscall.h>
#include <unistd.h>

/* Harmless workload only. No native handler, game or engine dependency. */
#define HANDLER "/source/inputs/fit-handler.txt"
#define SIDECAR "/source/assets/probe.bin.import"
#define RESOURCE "/source/.godot/imported/probe.resource"
static const char handler[]="DD1-FIT-HARMLESS-MODE-STANDIN\n";
static const char resource[]="DD1-INERT-RESOURCE:quality=7:ASSET-INERT\n";
static const char seed[]="[remap]\nimporter=\"dd1_inert\"\ntype=\"Resource\"\nuid=\"uid://dd1seed\"\n"
    "path=\"res://.godot/imported/probe.resource\"\n\n[deps]\n"
    "source_file=\"res://assets/probe.bin\"\n"
    "dest_files=[\"res://.godot/imported/probe.resource\"]\n\n[params]\nquality=7\n";
static atomic_int alive,peak,ready,release_workers,completed,spawn_ok,spawn_denied;
static void need(int ok,const char *what) {if(!ok){fprintf(stderr,"FAIL:%s errno=%d\n",what,errno);_exit(90);}}
static void denied(long rc,int e,const char *what) {
    need(rc==-1&&e==EOPNOTSUPP,what);printf("DENIED:%s:%d\n",what,e);fflush(stdout);
}
static void name_thread(void) {
    errno=0;long rc=syscall(SYS_prctl,15,"fit-inert",0,0,0);int e=errno;
    need(rc==-1&&e==EOPNOTSUPP,"name refusal");
}
static void *worker(void *arg) {
    int concurrent=(int)(long)arg;
    name_thread();int n=atomic_fetch_add(&alive,1)+1,old=atomic_load(&peak);
    while(n>old&&!atomic_compare_exchange_weak(&peak,&old,n)) {}
    atomic_fetch_add(&ready,1);
    if(concurrent)while(!atomic_load(&release_workers))sched_yield();
    unsigned long v=0;for(unsigned i=0;i<10000;i++)v+=i;
    need(v==49995000,"bounded work");
    atomic_fetch_sub(&alive,1);atomic_fetch_add(&completed,1);return NULL;
}
static void *spawn_race(void *arg) {
    (void)arg;name_thread();atomic_fetch_add(&ready,1);
    while(!atomic_load(&release_workers))sched_yield();
    pthread_t t;int e=pthread_create(&t,NULL,worker,(void *)0);
    if(e==0){atomic_fetch_add(&spawn_ok,1);need(!pthread_join(t,NULL),"join race child");}
    else {need(e==EOPNOTSUPP,"race birth refusal");atomic_fetch_add(&spawn_denied,1);}
    return NULL;
}
static void exact_read(const char *path,const char *wanted,size_t n) {
    char b[4096];int f=open(path,O_RDONLY);need(f>=0,"open input");
    ssize_t k=read(f,b,sizeof(b));need(k==(ssize_t)n&&!memcmp(b,wanted,n),"exact input");need(!close(f),"close input");
}
static void write_file(const char *path,const char *data,size_t n) {
    int f=open(path,O_CREAT|O_WRONLY|O_TRUNC,0600);need(f>=0,"output open");
    need(write(f,data,n)==(ssize_t)n&&!fsync(f)&&!close(f),"output write/fsync");
}
static void mode_check(void) {
    struct stat st;need(!stat(HANDLER,&st),"mode stat");
    need((st.st_mode&07777)==0555,"0555 exact mode");
    need(st.st_mode&S_IXUSR,"owner executable");need(st.st_mode&S_IXGRP,"group executable");
    need(st.st_mode&S_IXOTH,"other executable");
    exact_read(HANDLER,handler,sizeof(handler)-1);
    errno=0;int f=open(HANDLER,O_WRONLY);int e=errno;
    if(f>=0)close(f);
    need(f<0&&(e==EROFS||e==EACCES),"immutable handler write");
    printf("MODE:0555 owner=1 group=1 other=1 write_denied=%d\n",e);fflush(stdout);
}
int main(int argc,char **argv) {
    need(argc==4,"args: mode children stage");
    const char *mode=argv[1],*stage=argv[3];char *end;
    long count=strtol(argv[2],&end,10);need(!*end&&count>=0&&count<=32,"bounded count");
    mode_check();
    if(!strcmp(mode,"chmod")){errno=0;long rc=syscall(SYS_chmod,HANDLER,0777);int e=errno;denied(rc,e,"chmod");}
    if(!strcmp(mode,"exec")){char *args[]={HANDLER,NULL};errno=0;long rc=execve(HANDLER,args,NULL);int e=errno;denied(rc,e,"later-exec");}
    if(!strcmp(mode,"process")){errno=0;long rc=syscall(SYS_fork);int e=errno;if(rc==0)_exit(94);denied(rc,e,"process");}
    if(!strcmp(mode,"socket")){errno=0;long rc=socket(AF_INET,SOCK_STREAM,0);int e=errno;denied(rc,e,"socket");}
    if(!strcmp(mode,"raw")){char buf[4096]={0};int f=open("/out/raw.bin",O_CREAT|O_WRONLY,0600);need(f>=0,"raw open");
        for(int i=0;i<1024;i++){ssize_t rc=write(f,buf,sizeof(buf));if(rc<0){need(errno==EFBIG,"raw refusal");break;}}close(f);}
    if(!strcmp(mode,"memory")){void *p=mmap(NULL,3ULL<<30,PROT_READ|PROT_WRITE,MAP_PRIVATE|MAP_ANONYMOUS,-1,0);
        need(p==MAP_FAILED&&errno==ENOMEM,"memory limit");puts("MEMORY_LIMIT:ENOMEM");}
    if(!strcmp(mode,"cpu")){volatile unsigned long v=1;for(;;)v=v*3+1;}
    if(!strcmp(mode,"hold")){puts("HOLD_REACHED");fflush(stdout);for(;;)sleep(1);}
    name_thread();
    pthread_t threads[32];int created=0,denials=0;
    if(!strcmp(mode,"race")) {
        for(int i=0;i<2;i++)need(!pthread_create(&threads[i],NULL,spawn_race,NULL),"race initiator");
        while(atomic_load(&ready)!=2)sched_yield();
        atomic_store(&release_workers,1);
        for(int i=0;i<2;i++)need(!pthread_join(threads[i],NULL),"join race initiator");
        printf("RACE:created=%d denied=%d\n",atomic_load(&spawn_ok),atomic_load(&spawn_denied));
    } else {
        int concurrent=!strcmp(mode,"concurrent");
        for(int i=0;i<count;i++){
            int e=pthread_create(&threads[created],NULL,worker,(void *)(long)concurrent);
            if(e){need(e==EOPNOTSUPP,"thread refusal errno");denials++;break;}
            created++;
            if(!concurrent)need(!pthread_join(threads[created-1],NULL),"join sequential");
        }
        if(concurrent){while(atomic_load(&ready)!=created)sched_yield();atomic_store(&release_workers,1);
            for(int i=0;i<created;i++)need(!pthread_join(threads[i],NULL),"join concurrent");}
        printf("THREADS:created=%d completed=%d denied=%d peak_workers=%d\n",created,atomic_load(&completed),denials,atomic_load(&peak));
    }
    if(!strcmp(stage,"preparation")) {
        exact_read(SIDECAR,seed,sizeof(seed)-1);exact_read("/source/assets/probe.bin","ASSET-INERT\n",12);
        write_file(RESOURCE,resource,sizeof(resource)-1);write_file(SIDECAR,seed,sizeof(seed)-1);
        puts("PREPARATION:bound_seed_read_resource_generated");
    } else if(!strcmp(stage,"fixture")) {
        exact_read(RESOURCE,resource,sizeof(resource)-1);
        puts("RUNTIME:sealed_resource_and_mode_read");
    }
    write_file("/out/save.tmp","FIT1\n",5);need(!rename("/out/save.tmp","/out/save.bin"),"atomic rename");
    exact_read("/out/save.bin","FIT1\n",5);puts("SAVE:atomic_readback");return 0;
}
