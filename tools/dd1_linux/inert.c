#define _GNU_SOURCE
/* Test-only harmless workload. This file must never be substituted for game
 * evidence. Modes deliberately exercise the real kernel guards. */
#include <errno.h>
#include <fcntl.h>
#include <linux/sched.h>
#include <pthread.h>
#include <sched.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/syscall.h>
#include <sys/uio.h>
#include <unistd.h>

static const char *mode;
static void *work(void *v) {
    int id=(int)(intptr_t)v;
    if(!strcmp(mode,"cpu")) {volatile uint64_t n=0;for(;;) n++;}
    if(!strcmp(mode,"thread_limit")) {sleep(1);return NULL;}
    char p[32];snprintf(p,sizeof(p),"thread-%d",id);
    int f=open(p,O_WRONLY|O_CREAT|O_EXCL,0600);if(f<0) return (void*)1;
    if(!strcmp(mode,"race")) {
        char buf[1024];memset(buf,'R',sizeof(buf));
        for(int i=0;i<200;i++) if(pwrite(f,buf,sizeof(buf),0)<0) break;
    } else if(write(f,"THREAD\n",7)!=7) return (void*)2;
    close(f);return NULL;
}
static int denied(long result) {
    int e=errno;
    printf("DENIED ret=%ld errno=%d\n",result,e);
    return result<0 ? 0:31;
}
int main(int argc,char **argv) {
    if(argc<2) return 2;
    mode=argv[1];
    if(!strcmp(mode,"positive") || !strcmp(mode,"escape")) usleep(200000);
    if(!strcmp(mode,"positive")||!strcmp(mode,"cpu")||!strcmp(mode,"race")) {
        pthread_t a,b; if(pthread_create(&a,NULL,work,(void*)1)||pthread_create(&b,NULL,work,(void*)2)) return 10;
        void *x,*y;pthread_join(a,&x);pthread_join(b,&y);if(x||y) return 11;
        if(!strcmp(mode,"race")) return 0;
        int f=open("save.tmp",O_CREAT|O_EXCL|O_RDWR,0600);if(f<0) return 12;
        if(write(f,"{\"v\":2}\n",8)!=8||fsync(f)||rename("save.tmp","save.json")) return 13;
        char bfr[9]={0};if(pread(f,bfr,8,0)!=8||strcmp(bfr,"{\"v\":2}\n")) return 14;
        close(f);if(write(2,"ERR\n",4)!=4||write(1,"OK SAVE THREADS\n",16)!=16) return 15;
        return 0;
    }
    if(!strcmp(mode,"escape")) {
        if(argc<3) return 16;
        int f=open("/source/input",O_WRONLY);if(f>=0) return 17;
        if(rename("/source/input","/source/moved")==0) return 18;
        if(link("/source/input","hardlink")==0) return 19;
        if(symlink(argv[2],"original")||open("original",O_WRONLY)>=0) return 20;
        if(open("../../../../proc/self/root",O_RDONLY)>=0) return 21;
        if(open(argv[2],O_WRONLY)>=0||fcntl(64,F_GETFD)>=0) return 22;
        f=open("/source/input",O_RDONLY);char b[20]={0};
        if(f<0||read(f,b,19)<0||strcmp(b,"IMMUTABLE\n")) return 23;
        puts("ISOLATED");return 0;
    }
    if(!strcmp(mode,"thread_limit")) {pthread_t t[4];int e=0;
        for(int i=0;i<4;i++) {e=pthread_create(&t[i],NULL,work,(void*)1);if(e)break;}
        printf("THREAD_LIMIT errno=%d\n",e);return e?0:42;}
    if(!strcmp(mode,"fork")) {long p=syscall(SYS_fork);if(!p)_exit(41);return denied(p);}
    if(!strcmp(mode,"vfork")) return denied(syscall(SYS_vfork));
    if(!strcmp(mode,"clone")) return denied(syscall(SYS_clone,SIGCHLD,0,0,0,0));
    if(!strcmp(mode,"clone3")) {struct clone_args a={.exit_signal=SIGCHLD};return denied(syscall(SYS_clone3,&a,sizeof(a)));}
    if(!strcmp(mode,"exec")) return denied(syscall(SYS_execve,"/workload",argv,NULL));
    if(!strcmp(mode,"execveat")) return denied(syscall(SYS_execveat,AT_FDCWD,"/workload",argv,NULL,0));
    if(!strcmp(mode,"socket")) return denied(socket(AF_INET,SOCK_STREAM,0));
    if(!strcmp(mode,"namespace")) return denied(syscall(SYS_unshare,CLONE_NEWUSER));
    if(!strcmp(mode,"abi")) return denied(syscall(0x40000000UL|SYS_write,1,"BAD",3));
    if(!strcmp(mode,"ia32")) {long r;__asm__ volatile("int $0x80":"=a"(r):"a"(20):"memory");return 32;}
    if(!strcmp(mode,"blocked_io")) {int p[2];if(pipe(p))return 24;char c;return read(p[0],&c,1);}
    if(!strcmp(mode,"linger")) {for(;;){if(write(1,"LIVE\n",5)<0)return 0;usleep(20000);}}
    int f=open("output",O_RDWR|O_CREAT|O_TRUNC,0600);if(f<0)return 25;
    struct iovec vec={.iov_base="VECTOR",.iov_len=6};
    if(!strcmp(mode,"writev")) return denied(writev(f,&vec,1));
    if(!strcmp(mode,"pwritev")) return denied(pwritev(f,&vec,1,0));
    if(!strcmp(mode,"pwritev2")) return denied(syscall(SYS_pwritev2,f,&vec,1,0,0,0));
    if(!strcmp(mode,"shared_mmap")) return denied((long)mmap(NULL,4096,PROT_READ|PROT_WRITE,MAP_SHARED,f,0));
    if(!strcmp(mode,"shared_then_mprotect")) {
        void *p=mmap(NULL,4096,PROT_READ,MAP_SHARED,f,0);
        if(p!=MAP_FAILED) {mprotect(p,4096,PROT_READ|PROT_WRITE);*(char*)p='X';return 33;}
        return denied(-1);
    }
    if(!strcmp(mode,"truncate")) return denied(ftruncate(f,10000000));
    if(!strcmp(mode,"sendfile")) return denied(syscall(SYS_sendfile,1,f,0,1));
    if(!strcmp(mode,"splice")) return denied(syscall(SYS_splice,f,0,1,0,1,0));
    if(!strcmp(mode,"copy_file_range")) return denied(syscall(SYS_copy_file_range,f,0,1,0,1,0));
    if(!strcmp(mode,"io_uring")) return denied(syscall(SYS_io_uring_setup,1,0));
    if(!strcmp(mode,"aio")) {unsigned long ctx=0;return denied(syscall(SYS_io_setup,1,&ctx));}
    if(!strcmp(mode,"mknod")) return denied(syscall(SYS_mknod,"device",S_IFCHR|0600,0));
    if(!strcmp(mode,"mknodat")) return denied(mknod("device",S_IFCHR|0600,0));
    if(!strcmp(mode,"overwrites")) {char b[1024];memset(b,'W',sizeof(b));
        for(int i=0;i<200;i++) if(pwrite(f,b,sizeof(b),0)<0)return errno==EFBIG?0:36;
        return 34;}
    return 35;
}
