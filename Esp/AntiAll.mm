#import "AntiAll.h"
#import <UIKit/UIKit.h>
#include <mach-o/dyld.h>
#include <mach-o/loader.h>
#include <mach-o/getsect.h>
#include <mach-o/dyld_images.h>
#include <sys/syscall.h>
#include <unistd.h>
#include <pthread.h>
#include <mach/mach.h>
#include <sys/sysctl.h>
#include <dlfcn.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <sys/time.h>
#include <stdlib.h>
#include <dirent.h>
#include <sys/mount.h>
#include <objc/runtime.h>
#include <objc/message.h>
#include <mach/vm_region.h>

#ifdef __arm64__
#define INLINE_SYSCALL(sysno, arg1, arg2, arg3, arg4) ({ \
    register long x0 __asm__("x0") = (long)(arg1); \
    register long x1 __asm__("x1") = (long)(arg2); \
    register long x2 __asm__("x2") = (long)(arg3); \
    register long x3 __asm__("x3") = (long)(arg4); \
    register long x16 __asm__("x16") = (sysno); \
    __asm__ volatile ( \
        "svc #0x80\n" \
        : "=r"(x0) \
        : "r"(x0), "r"(x1), "r"(x2), "r"(x3), "r"(x16) \
        : "memory", "cc" \
    ); \
    x0; \
})
#else
#define INLINE_SYSCALL(sysno, arg1, arg2, arg3, arg4) syscall(sysno, arg1, arg2, arg3, arg4)
#endif

__attribute__((always_inline)) static inline void n_c() {
#ifdef __arm64__
    __asm__ __volatile__("brk #0x1337");
    __asm__ __volatile__("mov x0, #0; str x0, [x0]");
#endif
    __builtin_trap();
    INLINE_SYSCALL(1, 0, 0, 0, 0);
    volatile int *p = 0; *p = 0;
    exit(0);
}

__attribute__((always_inline)) static inline size_t c_s(const char *s) {
    size_t l = 0;
    while (s[l]) l++;
    return l;
}

__attribute__((always_inline)) static inline int c_sc(const char *s1, const char *s2) {
    while (*s1 && (*s1 == *s2)) { s1++; s2++; }
    return *(const unsigned char*)s1 - *(const unsigned char*)s2;
}

__attribute__((always_inline)) static inline const char* c_ss(const char *h, const char *n) {
    size_t l1 = c_s(h), l2 = c_s(n);
    if (!l2) return h;
    if (l2 > l1) return NULL;
    for (size_t i = 0; i <= l1 - l2; i++) {
        size_t j;
        for (j = 0; j < l2; j++) if (tolower(h[i + j]) != tolower(n[j])) break;
        if (j == l2) return &h[i];
    }
    return NULL;
}

// ================== SHA256 ==================
typedef struct {
    uint8_t data[64];
    uint32_t datalen;
    unsigned long long bitlen;
    uint32_t state[8];
} SHA256_CTX;

#define ROTRIGHT(a,b) (((a) >> (b)) | ((a) << (32-(b))))
#define CH(x,y,z) (((x) & (y)) ^ (~(x) & (z)))
#define MAJ(x,y,z) (((x) & (y)) ^ ((x) & (z)) ^ ((y) & (z)))
#define EP0(x) (ROTRIGHT(x,2) ^ ROTRIGHT(x,13) ^ ROTRIGHT(x,22))
#define EP1(x) (ROTRIGHT(x,6) ^ ROTRIGHT(x,11) ^ ROTRIGHT(x,25))
#define SIG0(x) (ROTRIGHT(x,7) ^ ROTRIGHT(x,18) ^ ((x) >> 3))
#define SIG1(x) (ROTRIGHT(x,17) ^ ROTRIGHT(x,19) ^ ((x) >> 10))

static const uint32_t k[64] = {
    0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
    0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
    0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
    0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
    0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
    0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
    0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
    0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2
};

