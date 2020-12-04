@echo off
rem alternative way to create OLEAUT32.DLL
rem uses JWasm, MS lib and MS link
cd RELEASE
del *.obj
jwasm.exe -coff -nologo -Sg -I..\..\..\Include -D?FLAT=1 -Fl ..\*.asm 
lib /NOLOGO *.obj /OUT:OLEAUTOS.LIB
lib /NOLOGO OLEAUTOS.LIB /REMOVE:OLEAUT32.OBJ /OUT:OLEAUTOS.LIB
link /NOLOGO /LIBPATH:..\..\..\Lib OLEAUT32.obj OLEAUTOS.LIB DKRNL32.LIB DADVAPI.LIB DUSER32.LIB /DLL /OUT:OLEAUT32.DLL /DEF:..\OLEAUT32.DEF /MAP /OPT:NOWIN98
cd ..
