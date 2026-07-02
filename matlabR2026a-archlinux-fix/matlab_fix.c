#define _GNU_SOURCE
#include <signal.h>
#include <ucontext.h>
#include <stdint.h>
#include <sys/mman.h>

/* Minimal x86-64 instruction length estimator for MOV/CMP patterns */
static int insn_len(uint8_t *ip) {
    int i = 0;
    while (i < 4 && (ip[i] & 0xf0) == 0x40) i++; /* REX */
    uint8_t op = ip[i++];
    if (op == 0x80) { /* CMP r/m8, imm8 */
        uint8_t m = ip[i++]; int mod=m>>6, rm=m&7;
        if (rm==4 && mod!=3) i++;
        if (mod==0&&rm==5) i+=4; else if(mod==1) i++; else if(mod==2) i+=4;
        return i+1; /* imm8 */
    }
    if ((op>=0x88&&op<=0x8b)||op==0x84||op==0x85) { /* MOV/TEST */
        uint8_t m = ip[i++]; int mod=m>>6, rm=m&7;
        if (rm==4 && mod!=3) i++;
        if (mod==0&&rm==5) i+=4; else if(mod==1) i++; else if(mod==2) i+=4;
        return i;
    }
    return 0;
}

static void segv_handler(int sig, siginfo_t *info, void *uctx) {
    ucontext_t *ctx = (ucontext_t *)uctx;
    uintptr_t addr = (uintptr_t)info->si_addr;
    if (addr < 0x10000) {
        uint8_t *rip = (uint8_t *)ctx->uc_mcontext.gregs[REG_RIP];
        int len = insn_len(rip);
        if (len > 0) {
            ctx->uc_mcontext.gregs[REG_RIP] += len;
            /* Zero likely destination registers */
            ctx->uc_mcontext.gregs[REG_RAX] = 0;
            ctx->uc_mcontext.gregs[REG_RCX] = 0;
            ctx->uc_mcontext.gregs[REG_RDX] = 0;
            ctx->uc_mcontext.gregs[REG_RSI] = 0;
            ctx->uc_mcontext.gregs[REG_RDI] = 0;
            ctx->uc_mcontext.gregs[REG_R8]  = 0;
            ctx->uc_mcontext.gregs[REG_R9]  = 0;
            return;
        }
    }
    struct sigaction sa = {.sa_handler = SIG_DFL};
    sigaction(SIGSEGV, &sa, NULL);
    raise(SIGSEGV);
}

__attribute__((constructor))
static void init(void) {
    /* Map zero pages at all three CPUID "GenuineIntel" vendor values:
       EBX=0x756e6547 "Genu", EDX=0x49656e69 "ineI", ECX=0x6c65746e "ntel" */
    uintptr_t pages[] = {0x75600000, 0x49600000, 0x6c600000};
    for (int i = 0; i < 3; i++)
        mmap((void*)pages[i], 0x100000,
             PROT_READ|PROT_WRITE,
             MAP_PRIVATE|MAP_ANONYMOUS|MAP_FIXED, -1, 0);

    /* SIGSEGV handler for downstream null+offset crashes */
    struct sigaction sa = {0};
    sa.sa_sigaction = segv_handler;
    sa.sa_flags = SA_SIGINFO;
    sigaction(SIGSEGV, &sa, NULL);
}
