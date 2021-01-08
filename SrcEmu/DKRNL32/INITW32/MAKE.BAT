@echo off
rem
rem InitW32
rem
jwasm.exe -nologo -c -coff -D?FLAT=1 -D?CLEARHIGHEBP=0 -I\hx\Include -FoCOFF\ INITW32.ASM
jwasm.exe -nologo -c       -D?FLAT=1 -D?CLEARHIGHEBP=0 -I\hx\Include -FoOMF\  INITW32.ASM
rem
rem InitW32x
rem
jwasm.exe -nologo -c -coff -FoCOFF\ INITW32X.ASM
jwasm.exe -nologo -c       -FoOMF\  INITW32X.ASM
rem
rem InitW3ow
rem GetModH (for MS VC++ Toolkit 2003
rem
jwasm.exe -nologo -c -coff               -FoCOFF\ INITW3ow.ASM
jwasm.exe -nologo -c -coff -I\hx\Include -FoCOFF\ GETMODH.ASM
