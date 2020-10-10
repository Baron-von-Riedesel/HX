@echo off
rem alternative way to create DDDRAW.DLL
rem uses JWasm, MS lib and MS link
cd RELEASE
del *.obj
jwasm.exe -coff -nologo -Sg -I..\..\..\Include -D?FLAT=1 -Fl ..\*.asm 
lib /NOLOGO *.obj /OUT:DDDRAWS.LIB
lib /NOLOGO DDDRAWS.LIB /REMOVE:DDDRAW.OBJ /OUT:DDDRAWS.LIB
link /NOLOGO /LIBPATH:..\..\..\Lib DDDRAW.obj DDDRAWS.LIB DKRNL32.LIB DGDI32.LIB /DLL /OUT:DDDRAW.DLL /DEF:..\DDDRAW.DEF /MAP /OPT:NOWIN98
cd ..