__attribute__((always_inline)) static inline void sha256_transform(SHA256_CTX *ctx, const uint8_t data[]) {
    uint32_t a, b, c, d, e, f, g, h, i, j, t1, t2, m[64];
    for (i = 0, j = 0; i < 16; ++i, j += 4)
        m[i] = (data[j] << 24) | (data[j + 1] << 16) | (data[j + 2] << 8) | (data[j + 3]);
    for ( ; i < 64; ++i)
        m[i] = SIG1(m[i - 2]) + m[i - 7] + SIG0(m[i - 15]) + m[i - 16];
    a = ctx->state[0]; b = ctx->state[1]; c = ctx->state[2]; d = ctx->state[3];
    e = ctx->state[4]; f = ctx->state[5]; g = ctx->state[6]; h = ctx->state[7];
    for (i = 0; i < 64; ++i) {
        t1 = h + EP1(e) + CH(e,f,g) + k[i] + m[i];
        t2 = EP0(a) + MAJ(a,b,c);
        h = g; g = f; f = e; e = d + t1;
        d = c; c = b; b = a; a = t1 + t2;
    }
    ctx->state[0] += a; ctx->state[1] += b; ctx->state[2] += c; ctx->state[3] += d;
    ctx->state[4] += e; ctx->state[5] += f; ctx->state[6] += g; ctx->state[7] += h;
}

__attribute__((always_inline)) static inline void sha256_init(SHA256_CTX *ctx) {
    ctx->datalen = 0; ctx->bitlen = 0;
    ctx->state[0] = 0x6a09e667; ctx->state[1] = 0xbb67ae85;
    ctx->state[2] = 0x3c6ef372; ctx->state[3] = 0xa54ff53a;
    ctx->state[4] = 0x510e527f; ctx->state[5] = 0x9b05688c;
    ctx->state[6] = 0x1f83d9ab; ctx->state[7] = 0x5be0cd19;
}

__attribute__((always_inline)) static inline void sha256_update(SHA256_CTX *ctx, const uint8_t data[], size_t len) {
    for (size_t i = 0; i < len; ++i) {
        ctx->data[ctx->datalen] = data[i];
        ctx->datalen++;
        if (ctx->datalen == 64) {
            sha256_transform(ctx, ctx->data);
            ctx->bitlen += 512;
            ctx->datalen = 0;
        }
    }
}

__attribute__((always_inline)) static inline void sha256_final(SHA256_CTX *ctx, uint8_t hash[]) {
    uint32_t i = ctx->datalen;
    ctx->data[i++] = 0x80;
    if (ctx->datalen < 56) {
        for (; i < 56; ++i) ctx->data[i] = 0x00;
    } else {
        for (; i < 64; ++i) ctx->data[i] = 0x00;
        sha256_transform(ctx, ctx->data);
        for (i = 0; i < 56; ++i) ctx->data[i] = 0x00;
    }
    ctx->bitlen += ctx->datalen * 8;
    ctx->data[63] = ctx->bitlen;        ctx->data[62] = ctx->bitlen >> 8;
    ctx->data[61] = ctx->bitlen >> 16;  ctx->data[60] = ctx->bitlen >> 24;
    ctx->data[59] = ctx->bitlen >> 32;  ctx->data[58] = ctx->bitlen >> 40;
    ctx->data[57] = ctx->bitlen >> 48;  ctx->data[56] = ctx->bitlen >> 56;
    sha256_transform(ctx, ctx->data);
    for (i = 0; i < 4; ++i) {
        hash[i]      = (ctx->state[0] >> (24 - i * 8)) & 0x000000ff;
        hash[i + 4]  = (ctx->state[1] >> (24 - i * 8)) & 0x000000ff;
        hash[i + 8]  = (ctx->state[2] >> (24 - i * 8)) & 0x000000ff;
        hash[i + 12] = (ctx->state[3] >> (24 - i * 8)) & 0x000000ff;
        hash[i + 16] = (ctx->state[4] >> (24 - i * 8)) & 0x000000ff;
        hash[i + 20] = (ctx->state[5] >> (24 - i * 8)) & 0x000000ff;
        hash[i + 24] = (ctx->state[6] >> (24 - i * 8)) & 0x000000ff;
        hash[i + 28] = (ctx->state[7] >> (24 - i * 8)) & 0x000000ff;
    }
}

