@echo off
rem alternative way to create OLE32.DLL
rem uses JWasm, MS lib and MS link
cd RELEASE
del *.obj
jwasm.exe -coff -nologo -Sg -I..\..\..\Include -D?FLAT=1 -Fl ..\*.asm 
lib /NOLOGO *.obj /OUT:OLE32S.LIB
lib /NOLOGO OLE32S.LIB /REMOVE:OLE32.OBJ /OUT:OLE32S.LIB
link /NOLOGO /LIBPATH:..\..\..\Lib OLE32.obj OLE32S.LIB DKRNL32.LIB DADVAPI.LIB DUSER32.LIB /DLL /OUT:OLE32.DLL /DEF:..\OLE32.DEF /MAP /OPT:NOWIN98
cd ..
