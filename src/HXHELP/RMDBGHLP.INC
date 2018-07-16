
EXECRM	struct
environ	dw ?		   ;0 environm
		dd ?		   ;2 cmdline
		dd ?		   ;6 fcb1
		dd ?		   ;10 fcb2
sssp	dd ?		   ;14 ss:sp
csip	dd ?		   ;18 cs:ip
EXECRM	ends

DEBRMVAR	struct
wSize		dw ?			;size of this structure	

wExit       dw ?            ;exit real mode code
wCancelRM   dw ?            ;IP for a AX=4CFFh, int 21h routine
wIntr00r    dw ?            ;IP to int 0 (- int7) rm routines
wPM2RMEntry dw ?            ;IP for PM to RM jump
;wExecRM4b   dw ?            ;IP for real mode int 21h
wIntr21r    dw ?            ;IP for real mode int 21h
wVCPI		dw ?			;IP for VCPI

bMode		db ?			;cpu mode (v86 or real-mode)
bFlags  	db ?			;flags (see below)
intno		dw ?
rm			RMCS <>

if ?RMCALLBACK
intxxcb 	dd ?
else
rmsavestate dd ?
rm2pmjump   dd ?            ;address of "jump to pm" proc
pmeip       dd ?            ;protected mode EIP to jump to  
pmcs        dw ?            ;protected mode CS
pmds        dw ?            ;protected mode DS
pmesp       dd ?            ;protected mode ESP            
savestatebuffRM dd ?        ;save state area real-mode address
savestatebuffPM dd ?        ;save state area protected mode address
endif

;--- we cannot use `TRAPRM214B switch, since it
;--- differs between windows/non-windows versions

if 1 	;?TRAPRM214B
oldint21r dd ?
essave	  dw ?		;ES saved

union
struct
ipsave	  dw ?		;saved IP on int 21h, ax=4B00h
cssave	  dw ?		;saved CS on int 21h, ax=4B00h
ends
csipsave  dd ?
ends
union
flsave    dw ?		;used to save FL of IRET16
flhigh    dw ?		;saved HiWord of real-mode EFL
ends

execbl	EXECRM <>
endif

if ?TRAPRM2F
oldint2Fr	dd ?	;previous vector int 2F real-mode
truepmentry dd ?	;saved protected-mode entry address
wIntr2Fr	dw ?	;offset new int 2f handler
endif

if ?TRAPRM15
oldint15r	dd ?
wIntr15r	dw ?
int15Cnt	db ?
endif

if ?TRAPRM2A
oldint2Ar	dd ?
wIntr2Ar	dw ?
int2ACnt	db ?
endif

oldint01r	dd ?
oldint03r	dd ?

DEBRMVAR	ends

;--- bFlags equates:

FLRM_NOTACTIVE	equ 1	;debugger is not active, dont catch int 21, ax=4b00

if 0;1
_TEXT16 segment word use16 'CODE'
_TEXT16 ends
endif

