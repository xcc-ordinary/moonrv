/* Sieve of Eratosthenes benchmark, freestanding RV32/RV64 C (gcc -O2, no libc).
 * Counts primes below 8192 (= 1028). Exercises .bss, nested loops, byte stores.
 * Build:
 *   riscv64-unknown-elf-gcc -march=rv32imac -mabi=ilp32 -nostdlib -static \
 *     -ffreestanding -O2 -Wl,-e,_start -o sieve-rv32 sieve.c
 *   riscv64-unknown-elf-gcc -march=rv64imac -mabi=lp64  -nostdlib -static \
 *     -ffreestanding -O2 -Wl,-e,_start -o sieve-rv64 sieve.c
 * Expected output: primes=1028\n
 */
typedef unsigned long ulong;
static long sys6(long n,long a,long b,long c,long d,long e,long f){
  register long a0 asm("a0")=a; register long a1 asm("a1")=b;
  register long a2 asm("a2")=c; register long a3 asm("a3")=d;
  register long a4 asm("a4")=e; register long a5 asm("a5")=f;
  register long a7 asm("a7")=n;
  asm volatile("ecall":"+r"(a0):"r"(a1),"r"(a2),"r"(a3),"r"(a4),"r"(a5),"r"(a7):"memory");
  return a0;
}
static void puts_(const char*s){ long n=0; while(s[n])n++; sys6(64,1,(long)s,n,0,0,0); }
static char* utoa(ulong v,char*end){ *--end='\n'; if(v==0)*--end='0'; while(v>0){*--end=(char)('0'+(v%10)); v/=10;} return end; }
static unsigned char flags[8192];
void _start(void){
  ulong N=8192, count=0;
  for(ulong i=0;i<N;i++) flags[i]=1;
  for(ulong i=2;i<N;i++){ if(flags[i]){ count++; for(ulong j=i*i;j<N;j+=i) flags[j]=0; } }
  char buf[40]; char* s=utoa(count,buf+40);
  puts_("primes="); puts_(s);
  sys6(93,0,0,0,0,0,0);
  for(;;){}
}