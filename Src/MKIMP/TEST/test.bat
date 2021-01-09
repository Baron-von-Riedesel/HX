@echo off
rem erase TEMP\*.obj >NUL
..\Release\mkimp.exe -q -o TEMP test.def
rem cd TEMP
rem lib *.obj /out:..\TEST.LIB
rem cd ..