__attribute__((always_inline)) static inline int cmp_hash(const uint8_t *h1, const uint8_t *h2) {
    for (int i = 0; i < 32; i++) if (h1[i] != h2[i]) return 1;
    return 0;
}

__attribute__((always_inline)) static inline void is_h_z(const uint8_t *h, int *z) {
    *z = 1;
    for (int i = 0; i < 32; i++) { if (h[i] != 0) { *z = 0; break; } }
}

// ================== INTEGRITY CHECK ==================
#define MAX_SECT_HASHES 64
static uint8_t orig_sect_hashes[MAX_SECT_HASHES][32] = {{0}};
static uint64_t orig_sect_sizes[MAX_SECT_HASHES] = {0};
static int sect_hash_count = 0;

// ✅ FIX: chỉ hash __TEXT,__text — code thuần, không bao giờ thay đổi runtime
__attribute__((always_inline)) static inline void v_m_i() {
    const struct mach_header_64 *h = (const struct mach_header_64 *)_dyld_get_image_header(0);
    if (!h) return;
    intptr_t sl = _dyld_get_image_vmaddr_slide(0);
    const struct load_command *c = (const struct load_command *)((char *)h + sizeof(struct mach_header_64));

    // (1) __TEXT phải không writable
    for (uint32_t i = 0; i < h->ncmds; i++) {
        if (c->cmd == LC_SEGMENT_64) {
            const struct segment_command_64 *sg = (const struct segment_command_64 *)c;
            if (c_sc(sg->segname, "__TEXT") == 0) {
                if ((sg->maxprot & VM_PROT_WRITE) || (sg->initprot & VM_PROT_WRITE)) n_c();
            }
        }
        c = (const struct load_command *)((char *)c + c->cmdsize);
    }

    // (2) Chỉ hash __TEXT,__text
    c = (const struct load_command *)((char *)h + sizeof(struct mach_header_64));
    int idx = 0;
    for (uint32_t i = 0; i < h->ncmds; i++) {
        if (c->cmd == LC_SEGMENT_64) {
            const struct segment_command_64 *sg = (const struct segment_command_64 *)c;
            if (c_sc(sg->segname, "__TEXT") != 0) {
                c = (const struct load_command *)((char *)c + c->cmdsize);
                continue;
            }
            const struct section_64 *sc = (const struct section_64 *)((char *)sg + sizeof(struct segment_command_64));
            for (uint32_t j = 0; j < sg->nsects; j++) {
                if (c_sc(sc->sectname, "__text") == 0 && sc->size > 0 && idx < MAX_SECT_HASHES) {
                    uint8_t *cs = (uint8_t *)(sc->addr + sl);
                    SHA256_CTX ctx; uint8_t out[32];
                    sha256_init(&ctx);
                    sha256_update(&ctx, cs, sc->size);
                    sha256_final(&ctx, out);

                    int z; is_h_z(orig_sect_hashes[idx], &z);
                    if (z) {
                        memcpy(orig_sect_hashes[idx], out, 32);
                        orig_sect_sizes[idx] = sc->size;
                    } else if (orig_sect_sizes[idx] == sc->size &&
                               cmp_hash(orig_sect_hashes[idx], out) != 0) {
                        n_c();
                    }
                    idx++;
                }
                sc = (const struct section_64 *)((char *)sc + sizeof(struct section_64));
            }
        }
        c = (const struct load_command *)((char *)c + c->cmdsize);
    }
    sect_hash_count = idx;
}

