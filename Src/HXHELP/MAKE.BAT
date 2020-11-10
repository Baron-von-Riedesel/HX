
jwasm -coff -nologo -D?FLAT=1 -D?DEBUGLEVEL=1 -Sg -FlRELEASE\HXHELP -FoRELEASE\HXHELP.obj -I..\..\Include hxhelp.asm
jwlink format win pe hx ru console name RELEASE\HXHELP.EXE file RELEASE\HXHELP.obj, RELEASE\privprof.obj op q, offset=0x3E0000, stack=0x2000, heap=0x1000, map=RELEASE\HXHELP.MAP, stub=..\dpmildr\stub32\dpmild32.bin
rem jwasm -coff -nologo -D?FLAT=1 -D?DEBUGLEVEL=1 -Sg -FlDEBUG\HXHELP -FoDEBUG\HXHELP.obj -I..\..\Include hxhelp.asm
rem jwlink format win pe hx ru console name DEBUG\HXHELP.EXE file DEBUG\HXHELP.obj, DEBUG\privprof.obj op q, offset=0x3E0000, stack=0x2000, heap=0x1000, map=DEBUG\HXHELP.MAP, stub=..\dpmildr\stub32d\dpmild32.bin

