@echo off
jwasm -c -nologo -Fl -Sg hmemset.asm
jwasm -c -nologo -Fl -Sg lstrcat.asm
jwasm -c -nologo -Fl -Sg lstrcpy.asm
jwasm -c -nologo -Fl -Sg lstrlen.asm
jwasm -c -nologo -Fl -Sg profstrg.asm
jwlib -b -n ldr16.lib +hmemset.obj +lstrcat.obj +lstrcpy.obj +lstrlen.obj +profstrg.obj
