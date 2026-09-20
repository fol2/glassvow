#define _GNU_SOURCE
/* DD1-PREP-1 harmless synthetic producer. NOT a Godot importer/cache. */
#include <errno.h>
#include <fcntl.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#define SEED "/source/assets/probe.bin.import"
#define ARCHIVE "/dd1-originals/assets/probe.bin.import"
#define RESOURCE "/source/.godot/imported/probe.resource"
static void fail(const char *p) {perror(p);exit(91);}
static size_t read_file(const char *p,char *b,size_t cap) {
    int fd=open(p,O_RDONLY);if(fd<0)fail(p);
    size_t n=0;ssize_t k;
    while((k=read(fd,b+n,cap-1-n))>0) {n+=(size_t)k;if(n==cap-1)fail("input too large");}
    if(k<0||close(fd))fail("read/close");
    b[n]=0;return n;
}
static void write_file(const char *p,const char *b) {
    int fd=open(p,O_WRONLY|O_CREAT|O_TRUNC,0600);if(fd<0)fail(p);
    size_t n=strlen(b);if(write(fd,b,n)!=(ssize_t)n||fsync(fd)||close(fd))fail("write/fsync/close");
}
static void readonly(const char *p) {
    errno=0;int fd=open(p,O_WRONLY|O_TRUNC);int err=errno;
    printf("READONLY %s fd=%d errno=%d\n",p,fd,err);
    if(fd>=0||(err!=EROFS&&err!=EACCES))fail("immutable original changed");
}
static void replace(char *b,const char *from,const char *to) {
    char *p=strstr(b,from);if(!p||strlen(from)!=strlen(to))fail("replace fixture");
    memcpy(p,to,strlen(to));
}
static void *worker(void *unused) {
    (void)unused;
    int rc=pthread_setname_np(pthread_self(),"prep1-worker");
    printf("THREAD_NAME_REFUSAL %d\n",rc);if(rc!=EOPNOTSUPP)fail("thread naming refusal");
    readonly("/source/assets/probe.bin");return NULL;
}
static void save(void) {
    write_file("/out/save.tmp","PREP1\n");if(rename("/out/save.tmp","/out/save.bin"))fail("save rename");
    char b[32];read_file("/out/save.bin",b,sizeof(b));if(strcmp(b,"PREP1\n"))fail("save readback");
    puts("SAVE_READBACK_OK");fflush(stdout);
}
int main(int argc,char **argv) {
    if(argc!=2)return 92;
    const char *mode=argv[1];char original[4096],config[4096],seed[4096],archive[4096],asset[128];
    read_file("/dd1-originals/project.godot",original,sizeof(original));
    read_file("/source/project.godot",config,sizeof(config));
    read_file(ARCHIVE,archive,sizeof(archive));
    read_file("/source/assets/probe.bin",asset,sizeof(asset));
    readonly("/dd1-originals/project.godot");readonly(ARCHIVE);readonly("/source/project.godot");
    pthread_t t;if(pthread_create(&t,NULL,worker,NULL)||pthread_join(t,NULL))fail("thread");
    if(!strcmp(mode,"runtime")) {
        if(strcmp(original,config))fail("runtime config not restored");
        read_file(SEED,seed,sizeof(seed));
        if(!strstr(seed,"; DERIVED-INERT\n"))fail("runtime not using generated sidecar");
        readonly(SEED);read_file(RESOURCE,seed,sizeof(seed));
        if(strcmp(seed,"DD1-INERT-RESOURCE:quality=7:ASSET-INERT\n"))fail("sealed resource");
        puts("ORIGINAL_CONFIG_RESTORED_AND_SEALED_RESOURCE_READ");save();return 0;
    }
    if(!strstr(original,"res://addons/funplay_mcp/plugin.cfg")||
       strstr(config,"res://addons/funplay_mcp/plugin.cfg")||
       !strstr(config,"res://addons/glassvow_web_export/plugin.cfg")||
       !strstr(config,"res://addons/glassvow_ios_export/plugin.cfg"))fail("config projection");
    if(!strcmp(mode,"never-read"))strcpy(seed,archive);
    else read_file(SEED,seed,sizeof(seed));
    if(strcmp(seed,archive))fail("wrong initial seed");
    if(!strstr(seed,"quality=7"))fail("authored parameter not read");
    puts("SEED_READ_AND_CONFIG_PROJECTED");
    if(!strcmp(mode,"mutate-restore")) {
        char bad[4096];strcpy(bad,seed);replace(bad,"quality=7","quality=9");
        write_file(SEED,bad);
        read_file(SEED,bad,sizeof(bad)); /* Distinct unapproved intermediate read. */
    }
    char resource[256];snprintf(resource,sizeof(resource),"DD1-INERT-RESOURCE:quality=%c:%s",'7',asset);
    if(strcmp(mode,"missing-resource"))write_file(RESOURCE,resource);
    char output[8192];snprintf(output,sizeof(output),"; DERIVED-INERT\n%s",seed);
    if(!strcmp(mode,"wrong-uid"))replace(output,"uid://dd1seed","uid://dd1oops");
    if(!strcmp(mode,"wrong-param"))replace(output,"quality=7","quality=9");
    if(!strcmp(mode,"wrong-source"))replace(output,"probe.bin\"","other.bin\"");
    if(!strcmp(mode,"invalid"))snprintf(output,sizeof(output),"; DERIVED-INERT\n[remap]\nvalid=false\n%s",seed+strlen("[remap]\n"));
    if(!strcmp(mode,"malformed"))strcpy(output,"[remap]\nuid=\"unfinished\n");
    if(!strcmp(mode,"incomplete"))strcpy(output,"[remap]\n[deps]\n[params]\n");
    write_file(SEED,output);
    if(!strcmp(mode,"double-write"))write_file(SEED,output);
    if(!strcmp(mode,"undeclared"))write_file("/source/.godot/extra.import","UNDECLARED\n");
    if(!strcmp(mode,"alias")||!strcmp(mode,"hardlink")) {
        errno=0;int rc=!strcmp(mode,"alias")?symlink(SEED,"/source/.godot/alias.import"):link(SEED,"/source/.godot/alias.import");
        printf("ALIAS rc=%d errno=%d\n",rc,errno);
        if(rc!=-1||errno!=EOPNOTSUPP)fail("alias guard");
    }
    if(!strcmp(mode,"source-mutation")) {readonly("/source/inputs/frozen.txt");return 7;}
    if(!strcmp(mode,"config-mutation")) {readonly("/source/project.godot");return 7;}
    save();
    if(!strcmp(mode,"failed"))return 7;
    if(!strcmp(mode,"block"))for(;;){struct timespec d={.tv_nsec=10000000};nanosleep(&d,NULL);}
    return 0;
}
