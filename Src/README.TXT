
List of HX main parts, their size and tools required to build the binary:

         lines   asm/c  linker  lib   rc
-------------------------------------------
HDPMI    30000   jwasm  jwlink  wlib
DPMILDR  13500   jwasm  jwlink
STUBS     1000   jwasm  -
VESA32    3000   jwasm  jwlink  wlib
HXLDR32   1000   jwasm  jwlink
PESTUB    1000   jwasm  jwlink
HXGUIHLP  1000   jwasm  jwlink
SB16      1500   jwasm  jwlink  wlib
MZSUPP    1150   jwasm  -       wlib
PATCHPE    300   jwasm  -
PATCHNE    500   jwasm  -
HXHELP    6900   jwasm  jwlink
                 
DKRNL32  36000   jwasm  jwlink  wlib
DADVAPI   2000   jwasm  jwlink  wlib
DGDI      8000   jwasm  jwlink  wlib
DUSER32   9000   jwasm  jwlink  wlib  wrc
DDDRAW    3600   jwasm  jwlink  wlib
DINPUT    1500   jwasm  jwlink  wlib
DSOUND    1200   jwasm  jwlink  wlib
OLE32      600   jwasm  jwlink  wlib
OLEAUT32   600   jwasm  jwlink  wlib
SHELL32    500   jwasm  jwlink  wlib
WINMM     2600   jwasm  jwlink  wlib
WSOCK32   1050   wcc386 jwlink
-------------------------------------------
       ~125000
