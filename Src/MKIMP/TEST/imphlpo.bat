@echo off
rem
rem make the library in OMF format
rem
if not exist TEMP\NUL mkdir TEMP
erase TEMP\*.obj >NUL
..\Release\mkimp -q -omf -o TEMP winbase.def
..\Release\mkimp -q -omf -o TEMP wincon.def
..\Release\mkimp -q -omf -o TEMP winnls.def
..\Release\mkimp -q -omf -o TEMP winuser.def
cd TEMP
dir /b *.obj >modules.tmp
\dm\bin\lib -c ..\IMPHLP.LIB @modules.tmp
cd ..
