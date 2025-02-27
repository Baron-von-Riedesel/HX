@echo off
rem jwasm v2.19 is able to create the binary without external linker
jwasm -c -nologo -pe -D?PE -FlRelease\ -Sg -FoRelease\JHDPMI.DLL -I\projects\jemm\include jhdpmi.asm
patchpe Release\JHDPMI.DLL
