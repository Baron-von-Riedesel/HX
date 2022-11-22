
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
 
   - PAGEMGR.ASM   physical memory, system address space, committed memory
 
 þ DPMI API (int 31h)
 
   - INT31API.ASM  dispatcher, ax=04xx, ax=06xx, ax=07xx, ax=09xx
   - I31SEL.ASM    ax=00xx
   - I31DOS.ASM    ax=01xx
   - I31INT.ASM    ax=02xx
   - I31SWT.ASM    ax=03xx
   - I31MEM.ASM    ax=05xx, ax=08xx - manages client address space
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

 þ internal include files

   - HDPMI.INC     global constants, macros
   - EXTERNAL.INC  externals, prototypes
   - PAGEMGR.INC   prototypes of pagemgr.asm
   - INT31API.INC  prototypes of I31xxx.asm
   - DEBUGSYS.INC  constants for kernel debugger interface
   - VERSION.INC   defines hdpmi version

 þ external include files ( from ..\..\Include )

   - KEYBOARD.INC  keyboard scan codes
   
 The source is not always easy to understand. It is old and was originally
 written with MASM 5.1. It's about 25.000 lines of code.
 
 
 2. Image Layout
 
 The HDPMI binary will have the following segments (in this order)

 Segment   Bits Type  Comment
 -------------------------------------------------------------
 BEGGRP16  16   data  TSS
 _DATA16   16   data  host's global data (for both modes)
 _DATA16V  16   data  vm specific data
 _DATA16C  16   data  client specific data for both modes
 _TEXT16   16   code  resident real-mode code
 CONST16   16   data  strings for both modes (usually empty)
 GDTSEG    16   data  GDT (usually moved to extended memory)
 IDTSEG    16   data  IDT (moved to extended memory)
 _ITEXT16  16   code  real-mode code for initialization
 _TEXT32   32   code  resident protected-mode code
 CONST32   32   data  constants and strings for protected-mode only
 _DATA32C  32   data  client specific data for protected-mode only
 _ITEXT32  32   code  protected-mode code for initialization
 
 16-bit segments are grouped in GROUP16.
 32-bit segments are grouped in GROUP32.

 Since v3.18, the standard HDPMI binary is in PE format. The 16-bit part
 is extracted and then added again as a "stub", using tool EditPE. The
 PE format doesn't support groups, so group GROUP32 doesn't exist here.
 
 On initialization, after the paging tables are initialized, the 32-bit part
 will be copied to extended memory. All segments behind CONST16 can then be
 released when the host stays resident.
  When running, segment registers are setup like this:
  
  - CS: contains GROUP16 in real mode, GROUP32 in protected mode
  - SS: contains GROUP16 in protected mode

  The _DATA16C/_DATA32C segments are saved when a new client starts and
  restored when it's terminating. 


 3. HDPMI Debug Version
 
  The debug version has an additional cmdline option:
 
   -z: toggles log writing

  Additionally, there are some functions accessible thru the DPMI vendor API.


 4. Makefiles

  þ HDPMIxx.MAK: creates standard version of HDPMIxx in STDxx directory. This
    is the only version currently that's in PE file format.

  þ HDPMIxxA.MAK: creates 2 versions: the first, in directory HSCMxx, has
    the host stack in conventional memory (which was "standard" before v3.18);
    the second version, in directory NOLFNxx, lacks LFN support, otherwise
    it's similar to the first.

  þ HDPMIxxE.MAK: creates an "enhanced" version, that will respond to some
    Win3x VxD calls, in directory ENHxx. The 16-bit version may be useful,
    since it allows to run Win9x in enhanced mode.

  þ HDPMIxxI.MAK: creates a version where clients will run with IOPL=0, in
    directory IOPL0xx.

  þ HDPMIxxS.MAK: creates a "stub" version, in directory STUBxx. These stubs
    may be added, either by the linker or as assembly include files, to other
    binaries.


 5. Todo List

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