// ================== DYLIB INJECTION ==================
__attribute__((always_inline)) static inline void c_d_i() {
    struct task_dyld_info d_i;
    mach_msg_type_number_t c_n = TASK_DYLD_INFO_COUNT;
    if (task_info(mach_task_self(), TASK_DYLD_INFO, (task_info_t)&d_i, &c_n) == KERN_SUCCESS) {
        struct dyld_all_image_infos *a_i = (struct dyld_all_image_infos *)d_i.all_image_info_addr;

        char k1[] = {'f','r','i','d','a','\0'};
        char k2[] = {'c','y','c','r','i','p','t','\0'};
        char k3[] = {'l','i','b','h','o','o','k','e','r','\0'};

        for (uint32_t i = 1; i < a_i->infoArrayCount; i++) {
            const char *p = a_i->infoArray[i].imageFilePath;
            if (!p) continue;
            if (c_ss(p, k1) || c_ss(p, k2) || c_ss(p, k3)) n_c();
        }
    } else {
        n_c();
    }
}

// ================== FRIDA THREAD CHECK ==================
extern "C" pthread_t pthread_from_mach_thread_np(mach_port_t);
__attribute__((always_inline)) static inline void c_f_t() {
    thread_act_array_t t_a;
    mach_msg_type_number_t t_c = 0;
    if (task_threads(mach_task_self(), &t_a, &t_c) == KERN_SUCCESS) {
        for (mach_msg_type_number_t i = 0; i < t_c; i++) {
            pthread_t pt = pthread_from_mach_thread_np(t_a[i]);
            if (pt) {
                char n[256]; n[0] = '\0';
                pthread_getname_np(pt, n, sizeof(n));
                if (c_s(n) > 0) {
                    // ✅ FIX: bỏ "gmain" vì quá phổ biến (GameCenter, GCD worker...)
                    char tk1[] = {'g','u','m','-','j','s','-','l','o','o','p','\0'};
                    char tk3[] = {'p','o','o','l','-','f','r','i','d','a','\0'};
                    char tk4[] = {'f','r','i','d','a','\0'};
                    if (c_ss(n, tk1) || c_ss(n, tk3) || c_ss(n, tk4)) n_c();
                }
            }
        }
        vm_deallocate(mach_task_self(), (vm_address_t)t_a, t_c * sizeof(thread_act_t));
    }
}

// ================== FRIDA PORT CHECK ==================
__attribute__((always_inline)) static inline void c_f_p() {
    int s = socket(AF_INET, SOCK_STREAM, 0);
    if (s >= 0) {
        struct sockaddr_in sa;
        bzero(&sa, sizeof(sa));
        sa.sin_family = AF_INET;
        sa.sin_port = htons(27042);
        sa.sin_addr.s_addr = inet_addr("127.0.0.1");
        if (connect(s, (struct sockaddr *)&sa, sizeof(sa)) == 0) { close(s); n_c(); }
        sa.sin_port = htons(27043);
        if (connect(s, (struct sockaddr *)&sa, sizeof(sa)) == 0) { close(s); n_c(); }
        close(s);
    }
}

// ================== TROLLFOOLS CHECK ==================
__attribute__((always_inline)) static inline void c_t_w() {
    @autoreleasepool {
        Class aw = NSClassFromString([NSString stringWithFormat:@"%@%@%@", @"LS", @"Application", @"Workspace"]);
        if (aw) {
            id w = ((id (*)(Class, SEL))objc_msgSend)(aw,
                NSSelectorFromString([NSString stringWithFormat:@"%@%@", @"default", @"Workspace"]));
            if (w) {
                NSArray *apps = ((NSArray *(*)(id, SEL))objc_msgSend)(w,
                    NSSelectorFromString([NSString stringWithFormat:@"%@%@", @"allInstalled", @"Applications"]));
                NSString *sel3 = [NSString stringWithFormat:@"%@%@", @"application", @"Identifier"];
                NSString *tf = [NSString stringWithFormat:@"%@.%@.%@", @"wiki", @"qaq", @"TrollFools"];
                for (id a in apps) {
                    NSString *b = ((NSString *(*)(id, SEL))objc_msgSend)(a, NSSelectorFromString(sel3));
                    if ([b isEqualToString:tf]) n_c();
                }
            }
        }
    }
}

