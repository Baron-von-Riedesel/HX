
   Some notes about the loader

1. the loader is a DOS MZ binary, but will be loaded by DPMISTxx.BIN
   as overlay (to avoid creating too many PSPs). The loader has to take this
   into account, because it can also be launched from the command line.

2. the loader will try to load HDPMIxx if no host is detected.
   HDPMIxx will be loaded as a MZ binary (old versions loaded it as
   overlay). Thus the loader is totally independant from the server.

3. the 32-Bit loader DPMILD32.EXE uses 386 instructions, but DPMILD16.EXE
   should be able to run on 286s.

4. DPMILD16 supports both DPMI-16 and OS/2 application types. DPMI-16
   may be further splitted to RTM and Win16 compatibles. Bit 4 in the NE
   header APPFLAGS field tells which one of the two it is.

5. NE file format features:
   - attribute DISCARDABLE is used. Such segments may be thrown away if
     memory is out (DPMILD16.EXE only).
   - attribute MOVEABLE (linear address may change) is ignored.
     if a segment grows (DGROUP if local heap grows), the linear address
     may change (doesn't work for segments in DOS memory!)
   - attribute LOADONCALL/PRELOAD will be used.
   - attributes PRELOAD+FIXED mean: load segment in DOS memory
   - if DGROUP is a code segment, a data alias will be created automatically
     (for SS and DS). This ensures that programs linked for the tiny memory
     model can be launched. 

6. some Win16 functions are NOT implemented in DPMILD32. These are:
   - local heap functions
   - file functions (LCREAT, ...)
   - string functions (LSTRCAT, ...)
   - private profile file read/write functions
   - special segment selectors _A000H, _B000H, _B800h, _0000H

7. DPMILD32 expects a exec parameter block (int 21,ax=4B00h) of format:
   - QWORD cmdline
   - QWORD fcb1
   - QWORD fcb2
   note that there is no environment segment at offset 0!
   Win9x, HDPMI, WinNT/2K/XP, DPMIONE supply this format, but DOSEMU does
   not! That's why for DOSEMU there is special code to handle this in
   DPMILD32.
   
8. The standard version of the loader understands LFN, but most
   likely it will not work up to the limits (256 bytes).

   Japheth
   
