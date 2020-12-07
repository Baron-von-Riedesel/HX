
 hx.trp is a simple dos real-mode binary.

 the modifications done for hx.trp:

 \watcom\trp_src\bld\trap\lcl\dos\dosx\c\dosxlink.c: 
      added ifdef for hx (hxhelp.dll)
 \watcom\trp_src\bld\trap\lcl\dos\dosx\asm\dosxfork.asm:
      added some debug messages

 how to build the trap file?

 1. run setvars.bat
 2. run wmake


