
 1. HDPMI Source Overview
 
 þ host core
 
   - HDPMI.ASM     IDT handlers, client data, host stack, host initialization,
                   client initialization and termination, mode switches
   - INIT.ASM      real-mode initialization                   
   - EXCEPT.ASM    default exception handler
   - PUTCHR.ASM    display text in protected mode
   - PUTCHRR.ASM   display text in real mode (used in debug mode only)
   - A20GATE.ASM   handles A20
   - CLIENTS.ASM   save/restore client state
   - SWITCH.ASM    mode switch routines
   - MOVEHIGH.ASM  move parts of host high
   - HEAP.ASM      host's heap 
 
 þ memory management
 
   - PAGEMGR.ASM   physical memory, address space, committed memory
 
 þ DPMI API (int 31h)
 
   - INT31API.ASM  dispatcher, ax=04xx, ax=06xx, ax=07xx, ax=09xx
   - I31SEL.ASM    ax=00xx
   - I31DOS.ASM    ax=01xx
   - I31INT.ASM    ax=02xx
   - I31SWT.ASM    ax=03xx
   - I31MEM.ASM    ax=05xx, ax=08xx
   - I31DEB.ASM    ax=0Bxx
   - I31FPU.ASM    ax=0Exx
 
 þ API translation
 
   - INT13API.ASM  int 13h
   - INT21API.ASM  int 21h
   - INT2FAPI.ASM  int 2Fh
   - INT2XAPI.ASM  int 23h, int 24h, int 25h, int 26h
   - INT33API.ASM  int 33h
   - INT41API.ASM  int 41h
   - INTXXAPI.ASM  int 10h, int 15h, int 4Bh 
   - HELPERS.ASM   API translation helper functions
   - VXD.ASM       (16bit only)
   
 The source is not always easy to understand. It is old and was originally
 written with MASM 5.1. It's about 25.000 lines of code.
 
 
 2. Memory Layout
 
 The HDPMI binary will have the following segments (in this order)

 Segment   Bits Type  Comment
 -------------------------------------------------------------
 BEGTEXT16 16   data  host stack + TSS
 _TEXT16   16   code  resident real-mode code
 CONST16   16   data  strings for both modes (usually empty)
 _DATA16   16   data  host's global data (for both modes)
 CDATA16   16   data  client specific data for both modes
 GDTSEG    16   data  GDT (usually moved to extended memory)
 _ITEXT16  16   code  real-mode code for initialization
 _TEXT32   32   code  resident protected-mode code
 CONST32   32   data  constants and strings for protected-mode only
 CDATA32   32   data  client specific data for protected-mode only
 _ITEXT32  32   code  protected-mode code for initialization
 
 16-bit segments are grouped in GROUP16.
 32-bit segments are grouped in GROUP32.
 
 On initialization, after the paging tables are initialized, GROUP32 will
 be copied to extended memory. GROUP32, GDTSEG and _ITEXT16 can then be 
 freed when the host stays resident.
  When running, segment registers are setup like this:
  
  - CS: contains GROUP16 in real mode, GROUP32 in protected mode
  - SS: contains GROUP16 in protected mode

  The CDATA16/CDATA32 segments are saved when a new client starts and
  restored when it's terminating. 

 
 3. Wish List

  þ bugs open:
    a. if DOS is not loaded in HMA, nested execution of
       DPMI clients may cause a reboot (A20 disabled?)
       test case: 
        1. HDPMI32 -r -a
        2. NMAKE which calls ML
  
  þ implement the missing functions to make HDPMI a full V1.0 host:
    - DPMI TSRs (int 31h, ah=0Ch)
    - shared memory (int 31h, ah=0Dh)
    - give each client its own copy of IDT/LDT
    The shared memory thing should be pretty easy to implement since
    v3.07 if clients run in separate address contexts.
    Support for shared memory would enable dkrnl32 to implement shared
    sections (file mapping accross processes, named pipes, ...).

  þ add an option to make HDPMI load both 32bit code versions for 16-
    and 32-bit clients (the 16-bit conventional memory part is already
    identical - except the very first 8 bytes). This would finally make
    HDPMI16.EXE (almost) superfluous. On inital switch, just change the
    GDT entry for the 32bit code. Will require separate address contexts
    to be active.

  þ support for INT 24h is not fully implemented. The stack frame
    does not contain the registers pushed by DOS.
  
