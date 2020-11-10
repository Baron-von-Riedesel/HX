@echo off
rem alternative way to create VESA32.DLL
rem uses JWasm, MS lib and MS link
cd RELEASE
del *.obj
jwasm.exe -coff -nologo -Sg -D_VESA32_=1 -I..\..\..\Include -D?FLAT=1 -Fl ..\*.asm 
lib /NOLOGO *.obj /OUT:VESA32S.LIB
lib /NOLOGO VESA32S.LIB /REMOVE:VESA32.OBJ /OUT:VESA32S.LIB
link /NOLOGO /LIBPATH:..\..\..\Lib VESA32.obj VESA32S.LIB /DLL /OUT:VESA32.DLL /DEF:..\VESA32.DEF /MAP /OPT:NOWIN98
cd ..
