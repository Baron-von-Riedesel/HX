@echo off
rem creates IMPHLP.LIB
rem uses mkimp.exe and MS lib
if not exist TEMP\NUL mkdir TEMP
erase TEMP\*.obj >NUL
..\Release\mkimp.exe -q -o TEMP winbase.def
..\Release\mkimp.exe -q -o TEMP wincon.def
..\Release\mkimp.exe -q -o TEMP winnls.def
..\Release\mkimp.exe -q -o TEMP winuser.def
cd TEMP
lib *.obj /out:..\IMPHLP.LIB
cd ..
