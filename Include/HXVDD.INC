
;--- interface to HXVDD.DLL

VDD_OPENCLIPBOARD               equ 0
VDD_CLOSECLIPBOARD              equ 1
VDD_EMPTYCLIPBOARD              equ 2
VDD_GETCLIPBOARDDATA            equ 3
VDD_SETCLIPBOARDDATA            equ 4
VDD_ISCLIPBOARDFORMATAVAILABLE  equ 5
VDD_ENUMCLIPBOARDFORMATS        equ 6

VDD_GLOBALALLOC                 equ 10
VDD_GLOBALLOCK                  equ 11
VDD_GLOBALUNLOCK                equ 12

HXLoadVDD  proto stdcall
HXDispatch proto stdcall

