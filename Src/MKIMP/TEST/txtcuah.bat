@echo off
del C:\TEMP\MKIMP\*.obj
..\Release\mkimp -q -o C:\TEMP\MKIMP txtcua32.def
if errorlevel 1 goto ende
C:
cd \TEMP\MKIMP
lib *.obj /out:D:\ASM\HX\SRC\MKIMP\TEST\txtcuah.LIB
D:
cd \ASM\HX\SRC\MKIMP\TEST
:ende
