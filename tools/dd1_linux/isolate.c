#define _GNU_SOURCE
#include "policy.h"
#include <errno.h>
#include <fcntl.h>
#include <linux/capability.h>
#include <linux/securebits.h>
#include <sched.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <sys/mount.h>
#include <sys/prctl.h>
#include <sys/syscall.h>
#include <unistd.h>

void dd1_die(const char *step) { perror(step); _exit(120); }
static void text(const char *p,const char *s) {
    int f=open(p,O_WRONLY|O_CLOEXEC); if(f<0) dd1_die(p);
    size_t n=0; while(s[n])++n;
    if(write(f,s,n)!=(ssize_t)n) dd1_die("namespace map write");
    close(f);
}
/* Layout is emitted by the fixed controller from the authenticated recipe.
 * No guest runs yet. Root and original directory topology stay read-only. */
static void generated_mounts(const char *root,const char *out) {
    char path[4096],line[512],target[4096],backing[4096];
    snprintf(path,sizeof(path),"%s/dd1-preparation.layout",root);
    FILE *f=fopen(path,"r"); if(!f) {if(errno==ENOENT)return;dd1_die("layout");}
    unsigned count=0,index;char kind,name[384],extra;
    while(fgets(line,sizeof(line),f)) {
        if(++count>128 || sscanf(line,"%c %383s %u %c",&kind,name,&index,&extra)!=3 ||
           (kind!='f'&&kind!='d') || index!=count-1 || strncmp(name,"source/",7) ||
           strstr(name,"..") || strlen(name)>350) dd1_die("layout syntax");
        for(char *p=name;*p;p++) if(!isalnum((unsigned char)*p)&&!strchr("/_.-",*p)) dd1_die("layout path");
        snprintf(target,sizeof(target),"%s/%s",root,name);
        snprintf(backing,sizeof(backing),"%s/../derived/%u",out,index);
        if(mount(backing,target,NULL,MS_BIND,NULL) ||
           mount(NULL,target,NULL,MS_REMOUNT|MS_BIND|MS_NOSUID|MS_NODEV|MS_NOEXEC,NULL))
            dd1_die("generated slot mount");
    }
    if(ferror(f)) dd1_die("layout read");
    fclose(f);
}
int dd1_isolate(const char *root,const char *out) {
    uid_t uid=getuid(); gid_t gid=getgid(); char b[80],target[4096];
    if(unshare(CLONE_NEWUSER)) dd1_die("unshare user");
    snprintf(b,sizeof(b),"0 %u 1\n",uid); text("/proc/self/uid_map",b);
    text("/proc/self/setgroups","deny\n");
    snprintf(b,sizeof(b),"0 %u 1\n",gid); text("/proc/self/gid_map",b);
    if(unshare(CLONE_NEWNS|CLONE_NEWNET)) dd1_die("unshare mount/net");
    if(mount(NULL,"/",NULL,MS_REC|MS_PRIVATE,NULL)) dd1_die("mount private");
    if(mount(root,root,NULL,MS_BIND,NULL)) dd1_die("bind root");
    if(mount(NULL,root,NULL,MS_REMOUNT|MS_BIND|MS_RDONLY|MS_NOSUID|MS_NODEV,NULL)) dd1_die("readonly root");
    if(snprintf(target,sizeof(target),"%s/out",root)>=(int)sizeof(target)) dd1_die("root path");
    if(mount(out,target,NULL,MS_BIND,NULL)) dd1_die("bind output");
    if(mount(NULL,target,NULL,MS_REMOUNT|MS_BIND|MS_NOSUID|MS_NODEV|MS_NOEXEC,NULL)) dd1_die("output flags");
    generated_mounts(root,out);
    if(chdir(root)||chroot(".")||chdir("/out")) dd1_die("chroot");
    /* No proc/sys/dev mount and no descriptor to the old root. UID 0 in this
     * one-entry user namespace loses all caps AND all root exec privileges. */
    if(prctl(PR_SET_SECUREBITS,SECBIT_NOROOT|SECBIT_NOROOT_LOCKED|
             SECBIT_NO_SETUID_FIXUP|SECBIT_NO_SETUID_FIXUP_LOCKED)) dd1_die("securebits");
    for(int c=0;c<=CAP_LAST_CAP;c++)
        if(prctl(PR_CAPBSET_DROP,c,0,0,0)) dd1_die("drop bounding capability");
    struct __user_cap_header_struct h={.version=_LINUX_CAPABILITY_VERSION_3,.pid=0};
    struct __user_cap_data_struct d[2]={{0},{0}};
    if(syscall(SYS_capset,&h,d)||prctl(PR_SET_NO_NEW_PRIVS,1,0,0,0)) dd1_die("drop capabilities");
    if(syscall(SYS_capget,&h,d) || d[0].effective || d[0].permitted || d[0].inheritable ||
       d[1].effective || d[1].permitted || d[1].inheritable ||
       prctl(PR_GET_NO_NEW_PRIVS,0,0,0,0)!=1 ||
       !(prctl(PR_GET_SECUREBITS,0,0,0,0)&SECBIT_NOROOT_LOCKED)) dd1_die("privilege drop readback");
    return 0;
}
