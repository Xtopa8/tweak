// =============================================================
//  MeituanRiderTweak.xm   v1 保守版
//  目标：美团众包 iOS (banma_iOS_crowdsource) 13.7.9
//  平台：iOS 16.3 arm64 / TrollStore + TrollFools 注入
//
//  本版本【有意不修改】任何定位原始数据：
//    ✗ 不改 CLLocation.speed
//    ✗ 不改 CLLocation.horizontalAccuracy
//  → 导航引擎读到的是真实数据，不会偏航
//
//  功能：
//    1. 越狱 / 注入检测绕过（9 个 OC 类 + 8 个 C 函数）
//    2. 红绿灯采集关闭（hasTrafficLight → NO）+ 上传拦截
//    3. 模拟定位标记清除（sourceInformation → nil）
// =============================================================

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#import <objc/runtime.h>
#import <mach-o/dyld.h>
#import <mach/vm_protect.h>
#import <mach/mach.h>

// ---- 轻量 inline hook 实现（不依赖 CydiaSubstrate） ----
// 说明：完整版 MSHookFunction 实现较长，这里用 dyld 符号重绑定（fishhook 思路）
//      对 libSystem 里的 stat/access/open/fork/ptrace/getenv/sysctl 这类
//      Mach-O lazy symbol pointer 有效。
typedef struct { const char *name; void *replacement; void **original; } rebind_t;

static void **findSymPtr(const char *sym) {
    uint32_t n = _dyld_image_count();
    for (uint32_t i = 1; i < n; i++) {
        const struct mach_header_64 *hdr =
            (const struct mach_header_64 *)_dyld_get_image_header(i);
        if (!hdr || hdr->magic != MH_MAGIC_64) continue;
        intptr_t slide = _dyld_get_image_vmaddr_slide(i);
        const struct segment_command_64 *linkedit = NULL;
        const struct segment_command_64 *dataconst = NULL;
        const struct symtab_command *symtab = NULL;
        const struct dysymtab_command *dysymtab = NULL;
        const struct load_command *lc =
            (const struct load_command *)((char *)hdr + sizeof(struct mach_header_64));
        for (uint32_t c = 0; c < hdr->ncmds; c++) {
            if (lc->cmd == LC_SEGMENT_64) {
                const struct segment_command_64 *seg = (void *)lc;
                if (strcmp(seg->segname, "__LINKEDIT") == 0) linkedit = seg;
                if (strcmp(seg->segname, "__DATA_CONST") == 0) dataconst = seg;
                if (!dataconst && strcmp(seg->segname, "__DATA") == 0) dataconst = seg;
            } else if (lc->cmd == LC_SYMTAB) symtab = (void *)lc;
            else if (lc->cmd == LC_DYSYMTAB) dysymtab = (void *)lc;
            lc = (const struct load_command *)((char *)lc + lc->cmdsize);
        }
        if (!linkedit || !symtab || !dysymtab || !dataconst) continue;
        const char *strtab = (char *)hdr + symtab->stroff + slide;
        const struct nlist_64 *syms =
            (const struct nlist_64 *)((char *)hdr + symtab->symoff + slide);
        const int32_t *indirect =
            (int32_t *)((char *)hdr + dysymtab->indirectsymoff + slide);
        // 遍历 __DATA_CONST,__la_symbol_ptr 与 __got
        const struct section_64 *sect =
            (const struct section_64 *)((char *)dataconst + sizeof(struct segment_command_64));
        for (uint32_t s = 0; s < dataconst->nsects; s++, sect++) {
            if ((sect->flags & SECTION_TYPE) != S_LAZY_SYMBOL_POINTERS &&
                (sect->flags & SECTION_TYPE) != S_NON_LAZY_SYMBOL_POINTERS) continue;
            uint32_t count = sect->size / sizeof(void *);
            void **ptrs = (void **)((char *)hdr + sect->offset + slide);
            for (uint32_t k = 0; k < count; k++) {
                int32_t symidx = indirect[sect->reserved1 + k];
                if (symidx < 0) continue;
                const char *name = strtab + syms[symidx].n_un.n_strx;
                if (!name) continue;
                if (strcmp(name, sym) == 0 || (name[0] == '_' && strcmp(name + 1, sym) == 0)) {
                    return &ptrs[k];
                }
            }
        }
    }
    return NULL;
}

