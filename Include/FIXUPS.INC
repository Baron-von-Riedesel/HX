
;--- 16bit floating point emulation - used by DPMILDR

fINT     equ 0CDh      ;opcode for INT xx
fFWAIT   equ 09Bh
fESCAPE  equ 0D8h
fFNOP    equ 090h
fES      equ 026h
fCS      equ 02Eh
fSS      equ 036h
fDS      equ 03Eh      ;DS segment prefix
BEGINT   equ 034h      ;begin of emulation interrupt vectors (34h-3Dh)

;FIARQQ  equ 0FE32H
;FISRQQ  equ 00632h
;FICRQQ  equ 00E32h
;FIERQQ  equ 01632h
;FIDRQQ  equ 05C32h
;FIWRQQ  equ 0A23Dh
;FJARQQ  equ 04000h
;FJSRQQ  equ 08000h
;FJCRQQ  equ 0C000h

;--- fixups for 16bit floating point emulation

FIARQQ  equ (fINT + 256*(BEGINT + 8)) - (fFWAIT + 256 * fDS)
FISRQQ  equ (fINT + 256*(BEGINT + 8)) - (fFWAIT + 256 * fSS)
FICRQQ  equ (fINT + 256*(BEGINT + 8)) - (fFWAIT + 256 * fCS)
FIERQQ  equ (fINT + 256*(BEGINT + 8)) - (fFWAIT + 256 * fES)
FIDRQQ  equ (fINT + 256*(BEGINT + 0)) - (fFWAIT + 256 * fESCAPE)
FIWRQQ  equ (fINT + 256*(BEGINT + 9)) - (fFNOP  + 256 * fFWAIT)
FJARQQ  equ 256*(((0 shl 6) or (fESCAPE and 03Fh)) - fESCAPE)
FJSRQQ  equ 256*(((1 shl 6) or (fESCAPE and 03Fh)) - fESCAPE)
FJCRQQ  equ 256*(((2 shl 6) or (fESCAPE and 03Fh)) - fESCAPE)

