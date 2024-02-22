
Regression tests for HDPMI32

dispgdt : display GDT; won't run with hdpmi option -s
dispidt : display IDT; won't run with hdpmi option -s
dostest : test int 21h 
dpmitest: simplest DPMI client, just terminates with int 21h, ah=4Ch
enuhlt  : test HLT emulation
example : tran's IRQ sample
exc00   : test exc 00 to int 00
exc01mz : test int 1 routing
exc03mz : test int 3 routing
exc05   : test exc 05
exc06   : test exc 06
exc07   : test exc 07
exc0B   : test exc 0B
exc0C   : test exc 0C
exc0D   : test exc 0D
exc0E   : test exc 0E, handled by host
exc0E2  : test exc 0E, handled by client
exc0Er0 : test exc 0E in ring 0
exc10   : test exc 10
exc11   : test exc 11 (modifies CR0, won't run with option -s)
exec2c  : test int 21h, ax=4b00h (start command.com with "/C dir" param)
exec2d  : test int 21h, ax=4b00h (start GETCLMZ.EXE with "this ..." param)
getirq8 : count IRQ8s occuring during 100 timer ticks (5500 ms)
I3100001: test int 31h, ax=0000h
I3100002: allocates a lot of descriptors, then starts another client
I3100003: displays state of client's LDT after initail switch to pm
I310100 : test int 31h, ax=0100h + 00101 (with and without errors)
I310102 : test int 31h, ax=0102h (with and without errors)
I310202 : display all 32 exception vectors returned by int 31h, ax=0202h
I310204 : display all 256 interrupt vectors returned by int 31h, ax=0204h
I310205 : test int 31h, ax=0205h (is it valid to set a pm vector to 0:0?)
I3102101: test int 31h, ax=0210h + 0212h with handled divide error
I3102102: test int 31h, ax=0210h + 0212h with handled page exception
I3102103: causes page fault in host, and tries to handle it in exc handler
I3103001: test int 31h, ax=0300h, simple
I3103002: test int 31h, ax=0300h, more complex
I3103011: test int 31h, ax=0301h (call real-mode far proc), 2 words on stack
I3105032: test int 31h, ax=0503h (resize mem block)
I310508 : test int 31h, ax=0508h (map phys. device/memory)
I310508a: test int 31h, ax=0508h (change from mapped to committed)
I310509 : test int 31h, ax=0509h (map DOS memory)
I31050B : test int 31h, ax=050Bh (get mem info)
I31090X : test virtual interrupt functions (int 31, ax=09xxh)
i310e00 : get coproc state with int 31h, ax=0e00
I4B8105 : test HDPMI's VDS scatter/gather lock implementation
int2129 : test int 21h, ax=2900h (parse filename, fill FCB); returns DS:ESI pointing behind filename to parse
int212F : DTA test   
int213F : read 128 kB into a code segment
int2148 : test int 21h, ah=48 alloc memory
int2155 : test int 21h, ah=55 (create child PSP)
?int23  : test ctrl-c handling (int 23h)
int24   : test critical error handling (int 24h)
int25   : test int 25h with cx=-1, try to read sector 0 of drive C
intspeed: test execution speed of real-mode ints. runs 500.000 int 69h   
irq01   : test routing irq0+irq1 from real-mode
IRQ12EXC: causes an exception inside IRQ 12 handler
IRQ1EXC : causes an exception inside IRQ 1 handler
mouevnt1: event proc installed with int 33h, ax=000C
mouevnt2: event proc installed with a real-mode callback (int 33h)
mouevnt3: event proc installed for Int 15h pointing device
newcl2  : alloc almost all selectors, then start a new client (which should fail)
newclmz : enter protected mode, then start a new shell
prvileg0: test emulation of "mov eax, crx" opcodes (will crash with option -s)
rawjmp1 : test raw jump + pm task state save/restore
rawjmp2 : test rm task state save/restore
rawjmp3 : test raw jump real-mode stack and flags values
rawjmp4 : test save/restore task state in real-mode
rawjmp6 : call real-mode far proc, raw jmp to pm, call dos, back to rm, RETF (didn't work in v3.18!)
rawjmp7 : like rawjmp6, but causes a GPF in proc that was "raw jumped" (didn't work in 3.18-3.19)
rmcb1   : complex test rmcb (nested calls)
rmcb3   : simple test rmcb
rmcb6   : test allocating and calling 2 rmcbs
rmcb7   : client terminates inside rmcb with int 21h, ax=4c00h!
rmcb8   : nested execution of rmcb until host stack is exhausted!
rmcb9   : cause an exception 10h inside a rmcb, cure it and continue
setcr0  : read CR0, then write CR0 ( src=eax);
          in v3.21, works ( so long as eax is src operand ); bits 0/31 are protected;
          in v3.20, works with all regs, but with hdpmi32i and HDPMI=2048 only;
          in v3.19 and below, works with all regs;
          will crash with option -s
setcr4  : set CR4 to 200h (will crash with option -s)
setmsr  : set MSR registers (will crash with option -s)
waitkey : helper program for mouse event tests
