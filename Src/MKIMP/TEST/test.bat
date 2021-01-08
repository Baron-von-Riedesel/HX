@echo off
erase TEMP\*.obj >NUL
..\Release\mkimp.exe -q -d -o TEMP test.def
cd TEMP
lib *.obj /out:..\TEST.LIB
cd ..
