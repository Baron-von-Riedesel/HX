@echo off
rem creates IMPHLP.LIB
rem uses mkimp.exe and MS lib
if not exist TEMP\NUL mkdir TEMP
erase TEMP\*.obj >NUL
echo processing winbase.def
..\Release\mkimp.exe -q -o TEMP winbase.def
echo processing wincon.def
..\Release\mkimp.exe -q -o TEMP wincon.def
echo processing winnls.def
..\Release\mkimp.exe -q -o TEMP winnls.def
echo processing winuser.def
..\Release\mkimp.exe -q -o TEMP winuser.def
cd TEMP
lib *.obj /out:..\IMPHLP.LIB
cd ..
