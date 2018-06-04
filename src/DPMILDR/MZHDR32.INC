
;*** used by DPMILD32 PE loader ***

MZHDR    struct
			dd ?         ;00 "MZ",0,0
			dd ?         ;04
			dd ?         ;08
			dd ?         ;0C
			dd ?         ;10
			dd ?         ;14
			dd ?         ;18
            dd ?         ;1c 
pModuleList dd ?         ;20 linear address of app module list (apps only)
hStack		dd ?         ;24 DPMI memory handle for stack (apps only)
wCnt		dw ?         ;28 count (for DLLs)
bFlags 		db ?         ;2A flags (DPMILD32)
			db ?         ;2B flags (was used by DKRNL32)
dwStack 	dd ?         ;2c linear address stack start (apps only)
hImage		dd ?         ;30 DPMI memory handle for image
pNxtMod		dd ?         ;34 next PE module (linear address)
pExeNam		dd ?         ;38 ^ EXE-Name (is a RVA)
ofsPEhdr	dd ?         ;3c (File:^ PE Header,Modul:Size)

MZHDR    ends

;--- bFlags values

FPE_CROSSREF	equ 1

;--- bKrnlFlags values

FKF_DISTHREADLIBCALLS 	equ 1	;DisableThreadLibraryCalls

