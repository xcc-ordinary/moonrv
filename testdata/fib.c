/* Freestanding RV32 C program compiled by gcc (-O2 -march=rv32imac -mabi=ilp32
 * -nostdlib -static -ffreestanding -Wl,-e,_start). No libc: raw ecall wrappers.
 * Exercises anonymous mmap, getpid, write and exit on real optimized C code
 * (loops, function calls, stack frames). Build:
 *   riscv64-unknown-elf-gcc -march=rv32imac -mabi=ilp32 -nostdlib -static \
 *     -ffreestanding -O2 -Wl,-e,_start -o fib-rv32 fib.c
 * Expected moonrv output: fib20=6765\npid=1\nOK\n (getpid is fixed to 1).
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
void _start(void){
  char* mem=(char*)sys6(222,0,4096,3,0x22,-1,0);   /* mmap anonymous RW */
  long pid=sys6(172,0,0,0,0,0,0);                   /* getpid */
  ulong a=0,b=1; for(int i=0;i<20;i++){ ulong t=a+b; a=b; b=t; }
  char buf[40]; char* s=utoa(a,buf+40);
  puts_("fib20="); puts_(s);
  char pb[24]; char* ps=utoa((ulong)pid,pb+24);
  puts_("pid="); puts_(ps);
  mem[0]='O'; mem[1]='K'; mem[2]='\n';
  sys6(64,1,(long)mem,3,0,0,0);                     /* write mmap'd buffer */
  sys6(93,0,0,0,0,0,0);                             /* exit */
  for(;;){}
}