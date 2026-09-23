#define _GNU_SOURCE
#include "capabilities.h"
#include <errno.h>
#include <signal.h>
#include <sched.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/syscall.h>

uint64_t dd1_task_start(pid_t group,pid_t tid) {
    char path[100],buf[4096];
    snprintf(path,sizeof(path),"/proc/%d/task/%d/stat",group,tid);
    FILE *f=fopen(path,"r"); if(!f) return 0;
    char *ok=fgets(buf,sizeof(buf),f); fclose(f); if(!ok) return 0;
    char *end=strrchr(buf,')'); if(!end||end[1]!=' ') return 0;
    char *save=NULL,*part=strtok_r(end+2," ",&save);
    for(int field=3;part;field++,part=strtok_r(NULL," ",&save)) {
        if(field==22) {char *e;unsigned long long n=strtoull(part,&e,10);return *e?0:n;}
    }
    return 0;
}

void dd1_refusal(struct dd1_capabilities *c,const struct seccomp_notif *q,
                 const struct seccomp_notif_resp *a,unsigned threads,
                 unsigned execs,unsigned clone3,int sent,uint64_t start) {
    const char *kind="UNEXPECTED";
    /* q.pid comes from seccomp, /proc path pins thread-group membership and
     * start ticks. No guest name/string/stack/stdout is used as authority. */
    if(q->data.nr==__NR_clone3) {
        kind="CLONE3_ENOSYS";
        if(!sent || (c->enabled && (!start || clone3>c->clone3_cap))) {
            kind="UNEXPECTED_CLONE3"; ++c->unexpected;
        }
    } else if(c->enabled && sent && start && execs==1 &&
              a->error==-EOPNOTSUPP && q->data.nr==__NR_clone &&
              q->pid==(unsigned)c->workload && threads==1 &&
              c->naming_refusals==0 && c->process_refusals==0 &&
              q->data.args[0]==(CLONE_VM|CLONE_VFORK|SIGCHLD) &&
              q->data.args[2]==0 && q->data.args[3]==0 && q->data.args[4]==0) {
        kind="PROCESS_CREATION_UNAVAILABLE"; ++c->process_refusals;
    } else if(c->enabled && sent && start && execs==1 &&
              a->error==-EOPNOTSUPP && q->data.nr==__NR_prctl && q->data.args[0]==15 &&
              c->naming_refusals<c->naming_cap && c->naming_refusals<threads &&
              c->naming_refusals<DD1_FIT_THREADS) {
        unsigned i;
        for(i=0;i<c->naming_refusals;i++)
            if(c->named[i].tid==(pid_t)q->pid && c->named[i].start==start) break;
        if(i==c->naming_refusals) {
            c->named[i]=(struct dd1_task){.tid=(pid_t)q->pid,.start=start};
            ++c->naming_refusals; kind="THREAD_NAMING_UNAVAILABLE";
        } else ++c->unexpected;
    } else ++c->unexpected;
    ++c->refused_requests;
    /* Emit EVERY received refusal. A finite diagnostic cap terminates the unit
     * after this event, never silently drops records to turn it into success. */
    if(c->refused_requests>=DD1_REFUSAL_RECORDS) c->fatal=1;
    printf("{\"phase\":\"refusal\",\"sequence\":%u,\"id\":%llu,\"tid\":%u,"
           "\"start_ticks\":%llu,\"nr\":%d,\"arch\":%u,\"ip\":%llu,"
           "\"args\":[%llu,%llu,%llu,%llu,%llu,%llu],\"errno\":%d,"
           "\"response_sent\":%s,\"capability_class\":\"%s\","
           "\"attribution\":\"CAPABILITY_CLASS_ONLY\"}\n",
           c->refused_requests,(unsigned long long)q->id,q->pid,
           (unsigned long long)start,q->data.nr,q->data.arch,
           (unsigned long long)q->data.instruction_pointer,
           (unsigned long long)q->data.args[0],(unsigned long long)q->data.args[1],
           (unsigned long long)q->data.args[2],(unsigned long long)q->data.args[3],
           (unsigned long long)q->data.args[4],(unsigned long long)q->data.args[5],
           -a->error,sent?"true":"false",kind);
    fflush(stdout);
}
