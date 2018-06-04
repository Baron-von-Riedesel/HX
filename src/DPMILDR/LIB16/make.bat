@echo off
ml -c -nologo -Fl -Sg hmemset.asm
ml -c -nologo -Fl -Sg lstrcat.asm
ml -c -nologo -Fl -Sg lstrcpy.asm
ml -c -nologo -Fl -Sg lstrlen.asm
ml -c -nologo -Fl -Sg profstrg.asm
erase ldr16.lib
lib16 ldr16.lib +hmemset.obj +lstrcat.obj +lstrcpy.obj +lstrlen.obj +profstrg.obj;