static void rebindSymbol(const char *sym, void *repl, void **orig) {
    void **p = findSymPtr(sym);
    if (!p) return;
    if (orig) *orig = *p;
    vm_protect(mach_task_self(), (vm_address_t)p, sizeof(void *),
               false, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
    *p = repl;
    vm_protect(mach_task_self(), (vm_address_t)p, sizeof(void *),
               false, VM_PROT_READ);
}
#define MSHookFunction(sym, repl, orig) rebindSymbol(#sym, (void*)(repl), (void**)(orig))

#import <sys/stat.h>
#import <sys/sysctl.h>
#import <sys/ptrace.h>
#import <unistd.h>
#import <errno.h>
#import <string.h>
#import <stdlib.h>

// =============================================================
//  一、越狱检测绕过
// =============================================================

static const char *kJailbreakPaths[] = {
    "/Applications/Cydia.app",
    "/Applications/Sileo.app",
    "/Applications/Zebra.app",
    "/Library/MobileSubstrate",
    "/Library/MobileSubstrate/MobileSubstrate.dylib",
    "/bin/bash", "/bin/sh",
    "/usr/sbin/sshd", "/usr/bin/ssh",
    "/etc/apt", "/etc/ssh/sshd_config",
    "/private/var/lib/apt",
    "/private/var/lib/cydia",
    "/private/jailbreak.txt",
    "/var/jb", "/private/preboot",
    "/usr/libexec/cydia",
    NULL
};

static BOOL isJailbreakPath(const char *path) {
    if (!path) return NO;
    for (int i = 0; kJailbreakPaths[i]; i++) {
        if (strcmp(path, kJailbreakPaths[i]) == 0) return YES;
    }
    if (strstr(path, "MobileSubstrate")) return YES;
    return NO;
}

static int (*orig_stat)(const char *, struct stat *);
static int my_stat(const char *path, struct stat *buf) {
    if (isJailbreakPath(path)) { errno = ENOENT; return -1; }
    return orig_stat(path, buf);
}

static int (*orig_access)(const char *, int);
static int my_access(const char *path, int mode) {
    if (isJailbreakPath(path)) { errno = ENOENT; return -1; }
    return orig_access(path, mode);
}

static int (*orig_open)(const char *, int, ...);
static int my_open(const char *path, int oflag, ...) {
    if (isJailbreakPath(path)) { errno = ENOENT; return -1; }
    va_list ap; va_start(ap, oflag);
    mode_t mode = va_arg(ap, int);
    va_end(ap);
    return orig_open(path, oflag, mode);
}

static pid_t (*orig_fork)(void);
static pid_t my_fork(void) { errno = EAGAIN; return -1; }

static int (*orig_ptrace)(int, pid_t, caddr_t, int);
static int my_ptrace(int req, pid_t pid, caddr_t addr, int data) { return 0; }

static char *(*orig_getenv)(const char *);
static char *my_getenv(const char *name) {
    if (name && strcmp(name, "DYLD_INSERT_LIBRARIES") == 0) return NULL;
    return orig_getenv(name);
}

static int (*orig_sysctl)(int *, u_int, void *, size_t *, void *, size_t);
static int my_sysctl(int *name, u_int namelen, void *info, size_t *infosize,
                     void *newp, size_t newlen) {
    int r = orig_sysctl(name, namelen, info, infosize, newp, newlen);
    if (r == 0 && name && namelen >= 2 && name[0] == CTL_KERN && name[1] == KERN_PROC && info) {
        struct kinfo_proc *kp = (struct kinfo_proc *)info;
        kp->kp_proc.p_flag &= ~P_TRACED;
    }
    return r;
}

static uint32_t (*orig_dyld_image_count)(void);
static uint32_t my_dyld_image_count(void) {
    return orig_dyld_image_count();
}

// --- OC 层越狱检测 ---
%hook BMCSJailbreakManager
- (BOOL)bmcs_isJailbreak { return NO; }
- (NSArray *)localForbiddenDylibs { return @[]; }
- (NSArray *)jailbreakDylibs { return @[]; }
%end

%hook BMPSecurityServiceImpl
- (BOOL)bmp_isJailbreak { return NO; }
- (BOOL)appIsJailbroken { return NO; }
%end

%hook CIPFJailBreak
- (BOOL)cipf_isJailBreak { return NO; }
- (BOOL)cipf_isAppJailBreak { return NO; }
%end

%hook SAKFJailBreak
- (BOOL)sakf_isJailBreak { return NO; }
%end

%hook MPCPaymentJailBreak
- (BOOL)mpc_isJailBreak { return NO; }
%end

%hook NVJailbrokenChecker
- (BOOL)checkJailBreak { return NO; }
- (BOOL)deviceIsJailbroken { return NO; }
%end

%hook BMPOperationJailbreakRootCheck
- (BOOL)isJailBroken { return NO; }
- (NSString *)readJailBreakFile { return nil; }
- (void)reportJailbrokenAsynDegrade { }
%end

%hook BMCSJailBreakLimitGrabWaybill
- (BOOL)checkJailBreakLimitGrab:(id)arg { return YES; }
%end

// 兜底：零散越狱检测方法
static void swizzleJailbreakBooleans(void) {
    NSArray *sels = @[@"dp_appIsJailbroken", @"fake_isJailbreak",
                      @"isJailBroken", @"bmcs_isJailbreak"];
    NSArray *clsNames = @[@"NSObject", @"BMCSJailbreakManager",
                          @"BMPOperationJailbreakRootCheck"];
    for (NSString *cn in clsNames) {
        Class c = objc_getClass(cn.UTF8String);
        if (!c) continue;
        for (NSString *sn in sels) {
            Method m = class_getInstanceMethod(c, NSSelectorFromString(sn));
            if (!m) continue;
            IMP fake = imp_implementationWithBlock(^BOOL(id _self) { return NO; });
            method_setImplementation(m, fake);
        }
    }
}

// =============================================================
//  二、红绿灯：关闭采集 + 拦截上传（不改判定结果值）
// =============================================================

%hook NaviTrafficLight
- (BOOL)hasTrafficLight { return NO; }
%end

%hook BMPIoTTrafficLightDispatchManager
- (void)uploadTrafficLightsAsyncVideo:(id)v videoKeyList:(id)l fps:(id)f
                              success:(id)s failure:(id)fl {
    // 空实现：不产生红绿灯上报
}
%end

static void disableTrafficLightGetters(void) {
    NSArray *clsNames = @[@"MTNVWaitRedLightInfo", @"WaitRedLightInfo",
                          @"MTNVWaitRedLightTimeInfo", @"WaitRedLightTimeInfo",
                          @"MTNVTrafficLightCountdownInfo", @"TrafficLightCountdownInfo",
                          @"NaviTrafficLight"];
    NSArray *boolSels = @[@"hasTrafficLight", @"shouldShowTrafficLight"];
    for (NSString *cn in clsNames) {
        Class c = objc_getClass(cn.UTF8String);
        if (!c) continue;
        for (NSString *sn in boolSels) {
            Method m = class_getInstanceMethod(c, NSSelectorFromString(sn));
            if (!m) continue;
            IMP fake = imp_implementationWithBlock(^BOOL(id _self) { return NO; });
            method_setImplementation(m, fake);
        }
    }
}

// =============================================================
//  三、模拟定位标记清除（不影响导航）
// =============================================================

%hook CLLocation
- (CLLocationSourceInformation *)sourceInformation { return nil; }
%end

// =============================================================
//  四、初始化
// =============================================================
%ctor {
    @autoreleasepool {
        NSLog(@"[MeituanRiderTweak] v1 conservative loading...");

        MSHookFunction((void *)stat, (void *)my_stat, (void **)&orig_stat);
        MSHookFunction((void *)access, (void *)my_access, (void **)&orig_access);
        MSHookFunction((void *)open, (void *)my_open, (void **)&orig_open);
        MSHookFunction((void *)fork, (void *)my_fork, (void **)&orig_fork);
        MSHookFunction((void *)ptrace, (void *)my_ptrace, (void **)&orig_ptrace);
        MSHookFunction((void *)getenv, (void *)my_getenv, (void **)&orig_getenv);
        MSHookFunction((void *)sysctl, (void *)my_sysctl, (void **)&orig_sysctl);
        MSHookFunction((void *)_dyld_image_count, (void *)my_dyld_image_count,
                       (void **)&orig_dyld_image_count);

        swizzleJailbreakBooleans();
        disableTrafficLightGetters();

        NSLog(@"[MeituanRiderTweak] v1 loaded. Navigation untouched.");
    }
}