// ================== FLEX CHECK ==================
__attribute__((always_inline)) static inline void c_b_i() {
    @autoreleasepool {
        Class aw = NSClassFromString([NSString stringWithFormat:@"%@%@%@", @"LS", @"Application", @"Workspace"]);
        if (aw) {
            id w = ((id (*)(Class, SEL))objc_msgSend)(aw,
                NSSelectorFromString([NSString stringWithFormat:@"%@%@", @"default", @"Workspace"]));
            if (w) {
                NSArray *apps = ((NSArray *(*)(id, SEL))objc_msgSend)(w,
                    NSSelectorFromString([NSString stringWithFormat:@"%@%@", @"allInstalled", @"Applications"]));
                NSString *sel3 = [NSString stringWithFormat:@"%@%@", @"application", @"Identifier"];
                NSString *flexId = [NSString stringWithFormat:@"%@.%@.%@", @"com", @"johncoates", @"Flex"];
                for (id a in apps) {
                    NSString *bid = ((NSString *(*)(id, SEL))objc_msgSend)(a, NSSelectorFromString(sel3));
                    if ([bid isEqualToString:flexId]) n_c();
                }
            }
        }
    }
}

// ================== HARDWARE BREAKPOINT ==================
// ✅ FIX: Metal/ImGui có thể dùng debug registers → false positive → tắt check này
__attribute__((always_inline)) static inline void c_h_b() {
    return;
}

// ================== EXCEPTION PORT ==================
__attribute__((always_inline)) static inline void c_e_p() {
    exception_mask_t m[EXC_TYPES_COUNT];
    mach_port_t p[EXC_TYPES_COUNT];
    exception_behavior_t b[EXC_TYPES_COUNT];
    thread_state_flavor_t f[EXC_TYPES_COUNT];
    mach_msg_type_number_t c = 0;
    if (task_get_exception_ports(mach_task_self(), EXC_MASK_ALL, m, &c, p, b, f) == KERN_SUCCESS) {
        // hiện tại không hành động gì
    }
}

// ================== ANTI-DEBUG (P_TRACED) ==================
__attribute__((always_inline)) static inline void c_d_t() {
    int m[4] = {CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()};
    struct kinfo_proc i;
    size_t s = sizeof(i);
    i.kp_proc.p_flag = 0;
    if (sysctl(m, 4, &i, &s, NULL, 0) == 0) {
        if ((i.kp_proc.p_flag & P_TRACED) != 0) n_c();
    }
}

// ================== BACKGROUND MONITOR ==================
static void* a_h_l(void* a) {
    while(1) {
        v_m_i();
        c_b_i();
        c_f_p();
        c_f_t();
        c_d_i();
        c_t_w();
        c_h_b();
        c_d_t();
        c_e_p();
        struct timeval t1, t2;
        gettimeofday(&t1, NULL);
        volatile int d = 0;
        for(int i=0; i<100000; i++) d += i;
        gettimeofday(&t2, NULL);
        long el = (t2.tv_sec - t1.tv_sec) * 1000 + (t2.tv_usec - t1.tv_usec) / 1000;
        if (el > 2000) n_c();
        sleep(3);
    }
    return NULL;
}

__attribute__((constructor)) static void i_u_p() {
    INLINE_SYSCALL(26, 31, 0, 0, 0);
    v_m_i();
    c_b_i();
    c_d_i();
    c_t_w();
    c_d_t();
    pthread_t t;
    pthread_create(&t, NULL, a_h_l, NULL);
}

@implementation AntiAll
@end