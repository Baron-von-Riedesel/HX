@echo off
rem
rem make the library with Fasm
rem
if not exist TEMP\NUL mkdir TEMP
erase TEMP\*.obj >NUL
..\Release\mkimp -q -f -o TEMP winbase.def
..\Release\mkimp -q -f -o TEMP wincon.def
..\Release\mkimp -q -f -o TEMP winnls.def
..\Release\mkimp -q -f -o TEMP winuser.def
cd TEMP
lib *.obj /out:..\IMPHLPF.LIB
cd ..
