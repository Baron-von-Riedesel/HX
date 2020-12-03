
  1. About
  
  This is the startup code for HX 16-bit MZ binaries.
  Three versions are created, which are:
  
  - JMPPM16.OBJ: very simple startup to be used by ASM programs
  - JMPPM16M.OBJ: MS VC 1.5 compatible startup code
  - JMPPM16W.OBJ: OW compatible startup code


  2. History

  12/01/2020: InitPM16.asm added.
  11/28/2006: check for 80286 cpu added
  08/29/2005: code segment name changed. This is to move the real-mode
              startup code away from the image start and the protected
              mode code in _TEXT will start at CS:0000 instead.
  08/28/2005: version 1.1
  08/26/2005: modifications for OW and MS VC added
  10/02/2004: version 1.0
              
              

