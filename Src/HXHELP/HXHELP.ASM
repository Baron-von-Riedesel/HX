
;--- HX trap helper file for Open Watcom debugger WD
;--- based on cwhelp.asm (CAUSEWAY extender trap debug help)
;--- this file needs JWasm/Masm to be assembled!
;--- best viewed with TABSIZE 4

ifndef ?DLL
?DLL	equ 0
endif

ifndef ?V19
?V19 equ 1
endif

?MDUSEINP	equ 1	;use input if REQ_MACHINE_DATA

		.486
if ?FLAT
		.model flat, stdcall
@flat	equ <ds>
@flatrd equ <cs>
@flatwr	equ <ds>
?NE		equ 0
?DPMI16 equ 0
		assume fs:nothing

else
		.model tiny, stdcall		; CS=DS=ES=SS
@flat	equ <gs>
@flatrd	equ <gs>
@flatwr	equ <gs>
 if ?NE
?DPMI16	equ 1
 endif
endif
		option casemap:none
;		option proc:private

?RMVECTOR	equ 6	;real mode interrupt vector used
ifndef ?DEBUGLEVEL
?DEBUGLEVEL	equ 0	;1 to activate log file writes
endif
?RMDBGHLP	equ 1
?STOPATPM	equ 0	;1=stop at protected mode entry
?STOPAT4G	equ 0	;1=stop at first int 21h, ax=ff00h, dx=0078h
?INTRMEXC	equ 1	;1=check for rm exc while trap code is running
?INTPMEXC	equ 1	;1=optionally check for pm exc while trap code is running
?CLOSE5		equ 1	;1=close file handle 5. This cures a WD-DOS4G bug
					;when debugging locally

if ?FLAT
?DJGPP		equ 1	;1=support DJGPP binaries
else
?DJGPP		equ 0
endif

		include dpmi.inc
		include winnt.inc
if ?RMDBGHLP
?RMCALLBACK equ 0
?TRAPRM2F	equ 0
?TRAPRM15	equ 0
?TRAPRM2A	equ 0
		include rmdbghlp.inc
endif
		include hxhelp.inc

;*******************************************************************************
;Replacement for PUSH that maintains the stack offset for PARAMS,LOCALS &
;MLOCAL and allows multiple parameters.
;*******************************************************************************
pushs macro r1,r2,r3,r4,r5,r6,r7,r8,r9,r10,r11,r12,r13,r14,r15,r16
	irp 	x,<r1,r2,r3,r4,r5,r6,r7,r8,r9,r10,r11,r12,r13,r14,r15,r16> ;REPEAT FOR EACH PARM
		ifnb	<x>
		push	x
		endif
	endm
endm

;*******************************************************************************
;A replacement for POP that maintains the stack offset for PARAMS,LOCALS &
;MLOCAL and allows multiple parameters. POP's in reverse order.
;*******************************************************************************
pops macro r1,r2,r3,r4,r5,r6,r7,r8,r9,r10,r11,r12,r13,r14,r15,r16
	irp x,<r16,r15,r14,r13,r12,r11,r10,r9,r8,r7,r6,r5,r4,r3,r2,r1> ;REPEAT FOR EACH PARM
		ifnb	<x>
		pop 	x
		endif
	endm
endm

;--- define an asciiz string in .DATA

CStr macro x:vararg
local xxx
	.data
xxx label byte
ifnb <x>
	db x
endif
	db 0
	.code
	exitm <offset xxx>
	endm

;
;Hardware break point table entry structure.
;
HBRK struct
HBRK_Flags		dw ?	;padding.
HBRK_Handle 	dw ?	;DPMI break point handle.
HBRK_Address	dd ?	;Linear break point address.
HBRK_Size		db ?	;DPMI size code to use.
HBRK_Type		db ?	;DPMI type code to use.
HBRK ends

NUMWATCH	equ 256
NUMSBREAK	equ 64

;
;Software watch point table entry structure.
;

WATCH struct
WATCH_Flags 	dd ?
WATCH_Address	dd ?
WATCH_Length	dd ?
WATCH_Check 	dd ?
WATCH ends

SBREAK struct
dwAddr	dd ?		;linear address
dwOffs	dd ?		;offset of break
wSeg	dw ?		;segment/selector
wFlags	dw ?		;bit 0: is set, bit 1: is real-mode
SBREAK ends

	.data

g_psp			DD 0	;PSP selector of debug helper app
ReqAddress		dd 0	;
ReqLength		dd 0
g_dsreg			dd 0
g_flatsel		dd 0	;flat data selector
g_bWantReturn	db 0
g_bIsNT			db 0	;running on NT platform?
g_bIsWin9x		db 0	;running on Win9x/Win3x platform?
if ?DPMI16
g_bUseCsAlias	db 0	;use cs16 alias (default for windows)
endif
g_bRMInt21Trapped db 0
g_bLoader		db 1	;DPMILDxx has been found/is active
if ?DJGPP
g_bIsDjgpp		db 0
endif
g_bRC			db 0
				align 4
g_dwHelperStart	dd 0
g_dwHelperEnd	dd 0
if ?DPMI16
g_hModuleHelper	dd 0
g_cs16alias		dd 0
endif

if ?RMDBGHLP
g_dwRMAddr			dd 0	;rm segment linear address
g_dwRMData			dd 0	;rm segment data selector
g_dwRMCode			dd 0	;rm segment code selector
g_dfSaveRestorePM	df 0	;save restore task state in PM
g_pm2rmjump			df 0	;raw jump pm to rm
g_rm2pmjump			dd 0	;raw jump rm to pm
g_dwDPMIEntry		dd 0	;rm address DPMI first entry
g_dwSaveRestoreRM	dd 0	;rm address save/restore task state
g_dwInternalBrkAddr	dd -1
g_bSavedInternalBrk	db 0

g_rminttab label byte
		db 0
dwOldInt00RM	dd 0
		db 1
dwOldInt01RM	dd 0	;old int 01 real-mode
		db 3
dwOldInt03RM	dd 0	;old int 03 real-mode
		db 5
dwOldInt05RM	dd 0
		db 6
dwOldInt06RM	dd 0
		db 7
dwOldInt07RM	dd 0
		db -1
		
g_bRMIntsTrapped db 0	;-1 = rm ints 0,1,3,6,... are trapped
g_fV86		db 0		;0=real-mode,1=v86 mode
g_fRealMode	db 0		;-1=debuggee in real-mode
g_fPrevMode	db 0
g_fPrevDef	db 0		;saved default bit of CS in prot-mode (bit 0)
 if ?STOPATPM or ?STOPAT4G
g_fDPMIClient db 0		;bit 0: 1=debuggee is a dpmi client
						;bit 1: 1=stopped in pm already
						;bit 2: 1=stopped in pm at int 21h, ax=ff00
 endif
endif

	align 4

OldInt00		INTVEC 0
OldInt01		INTVEC 0
OldInt03		INTVEC 0
OldInt08		INTVEC 0
SavedInt08		INTVEC 0	;must be behind OldInt08
OldInt09		INTVEC 0
SavedInt09		INTVEC 0	;must be behind OldInt09
OldInt21		INTVEC 0
OldInt31		INTVEC 0
OldInt41		INTVEC 0
OldInt75		INTVEC 0	;should get both prot-mode and real-mode ints


OldExc00		df 0
OldExc01		df 0,0
OldExc03		df 0,0
OldExc04		df 0
OldExc05		df 0
OldExc06		df 0
OldExc07		df 0
OldExc0B		df 0
OldExc0C		df 0
OldExc0D		df 0
OldExc0E		df 0
OldExc10		df 0

excstr struct
bExc	db ?
bFirst	db ?	; 1=debugger must be first in chain
pOldVec	dd ?
pProc	dd ?
excstr ends

	.const

InterruptTab label byte
		excstr <00h, 0, offset OldInt00, offset Int00Handler>
		excstr <01h, 1, offset OldInt01, offset Int01Handler>
		excstr <03h, 1, offset OldInt03, offset Int03Handler>
		excstr <08h, 3, offset OldInt08, offset Int08Handler>
		excstr <09h, 3, offset OldInt09, offset Int09Handler>
		excstr <21h, 0, offset OldInt21, offset Int21Handler>
		excstr <31h, 0, offset OldInt31, offset Int31Handler>
		excstr <41h, 0, offset OldInt41, offset Int41Handler>
		excstr <75h, 0, offset OldInt75, offset Int75Handler>
		db -1

	align 4

ExceptionTab label byte
		excstr <00h, 0, offset OldExc00, offset Exc00Handler>
		excstr <01h, 1, offset OldExc01, offset Exc01Handler>
		excstr <03h, 1, offset OldExc03, offset Exc03Handler>
		excstr <04h, 0, offset OldExc04, offset Exc04Handler>
		excstr <05h, 0, offset OldExc05, offset Exc05Handler>
		excstr <06h, 0, offset OldExc06, offset Exc06Handler>
		excstr <07h, 0, offset OldExc07, offset Exc07Handler>
;--- let DPMILD32/DPMILD16 handle not present exceptions
;		excstr <0Bh, 0, offset OldExc0B, offset Exc0BHandler>
		excstr <0Ch, 0, offset OldExc0C, offset Exc0CHandler>
		excstr <0Dh, 0, offset OldExc0D, offset Exc0DHandler>
		excstr <0Eh, 0, offset OldExc0E, offset Exc0EHandler>
		excstr <10h, 0, offset OldExc10, offset Exc10Handler>
		db -1

	align 4

ReqTable label dword
		dd 0	;0 Req_Connect
		dd 0	;1 Req_Disconnect
		dd 0	;2 Req_Suspend
		dd 0	;3 Req_Resume
		dd 0	;4 Req_Get_Supplementary_Service
		dd 0	;5 Req_Perform_Supplementary_Service
		dd REQ_GET_SYS_CONFIG	;6
		dd Request_Map_Addr 	;7
if ?V19
		dd REQ_ADDR_INFO		;8 obsolete?
endif
		dd REQ_CHECKSUM_MEM 	;9
		dd Request_Read_Mem		;10
		dd Request_Write_Mem	;11
		dd REQ_READ_IO			;12
		dd REQ_WRITE_IO 		;13
if ?V19
		dd REQ_READ_CPU 		;14
		dd REQ_READ_FPU 		;15
		dd REQ_WRITE_CPU		;16
		dd REQ_WRITE_FPU		;17
endif
		dd REQ_PROG_GO			;18
		dd REQ_PROG_STEP		;19
		dd REQ_PROG_LOAD		;20
		dd Request_Prog_Kill	;21
		dd REQ_SET_WATCH		;22
		dd REQ_CLEAR_WATCH		;23
		dd REQ_SET_BREAK		;24
		dd REQ_CLEAR_BREAK		;25
		dd REQ_GET_NEXT_ALIAS	;26
		dd 0					;27 set user screen
		dd 0					;28 set debug screen
		dd 0					;29 read user keyboard
		dd REQ_GET_LIB_NAME 	;30
		dd REQ_GET_ERR_TEXT 	;31
		dd REQ_GET_MESSAGE_TEXT ;32
		dd REQ_REDIRECT_STDIN	;33
		dd REQ_REDIRECT_STDOUT	;34
		dd 0					;35  split cmd

		dd REQ_READ_REGS		;36
		dd REQ_WRITE_REGS		;37
		dd Request_Machine_Data ;38

		dd 0	;39
		dd 0	;40
		dd 0	;41
		dd 0	;42
		dd 0	;43
		dd 0	;44
		dd 0	;45
		dd 0	;46
		dd 0	;47
		dd 0	;48
		dd 0	;49
		dd 0	;50
		dd 0	;51
		dd 0	;52
		dd 0	;53
		dd 0	;54
		dd 0	;55
		dd 0	;56
		dd 0	;57
		dd 0	;58
		dd 0	;59
		dd 0	;60
		dd 0	;61
		dd 0	;62
		dd 0	;63
		dd 0	;64
		dd 0	;65
		dd 0	;66
		dd 0	;67
		dd 0	;68
		dd 0	;69
		dd 0	;70
		dd 0	;71
		dd 0	;72
		dd 0	;73
		dd 0	;74
		dd 0	;75
		dd 0	;76
		dd 0	;77
		dd 0	;78
		dd 0	;79
		dd 0	;80
		dd 0	;81
		dd 0	;82
		dd 0	;83
		dd 0	;84
		dd 0	;85
		dd 0	;86
		dd 0	;87
		dd 0	;88
		dd 0	;89
		dd 0	;90
		dd 0	;91
		dd 0	;92
		dd 0	;93
		dd 0	;94
		dd 0	;95
		dd 0	;96
		dd 0	;97
		dd 0	;98
		dd 0	;99
		dd 0	;100
		dd 0	;101
		dd 0	;102
		dd 0	;103
		dd 0	;104
		dd 0	;105
		dd 0	;106
		dd 0	;107
		dd 0	;108
		dd 0	;109
		dd 0	;110
		dd 0	;111
		dd 0	;112
		dd 0	;113
		dd 0	;114
		dd 0	;115
		dd 0	;116
		dd 0	;117
		dd 0	;118
		dd 0	;119
		dd 0	;120
		dd 0	;121
		dd 0	;122
		dd 0	;123
		dd 0	;124
		dd 0	;125
		dd 0	;126
		dd 0	;127

	.data

DebugPSP		dd 0
DebugModule		dd 0
DebugPrevCS		dw 0

		align 4

Debuggee x86_mad_registers <>

g_bTerminated	db -1	;-1=debuggee is terminated
bExecuting		db 0	;1=debuggee is running
ExceptionFlag	db 0	;reset to -1 before executing
BreakFlag		db 0	;is a int/exc 03 break
TraceFlag		db 0	;is a int/exc 01 break 
				align 4
dwFeatures		dd 0
DebuggerESP 	dd 0
DebuggerSS		dw 0
bExecuteFlags	db 0	;1=single step,2=forced single step
bBreakKeyFlag	db 0	;break key pressed
bInternalExc	db 0	;-1=internal exception in trap helper
bIsGDT			db 0	;is selector in GDT?
wDbgeeFpuEmu	dw 0

NumWatches		dd 0

pErrorMessage	dd 0

?MSG	= 0

@DefMsg macro xx,yy
local xxx
ifb <yy>
		.CONST
xxx		label byte
 ifnb <xx>
		db xx
 endif
		db 0
		.DATA
else
xxx	equ xx
endif
		dd offset xxx
;msgid	textequ @CatStr(MSG_,%?MSG)
;%msgid	equ ?MSG
@CatStr(MSG_,%?MSG) equ ?MSG
?MSG = ?MSG + 1
		endm

if ?INTRMEXC
szRMExcInTrap db 13,10,"Real-mode interrupt "
bRMExcNo db ' '
		db "occured while trap was active. Press a key",'$'
endif
if ?INTPMEXC
szInternalExc  db 13,10,"Exception 0x"
bIntExc db "0 in trap helper at CS:EIP="
bIntExcCS db '0000:'
bIntExcEIP db '00000000',13,10
		db "press any key to terminate the trap helper$"
endif

szLoadFail	db "Loading debuggee failed [DOS error "
LoadErrCode db "____]",0

ErrorList  label dword
		@DefMsg "Unknown error" 					;0
		@DefMsg "DOS reported a file access error"	;not used
		@DefMsg "File not found"
		@DefMsg "Not enough memory" 				;not used
		@DefMsg "Invalid task handle"				;4
		@DefMsg "Not enough WATCH table space"
		@DefMsg "Function not implemented"
		@DefMsg "Could not stop in debuggee"
		@DefMsg szLoadFail,1
		@DefMsg "Load request without program name" ;9
		@DefMsg
		@DefMsg "Unknown exception" 				;11
		@DefMsg "Hardware break point triggered"
		@DefMsg
		@DefMsg
		@DefMsg

;--- error# 16-32 are exception texts

		@DefMsg "Divide by zero exception (00h)"	;16
		@DefMsg
		@DefMsg
		@DefMsg
		@DefMsg "Integer overflow exception (04h)"
		@DefMsg "Array bounds exception (05h)"
		@DefMsg "Invalid opcode exception (06h)"
		@DefMsg "Device not available exception (07h)";23
		@DefMsg
		@DefMsg
		@DefMsg
		@DefMsg "Segment not present exception (0Bh)";27
		@DefMsg "Stack access exception (0Ch)"
		@DefMsg "General protection exception (0Dh)"
		@DefMsg "Page access exception (0Eh)"
		@DefMsg
		@DefMsg "Floating point exception (10h)"	;32
SIZEERRORLIST equ ($ - ErrorList) / 4


dwExcProc		dd 0	;offset to jump to on internal exc 0Eh
dfDbgeeExc0e	df 0	;old exc 0e vector saved

if ?DPMI16
szConfigFile	db "HXHP16.CFG",0
ConfigName		db "HXHP16.CFG", 128 dup (0)
else
szConfigFile	db "HXHELP.CFG",0
ConfigName		db "HXHELP.CFG", 128 dup (0)
endif
szOptions		db "Options",0
BreakKeyList	dd 37h,0,0,0		;"print" key is default
bScanCode		db 0
bPrevScanCode	db 0
;ResetTimerVAR	 db "ResetTimer",0
;ResetTimer 	 dd 0
g_bDebugLevel	db ?DEBUGLEVEL
if ?INTPMEXC
g_bTrapIntExc	db 0
endif

szLogFileName	db "HXHELP.LOG",0
g_hLogFile		dw -1
g_dwSavedPSP	dd 0			;PSP saved by write log

szError			db "Error: ",0
szReq			db "Rqst: ",0
szReply			db "Rply: ",0

	.data?

WatchTable		WATCH NUMWATCH dup (<>)
SoftBrkTable	SBREAK NUMSBREAK dup (<>)
HBRKTable		HBRK 4 dup (<>)
KeyTable		dd 128/32 dup (?)  ;keypress table.
execpb			EXECPM <>
RealModeRegs	RMCS <>	;rmcs to communicate with real-mode trap 
				align 4
ProgName		db 128 dup (?)
ProgCommand 	db 256 dup (?)
ReqBuffer		db 512 dup (?)
ReplyBuffer 	db 512 dup (?)
szTemp			db 12 dup (?)
DebugBuffer 	db 256 dup (?)
				align 4
				db 1024 dup (?)
loadstack		label byte

	.code

Byte2Ascii		proto stdcall number:dword, pBuffer:dword
Word2Ascii		proto stdcall number:dword, pBuffer:dword
DWord2Ascii		proto stdcall number:dword, pBuffer:dword
Ascii2Bin		proto stdcall pBuffer:ptr byte
strcpy			proto C :ptr byte, :ptr byte
strcat			proto C :ptr byte, :ptr byte
strlen			proto C :ptr byte
String2File		proto stdcall :ptr byte
DWord2File		proto stdcall :DWORD
SetErrorText	proto stdcall :dword

DisplayMsg proc stdcall uses esi ebx edx pText:ptr byte

if 0
	mov bh,0
	mov ax,0e07h
	int 10h
endif
	mov esi, pText
if 1
@@:
	lodsb
	and al, al
	jz @F
	mov dl, al
	mov ah, 2
	int 21h
	jmp @B
@@:
else
	mov ax,2
	int 41h
endif
	ret
DisplayMsg endp

OpenLogFile proc
	mov edx,offset szLogFileName
	mov ax,3d01h
	int 21h
	jnc @F
	mov ah,3ch
	xor cx,cx
	int 21h
	jnc @F
	mov ax,1			;use stdout then
@@:
	mov g_hLogFile,ax
	mov ebx,eax
	xor cx,cx
	xor dx,dx
	mov ax,4202h
	int 21h
error:
	ret
OpenLogFile endp

CloseLogFile proc
	mov bx, g_hLogFile
	cmp bx, -1
	jz done
	cmp bx, 1
	jz done
	mov ah,3Eh
	int 21h
done:
	ret
CloseLogFile endp

;--- write E/CX bytes to log file

WriteLog proc
	mov bx,cs:g_hLogFile
	mov ah,40h
	int 21h
	jc @F
	ret
@@:
	invoke DisplayMsg, CStr("error writing to log file",13,10)
	ret
WriteLog endp

StartLog proc

	pushad
	mov ah,51h
	int 21h
	push ds
	mov ds,cs:[g_dsreg]
	mov g_dwSavedPSP,ebx
	mov ebx, g_psp
	pop ds
	mov ah,50h
	int 21h
	popad
	ret
StartLog endp

EndLog proc
	mov bx, cs:g_hLogFile
	mov ah,68h
	int 21h
	mov ebx, cs:g_dwSavedPSP
	mov ah,50h
	int 21h
	ret
EndLog endp

;--- write a string to the log file

String2File proc stdcall pszText:ptr byte

	cmp g_bDebugLevel,0
	jz exit
	pushad
	mov edx, pszText
	xor ecx, ecx
	.while (byte ptr [edx+ecx])
		inc ecx
	.endw
	call StartLog
	call WriteLog
	call EndLog
	popad
exit:
	ret
String2File endp

;--- win9x doesnt want to send exc 01 messages!!!

forceexc01supply proc

	cmp g_bIsWin9x,0
	jz exit
	pushad
	mov cx,word ptr OldExc01+4
	push ecx
	push dword ptr OldExc01+0
	mov dword ptr OldExc01+0, offset exc01received
if ?INTPMEXC
	mov al, g_bTrapIntExc
	push eax
	mov g_bTrapIntExc,0
endif
if ?DPMI16
	mov ecx, g_cs16alias
	mov word ptr OldExc01+4, cx
else
	mov word ptr OldExc01+4, cs
endif
	mov ecx,1000000h
if ?DPMI16
	movzx esi,sp
else
	mov esi,esp
endif
@@:
	pushfd
	or byte ptr [esi-3],1
	popfd
	loop @B
	jmp done
cont_after_exc:
	@switchcs
;	invoke String2File, CStr("got exception 01 on win3x/9x system",13,10)
done:
if ?INTPMEXC
	pop eax
	mov g_bTrapIntExc,al
endif
	pop dword ptr OldExc01+0
	pop ecx
	mov word ptr OldExc01+4,cx
	popad
exit:
	ret
exc01received:
if ?DPMI16
	@switchcs
	push ebp
	movzx ebp,sp
	and byte ptr [ebp+4].EXCFRAME16._eflags+1,not 1
	mov [ebp+4].EXCFRAME16._eip,lowword(offset cont_after_exc)
	push eax
	@loadcs eax
	mov [ebp+4].EXCFRAME16._cs,ax
	pop eax
	pop ebp
else
	and byte ptr [esp].EXCFRAME._eflags+1,not 1
	mov [esp].EXCFRAME._eip,offset cont_after_exc
endif
	@retf

forceexc01supply endp


if ?RMDBGHLP

traprm21 proc
	cmp g_bRMInt21Trapped,-1
	jz done
	mov ax,0200h
	mov bl,21h
	int 31h
	mov eax,g_dwRMAddr
	mov word ptr @flat:[eax].DEBRMVAR.oldint21r+0,dx
	mov word ptr @flat:[eax].DEBRMVAR.oldint21r+2,cx
	mov ecx,g_dwRMAddr
	shr ecx,4
	mov dx,@flat:[eax].DEBRMVAR.wIntr21r
	mov ax,0201h
	int 31h
	mov g_bRMInt21Trapped,-1
done:
	ret
traprm21 endp

untraprm21 proc
	cmp g_bRMInt21Trapped,0
	jz @F
	mov eax, g_dwRMAddr
	mov dx, word ptr @flat:[eax].DEBRMVAR.oldint21r+0
	mov cx, word ptr @flat:[eax].DEBRMVAR.oldint21r+2
	mov bl,21h
	mov ax,0201h
	@callint31
	mov g_bRMInt21Trapped,0
@@:
	ret
untraprm21 endp

InitRMDbgHelper proc uses fs

local	dwSize:dword
local	dwSaveRestoreSize:dword
local	hFile:dword
local	_InitRmDbgHlp:PF32
local	desc[8]:byte
local	szPath[260]:byte

;----------------------- get task state save addresses

	mov hFile,-1
	mov ax,305h
	int 31h
	mov word ptr g_dwSaveRestoreRM+0,cx
	mov word ptr g_dwSaveRestoreRM+2,bx
if ?DPMI16
	movzx edi,di
endif
	mov dword ptr g_dfSaveRestorePM+0,edi
	mov word ptr g_dfSaveRestorePM+4,si
	movzx eax,ax
	mov	dwSaveRestoreSize, eax

	invoke String2File, CStr("InitRMDbgHelper starts",13,10)
	push es
	mov es, g_psp
	mov es,es:[002Ch]
	xor edi,edi
	mov al,0
	or ecx,-1
@@:
	repnz scasb
	scasb
	jnz @B
	inc edi
	inc edi
	lea edx, szPath
	mov ebx, edx
	mov ecx, sizeof szPath
nextitem:
	mov al,es:[edi]
	mov [edx],al
	inc edi
	inc edx
	cmp al,'\'
	jnz @F
	mov ebx, edx
@@:
	and al,al
	loopnz nextitem
	pop es

	mov esi, CStr("rmdbghlp.bin")
	mov edi, ebx
@@:
	lodsb
	stosb
	and al,al
	loopnz @B

	lea edx, szPath
	mov ax,3D00h		;open file
	int 21h
	jc error1
	mov hFile, eax
	mov ebx, eax
	xor ecx,ecx
	xor edx,edx
	mov ax,4202h		;get file size
	int 21h
	push dx
	push ax
	pop eax
	mov dwSize, eax
	invoke String2File, CStr("Size RM helper code: ")
	invoke DWord2File, eax
	invoke String2File, CStr(13,10)
	add eax, dwSaveRestoreSize
	mov ebx, eax
	shr ebx, 4
	test al,0Fh
	jz @F
	inc ebx
@@:
	mov ax,0100h		;alloc conventional DOS memory
	int 31h
	jc error2
	movzx eax,ax
	shl eax, 4
	mov g_dwRMAddr, eax	;linear address of DOS memory
	movzx edx,dx
	mov g_dwRMData, edx	;selector for DOS memory

	invoke String2File, CStr("RM helper linear address: ")
	invoke DWord2File, eax
	invoke String2File, CStr(13,10)

	xor ecx,ecx
	xor edx,edx
	mov ebx,hFile
	mov ax,4200h		;reposition to start of file
	int 21h

	mov ecx, dwSize
if ?DPMI16
	push ds
	mov ds, g_dwRMData
	xor edx, edx
else
	mov edx, g_dwRMAddr
endif
	mov ax,3F00h		;read file (rmdbghlp.bin)
	int 21h
if ?DPMI16
	pop ds
	mov edx, g_dwRMAddr
endif
	jc error3

	cmp word ptr @flat:[edx], sizeof DEBRMVAR	;version must match
	jnz error4

;	invoke String2File, CStr("Init RM Dbg Helper MS 2",13,10)

	mov ax,0		;allocate a LDT descriptor
	mov cx,1
	int 31h
	jc error5
	movzx eax,ax
	mov g_dwRMCode, eax	;will be used to call code in rmdbghlp.bin
	mov ebx, g_dwRMData
	lea edi, desc
	mov ax,000bh
	int 31h
	mov ebx, g_dwRMCode
	or byte ptr desc+5,8		;set CODE attribute
	and byte ptr desc+6,not 40h	;required by DOSEMU DPMI host
	mov ax,000ch
	int 31h

;	invoke String2File, CStr("Init RM Dbg Helper MS 3",13,10)

;	mov dword ptr _InitRmDbgHlp, eax
	mov dword ptr _InitRmDbgHlp, sizeof DEBRMVAR
	mov word ptr _InitRmDbgHlp+4, bx

	mov eax, g_dwRMAddr
	shr eax, 4
	push ax
	mov ax, word ptr g_dwRMData
	push ax
	call _InitRmDbgHlp
;	invoke String2File, CStr("Init RM Dbg Helper MS 4",13,10)

	mov edx, g_dwRMAddr
	mov word ptr @flat:[edx].DEBRMVAR.pmcs,cs
	mov word ptr @flat:[edx].DEBRMVAR.pmds,ds
	mov eax,offset loadstack - 80h
	mov @flat:[edx].DEBRMVAR.pmesp,eax
	mov @flat:[edx].DEBRMVAR.pmeip,offset rm2pm

	mov eax, g_dwSaveRestoreRM
	mov @flat:[edx].DEBRMVAR.rmsavestate,eax

	invoke String2File, CStr("save/restore state rm addr: ")
	invoke DWord2File, eax
	invoke String2File, CStr(13,10)
	invoke String2File, CStr("rm offset for raw switch: ")
	movzx eax, @flat:[edx].DEBRMVAR.wPM2RMEntry
	invoke DWord2File, eax
	invoke String2File, CStr(13,10)

	mov eax, g_dwRMAddr
	shr eax, 4
	shl eax, 16
	mov ax,word ptr dwSize
	mov @flat:[edx].DEBRMVAR.savestatebuffRM, eax
	invoke String2File, CStr("rm addr save state buffer: ")
	invoke DWord2File, eax
	invoke String2File, CStr(13,10)
	mov eax, g_dwRMData
	shl eax, 16
	mov ax,word ptr dwSize
	mov @flat:[edx].DEBRMVAR.savestatebuffPM, eax
	mov ax,306h
	int 31h
	mov word ptr @flat:[edx].DEBRMVAR.rm2pmjump+0,cx
	mov word ptr @flat:[edx].DEBRMVAR.rm2pmjump+2,bx
	mov word ptr g_rm2pmjump+0,cx
	mov word ptr g_rm2pmjump+2,bx
if ?DPMI16
	movzx edi,di
endif
	mov dword ptr [g_pm2rmjump+0],edi
	mov word ptr  [g_pm2rmjump+4],si

;	invoke	String2File, CStr("Init RM Dbg Helper MS 5",13,10)

	mov esi, offset g_rminttab
	.while (byte ptr [esi] != -1)
		mov ax,0200h
		mov bl,[esi]
		int 31h
		mov [esi+1],dx
		mov [esi+3],cx
		mov edx, g_dwRMAddr
		movzx edx, @flat:[edx].DEBRMVAR.wIntr00r
		movzx ebx,bl
		lea edx, [edx+4*ebx]
		mov ecx, g_dwRMAddr
		shr ecx,4
		mov ax,0201h
		int 31h
		add esi,5
	.endw
;--- trap int 21h rm only just before int 21h, ax=4b00h!
;	call traprm21

	mov g_bRMIntsTrapped,-1

	lea edi,szPath
	xor eax,eax
	mov [edi].RMCS.rSSSP,eax
	mov [edi].RMCS.rFlags,ax
	mov [edi].RMCS.rAX,1687h
	mov bx,002Fh
	xor ecx,ecx
	mov ax,300h
	int 31h
	mov ax,[edi].RMCS.rES
	shl eax,16
	mov ax,[edi].RMCS.rDI
	mov g_dwDPMIEntry,eax

	invoke String2File, CStr("Init RM Dbg Helper ok",13,10)

done:
	mov ebx, hFile
	cmp bx,-1
	jz @F
	mov ah,3Eh
	int 21h
@@:
	clc
	ret
error1:
	push edx
	invoke String2File, CStr("open error file ")
	pop edx
	invoke String2File, edx
	invoke String2File, CStr(13,10)
	invoke DisplayMsg, CStr("rmdbghlp.bin not loaded",13,10)
	jmp error
error2:
	mov edx, CStr("no DOS memory available",13,10)
	jmp @F
error3:
	mov edx, CStr("rmdbghlp.bin read error",13,10)
	jmp @F
error4:
	mov edx, CStr("wrong version",13,10)
	jmp @F
error5:
	mov edx, CStr("no more selectors available",13,10)
@@:
	invoke DisplayMsg, CStr("InitRMDbgHelper: ")
	invoke DisplayMsg, edx
	invoke String2File, edx
error:
	mov g_bRC,1
	stc
	ret

InitRMDbgHelper endp

DeinitRMDbgHelper proc
	call untraprm21
	cmp g_bRMIntsTrapped,0
	jz done
	mov esi, offset g_rminttab
	.while (byte ptr [esi] != -1)
		mov bl, [esi+0]
		mov dx, [esi+1]
		mov cx, [esi+3]
		mov ax, 201h
		@callint31
		add esi, 5
	.endw
done:
	mov ebx,g_dwRMData
	mov ax, 101h
	@callint31
	ret
DeinitRMDbgHelper endp

;*** break debuggee in real-mode
;*** FS/GS=NULL

rm2pm proc
if ?INTRMEXC
	cmp [bExecuting],0
	jz rmintintrap
endif
	lss esp,fword ptr [DebuggerESP]
ife ?FLAT
	mov @flat,[g_flatsel]
endif
	mov esi, g_dwRMAddr
	add esi, offset DEBRMVAR.rm

;--- copy DPMI RMCS structure to a WD Debuggee structure

	cld
	@lodsdflat
	mov [Debuggee.cpu._Edi],eax
	@lodsdflat
	mov [Debuggee.cpu._Esi],eax
	@lodsdflat
	mov [Debuggee.cpu._Ebp],eax
	@lodsdflat
	@lodsdflat
	mov [Debuggee.cpu._Ebx],eax
	@lodsdflat
	mov [Debuggee.cpu._Edx],eax
	@lodsdflat
	mov [Debuggee.cpu._Ecx],eax
	@lodsdflat
	mov [Debuggee.cpu._Eax],eax
	@lodswflat
	movzx eax,ax
	mov [Debuggee.cpu._Efl],eax
	@lodswflat
	mov [Debuggee.cpu._Es],ax
	@lodswflat
	mov [Debuggee.cpu._Ds],ax
	@lodswflat
	mov [Debuggee.cpu._Fs],ax
	@lodswflat
	mov [Debuggee.cpu._Gs],ax
	@lodswflat
	mov [Debuggee.cpu._Eip],eax
	@lodswflat
	mov [Debuggee.cpu._Cs],ax
	@lodswflat
	mov [Debuggee.cpu._Esp],eax
	@lodswflat
	mov [Debuggee.cpu._Ss],ax

	or g_fRealMode, -1
	mov esi, g_dwRMAddr
	mov cl,@flat:[esi].DEBRMVAR.bMode
	mov g_fV86,cl
	mov ax,@flat:[esi].DEBRMVAR.intno
	cmp al,1
	jnz @F
	or TraceFlag,-1
	call IsHardBreak
	jnc done
	mov ExceptionFlag,1
	jmp done
@@:
	cmp al,3
	jnz @F
	or BreakFlag,-1
	dec [Debuggee.cpu._Eip]
	jmp done
@@:
	cmp al,5
	jnz @F
	movzx edx,Debuggee.cpu._Cs			;get CS:IP in EDX
	shl edx,4
	add edx,Debuggee.cpu._Eip
	cmp byte ptr @flatrd:[edx],62h	;bound instruction?
	jz @F
										;else it is a called INT 05
	mov edx, dwOldInt05RM
	mov esi, g_dwRMAddr
	xchg edx, @flat:[esi].DEBRMVAR.rm.rCSIP
	movzx eax, @flat:[esi].DEBRMVAR.rm.rSS
	shl eax,4
	movzx ecx,@flat:[esi].DEBRMVAR.rm.rSP
	add eax,ecx
	mov @flat:[eax-3*2],edx
	mov cx,@flat:[esi].DEBRMVAR.rm.rFlags
	mov @flat:[eax-1*2], cx
	sub @flat:[esi].DEBRMVAR.rm.rSP,3*2
	and byte ptr @flat:[esi].DEBRMVAR.rm.rFlags+1,0FCh
	jmp pm2rmEx
@@:
	cmp al,7
	ja done
	mov ExceptionFlag,al
done:
if ?DEBUGLEVEL
	invoke String2File, CStr("rm2pm eax=")
	invoke DWord2File, eax
	invoke String2File, CStr(13,10)
endif
	ret
if ?INTRMEXC
rmintintrap:
;--- a real mode exception occured while trap was active
;--- not much can be done, just display a message and wait for a key
;--- then jump back to real-mode
ife ?FLAT
	mov @flat,[g_flatsel]
endif
	mov esi, g_dwRMAddr
	and byte ptr @flat:[esi].DEBRMVAR.rm.rFlags+1,not 1
	mov ax,@flat:[esi].DEBRMVAR.intno
	add al,'0'
	mov [bRMExcNo],al
	mov edx,offset szRMExcInTrap
	mov ah,9
	@callint21
	mov ah,0
	int 16h
	jmp pm2rmEx
endif

rm2pm endp

;*** continue running debuggee in real-mode

pm2rm proc
	push ds
	pop es
	mov edi,g_dwRMAddr
	add edi,offset DEBRMVAR.rm
if ?DEBUGLEVEL
	invoke String2File, CStr("pm2rm",13,10)
endif
	cld
if ?DPMI16
	push es
	push @flat
	pop es
endif
	mov eax,[Debuggee.cpu._Edi]
	stosd
	mov eax,[Debuggee.cpu._Esi]
	stosd
	mov eax,[Debuggee.cpu._Ebp]
	stosd
	add edi,4
	mov eax,[Debuggee.cpu._Ebx]
	stosd
	mov eax,[Debuggee.cpu._Edx]
	stosd
	mov eax,[Debuggee.cpu._Ecx]
	stosd
	mov eax,[Debuggee.cpu._Eax]
	stosd
	mov ax,word ptr [Debuggee.cpu._Efl]
	stosw
	mov ax,[Debuggee.cpu._Es]
	stosw
	mov ax,[Debuggee.cpu._Ds]
	stosw
	mov ax,[Debuggee.cpu._Fs]
	stosw
	mov ax,[Debuggee.cpu._Gs]
	stosw
	mov ax,word ptr [Debuggee.cpu._Eip]
	stosw
	mov ax,[Debuggee.cpu._Cs]
	stosw
	mov ax,word ptr [Debuggee.cpu._Esp]
	stosw
	mov ax,[Debuggee.cpu._Ss]
	stosw
if ?DPMI16
	pop es
endif
pm2rmEx::
	mov edi,g_dwRMAddr
	mov dx, @flat:[edi].DEBRMVAR.rm.rSS
	mov bx, @flat:[edi].DEBRMVAR.rm.rSP
	mov di, @flat:[edi].DEBRMVAR.wPM2RMEntry	;ip

	mov eax,g_dwRMAddr			;ds
	shr eax, 4
	mov cx,ax					;es
	mov si,ax					;cs
	jmp fword ptr [g_pm2rmjump]

endif
pm2rm endp

;******************************************************************************
;Main entry point. Just has to find the trap file signature and note the
;buffer details before passing control back to real mode.
;******************************************************************************

main proc near c uses esi edi ebp

;
;Read configuration.
;
	call ReadConfig

;
;If in debug mode we need to delete the last log file.
;
	cmp g_bDebugLevel,0
	jz @F
	mov edx,offset szLogFileName
	mov ah,41h
	int 21h
	invoke OpenLogFile
	invoke String2File, CStr("HX Trap helper starts, helper psp=")
	invoke DWord2File, [g_psp]
	invoke String2File, CStr(13,10)
@@:
;
;Look for trap file signature off vector 6.
;
	mov esi,?RMVECTOR*4 		;point to int 6 vector.
	mov esi,@flatrd:[esi]		;retrieve contents.
	cmp esi,10FFF0h
	jnb @@errormain1
	cmp dword ptr @flat:[esi+0],0deb0deb0h ;right signature?
	jnz @@errormain2

	invoke String2File, CStr("signature found",13,10)
;
;Get the buffer address.
;
	mov eax,@flat:[esi+4]
	mov ReqAddress,eax
;
;Get the real mode call-back address.
;
	mov eax,@flat:[esi+8]
	mov RealModeRegs.rCSIP,eax

;--- missing in CWHELP.ASM: restore INT 6 RM

	mov dx,@flat:[esi+12]
	mov cx,@flat:[esi+14]
	mov bl,?RMVECTOR			;do it with DPMI
	mov ax,0201h				;because DS may be ED in flat model
	int 31h
;
;Patch exception vectors
;
	mov esi, offset ExceptionTab
	.while ([esi].excstr.bExc != -1)
		lodsw
		mov ebx,eax
		mov ax,0202h
		int 31h
		lodsd
if ?DPMI16
		movzx edx,dx
endif
		mov [eax+0],edx
		mov [eax+4],cx
		test bh,1
		jz @F
		add eax, sizeof fword
		mov [eax+0],edx
		mov [eax+4],cx
@@:
		lodsd
		mov edx, eax
		@loadcs ecx
if ?DPMI16
		cmp g_bUseCsAlias,0
		jz @F
		mov ecx,cs
		add edx, 8	;dont use @switchcs, skip "jmp far32 SSSS:OOOOOOOO"
@@:
endif
		mov ax,0203h
		int 31h
	.endw

	invoke String2File, CStr("exception vectors set",13,10)
;
;Patch interrupt vectors
;
	mov esi, offset InterruptTab
	.while ([esi].excstr.bExc != -1)
		lodsw
		mov ebx,eax
		mov ax,0204h
		int 31h
		lodsd
		mov [eax+0],edx
		mov [eax+?SEGOFS],cx
		test bh,2
		jz @F
		mov [eax+sizeof INTVEC+0],edx
		mov [eax+sizeof INTVEC+?SEGOFS],cx
@@:
		lodsd
		mov edx, eax
		@loadcs ecx
if ?DPMI16
		cmp g_bUseCsAlias,0
		jz @F
		mov ecx,cs
		add edx, 8	;dont use @switchcs, skip "jmp far32 SSSS:OOOOOOOO"
@@:
endif
		mov ax,0205h
		int 31h
	.endw

	invoke String2File, CStr("interrupt vectors set",13,10)

if ?RMDBGHLP
	call InitRMDbgHelper
	jc dontload
endif

;
;Say hello.
;
versionstring textequ @CatStr(!",%?VERMAJOR,.,%?VERMINOR,!")
	invoke DisplayMsg, CStr(13,10,"HX Trap helper v",versionstring," initialized",13,10)
;
;Pass control to real mode call handler.
;
	call Dispatcher

if ?RMDBGHLP
	call DeinitRMDbgHelper
endif
if ?FLAT or ?NE
	cmp g_bLoader, 0
	jnz @F
	mov bl,1		;enable loader
	mov ax,4b91h	;set DPMILDR variable
	@callint21
@@:
endif
dontload:
;
;--- display last message here, before int 21h is restored!
;
if 0
	invoke String2File, CStr("current psp linear addr=")
	mov ah, 51h
	int 21h
	mov ax, 6
	int 31h
	push cx
	push dx
	pop ebx
	invoke DWord2File, ebx
endif
	invoke String2File, CStr("HX Trap helper terminates",13,10)
	invoke CloseLogFile
;
;--- restore interrupt handlers
;
	cld
	mov esi, offset InterruptTab
	.while (byte ptr [esi] != -1)
		lodsw
		mov ebx,eax
		lodsd
		mov edx,[eax+0]
		mov cx,[eax+?SEGOFS]
		test bh, 2
		jz @F
		mov edx,[eax+sizeof INTVEC+0]
		mov cx,[eax+sizeof INTVEC+?SEGOFS]
@@:
		mov ax,0205h
		@callint31
		lodsd
	.endw
;
;--- restore exception handlers
;
	mov esi, offset ExceptionTab
	.while (byte ptr [esi] != -1)
		lodsw
		mov bl,al
		lodsd
		mov edx,[eax+0]
		mov cx,[eax+4]
		mov ax,0203h
		@callint31
		lodsd
	.endw
;
;
;Better return an errorlevel of zero.
;
	mov al,g_bRC
	ret
@@errormain1:
	invoke DisplayMsg, CStr("HX Trap helper can't be executed from the command line",13,10)
	mov al,1
	ret
@@errormain2:
	invoke DisplayMsg, CStr("signature not found",13,10)
	mov al,1
	ret
main endp


;*******************************************************************************
;Takes care of low-level link to the trap file and dishes out control to
;appropriate functions.
;*******************************************************************************
Dispatcher proc near

@@0disp:
	mov edi,offset RealModeRegs
	mov bx,0
	mov cx,0
	mov ax,0301h		;call realmode far proc (RETF frame)
	@callint31
;	invoke	String2File, CStr("back from real mode",13,10)
;
;Copy commands up into the local buffer.
;
ife ?FLAT
	mov @flat,[g_flatsel]
endif
	mov esi,ReqAddress
	mov edi,offset ReqBuffer
	mov ecx,@flat:[esi+4]		;get data length.
	mov esi,@flat:[esi+0]		;point to data.
	cmp ecx,sizeof ReqBuffer
	jbe @F
	mov ecx,sizeof ReqBuffer
@@:
	mov ReqLength,ecx
ife ?FLAT
	push ds
	push @flat
	pop ds
endif
	rep movsb
ife ?FLAT
	pop ds
endif
;
;If we're doing debug info dump this request.
;
	cmp g_bDebugLevel,0
	jz @F
	call DumpRequest2File
@@:
;
;Check if this is a get lost message.
;
	cmp [ReqBuffer],0
	jz exit
;
;Check if any results are needed and skip processing on this pass if they are.
;
	mov al,[ReqBuffer]
	and [ReqBuffer],7Fh
	and al,80h
	xor al,80h
	mov g_bWantReturn,al
;	jnz @@2disp
;
;Pass control back to real mode ready for result transfer.
;
if 0
	mov edi,offset RealModeRegs
	mov bx,0
	mov cx,0
	mov ax,0301h	;call realmode proc with RETF frame
	@callint31
endif
;
;Process specified commands.
;
@@2disp:
	mov esi,offset ReqBuffer
	mov ecx,ReqLength
	mov edi,ReqAddress
	mov edi,@flat:[edi+0]
ife ?FLAT
  if ?DPMI16
	mov edi,offset ReplyBuffer
  else
	sub edi, [__baseadd]
  endif
endif
;
;Go through all commands.
;
@@3disp:
	xor eax,eax
	mov al,[esi]				;get the command number.
	and al,7Fh
	cmp dword ptr [ReqTable+eax*4],0
	jz @@oopsdisp
	call dword ptr [ReqTable+eax*4]
	or ecx,ecx
	jnz @@3disp
	jmp @@4disp
;
;Display request buffer if we don't understand it.
;
@@oopsdisp:
	cmp g_bDebugLevel,0
	jz @F
	call DumpError2File
@@:
;
;Set output length.
;
@@4disp:
	cmp g_bWantReturn,0
	jz noreturn
	mov esi,ReqAddress
if ?FLAT
	sub edi,@flat:[esi+0]
else
	mov @flat,[g_flatsel]
  if ?DPMI16
	sub edi,offset ReplyBuffer
  else
	add edi,[__baseadd]
	sub edi,@flat:[esi+0]
  endif
endif
	mov @flat:[esi+4],edi	;set size of reply
if ?DPMI16
	pushad
	mov ecx,edi
	push es
	push @flat
	pop es
	mov edi,@flat:[esi+0]
	mov esi,offset ReplyBuffer
	rep movsb
	pop es
	popad
endif
	cmp g_bDebugLevel,0
	jz @F
	call DumpReply2File	;write reply to log file.
@@:
	mov edi,offset RealModeRegs
	mov bx,0
	mov cx,0
	mov ax,0301h	;call realmode proc with RETF frame
	@callint31
noreturn:
	jmp @@0disp
;
exit:
	ret
Dispatcher endp

;--- save debuggee fpu emulation bits and clear them

clearfpuemu proc
	mov ax,0E00h
	@callint31
	and ax,1+2
	mov wDbgeeFpuEmu,ax
	xor ebx,ebx
	mov ax,0E01h
	@callint31
	ret
clearfpuemu endp

;--- restore debuggee fpu emulation bits

restorefpuemu proc
	mov bx,wDbgeeFpuEmu
	mov ax,0E01h
	@callint31
	ret
restorefpuemu endp

;--- check cpu type, return features if CPUID is supported

Is486 proc
	pushfd						; save EFlags
	xor edx,edx
	xor esi,esi
	push 240000h				; set AC+ID bits in eflags
	popfd
	pushfd
	pop eax
	popfd						; restore EFlags
	shr eax, 16
	test al,04					; AC bit set? then it is a 486+
	mov ah,0
	je @@no_486
	inc ah
	test al,20h 				; CPUID supported?
	jz @@nocpuid
	xor eax,eax
	inc eax 					; get register 1
	.586
	cpuid
	.486
	mov esi, eax
	mov ah,1
@@nocpuid:
@@no_486:
	mov al,ah
	ret
Is486 endp


;*******************************************************************************
;
;Get system configuration info (processor type etc).
;
;On Entry:
;
;ECX	- remaining request bytes.
;ESI	- current request data.
;EDI	- result buffer position.
;
;Returns:
;
;ECX,ESI & EDI updated.
;
;*******************************************************************************
REQ_GET_SYS_CONFIG proc

local @@incount:DWORD
local @@inaddr:DWORD
local @@outaddr:DWORD
local dwEsp:DWORD

;	pushads
	pushad

	inc esi 			;skip REQ_GET_SYS_CONFIG
	dec ecx

	mov @@incount,ecx
	mov @@inaddr,esi
	mov @@outaddr,edi
;
;Get the main processor type.
;does recognize 386 and 486 only!

	mov dwEsp, esp
	and esp,not 3		; align it to avoid faults
	call Is486
	add al,3			;3/4 for 386/486
	and edx, edx
	jz @F
	mov dwFeatures, edx	;important for FXSAVE/FXRSTOR support
	mov eax, esi		;get model from cpuid
	shr eax, 4			;skip stepping info
	and al,0Fh
@@:
	test edx,1 shl 23	;MMX support?
	jz @F
	or al,10h
@@:
	test edx,1 shl 25	;SSE support?
	jz @F
	or al,20h
@@:
	mov [edi].system_config.cpu, al
	mov esp,dwEsp
;
;Get the math co-processor type.
;
	mov [edi].system_config.fpu, al
	cmp [edi].system_config.cpu, 5	;don't examine fpu if cpu is pentium or better
	jnc fpu_ok

	call clearfpuemu

	push ebp 			; save bp
	sub eax,eax 		; set initial control word to 0
	push eax 			; push it on stack
if ?DPMI16
	movzx ebp,sp		; point to control word
else
	mov ebp,esp 		; point to control word
endif
	fninit				; initialize math coprocessor
	fnstcw [ebp]		; store control word in memory
	mov al,0			; assume no coprocessor present
	mov ah,[ebp+1]		; upper byte is 03h if
	cmp ah,03h			; coprocessor is present
	jne @@0conf 		; exit if no coprocessor present
	mov al,1			; assume it is an 8087
	and dword ptr [ebp],NOT 0080h		; turn interrupts on (IEM=0)
	fldcw [ebp]			; load control word
	fdisi				; disable interrupts (IEM=1)
	fstcw [ebp]			; store control word
	test dword ptr [ebp],080h	; if IEM=1, then 8087
	jnz @@0conf
	finit				; use default infinity mode
	fld1				; generate infinity by
	fldz				; dividing 1 by 0
	fdiv				; ...
	fld 	st			; form negative infinity
	fchs				; ...
	fcompp				; compare +/- infinity
	fstsw [ebp]			; equal for 87/287
	fwait				; wait fstsw to complete
	mov eax,[ebp]		; get NDP control word
	mov al,2			; assume 80287
	sahf				; store condition bits in flags
	jz @@0conf 			; it's 287 if infinities equal
	mov al,3			; indicate 80387
@@0conf:
	pop ebp
	pop ebp
	mov [edi].system_config.fpu,al
	call restorefpuemu

fpu_ok:
;
;Set OS values.
;
	mov ah,30h
	int 21h 			;Get DOS version.

	mov [edi].system_config.osmajor,al
	mov [edi].system_config.osminor,ah

	mov [edi].system_config.os, OS_RATIONAL ;( =DOS4G or compatible? )
;
;Set huge shift value.
;
	mov [edi].system_config.huge_shift,12	;HUGE_SHIFT!

	mov [edi].system_config.mad,MAX_X86
	add edi, sizeof system_config
	mov @@outaddr,edi
;
;Return results to caller.
;
	popad
	mov ecx,@@incount
	mov esi,@@inaddr
	mov edi,@@outaddr
	ret

REQ_GET_SYS_CONFIG endp


;--- get handle(=selector) of a segment#
;--- first segment# is 1, not 0!

GetSegmentHandle proc uses es esi dwModule:dword, dwSegmentNo:dword

	xor eax, eax
	mov ecx,dwModule
	verw cx
	jnz exit
	mov es,ecx
	cmp word ptr es:[0],"EN"
	jnz exit
	movzx ecx,word ptr es:[001Ch]	;number of segments
	jecxz exit
	cmp eax,dwSegmentNo	;segment# 0 is invalid
	jz exit
	cmp ecx,dwSegmentNo	;segment# too big?
	jc exit

	movzx esi,word ptr es:[0022h]	;offset segment table
	movzx eax,word ptr es:[0024h]	;offset resource table
	sub eax,esi
	cdq
	div ecx				;now ax=size of one segment entry
	mov ecx,dwSegmentNo
	dec ecx
	mul ecx
	add esi, eax
	movzx eax,word ptr es:[esi+8]
exit:
	ret
GetSegmentHandle endp


;*******************************************************************************
;
;Convert image segment/selector number/offset into real address.
;
;On Entry: esi -> REQ_MAP_ADDR
;expected  edi -> REPLY_MAP_ADDR
;          ecx - remaining request bytes.
;
;Returns:
;
;ECX,ESI & EDI updated.
;
;*******************************************************************************

REQ_MAP_ADDR struct
bReq	 db ?
dwOfs	 dd ?
wSeg	 dw ?
dwModule dd ?
REQ_MAP_ADDR ends

REPLY_MAP_ADDR struct
dwOfs	 dd ?
wSeg	 dw ?
lobounds dd ?
hibounds dd ?
REPLY_MAP_ADDR ends

MAP_FLAT_CODE_SELECTOR	equ -1
MAP_FLAT_DATA_SELECTOR	equ -2

Request_Map_Addr proc

local incount:DWORD
local inaddr:DWORD
local outaddr:DWORD
local wSeg:word

	pushad
;
;Setup new input count/address.
;Setup output address
;
	mov incount, ecx
	mov inaddr, esi
	sub incount, sizeof REQ_MAP_ADDR
	add inaddr, sizeof REQ_MAP_ADDR
	mov outaddr, edi
	add outaddr, sizeof REPLY_MAP_ADDR

	xor eax,eax
	mov [edi].REPLY_MAP_ADDR.dwOfs, eax
	mov [edi].REPLY_MAP_ADDR.wSeg, ax
	mov [edi].REPLY_MAP_ADDR.lobounds, eax
	mov [edi].REPLY_MAP_ADDR.hibounds, eax
;
;Check the module handle.
;
	mov edx,[esi].REQ_MAP_ADDR.dwModule
ife ?DPMI16
	test edx,0FFFF0000h			;is it a PE module?
	jnz ispe
  if ?DJGPP
	cmp g_bIsDjgpp, -1
	jz isdjgpp
  endif
endif
	mov dx, [esi].REQ_MAP_ADDR.wSeg
	cmp dx, MAP_FLAT_CODE_SELECTOR
	jz @F
	cmp dx, MAP_FLAT_DATA_SELECTOR
	jnz selok
@@:
	mov dx, 0
selok:
	mov wSeg, dx
	cmp g_fRealMode,0
	jz isprotmode16
;--- ignore offset.
;--- DGROUP might actually start "within" a paragraph, but
;--- since it is a segment address, there might be an "offset" then.
;--- it has to be ignored for map_addr - else the contents of globals
;--- aren't correctly shown in the debugger.
	mov eax,[esi].REQ_MAP_ADDR.dwOfs
	mov [edi].REPLY_MAP_ADDR.dwOfs, eax
	mov ebx, [esi].REQ_MAP_ADDR.dwModule	;module handle (=PSP)

	invoke String2File, CStr("ReqMapAddr, rm, Module=")
	invoke DWord2File, ebx
	invoke String2File, CStr(13,10)

	mov ax, 6
	@callint31
	jc exit
	push cx
	push dx
	pop edx
	shr edx, 4
	add dx, 10h
	add dx, wSeg

	invoke String2File, CStr("ReqMapAddr, out seg=")
	invoke DWord2File, edx
	invoke String2File, CStr(13,10)

	mov [edi].REPLY_MAP_ADDR.wSeg, dx
	mov [edi].REPLY_MAP_ADDR.hibounds, 0FFFFh
	jmp exit   

isprotmode16:
	movzx ebx, wSeg
	mov eax,[esi].REQ_MAP_ADDR.dwModule

	invoke String2File, CStr("ReqMapAddr, pm16, Module=")
	invoke DWord2File, eax
	invoke String2File, CStr(13,10)

	movzx eax, ax
	invoke GetSegmentHandle, eax, ebx
	and eax,eax
	jz exit
	mov [edi].REPLY_MAP_ADDR.wSeg, ax
	lsl ecx,eax
	mov eax,[esi].REQ_MAP_ADDR.dwOfs
	mov [edi].REPLY_MAP_ADDR.dwOfs, eax
	mov [edi].REPLY_MAP_ADDR.hibounds,ecx
	jmp exit

if ?DJGPP
isdjgpp:

	invoke String2File, CStr("ReqMapAddr djgpp, Module=")
	invoke DWord2File, edx
	invoke String2File, CStr(13,10)

	mov eax,[esi].REQ_MAP_ADDR.dwOfs
	mov [edi].REPLY_MAP_ADDR.dwOfs,eax
	mov [edi].REPLY_MAP_ADDR.wSeg,dx		;addr selector
	mov [edi].REPLY_MAP_ADDR.lobounds,0
	lsl eax,edx
	mov [edi].REPLY_MAP_ADDR.hibounds,eax
	jmp exit   
endif

ispe:

	invoke String2File, CStr("ReqMapAddr, pm32, Module=")
	invoke DWord2File, edx
	invoke String2File, CStr(13,10)

	mov ebx,cs
	mov ax,[esi].REQ_MAP_ADDR.wSeg	;selector (MAP_FLAT_CODE/MAP_FLAT_DATA)
	cmp ax,MAP_FLAT_CODE_SELECTOR
	jz iscode
	mov ebx,ds
	cmp ax,MAP_FLAT_DATA_SELECTOR
	jz isdata
	mov ebx, eax
iscode:
isdata:
	mov [edi].REPLY_MAP_ADDR.wSeg,bx
	mov ecx,[esi].REQ_MAP_ADDR.dwOfs
	mov [edi].REPLY_MAP_ADDR.dwOfs, ecx
	call SetIntExc0E
	mov dwExcProc, offset error1
	cmp word ptr @flat:[edx],"ZM"
	jnz moddone
if ?DEBUGLEVEL
	invoke String2File, CStr("MZ found",13,10)
endif
	mov ecx,@flat:[edx+3Ch]
	add ecx,edx
	cmp word ptr @flat:[ecx],"EP"
	jz @F
	cmp word ptr @flat:[ecx],"LP"
	jz @F
	cmp word ptr @flat:[ecx],"XP"
	jnz moddone
@@:
if ?DEBUGLEVEL
	invoke String2File, CStr("PE/PX found",13,10)
endif
	movzx eax, @flat:[ecx].IMAGE_NT_HEADERS.FileHeader.NumberOfSections
	lea ebx, @flat:[ecx+IMAGE_NT_HEADERS]
	.if ( ax >= [esi].REQ_MAP_ADDR.wSeg )
		movzx eax, [esi].REQ_MAP_ADDR.wSeg
		dec eax
		mov edx, sizeof IMAGE_SECTION_HEADER
		mul edx
		add ebx, eax
		.if ( [ebx].IMAGE_SECTION_HEADER.Characteristics & IMAGE_SCN_CNT_CODE )
			mov eax, cs
		.else
			mov eax, ds
		.endif
		mov edx, [ebx].IMAGE_SECTION_HEADER.VirtualAddress
		add edx, [esi].REQ_MAP_ADDR.dwModule
		mov [edi].REPLY_MAP_ADDR.dwOfs, edx
		mov [edi].REPLY_MAP_ADDR.wSeg,ax
	.endif
if 0
	mov eax,@flat:[ecx].IMAGE_NT_HEADERS.OptionalHeader.BaseOfCode
	add eax,[esi].REQ_MAP_ADDR.dwModule
	mov [edi].REPLY_MAP_ADDR.lobounds,eax
	add eax,@flat:[ecx].IMAGE_NT_HEADERS.OptionalHeader.SizeOfImage
	dec eax
	mov [edi].REPLY_MAP_ADDR.hibounds,eax
else
	mov [edi].REPLY_MAP_ADDR.lobounds,0
	mov [edi].REPLY_MAP_ADDR.hibounds,-1
endif
error1:
moddone:
	call ResetIntExc0E
;
;Return to caller.
;
exit:
	popad
	mov ecx, incount
	mov esi, inaddr
	mov edi, outaddr
	ret
Request_Map_Addr endp

if ?V19
;*******************************************************************************
;
;Work out if specified address has big bit set.
;
;On Entry:
;
;ECX	- remaining request bytes.
;ESI	- current request data.
;EDI	- result buffer position.
;
;Returns:
;
;ECX,ESI & EDI updated.
;
;*******************************************************************************
; commented MED 1/20/2003
REQ_ADDR_INFO proc
	movzx eax,word ptr [esi+1+4]	; addr_info_req.req + addr_info_req.in_addr.segment
if ?RMDBGHLP
	cmp g_fRealMode,0
	jz isprotmode
	mov al,0	;X86AC_REAL
	jmp @@0info
isprotmode:
endif
	lar eax,eax
	jnz @F
	test eax,00400000h
	mov eax,X86AC_BIG
	jnz @@0info
@@:
	xor eax,eax
@@0info:
	mov [edi],al		; addr_info_ret.is_32
	inc edi 			; size of (addr_info_ret)
	add esi,1+6 		; sizeof (addr_info_req)
	sub ecx,1+6
	ret
REQ_ADDR_INFO endp
endif

;--- what is this proc for?
;--- the debuggee may have switched to 32bit protected mode
;--- so the real-mode CS and a 32-bit CS selector are address aliases.
;--- if this is the case, machine data requested for the real-mode CS
;--- should have the BIG bit set, else the WD debugger is very confused.

testrmcs proc
	cmp g_fRealMode,-1		;is debuggee in real-mode?
	jz @F					;then no BIG bit possible
	mov bx,Debuggee.cpu._Cs
	lar eax,ebx
	test eax,400000h			;is CS D bit set?
	jz @F					;no, nothing to do
	push ecx					;dont modify ECX, EDX	
	push edx
	mov ax,6				;get the base of CS
	@callint31
	push cx
	push dx
	pop eax					;linear address of CS -> EAX
	pop edx
	pop ecx
	test al,0Fh
	jnz @F					;cant be a real-mode segment
	shr eax,4
	movzx ebx,word ptr [esi+1+1+4]
	cmp eax,ebx
	jnz @F					;are both address aliases?
	or dl,X86AC_BIG
@@: 
	ret
testrmcs endp

;*******************************************************************************
; REQ_MACHINE_DATA processing, follows REQ_ADDR_INFO, MED 1/20/2003
;*******************************************************************************
; machine_data_req.req + 
; machine_data_req.info_type +
; machine_data_req.addr.segment
REQ_MACHINE_DATA struct
bReq		db ?
bInfo		db ?	;info type (is always 0?)
dwOfs		dd ?
wSeg		dw ?
REQ_MACHINE_DATA ends

REPLY_MACHINE_DATA struct
cache_start	dd ?
cache_end	dd ?
bFlags		db ?
REPLY_MACHINE_DATA ends

Request_Machine_Data proc
	movzx ebx,[esi].REQ_MACHINE_DATA.wSeg
if ?RMDBGHLP
	cmp g_fRealMode,0
	jz isprotmode
isrealmode:
if ?MDUSEINP
	shl ebx, 4
	mov eax, [esi].REQ_MACHINE_DATA.dwOfs
	add eax, ebx
	mov [edi].REPLY_MACHINE_DATA.cache_start,eax
	add eax, 65535
	mov [edi].REPLY_MACHINE_DATA.cache_end,eax
else
	xor eax, eax
	mov [edi].REPLY_MACHINE_DATA.cache_start,eax
	or eax,-1
	mov [edi].REPLY_MACHINE_DATA.cache_end,eax
endif
	mov dl,0
if 1
	call testrmcs
endif
if 0
	cmp g_fRealMode,0
	jnz @F
	or dl,X86AC_REAL
@@:
endif
	mov [edi].REPLY_MACHINE_DATA.bFlags,dl
	jmp done
isprotmode:
endif
	lar eax,ebx
	jnz isrealmode
	test eax,00400000h
	mov al,X86AC_BIG
	jnz gmdata
no32bit:
	mov al,0
gmdata:
	mov [edi].REPLY_MACHINE_DATA.bFlags,al
if ?MDUSEINP
	mov ax,6
	push ecx
	@callint31
	push cx
	push dx
	pop eax
	push [esi].REQ_MACHINE_DATA.dwOfs
	pop [edi].REPLY_MACHINE_DATA.cache_start
	add [edi].REPLY_MACHINE_DATA.cache_start,eax

	pop ecx
else
	xor eax,eax
	mov [edi].REPLY_MACHINE_DATA.cache_start,eax
endif
if ?MDUSEINP
	push ecx
	lar ecx, ebx
	jnz ulset
	lsl edx, ebx
	test ch, 08	;DATA?
	jnz @F
	test ch, 04	;expand down?
	jz @F
	or eax, -1
	jmp ulset
@@:
	add eax,edx
ulset:
	pop ecx
else
	dec eax
endif
	mov [edi].REPLY_MACHINE_DATA.cache_end, eax
done:
	add edi,sizeof REPLY_MACHINE_DATA
	add esi,sizeof REQ_MACHINE_DATA
	sub ecx,sizeof REQ_MACHINE_DATA
	ret
Request_Machine_Data endp

;--- read memory byte [esi] into BL

ReadMemory proc
if 0
	cmp g_bTerminated,0		;since exc 0E is NOT reported here
	jnz ReadMemory_1
endif
	cmp g_bIsNT,0			;on NT dont read debuggee memory
	jz @F					;after it has terminated
	cmp g_bTerminated,0		;since exc 0E is NOT reported here
	jz @F
	cmp esi,110000h			;conventional memory is ok
	jb @F
	cmp esi,[g_dwHelperStart]
	jb ReadMemory_11
	cmp esi,[g_dwHelperEnd]
	jae ReadMemory_11
@@:
	call SetIntExc0E
	mov dwExcProc, offset ReadMemory_1
	mov bl,@flatrd:[esi]
	call ResetIntExc0E
	ret
ReadMemory_1:
	call ResetIntExc0E
ReadMemory_11:
;	invoke String2File, CStr("ReadMemory error",13,10)
	stc
	ret
ReadMemory endp

;--- write memory byte BL to [ESI]

WriteMemory proc
	cmp g_bIsNT,0
	jz @F
	cmp g_bTerminated,0		;on NT dont write memory after termination
	jnz WriteMemory_11		;since exc 0E is NOT reported here
@@:
	call SetIntExc0E
	mov dwExcProc, offset WriteMemory_1
if ?FLAT
	cmp [g_flatsel],0
	jz @F
	mov es,[g_flatsel]
	xchg bl,es:[esi]
	push ds
	pop es
	jmp byte_written
@@:
endif
	xchg bl,@flat:[esi]
byte_written:
	call ResetIntExc0E
	ret
WriteMemory_1:
	call ResetIntExc0E
WriteMemory_11:
;	invoke String2File, CStr("WriteMemory error",13,10)
	stc
	ret
WriteMemory endp

;*******************************************************************************
;
;Check-sum some memory.
;
;On Entry:
;
;ECX	- remaining request bytes.
;ESI	- current request data.
;EDI	- result buffer position.
;
;Returns:
;
;ECX,ESI & EDI updated.
;
;*******************************************************************************
REQ_CHECKSUM_MEM proc
	push ecx
	mov bx,[esi+1+4]			;get selector.
	mov ax,6
	@callint31
	push cx
	push dx
	pop edx
	lsl ecx,ebx
	mov ebp,ecx
	pop ecx
	mov eax,0
	jc @@9mem
	movzx eax,word ptr [esi+1+6]	;get length.
	add eax,[esi+1] 			;include the offset.
	cmp eax,ebp
	jc @@1mem
	sub eax,ebp
	sub word ptr [esi+1+6],ax
	mov eax,0
	js @@0mem
	jz @@0mem
@@1mem:
	add edx,[esi+1] 			;get linear address.
	movzx ebp,word ptr [esi+1+6]	;get length.
	xor eax,eax
	xor ebx,ebx
	push esi
	mov esi,edx
@@0mem:
	call ReadMemory
	jc @@2mem
	add eax,ebx
	inc esi
	dec ebp
	jnz @@0mem
@@2mem:
	pop esi
@@9mem:
	mov [edi],eax				;store result.
	add edi,4
	add esi,1+6+2
	sub ecx,1+6+2
	ret
REQ_CHECKSUM_MEM endp

;--- read @flat:[esi] to es:[edi], ecx bytes

ReadFlatMemory proc
	push ds
if ?FLAT
	push cs
	pop ds
else
	push @flat
	pop ds
endif
	rep movsb
	pop ds
	ret
ReadFlatMemory endp

;--- write @flat:[edi] from ds:[esi], ecx bytes

WriteFlatMemory proc
	push es
if ?FLAT
else
	push @flat
	pop es
endif
	rep movsb
	pop es
	ret
WriteFlatMemory endp

;*******************************************************************************
;
;Read some memory.
;
;On Entry:
;
;ECX	- remaining request bytes.
;ESI	- current request data.
;EDI	- result buffer position.
;
;Returns:
;
;ECX,ESI & EDI updated.
;
;*******************************************************************************

REQ_READ_MEM struct
bReq	db ?
dwOfs	dd ?
wSeg	dw ?
wSize	dw ?
REQ_READ_MEM ends


Request_Read_Mem proc
	movzx ebx, [esi].REQ_READ_MEM.wSeg
if ?RMDBGHLP
	cmp g_fRealMode,0
	jz isprotmode
isrealmode:
	shl ebx, 4
	movzx edx, word ptr [esi].REQ_READ_MEM.dwOfs
	add ebx, edx
	push ecx
	push esi
	movzx ecx, [esi].REQ_READ_MEM.wSize
	mov esi, ebx
	call ReadFlatMemory
	pop esi
	pop ecx
	jmp done
isprotmode:
	lar eax,ebx
	jnz isrealmode
 if ?DPMI16         ; v1.5: handle "not present" segments
	test ah, 80h	; segment present?
	jnz @F
	push fs
	mov fs, ebx
	pop fs
 @@:
 endif
	verr bx
	jnz done
endif
	and bIsGDT,0
	push ecx
	mov ax,6
	@callint31
	push cx
	push dx
	pop edx
	pop ecx
	jnc isvalid
	cmp g_bIsNT,0		;on NT platforms dont touch such selectors
	jnz done
	or bIsGDT,-1
isvalid:
	lsl ebp,ebx
	lar eax,ebx
	and ah,0Ch
	cmp ah,04h					;expand down?
	jnz noed
	mov eax, [esi].REQ_READ_MEM.dwOfs
	cmp eax,ebp
	ja limitok
	jmp done
noed:
	movzx eax, [esi].REQ_READ_MEM.wSize
	add eax, [esi].REQ_READ_MEM.dwOfs
	cmp eax, ebp
;	jc limitok		;v1.5 ( include the last byte of the segment )
	jbe limitok
	sub eax, ebp
	test eax, 0FFFF0000h
	jnz @@0rmem
	sub [esi].REQ_READ_MEM.wSize, ax
	jc @@0rmem
	jz @@0rmem
limitok:
	cmp bIsGDT,-1
	jnz @F
	push fs
	mov fs, ebx
	mov edx,[esi].REQ_READ_MEM.dwOfs
	jmp isgdt
@@:
	add edx,[esi].REQ_READ_MEM.dwOfs
isgdt:
	pushs ecx,esi
	movzx ecx, [esi].REQ_READ_MEM.wSize
	mov esi,edx
	or ecx,ecx
@@2rmem:
	jz @@3rmem
	.if (bIsGDT == -1)
		call SetIntExc0E
		mov dwExcProc, offset @F
		stc
		mov bl,fs:[esi]
		clc
@@:
		pushfd
		call ResetIntExc0E
		popfd
		jc @@3rmem
	.else
		call ReadMemory
		jc @@3rmem
	.endif
	mov al,bl
	mov [edi],al
	inc esi
	inc edi
	dec ecx
	jmp @@2rmem
@@3rmem:
	pops ecx,esi
	cmp bIsGDT,-1
	jnz @F
	pop fs
@@:
@@0rmem:
done:
	add esi, sizeof REQ_READ_MEM
	sub ecx, sizeof REQ_READ_MEM
	ret
Request_Read_Mem endp


;*******************************************************************************
;
;Write some memory.
;
;On Entry:
;
;ECX	- remaining request bytes.
;ESI	- current request data.
;EDI	- result buffer position.
;
;Returns:
;
;ECX,ESI & EDI updated.
;
;*******************************************************************************
REQ_WRITE_MEM struct
bReq	db ?
dwOfs	dd ?
wSeg	dw ?
REQ_WRITE_MEM ends

Request_Write_Mem proc

	movzx ebx, [esi].REQ_WRITE_MEM.wSeg
if ?RMDBGHLP
	cmp word ptr [esi].REQ_WRITE_MEM.dwOfs+2,0	;HIWORD of addr != 0?
	jnz isprotmode2
	cmp g_fRealMode,0
	jz isprotmode
isrealmode:
	shl ebx, 4
	mov edx, [esi].REQ_WRITE_MEM.dwOfs
	add esi, sizeof REQ_WRITE_MEM
	sub ecx, sizeof REQ_WRITE_MEM
	mov eax,ebx
	or eax,edx		;is is 0000:0000? (comes from invalid mapping)
	jz write_err
	add ebx, edx
	push edi
	mov edi, ebx
	call WriteFlatMemory
	mov eax, edi
	sub eax, ebx
	pop edi
	jmp done
isprotmode:
	lar eax,ebx
	jnz isrealmode
isprotmode2:
endif
	push ecx
	mov ax,6
	@callint31
	push cx
	push dx
	pop edx
	pop ecx
	jc write_err
	lsl ebp,ebx
	lar eax,ebx
	and ah,0Ch
	cmp ah,04h					;expand down?
	jnz noed
	mov eax, [esi].REQ_WRITE_MEM.dwOfs
	cmp eax,ebp
	ja limitok
	jmp write_err
noed:
	mov eax,ecx 		;get length.
	sub eax, sizeof REQ_WRITE_MEM
	add eax,[esi].REQ_WRITE_MEM.dwOfs
	cmp eax,ebp
;	jc limitok		;v1.5 include the last byte
	jbe limitok
	sub eax,ebp
	sub ecx,eax
	js write_err
	jz write_err
limitok:
	add edx,[esi].REQ_WRITE_MEM.dwOfs
	push edi
	mov edi,edx
	add esi, sizeof REQ_WRITE_MEM	;let esi point to the data to write
	sub ecx, sizeof REQ_WRITE_MEM
	xor eax,eax
	xchg esi,edi
nextitem:
	jecxz write_done
	mov bl,[edi]
	call WriteMemory
	inc esi
	inc edi
	inc eax
	dec ecx
	jmp nextitem
write_done:
	xchg esi,edi
	pop edi
	jmp done
write_err:
	add esi, ecx
	xor eax, eax
done:
	mov [edi],ax
	add edi,2
	xor ecx,ecx
	ret
Request_Write_Mem endp

;*******************************************************************************
;
;Read from I/O port.
;
;On Entry:
;
;ECX	- remaining request bytes.
;ESI	- current request data.
;EDI	- result buffer position.
;
;Returns:
;
;ECX,ESI & EDI updated.
;
;*******************************************************************************
REQ_READ_IO proc
	inc esi
	lodsd
	mov edx, eax			   ;get I/O port.
	lodsb
	cmp al,1
	jz @@byteio
	cmp al,2
	jz @@wordio
	cmp al,4
	jz @@dwordio
	jmp @@9io
;
@@byteio:
	in al,dx
	stosb
	jmp @@9io
;
@@wordio:
	in ax,dx
	stosw
	jmp @@9io
;
@@dwordio:
	in eax,dx
	stosd
;
@@9io:
	sub ecx,1+4+1
	ret
REQ_READ_IO endp


;*******************************************************************************
;
;Write to I/O port.
;
;On Entry:
;
;ECX	- remaining request bytes.
;ESI	- current request data.
;EDI	- result buffer position.
;
;Returns:
;
;ECX,ESI & EDI updated.
;
;*******************************************************************************
REQ_WRITE_IO proc
	inc esi
	lodsd
	mov edx,eax 			;get I/O address.
	sub ecx,5
	cmp ecx,1
	jz @@bytewio
	cmp ecx,2
	jz @@wordwio
	cmp ecx,4
	jz @@dwordwio
	xor al,al
	jmp @@9wio
;
@@bytewio:
	lodsb
	out dx,al
	mov al,1
	jmp @@9wio
;
@@wordwio:
	lodsw
	out dx,ax
	mov al,2
	jmp @@9wio
;
@@dwordwio:
	lodsd
	out dx,eax
	mov al,4
;
@@9wio:
	stosb
	xor ecx,ecx
	ret
REQ_WRITE_IO endp


if 1;?V19
;*******************************************************************************
;
;Get main CPU register contents.
;
;On Entry:
;
;ECX	- remaining request bytes.
;ESI	- current request data.
;EDI	- result buffer position.
;
;Returns:
;
;ECX,ESI & EDI updated.
;
;*******************************************************************************
REQ_READ_CPU proc
	local	@@incount:DWORD,@@inaddr:DWORD,@@outaddr:DWORD

	pushad
;
	inc esi 			;skip REQ_READ_CPU
	dec ecx
;
	mov @@incount,ecx
	mov @@inaddr,esi

	smsw ax
if ?RMDBGHLP
	cmp g_fRealMode,0
	jz @F
	and al,0FEh
@@:
endif
	mov word ptr Debuggee.cpu._Cr0,ax
;
;Copy CPU register values.
;
	mov esi,offset Debuggee.cpu
	mov ecx,sizeof trap_cpu_regs
	rep movsb
	mov @@outaddr,edi
;
	popad
	mov ecx,@@incount
	mov esi,@@inaddr
	mov edi,@@outaddr
	ret
REQ_READ_CPU endp
;*******************************************************************************
;
;Get FPU register contents.
;
;On Entry:
;
;ECX	- remaining request bytes.
;ESI	- current request data.
;EDI	- result buffer position.
;
;Returns:
;
;ECX,ESI & EDI updated.
;
;*******************************************************************************
REQ_READ_FPU proc

local @@incount:DWORD
local @@inaddr:DWORD
local @@outaddr:DWORD

	pushad
;
	inc esi 			;skip REQ_READ_FPU
	dec ecx
;
	mov @@incount,ecx
	mov @@inaddr,esi

	call clearfpuemu
;
;Get FPU register value.

;
	test [dwFeatures],1 shl 24
	jz no_fxsave
	mov edx, esp
	sub esp,512
	and esp, not 15
	.686
	.xmm
if ?FLAT
	mov esi, esp
else
	movzx esi, sp
endif
	fxsave [esi]
	fnsave [edi]
	.486
	add esi, sizeof fxsav_ctrl + 8 * 16
	add edi, sizeof x86_fpu
	mov ecx, 8*16/4
	rep movsd
if ?FLAT
	mov eax,[esp].fxsav_ctrl.mxcsr
else
	movzx eax,sp
	mov eax,ss:[eax].fxsav_ctrl.mxcsr
endif
	stosd
	mov esp, edx
	jmp fpu_done
no_fxsave:
	fnsave [edi]
	frstor [edi]
	fwait
	add edi,sizeof x86_fpu
fpu_done:
	mov @@outaddr,edi

	call restorefpuemu
;
	popad
	mov ecx,@@incount
	mov esi,@@inaddr
	mov edi,@@outaddr
	ret
REQ_READ_FPU endp


;*******************************************************************************
;
;Set main CPU register contents.
;
;On Entry:
;
;ECX	- remaining request bytes.
;ESI	- current request data.
;EDI	- result buffer position.
;
;Returns:
;
;ECX,ESI & EDI updated.
;
;*******************************************************************************
REQ_WRITE_CPU proc
;
	inc esi 			;skip REQ_WRITE_CPU
	dec ecx
;
;Copy CPU register values.
;
	pushs ecx,edi
	mov edi,offset Debuggee.cpu
	mov ecx,sizeof trap_cpu_regs
	rep movsb
	pops ecx,edi
;
	sub ecx,sizeof trap_cpu_regs
	ret
REQ_WRITE_CPU endp


;*******************************************************************************
;
;Set FPU register contents.
;
;On Entry:
;
;ECX	- remaining request bytes.
;ESI	- current request data.
;EDI	- result buffer position.
;
;Returns:
;
;ECX,ESI & EDI updated.
;
;*******************************************************************************
REQ_WRITE_FPU proc
;
	inc esi 			;skip REQ_WRITE_FPU
	dec ecx

	call clearfpuemu
;
;Set FPU register values.
;
	frstor [esi]
;	fwait
	add esi, sizeof x86_fpu
	sub ecx, sizeof x86_fpu

	test [dwFeatures],1 shl 24
	jz fpu_done
	push edi
	push ecx
ife ?FLAT
	push ebp
endif
	mov edx, esp
	sub esp, 512
	and esp, not 15   ;FXRSTOR buffer must be 16-byte aligned
	.686
	.xmm
if ?FLAT
	fxsave [esp]
	lea edi, [esp + sizeof fxsav_ctrl + 8*16]
else
	movzx ebp,sp
	fxsave [ebp]
	lea edi, [ebp + sizeof fxsav_ctrl + 8*16]
endif
	mov ecx, 8*16 / 4
	rep movsd
	lodsd
if ?FLAT
	mov [esp].fxsav_ctrl.mxcsr,eax
	fxrstor [esp]
else
	mov [ebp].fxsav_ctrl.mxcsr,eax
	fxrstor [ebp]
endif
	.486
	mov esp, edx
ife ?FLAT
	pop ebp
endif
	pop ecx
	pop edi
	sub ecx, sizeof x86_xmm
fpu_done:

	call restorefpuemu
;
	ret
if 0
;--- convert the FSAVE format to FXSAVE
convert:
	mov eax,[esi].x86_fpu.fcw
	mov [edi].fxsav_ctrl.fcw, ax
	mov eax,[esi].x86_fpu.fsw
	mov [edi].fxsav_ctrl.fsw, ax

;	mov ecx,eax
;	shr cx, 10  ;mov TOP to 1-3
;	and cl, 00001110b
	mov ebx,[esi].x86_fpu.ftw
;	ror bx, cl  ;now the bits are in the correct position for fxrstor
	mov cl,8
	xor al,al
@@:
	mov ah,3
	and ah,bl
	cmp ah,3
	setnz ah
	or al,ah
	ror bx,2
	ror al,1
	dec cl
	jnz @B

	mov ah,0
	mov [edi].fxsav_ctrl.ftw, ax
	mov ax,[esi].x86_fpu.fop
	mov [edi].fxsav_ctrl.fop,ax
	mov eax,[esi].x86_fpu.fip
	mov [edi].fxsav_ctrl.fip,eax
	movzx eax,[esi].x86_fpu.fcs
	mov [edi].fxsav_ctrl.fcs,eax
	mov eax,[esi].x86_fpu.fdp
	mov [edi].fxsav_ctrl.fdp,eax
	mov eax,[esi].x86_fpu.fds
	mov [edi].fxsav_ctrl.fds,eax
	retn
endif
REQ_WRITE_FPU endp

endif

;*******************************************************************************
; REQ_READ_REGS processing, follows REQ_READ_CPU, MED 1/20/2003
;*******************************************************************************
REQ_READ_REGS proc
	call REQ_READ_CPU
	dec esi
	inc ecx
	call REQ_READ_FPU
	ret
REQ_READ_REGS endp


;*******************************************************************************
; REQ_WRITE_REGS processing, follows REQ_WRITE_CPU, MED 1/20/2003
;*******************************************************************************
REQ_WRITE_REGS proc
	call REQ_WRITE_CPU
	dec esi
	inc ecx
	call REQ_WRITE_FPU
	ret
REQ_WRITE_REGS endp

;--- this is to overcome a WD restriction.
;--- it helps WD to determine that a soft break has been hit
;--- EDI -> return buffer for REQ_PROG_GO/REQ_PROG_STEP

PROG_GO_RET struct
dwEsp dd ?
wSS   dw ?
dwEip dd ?
wCS   dw ?
wCond dw ?
PROG_GO_RET ends


CheckForBreakHits proc uses ecx
	cmp BreakFlag,0	;was it an int 03?
	jz done
	mov bx, [edi].PROG_GO_RET.wCS
	cmp g_fRealMode,0
	jnz isrealmode
	mov ax, 6
	@callint31
	push cx
	push dx
	pop edx
	jmp cont_1
isrealmode:
	movzx edx, bx
	shl edx, 4
cont_1:
	add edx, [edi].PROG_GO_RET.dwEip
	call FindBreakInTable
	jc done
	mov [edi].PROG_GO_RET.dwEip, eax
	mov [edi].PROG_GO_RET.wCS, dx
done:
	ret
CheckForBreakHits endp

REQ_PROG_GO:
	xor eax, eax
	jmp RunProg

REQ_PROG_STEP:
	mov eax, 1
	jmp RunProg

;*******************************************************************************
;
;Run the program.
;
;On Entry:
;
;EAX    - 0 or 1.
;ECX    - remaining request bytes.
;ESI    - current request data.
;EDI    - result buffer position.
;
;Returns:
;
;ECX,ESI & EDI updated.
;
;*******************************************************************************

RunProg proc
	local @@result:DWORD

	inc esi
	dec ecx 			;skip REQ_PROG_GO
	pushad
;
	call Execute		;expects eax=0 (go) or 1 (single-step)
	mov @@result,eax
;
	popad
	mov eax, Debuggee.cpu._Esp
	mov [edi].PROG_GO_RET.dwEsp, eax
	mov ax, Debuggee.cpu._Ss
	mov [edi].PROG_GO_RET.wSS, ax
	mov eax, Debuggee.cpu._Eip
	mov [edi].PROG_GO_RET.dwEip, eax
	mov ax, Debuggee.cpu._Cs
	mov [edi].PROG_GO_RET.wCS, ax
	call CheckForBreakHits
	mov eax, @@result
	mov [edi].PROG_GO_RET.wCond, ax
	add edi, sizeof PROG_GO_RET
	ret
RunProg endp

if ?DJGPP

CheckDjgpp proc

local Hdr[40h]:byte

	mov g_bIsDjgpp,0
	mov edx,offset ProgName
	mov ax,3D00h
	int 21h
	jc exit
	mov ebx,eax
	lea edx,Hdr
	mov ecx,sizeof Hdr
	mov ax,3F00h
	int 21h
	jc done
	cmp eax,ecx
	jnz done
	cmp word ptr [edx],"ZM"
	jnz done
	cmp dword ptr [edx+2], 40000h
	jnz done
	mov cx,0
	mov dx,800h
	mov ax,4200h
	int 21h
	jc done
	lea edx,Hdr
	mov ecx,2
	mov ax,3F00h
	int 21h
	jc done
	cmp eax,ecx
	jnz done
	cmp word ptr [edx],14Ch
	jnz done
	mov g_bIsDjgpp,-1
done:
	mov ah,3Eh
	int 21h
exit:
	ret
CheckDjgpp endp

endif

;*******************************************************************************
;
;Load a program ready for debugging.
;
;On Entry:
;
;ECX	- remaining request bytes.
;ESI	- current request data.
;EDI	- result buffer position.
;
;Returns:
;
;ECX,ESI & EDI updated.
;
;*******************************************************************************

REPLY_PROG_LOAD struct
dwError		dd ?
dwTask		dd ?
dwModule	dd ?
bFlags		db ?
REPLY_PROG_LOAD ends

REQ_PROG_LOAD proc
	local @@incount:DWORD,@@inaddr:DWORD,@@outaddr:DWORD
	local dwOldLdrBits:dword

	xor eax,eax
	mov [edi].REPLY_PROG_LOAD.dwError, eax	;MSG_9
	mov [edi].REPLY_PROG_LOAD.dwTask, eax
	mov [edi].REPLY_PROG_LOAD.dwModule, eax
	mov @@outaddr,edi

;
	inc esi 			;skip REQ_PROG_LOAD
	dec ecx
;
	inc esi
	dec ecx 			;skip argv flag
;
;Get the program name.
;

	mov edi,offset ProgName
@@:
	lodsb
	stosb
	and al,al
	loopnz @B
;
;Get the command line.
;
	mov edi,offset ProgCommand+1
	jecxz @@2load
@@:
	lodsb
	stosb
	and al,al
	loopnz @B
	jecxz @@2load
	mov byte ptr [edi-1]," "
	jmp @B
@@2load:
	mov byte ptr [edi],13
@@5load:
	sub edi,offset ProgCommand+1
	mov eax,edi
	mov ProgCommand,al	;set command line length.
	mov @@incount,ecx
	mov @@inaddr,esi

	cmp ProgName,0		;program name 0?
	jz load_done

	mov DebugModule, 0	;reset the module handle

	call forceexc01supply

if ?FLAT or ?NE
;--- this call changes DPMILDR variable in DPMILD32
;--- obsolete [bit 0=1 is to make DPMILD16/32 call the debugger with CS:EIP in CX:EBX]
;--- bit 3=0 is to make current DPMILD16/32 handle int 21h, ax=4B00h
;--- bit 4=1 is to prevent DPMILD32 from protecting r/o sections
;   mov cx,0019h	;mask for bits to change
;   mov dx,0011h	;values for these bits
	mov cx,0018h	;mask for bits to change
	mov dx,0010h	;values for these bits
	mov ax,4b94h	;set DPMILDR variable
	@callint21
	mov dwOldLdrBits, eax
	.if (!g_bLoader)
		mov bl,0		;disable loader
		mov ax,4b91h	;set DPMILDR variable
		@callint21
	.endif
endif


if ?DJGPP
	call CheckDjgpp
	cmp g_bIsDjgpp,0	;is it a DJGPP app
	jnz loadpmapp		;then dont trap int 21 rm
endif

	call traprm21	;trap int 21h in real mode

loadpmapp:
;
;Load the program ready for debugging.
;
	mov edx,offset ProgName
	mov ebx,offset execpb
if ?DPMI16
	mov [ebx].EXECPM.environ,0
	mov eax, offset ProgCommand
	mov word ptr [ebx].EXECPM.cmdline+0, ax
	mov word ptr [ebx].EXECPM.cmdline+2, ds
	mov eax, g_psp
	mov word ptr [ebx].EXECPM.fcb1+0,5Ch
	mov word ptr [ebx].EXECPM.fcb1+2,ax
	mov word ptr [ebx].EXECPM.fcb2+0,6Ch
	mov word ptr [ebx].EXECPM.fcb2+2,ax
	push 0
	pop @flat
else
	mov dword ptr [ebx].EXECPM.cmdline+0, offset ProgCommand
	mov dword ptr [ebx].EXECPM.cmdline+4, ds
	mov eax, g_psp
	mov dword ptr [ebx].EXECPM.fcb1+0,5Ch
	mov dword ptr [ebx].EXECPM.fcb1+4,eax
	mov dword ptr [ebx].EXECPM.fcb2+0,6Ch
	mov dword ptr [ebx].EXECPM.fcb2+4,eax
endif
	push ds
	mov ds,eax
	and byte ptr ds:[4Fh],not 80h	;reset "rm/pm" bit in PSP 
	pop ds

	invoke String2File, CStr("before int 21h, ax=4b00",13,10)

	push ebp
	push offset backload
	mov word ptr [DebuggerSS],ss
	mov dword ptr [DebuggerESP],esp
	mov g_bTerminated,0
	mov ExceptionFlag,-1
	mov bExecuting,1+2
if ?DPMI16
	movzx eax,ax
	movzx ecx,cx
	movzx ebx,bx
	movzx edx,dx
	movzx esi,si
	movzx edi,di
endif
	xor ebp, ebp
	mov esp,offset loadstack
	mov ax,4b00h
	int 21h
after_loadcall:
	jc load_error1
	test bExecuting,2		;could not stop in debuggee
	jnz load_error2
	or g_bTerminated,-1
	mov g_fRealMode,0
	invoke String2File, CStr("after int 21h, ax=4b00",13,10)
if ?DPMI16
	pushf
	push eax
	mov eax,cs
	shl eax,16
	mov ax,lowword offset after_loadcall
	push bp
	mov bp,sp
	xchg eax,[bp+2]
	pop bp
else
	pushfd
	push cs
	push offset after_loadcall
endif
	jmp Int01HandlerEx

;--- the debuggee returned. this may be because of:
;--- + the real-mode handler has caught an int 21h, ax=4B00h
;--- + int 41h, ax=F003h indicating a PE app has been loaded
;---   this is signaled by an int 01
;--- + int 41h, ax=0040h indicating a NE app has been loaded (16/32bit)
;---   this is signaled by an int 01
;--- + a breakpoint in a dll (PE or NE)
;--- + an exception in protected-mode occured
;--- + an exception in real-mode occured

backload:
	pop ebp
	mov ah,62h
	@callint21
	movzx ebx,bx
	mov [DebugPSP],ebx
	mov eax, ebx	;for real mode debuggees PSP is module handle
	mov g_fPrevDef,0
	mov cl,g_fRealMode
	mov g_fPrevMode,cl
	cmp cl,0
	jnz setmodule
	mov bx,Debuggee.cpu._Cs
	lar ecx,ebx
	test ecx,400000h
	setnz cl
	mov g_fPrevDef,cl


;--- v1.5: there was a problem with handling of int 21h, ax=4b94h in dpmildr < v3.11:
;--- PSP/ENV of debuggee weren't released if the DPMILDR=8 flag was modified.
ife ?DPMI16

	mov ax,6
	@callint31
	push cx
	push dx
	pop eax
	and eax,eax
	jnz isnoPE

	mov cx,8			;mask for bits to change
	mov edx,dwOldLdrBits;values for these bits
	mov ax,4b94h
	int 21h

	xor edx,edx
	mov ax,4B82h	;getmodulehandle
	int 21h			;use int instruction here! @callint21
	jc @F
	and eax, eax	;is there a PE module attached to this task?
	jnz setmodule
@@:
	mov eax,[DebugPSP]
	jmp setmodule
isnoPE:
	mov dx,Debuggee.cpu._Cs
	mov cl,1
	mov ax,4b88h	;call DPMILD32 to get module handle in AX
	int 21h			;use int instruction here! @callint21
	jc no_module 
	movzx eax,ax
else
	mov eax,DebugModule
endif
setmodule:
	mov [DebugModule],eax
no_module:
	invoke String2File, CStr("debuggee loaded",13,10)
	cmp g_fRealMode, 0
	jz @F
	invoke String2File, CStr("debuggee in real-mode",13,10)
	call noclone
@@:
;
;Setup results.
;
	mov edi, @@outaddr
	mov [edi].REPLY_PROG_LOAD.dwError, 0
	mov [edi].REPLY_PROG_LOAD.bFlags, LD_FLAG_DISPLAY_DAMAGED
	mov eax, DebugPSP
	mov edx, DebugModule
	mov [edi].REPLY_PROG_LOAD.dwTask, eax
	mov [edi].REPLY_PROG_LOAD.dwModule, edx
	cmp eax, g_psp
	jnz @F
	invoke String2File, CStr("*** error: psp is still trap helper psp!",13,10)
@@:
	cmp ExceptionFlag,-1
	jz @F
	invoke String2File, CStr("*** error: exception occured during program load!",13,10)
@@:
	cmp g_fRealMode,-1
	jz load_done
if ?DJGPP
	cmp g_bIsDjgpp,-1
	jnz @F
	or [edi].REPLY_PROG_LOAD.bFlags, LD_FLAG_IS_PROT or LD_FLAG_IS_32
	jmp load_done
@@:
endif
if ?DPMI16
	or [edi].REPLY_PROG_LOAD.bFlags, LD_FLAG_IS_PROT or LD_FLAG_HAVE_RUNTIME_DLLS
else
	or [edi].REPLY_PROG_LOAD.bFlags, LD_FLAG_IS_PROT or LD_FLAG_HAVE_RUNTIME_DLLS or LD_FLAG_IS_32
endif
	jmp load_done
load_error2:
	mov eax,MSG_7
	jmp load_error
load_error1:
	invoke Word2Ascii, eax, offset LoadErrCode
	mov eax,MSG_8
load_error:
	lss esp, fword ptr [DebuggerESP]
	pop ebp				;throw away the return address
	pop ebp
	mov edi,@@outaddr
	mov [edi].REPLY_PROG_LOAD.dwError, eax
	invoke SetErrorText, eax

	invoke String2File, CStr("error occured in int 21h, ax=4b00: ")
	invoke DWord2File, eax
	invoke String2File, CStr(13,10)
;
;Return results to caller.
;
load_done:
	mov edi, @@outaddr
	add edi, sizeof REPLY_PROG_LOAD
	mov ecx, @@incount
	mov esi, @@inaddr
	ret
noclone:
	push es
	mov esi, CStr("HDPMI")
	mov ax, 168ah
	int 2Fh
	cmp al,0
	jnz @F
	mov ax, 5
	mov bl, 0
ife ?DPMI16
	push es
	push edi
	call fword ptr [esp]
	add esp,4+4
else
	push es
	push di
	mov di, sp 
	call far16 ptr ss:[di]
	add esp,2+4
endif
@@:
	pop es
	retn
	
REQ_PROG_LOAD endp

cmppsps proc
	mov ax,6
	@callint31
	push cx
	push dx
	mov ebx,DebugPSP
	mov ax,6
	@callint31
	push cx
	push dx
	pop eax
	pop ecx
	cmp eax,ecx
	ret
cmppsps endp
;*******************************************************************************
;
;Lose a program loaded for debugging.
;
;On Entry:
;
;ECX	- remaining request bytes.
;ESI	- current request data.
;EDI	- result buffer position.
;
;Returns:
;
;ECX,ESI & EDI updated.
;
;*******************************************************************************
REQ_PROG_KILL struct
bReq		db ?
dwTask		dd ?
REQ_PROG_KILL ends

Request_Prog_Kill proc
	pushad
	invoke String2File, CStr("REQ_PROG_KILL enter, current PSP=")
	invoke DWord2File, DebugPSP
	invoke String2File, CStr(13,10)
	cmp g_bTerminated,-1	;already terminated?
;	stc						;dont report this as error
	jz label2
	mov ebx,[esi].REQ_PROG_KILL.dwTask
	and ebx, ebx
;	stc						;dont report this as error
	jz label2
	invoke cmppsps
	stc
	jnz label2
if ?RMDBGHLP
	cmp g_fRealMode,0		;debuggee in realmode?
	jz isprotmode
	push ds
	mov ds,DebugPSP
	test byte ptr ds:[4Fh],80h	;is PSP "protected mode"?
	pop ds
	jnz isprotpsp
	mov edx,g_dwRMAddr		;debuggee is a true real-mode app
	movzx ecx, @flat:[edx].DEBRMVAR.wCancelRM
	mov Debuggee.cpu._Eip,ecx
	shr edx,4
	mov Debuggee.cpu._Cs,dx
	jmp do_kill
isprotpsp:						;debuggee is a pm app currently in real-mode
	mov Debuggee.cpu._Ss,ds
if ?DPMI16
	movzx eax,sp
	lea eax,[eax-100h]
else
	lea eax,[esp-100h]
endif
	mov Debuggee.cpu._Esp,eax
	xor eax,eax
	mov Debuggee.cpu._Ds,ax
	mov Debuggee.cpu._Es,ax
	mov Debuggee.cpu._Fs,ax
	mov Debuggee.cpu._Gs,ax
	mov g_fRealMode, 0
isprotmode:
endif
	mov Debuggee.cpu._Cs,cs
	mov Debuggee.cpu._Eip, offset terminate
do_kill:
	xor eax,eax 		;set code for GO.
	call Execute
	mov DebugPSP, 0
	invoke String2File, CStr("REQ_PROG_KILL: debuggee killed",13,10)
	clc
label2:
	popad
	mov dword ptr [edi],0
	jnc @@0kill
	mov dword ptr [edi], MSG_4
	invoke SetErrorText, MSG_4
	invoke String2File, CStr("REQ_PROG_KILL: error detected, debuggee not killed",13,10)
@@0kill:
	add esi,sizeof REQ_PROG_KILL
	sub ecx,sizeof REQ_PROG_KILL
	add edi,4
;
;Reset the timer if required.
;
if 0
	cmp ResetTimer,0
	jz @@1kill
	pushad
	or eax,-1
	call LoadTimer
	popad
;
@@1kill: 
endif
	ret

terminate:
	mov ax,4cffh
	int 21h
Request_Prog_Kill endp


;*******************************************************************************
;
;Set a watch point.
;
;On Entry:
;
;ECX	- remaining request bytes.
;ESI	- current request data.
;EDI	- result buffer position.
;
;Returns:
;
;ECX,ESI & EDI updated.
;
;*******************************************************************************
REQ_SET_WATCH proc
;
;Check if size is OK for HBRK
;
	cmp g_bIsNT,0				;no HW breaks for NT platforms!
	jnz @@3watch		
	cmp byte ptr [esi+1+6],1
	jz @@0watch
	cmp byte ptr [esi+1+6],2
	jz @@0watch
	cmp byte ptr [esi+1+6],4
	jnz @@3watch
;
;Size is OK so see if we can find a free entry.
;
@@0watch:
	mov ebx,offset HBRKTable
	mov ebp,4
@@1watch:
	test [ebx].HBRK.HBRK_Flags,1	;free?
	jz @@2watch
	add ebx,size HBRK
	dec ebp
	jnz @@1watch
	jmp @@3watch				;have to be software watch then.
;
;Fill in hardware break point details.
;
@@2watch:
	mov [ebx].HBRK.HBRK_Flags,1 	  ;mark it in use.
	mov dx,[esi+1+4]			;get selector.
if ?RMDBGHLP
	cmp g_fRealMode,0
	jz isprotmode
	movzx edx,dx
	shl edx,4
	jmp cont_1
isprotmode:
endif
	pushs ebx,ecx
	mov ebx,edx
	mov ax,6
	@callint31
	push cx
	push dx
	pop edx
	pops ebx,ecx
	jc @@7watch					;is wrong error code currently
cont_1:
	add edx,[esi+1] 				  ;include offset.
	mov [ebx].HBRK.HBRK_Address,edx   ;set linear address of break.
	mov al,[esi+1+6]
	mov [ebx].HBRK.HBRK_Size,al 	  ;set break point size.
	mov [ebx].HBRK.HBRK_Type,1		  ;set type to write.
	mov dword ptr [edi],0			  ;clear error field.
	add edi,4
	mov dword ptr [edi],10+(1 shl 31)
	add edi,4
	add esi,1+6+1
	sub ecx,1+6+1
	jmp @@9watch
;
;OK, either the size won't work for a HBRK or all HBRK's are in use so set up
;a software WATCH.
;
@@3watch:
	cmp NumWatches, NUMWATCH	;all watches in use?
	jnz @@4watch
	;
	;No more watches either so return an error.
	;
@@7watch:
	add esi,1+6+1
	sub ecx,1+6+1
	mov dword ptr [edi], MSG_5
	add edi,4
	mov dword ptr [edi],0
	add edi,4
	invoke SetErrorText, MSG_5
	jmp @@9watch
;
;Must be a free WATCH entry so find it.
;
@@4watch:
	mov ebx, offset WatchTable
	mov ebp, NUMWATCH
@@5watch:
	test [ebx].WATCH.WATCH_Flags,1
	jz @@6watch
	add ebx,size WATCH
	dec ebp
	jnz @@5watch
	jmp @@7watch				;can't happen but...
;
;Found next free WATCH so fill in the details.
;
@@6watch:
	mov [ebx].WATCH.WATCH_Flags,1
	pushs ebx,ecx
	mov bx,[esi+1+4]			;get selector.
if ?RMDBGHLP
	cmp g_fRealMode,0
	jz isprotmode2
	movzx edx,bx
	shl edx,4
	jmp cont_2
isprotmode2:
endif
	mov ax,6
	@callint31
	push cx
	push dx
	pop edx
	pops ebx,ecx
cont_2:
	add edx,[esi+1] 			;include offset.
	mov [ebx].WATCH.WATCH_Address,edx  ;set linear address of WATCH.
	xor eax,eax
	mov al,[esi+1+6]
	mov [ebx].WATCH.WATCH_Length,eax   ;set WATCH length.
	;
	;Need to setup checksum.
	;
	call SetIntExc0E
	pushs esi,edi
	mov dwExcProc, offset acc_err
	xor edi,edi
	mov esi,eax
	xor eax,eax
@@8watch:
	mov al,@flat:[edx]
	add edi,eax
	inc edx
	dec esi
	jnz @@8watch
	mov eax,edi
acc_err:
	pops esi,edi
	mov [ebx].WATCH.WATCH_Check,eax    ;set check-sum.
	call ResetIntExc0E
;
	inc NumWatches				;update WATCH count.
;
;set return details.
;
	mov dword ptr [edi],0				 ;clear error field.
	add edi,4
	mov dword ptr [edi],5000			 ;copy DOS4GW slow down value.
	add edi,4
	add esi,1+6+1
	sub ecx,1+6+1
;
;Return to caller.
;
@@9watch:
	ret
REQ_SET_WATCH endp


;*******************************************************************************
;
;Clear a watch point.
;
;On Entry:
;
;ECX    - remaining request bytes.
;ESI    - current request data.
;EDI    - result buffer position.
;
;Returns:
;
;ECX,ESI & EDI updated.
;
;*******************************************************************************
REQ_CLEAR_WATCH proc
;
;Get the linear address ready for comparison.
;
	mov bx,[esi+1+4]			;get selector.
if ?RMDBGHLP
	cmp g_fRealMode,0
	jz isprotmode
	movzx edx,bx
	shl edx,4
	jmp cont_1
isprotmode:
endif
	push ecx
	mov ax,6
	@callint31
	push cx
	push dx
	pop edx
	pop ecx
	jc done
cont_1:
	add edx,[esi+1] 			;include offset.
	xor eax,eax
	mov al,[esi+1+6]			;get size.
;
;Check all HBRK's
;
	mov ebx,offset HBRKTable
	mov ebp,4
@@3cwatch:
	test [ebx].HBRK.HBRK_Flags,1 	  ;in use?
	jz @@4cwatch
	cmp edx,[ebx].HBRK.HBRK_Address   ;right address?
	jnz @@4cwatch
	cmp al,[ebx].HBRK.HBRK_Size 	  ;right size?
	jnz @@4cwatch
	mov [ebx].HBRK.HBRK_Flags,0 	  ;free this entry.
	jmp @@2cwatch
@@4cwatch:
	add ebx,size HBRK
	dec ebp
	jnz @@3cwatch
;
;Check all WATCH's.
;
	cmp NumWatches,0			;no point if no WATCH's in use.
	jz @@2cwatch
	mov ebx, offset WatchTable
	mov ebp, NUMWATCH
@@0cwatch:
	test [ebx].WATCH.WATCH_Flags,1	   ;in use?
	jz @@1cwatch
	cmp edx,[ebx].WATCH.WATCH_Address  ;right address?
	jnz @@1cwatch
	cmp eax,[ebx].WATCH.WATCH_Length   ;right length?
	jnz @@1cwatch
	mov [ebx].WATCH.WATCH_Flags,0	   ;clear WATCH.
	dec NumWatches				;update number of WATCH's.
	jmp @@2cwatch
@@1cwatch:
	add ebx,size WATCH
	dec ebp
	jnz @@0cwatch
;
@@2cwatch:
done:
	add esi,1+6+1
	sub ecx,1+6+1
	ret
REQ_CLEAR_WATCH endp

;--- since WD has problems to determine if a break has been hit
;--- we must help him. For this we have to save all breaks WD will set

;--- edx = linear address of break
;--- [esi+4] = segment/selector
;--- [esi+0] = offset
;--- al: 0=prot-mode, 2 = real-mode

AddBreakToTable proc
	pushad
	mov ebx, offset SoftBrkTable
	mov ecx, NUMSBREAK
	.while (ecx)
		test [ebx].SBREAK.wFlags,1	;is free?
		jnz @F
		mov [ebx].SBREAK.dwAddr,edx
		mov edx,[esi+0]
		mov [ebx].SBREAK.dwOffs,edx
		mov dx,[esi+4]
		mov [ebx].SBREAK.wSeg,dx
		or al,1
		mov ah,0
		mov [ebx].SBREAK.wFlags,ax
		.break
@@:
		add ebx, sizeof SBREAK
		dec ecx
	.endw
	popad
	ret
AddBreakToTable endp

;--- remove the first break matching linear address in edx

RemoveBreakFromTable proc
	pushad
	mov ebx, offset SoftBrkTable
	mov ecx, NUMSBREAK
	.while (ecx)
		test [ebx].SBREAK.wFlags,1	;is free?
		jz @F
		cmp edx, [ebx].SBREAK.dwAddr
		jnz @F
		and byte ptr [ebx].SBREAK.wFlags,not 1
		.break
@@:
		add ebx, sizeof SBREAK
		dec ecx
	.endw
	popad
	ret
RemoveBreakFromTable endp

;--- find the first break matching linear address in edx
;--- return SEG:OFFS in DX:EAX or Carry

FindBreakInTable proc uses ebx ecx
	mov ebx, offset SoftBrkTable
	mov ecx, NUMSBREAK
	.while (ecx)
		test [ebx].SBREAK.wFlags,1	;is free?
		jz @F
		cmp edx, [ebx].SBREAK.dwAddr
		jnz @F
		mov dx, [ebx].SBREAK.wSeg
		mov eax, [ebx].SBREAK.dwOffs
		clc
		jmp found
@@:
		add ebx, sizeof SBREAK
		dec ecx
	.endw
	stc
found:
	ret
FindBreakInTable endp

;*******************************************************************************
;
;Set a break point.
;
;On Entry:
;
;ECX    - remaining request bytes.
;ESI    - current request data.
;EDI    - result buffer position.
;
;Returns:
;
;ECX,ESI & EDI updated.
;
;*******************************************************************************
REQ_SET_BREAK proc
	inc esi 			;skip REQ_SET_BREAK
	dec ecx
;
;Get selector base.
;
	mov bx,[esi+4]
if ?RMDBGHLP
	cmp word ptr [esi+2],0	;HIWORD(offset) != 0 ?
	jnz isprotmode2
	cmp g_fRealMode,0
	jz isprotmode
isrealmode:
	movzx edx,bx
	shl edx,4
	add edx,[esi+0]
	mov al,@flat:[edx]
	mov [edi],al
	and edx,edx				;dont allow NULL
	jz exit
	mov byte ptr @flat:[edx],0CCh
	mov al,2
	jmp done
isprotmode:
	lar edx,ebx
	jnz isrealmode
isprotmode2:
endif
	push ecx
	mov ax,6
	@callint31
	push cx
	push dx
	pop edx
	pop ecx
	jc exit
;
;Include offset.
;
	add edx,[esi+0]
;
;Set break point
;
	push esi
	mov esi, edx
	mov bl,0CCh
	call WriteMemory
	pop esi
	mov [edi],bl		;save the old value
	mov al,0
;
;Update input values.
;
done:
	call AddBreakToTable
exit:
	add edi,4
	add esi,6
	sub ecx,6
;
	ret
REQ_SET_BREAK endp


;*******************************************************************************
;
;Clear a break point.
;
;On Entry:
;
;ECX	- remaining request bytes.
;ESI	- current request data.
;EDI	- result buffer position.
;
;Returns:
;
;ECX,ESI & EDI updated.
;
;*******************************************************************************
REQ_CLEAR_BREAK proc
	inc esi
	dec ecx 			;skip REQ_CLEAR_BREAK
;
;Get selector base.
;
	mov bx,[esi+4]
if ?RMDBGHLP
	cmp word ptr [esi+2],0	;HIWORD(offset) != 0 ?
	jnz isprotmode2
	cmp g_fRealMode,0
	jz isprotmode
isrealmode:
	movzx edx,bx
	shl edx,4
	add edx,[esi+0]
	and edx,edx				;dont allow NULL linear address
	jz exit
	cmp byte ptr @flat:[edx],0CCh	;there is no bp anymore!
	jnz done
	mov al,[esi+6]			;get the previous byte value
	mov @flat:[edx],al
	jmp done
isprotmode:
	lar edx,ebx
	jnz isrealmode
isprotmode2:
endif
	push ecx
	mov ax,6
	@callint31
	push cx

	push dx
	pop edx
	pop ecx
	jc exit
;
;Include offset.
;
	add edx,[esi]
;
;Restore value.
;
	push esi
	mov bl,[esi+6]
	cmp bl,0CCh
	jz @F
	mov esi, edx
	call WriteMemory
@@:
	pop esi
;
;Update input values.
;
done:
	call RemoveBreakFromTable
exit:
	add esi,6+4
	sub ecx,6+4
;
	ret
REQ_CLEAR_BREAK endp


;*******************************************************************************
;
;Return the alias of a selector.
;
;On Entry:
;
;ECX    - remaining request bytes.
;ESI    - current request data.
;EDI    - result buffer position.
;
;Returns:
;
;ECX,ESI & EDI updated.
;
;*******************************************************************************
REQ_ALIAS struct
bReq	db ?
wPrev	dw ?
REQ_ALIAS ends

REPLY_ALIAS struct
wSeg	dw ?
wAlias	dw ?
REPLY_ALIAS ends

REQ_GET_NEXT_ALIAS proc
	mov [edi].REPLY_ALIAS.wSeg,0
	mov [edi].REPLY_ALIAS.wAlias,0
	mov al,g_fRealMode
	cmp al,-1
	jz done
	cmp al,g_fPrevMode
	jnz modechange
if 1
	mov ax,Debuggee.cpu._Cs
	lar eax,eax
	test eax,400000h
	setnz al
	xor al,g_fPrevDef
	jnz modechange
endif
	jmp done
modechange:
	movzx eax,[esi].REQ_ALIAS.wPrev  ;get alias requested
	and eax,eax
	jnz notfirst
	mov bx,Debuggee.cpu._Cs
	push ecx
	mov ax,6
	@callint31
	push cx
	push dx
	pop eax
	pop ecx
	test al,0Fh
	jnz done
	cmp eax,10FFF0h
	ja done
	shr eax,4
	mov [edi].REPLY_ALIAS.wSeg,ax
	mov [edi].REPLY_ALIAS.wAlias,bx
	jmp done
notfirst:
done:
	add edi,sizeof REPLY_ALIAS
	add esi,sizeof REQ_ALIAS
	sub ecx,sizeof REQ_ALIAS
	ret
REQ_GET_NEXT_ALIAS endp

if ?DPMI16

;--- get next module of EDX, eax=list start

getnextmod16 proc
	push es
	and edx,edx
	jz done
nextitem:
	mov es,eax
	cmp eax,edx
	jz found
	mov ax,es:[6]
	and eax,eax
	jnz nextitem
	pop es
	ret
found:
	mov ax,es:[6]
done:
	pop es
	ret
getnextmod16 endp
endif

;*******************************************************************************
;
;Return the name of a module.
;
;On Entry:
;
;ECX    - remaining request bytes.
;ESI    - current request data.
;EDI    - result buffer position.
;
;Returns:
;
;ECX,ESI & EDI updated.
;
;*******************************************************************************

REPLY_GET_LIB_NAME struct
dwHandle	dd ?
szName		db ?
REPLY_GET_LIB_NAME ends

REQ_GET_LIB_NAME proc

	mov [edi].REPLY_GET_LIB_NAME.dwHandle,0
	mov [edi].REPLY_GET_LIB_NAME.szName,0
	push ecx
	cmp g_fRealMode,-1
	jz error
if ?FLAT
	mov edx,[esi+1]
@@:
	mov ax,4b83h			;get next module handle
	int 21h					;use int instruction! @callint21
	jc error
	and eax, eax
	jz error
	mov edx,eax
	cmp eax,[g_dwHelperStart]	;dont return handle of hxhelp.exe 
	jz @B
	cmp eax,[DebugModule]	;dont return debuggee app handle
	jz @B
	mov [edi].REPLY_GET_LIB_NAME.dwHandle,eax
	mov ax,4b86h
	int 21h					;use int instruction! @callint21
	jc error
	mov ebx, eax
nextchar:
	cmp byte ptr @flat:[eax],0
	jz namescanned
	cmp byte ptr @flat:[eax],'\'
	jnz @F
	lea ebx, [eax+1]
@@:
	inc eax
	jmp nextchar
namescanned:
	lea edi,[edi].REPLY_GET_LIB_NAME.szName
@@:
	mov al,@flat:[ebx]
	mov [edi],al
	inc ebx
	inc edi
	and al,al
	jnz @B
	jmp done
error:
endif
if ?DPMI16
	mov edx,ds
	mov cl,1
	mov ax,4b88h			;get NE module handle
	int 21h					;use int instruction! @callint21
	jc error
	movzx eax,dx				;get the first hModule (kernel.dll)
	mov edx,[esi+1]
@@:
	call getnextmod16
	and eax,eax
	jz error
	mov edx,eax
	cmp eax,[g_hModuleHelper]	;dont return handle of hxhelp.exe 
	jz @B
	cmp eax,[DebugModule]	;dont return debuggee app handle
	jz @B
	mov [edi].REPLY_GET_LIB_NAME.dwHandle,eax
	push ds
	mov ds,eax
	movzx ebx,word ptr ds:[0026h]	;start resident names
	inc ebx
	lea edi,[edi].REPLY_GET_LIB_NAME.szName
@@:
	mov al,ds:[ebx]
	mov es:[edi],al
	inc ebx
	inc edi
	and al,al
	jnz @B
	pop ds
	jmp done
error:
endif
	add edi,sizeof REPLY_GET_LIB_NAME
done:
	pop ecx
	add esi,1+4
	sub ecx,1+4
	ret
REQ_GET_LIB_NAME endp


;*******************************************************************************
;
;Return the text for an error number.
;
;On Entry:
;
;ECX    - remaining request bytes.
;ESI    - current request data.
;EDI    - result buffer position.
;
;Returns:
;
;ECX,ESI & EDI updated.
;
;*******************************************************************************
REQ_GET_ERR_TEXT proc
	mov edx,[esi+1]
	add esi,1+4
	sub ecx,1+4
	cmp edx,SIZEERRORLIST
	jae done 
	mov edx,[ErrorList+edx*4]
@@0text:
	mov al,[edx]
	mov [edi],al
	inc edx
	inc edi
	or al,al
	jnz @@0text
	ret
done:
	mov al,0
	mov [edi],al
	inc edi
	ret
REQ_GET_ERR_TEXT endp


;*******************************************************************************
;
;Return current message/error text.
;
;On Entry:
;
;ECX	- remaining request bytes.
;ESI	- current request data.
;EDI	- result buffer position.
;
;Returns:
;
;ECX,ESI & EDI updated.
;
;*******************************************************************************
REQ_GET_MESSAGE_TEXT proc
	xor edx,edx
	xchg edx,pErrorMessage
	add esi,1
	sub ecx,1
	mov byte ptr [edi],0		 ;set flags.
	inc edi
nextchar:
	mov al,[edx]
	mov [edi],al
	inc edx
	inc edi
	or al,al
	jnz nextchar
	ret
REQ_GET_MESSAGE_TEXT endp


;*******************************************************************************
;
;Redirect standard input.
;
;On Entry:
;
;ECX	- remaining request bytes.
;ESI	- current request data.
;EDI	- result buffer position.
;
;Returns:
;
;ECX,ESI & EDI updated.
;
;*******************************************************************************
REQ_REDIRECT_STDIN proc
	add esi,ecx
	xor ecx,ecx
	mov dword ptr [edi], MSG_6
	invoke SetErrorText, MSG_6
	add edi,4
	ret
REQ_REDIRECT_STDIN endp


;*******************************************************************************
;
;Redirect standard output.
;
;On Entry:
;
;ECX	- remaining request bytes.
;ESI	- current request data.
;EDI	- result buffer position.
;
;Returns:
;
;ECX,ESI & EDI updated.
;
;*******************************************************************************
REQ_REDIRECT_STDOUT proc
	add esi,ecx
	xor ecx,ecx
	mov dword ptr [edi], MSG_6
	invoke SetErrorText, MSG_6
	add edi,4
	ret
REQ_REDIRECT_STDOUT endp


;*******************************************************************************
;
;Setup ErrorMessage with text for ErrorNumber.
;
;*******************************************************************************
SetErrorText proc near dwError:DWORD
	push eax
	mov eax,dwError
	cmp eax,SIZEERRORLIST
	jae @F
	mov eax,[ErrorList+eax*4]
	mov pErrorMessage,eax
@@:
	pop eax
	ret
SetErrorText endp

;--- install hardware breakpoints

InstallHWBreaks proc
	mov esi,offset HBRKTable
	mov ebp,4
nextitem:
	test [esi].HBRK.HBRK_Flags,1
	jz @F
	mov ax,0b00h
	mov ebx,[esi].HBRK.HBRK_Address
	mov cx,bx
	shr ebx,16
	mov dl,[esi].HBRK.HBRK_Size
	mov dh,[esi].HBRK.HBRK_Type
	@callint31
	jc @F
	mov [esi].HBRK.HBRK_Handle,bx
	or [esi].HBRK.HBRK_Flags,2
	@callint31
@@:
	add esi,size HBRK
	dec ebp
	jnz nextitem
	ret
InstallHWBreaks endp

ClearHWBreaks proc

	mov esi,offset HBRKTable
	mov ebp,4
nextitem:
	test [esi].HBRK.HBRK_Flags,2
	jz @F
	and [esi].HBRK.HBRK_Flags,not 2
	mov bx,[esi].HBRK.HBRK_Handle
	mov ax,0b01h
	@callint31
@@:
	add esi,size HBRK
	dec ebp
	jnz nextitem
	ret
ClearHWBreaks endp

;--- test if we have reached raw jump to protected mode
;--- if so, set a breakpoint at protected mode destination

CheckRMAddr proc
	cmp bExecuteFlags,0		;dont do anything with GO!
	jz done
	mov ax,Debuggee.cpu._Cs		;have we reached raw jump to pm?
	shl eax,16
	mov ax,word ptr Debuggee.cpu._Eip
	cmp eax,g_rm2pmjump
	jz isrm2pm
	cmp eax,g_dwDPMIEntry
	jz isdpmientry
	cmp eax,g_dwSaveRestoreRM
	jz issaverestore
	jmp done
isdpmientry:
	test byte ptr Debuggee.cpu._Eax,1
	jnz is32
	mov pErrorMessage, CStr("Initial switch to protected mode (16-bit)")
	jmp @F
is32:
	mov pErrorMessage, CStr("Initial switch to protected mode (32-bit)")
@@:
issaverestore:
	movzx eax,word ptr Debuggee.cpu._Ss
	shl eax,4
	movzx ecx,word ptr Debuggee.cpu._Esp
	add eax,ecx
	movzx ecx,word ptr @flat:[eax+2]
	shl ecx,4
	movzx eax,word ptr @flat:[eax+0]
	add eax,ecx
	jmp setbreak
isrm2pm:
	mov pErrorMessage, CStr("Raw jump to protected mode")
	mov ebx,Debuggee.cpu._Esi
	mov ax,6
	@callint31
	jc done
	push cx
	push dx
	pop eax
if ?DPMI16
	movzx ecx,word ptr Debuggee.cpu._Edi
	add eax,ecx
else
	add eax,Debuggee.cpu._Edi
endif
setbreak:
	mov esi,eax
	mov bl,0CCh
	call WriteMemory
	jc done
	mov g_bSavedInternalBrk,bl
	mov g_dwInternalBrkAddr,esi
	and byte ptr Debuggee.cpu._Efl+1,not 1	;clear single step mode
	stc
	ret
done:
	clc
	ret
CheckRMAddr endp

;--- test if we have reached special protected mode addresses

CheckPMAddr proc
	cmp bExecuteFlags,0		;dont do anything with GO!
	jz done
	mov ax,Debuggee.cpu._Cs		;have we reached raw jump to pm?
	mov edx,Debuggee.cpu._Eip
	cmp edx,dword ptr g_dfSaveRestorePM+0
	jnz @F
	cmp ax,word ptr g_dfSaveRestorePM+4
	jz issaverestore
@@:
	cmp edx,dword ptr g_pm2rmjump+0
	jnz @F
	cmp ax,word ptr g_pm2rmjump+4
	jz ispm2rm
@@:
	jmp done
issaverestore:
	mov bx,Debuggee.cpu._Ss
	mov ax,6
	@callint31
	jc done
	push cx
	push dx
	pop eax
	add eax,Debuggee.cpu._Esp
	mov bx,@flat:[eax+?SEGOFS]
if ?DPMI16
	movzx ecx,word ptr @flat:[eax+0]
else
	mov ecx,@flat:[eax+0]
endif
	push ecx
	mov ax,6
	@callint31
	push cx
	push dx
	pop eax
	pop ecx
	jc done
	add eax,ecx
	jmp setbreak
ispm2rm:
	mov pErrorMessage, CStr("Raw jump to real mode")
	movzx ebx,word ptr Debuggee.cpu._Esi
	shl ebx,4
	movzx eax,word ptr Debuggee.cpu._Edi
	add eax,ebx
setbreak:
	mov esi,eax
	mov bl,0CCh
	call WriteMemory
	jc done
	mov g_bSavedInternalBrk,bl
	mov g_dwInternalBrkAddr,esi
	and byte ptr Debuggee.cpu._Efl+1,not 1	;clear single step mode
	stc
	ret
done:
	clc
	ret
CheckPMAddr endp

RestoreInternalBrk proc
	mov bl,g_bSavedInternalBrk
	mov esi,g_dwInternalBrkAddr
	call WriteMemory
	mov g_dwInternalBrkAddr,-1
	or TraceFlag,-1
	and BreakFlag,0
	or ExceptionFlag,-1
	ret
RestoreInternalBrk endp

;*******************************************************************************
;
;Execute the debugee.
;
;On Entry:
;
;EAX    - mode, 0=go, 1=step.
;
;Returns:
;
;EAX    - status (see REQ_PROG_GO/STEP return flags)
;
;*******************************************************************************
Execute proc
	pushs ebx,ecx,edx,esi,edi,ebp
	mov bExecuteFlags,al

;	invoke String2File, CStr("Execute enter",13,10)

	cmp g_bTerminated,0
	jnz no_execution
;
;Switch to debuggee's PSP.
;
	mov ebx,DebugPSP
	mov ah,50h
	@callint21
;
;Install hardware break points.
;
	call InstallHWBreaks
;
;Force watch point checking if watches are present.
;
	cmp NumWatches,0
	jz @F
	or bExecuteFlags,2	;force single steping.
@@:
	mov al,g_fRealMode
	mov g_fPrevMode,al	;save CPU state 
	mov g_fPrevDef,0
	cmp al,0
	jnz @F
	mov ax,Debuggee.cpu._Cs
	lar eax,eax
	test eax,400000h
	setnz al
	mov g_fPrevDef,al
@@:
cont_execute:
;
;Set debuggee trap flag if it's a single instruction trace else clear it if
;not.
;
	and byte ptr Debuggee.cpu._Efl+1,not 1
	cmp bExecuteFlags,0
	jz @F
;	or byte ptr Debuggee.cpu._Efl+1,1	;set TRACE flag
	or Debuggee.cpu._Efl, 10100h		;set TRACE + RESUME flags
	cmp g_fRealMode,-1
	jz @F
	call forceexc01supply
@@:
;
;Set flags ready for execution.
;
cont_execute2:
	mov bExecuting,1
	mov ExceptionFlag,-1
	mov BreakFlag,0
	mov TraceFlag,0
	mov bBreakKeyFlag,0
;
;Put return address on the stack.
;
	mov eax,offset @@backexec	;store return address for int 3.
	push eax
	mov word ptr [DebuggerSS],ss
	mov dword ptr [DebuggerESP],esp

;	invoke String2File, CStr("Execute MS 1",13,10)

;
;Execute the program.
;
if ?RMDBGHLP
	cmp g_fRealMode,-1
	jz pm2rm
endif
	mov ss,Debuggee.cpu._Ss
	mov esp,Debuggee.cpu._Esp
	push [Debuggee.cpu._Efl]
	push word ptr 0
	push [Debuggee.cpu._Cs]
	push [Debuggee.cpu._Eip]
	mov eax,Debuggee.cpu._Eax
	mov ebx,Debuggee.cpu._Ebx
	mov ecx,Debuggee.cpu._Ecx
	mov edx,Debuggee.cpu._Edx
	mov esi,Debuggee.cpu._Esi
	mov edi,Debuggee.cpu._Edi
	mov ebp,Debuggee.cpu._Ebp
	mov gs,Debuggee.cpu._Gs
	mov fs,Debuggee.cpu._Fs
	mov es,Debuggee.cpu._Es
	mov ds,Debuggee.cpu._Ds
	iretd
;
;Clear execution flag.
;
@@backexec:
	mov bExecuting,0
ife ?FLAT
	mov @flat,[g_flatsel]
endif
;
;Check if we're single stepping to allow for watches.
;
	test bExecuteFlags,2
	jz @@8exec
	cmp g_bTerminated,0 		;terminated?
	jnz @@8exec
	cmp ExceptionFlag,-1		;exception triggered?
	jnz @@8exec
	cmp bBreakKeyFlag,0
	jnz @@8exec
;
;Check state of all watches.
;
	mov esi, offset WatchTable
	mov ebp, NUMWATCH
nextitem:
	test [esi].WATCH.WATCH_Flags,1	   ;in use?
	jz @@hbrk7
	;
	;Check if this watch changed.
	;
	call SetIntExc0E
	mov dwExcProc, offset acc_err2
	mov edi,[esi].WATCH.WATCH_Address
	mov ecx,[esi].WATCH.WATCH_Length
	xor eax,eax
	xor ebx,ebx
@@:
	mov bl,@flat:[edi]
	add eax,ebx
	inc edi
	dec ecx
	jnz @B
acc_err2:
	call ResetIntExc0E
	and ecx,ecx					;access error?
	jnz @F
	cmp eax,[esi].WATCH.WATCH_Check
	jnz @@10exec				;signal COND_WATCH
@@:
@@hbrk7:
	add esi,size WATCH
	dec ebp
	jnz nextitem
;
;Check it wasn't a single step anyway.
;
	test bExecuteFlags,1  ;single steping anyway?
	jnz @@8exec
	jmp cont_execute

;
;Set vars to trigger COND_WATCH
;
@@10exec:
	mov ExceptionFlag,1 ;force trace flag setting.
	or TraceFlag,-1
@@8exec:

;	 mov al,20h  ; MED 08/06/96, re-enable interrupts
;	 out 20h,al
;
;Remove HBRK's
;
	call ClearHWBreaks

;--- special handling for raw jump real-mode to protected mode
;--- single-step will most likely loose control

	cmp g_fRealMode,0
	jz @F
	call CheckRMAddr
	jc cont_execute2
	jmp cont_rm
@@:
	call CheckPMAddr
	jc cont_execute2
cont_rm:
	cmp g_dwInternalBrkAddr,-1
	jz @F
	call RestoreInternalBrk
@@:
;
;Store PSP incase it changed.
;
	mov ah,62h
	@callint21
	movzx ebx,bx
	mov DebugPSP,ebx
	cmp g_fRealMode,0		;debuggee in protected mode?
	jnz @F
	push ds
	mov ds,ebx
	or byte ptr ds:[4Fh],80h	;mark PSP as "protected mode"
	pop ds
if ?STOPAT4G or ?STOPATPM
	or g_fDPMIClient,1			;this is a dpmi client
endif
	call untraprm21				;stop trapping int 21h in realmode
@@:
;
;Switch back to helpers PSP.
;
	mov ebx, g_psp
	mov ah,50h
	@callint21
;
;Now setup return value to reflect why we stopped execution.
;
no_execution:
	xor eax,eax
	cmp g_bTerminated,0 		  ;program terminated?
	jz @F
	or eax, COND_TERMINATE
	jmp done
@@:
	mov cl,g_fRealMode
	cmp cl,g_fPrevMode
	jz @F
;	or eax, COND_ALIASING
	or eax, COND_ALIASING or COND_CONFIG	;ok? COND_CONFIG makes WD call GetSysConfig() and CheckMADChange()
@@: 
	cmp g_fRealMode,0
	jnz @F
	mov cx,Debuggee.cpu._Cs
	lar ecx,ecx
	test ecx,400000h
	setnz cl
	xor cl,g_fPrevDef
	jz @F
	or eax, COND_ALIASING
@@:
	cmp bBreakKeyFlag,0
	jz @F
	or eax, COND_USER
	jmp check_msg
@@:
	cmp BreakFlag,0 			;break point?
	jz @F
	or eax,COND_BREAK
	jmp check_msg
@@:
	cmp TraceFlag,0 			;trace point?
	jz @@3exec
	cmp ExceptionFlag,1 		;hardware break point?
	jnz @F
	or eax,COND_WATCH or COND_EXCEPTION
	invoke SetErrorText, MSG_12
	jmp done
@@:
	or eax, COND_TRACE
	jmp check_msg
@@3exec:
	cmp ExceptionFlag,-1		;exception?
	jz noexc
	or eax,COND_EXCEPTION
	movzx ecx, ExceptionFlag
	add ecx, 16
	invoke SetErrorText, ecx
	jmp done
noexc:
	or eax,COND_WATCH
check_msg:
	cmp pErrorMessage,0
	jz done
	or eax,COND_MESSAGE
;
;Return to caller.
;
done:
	pops ebx,ecx,edx,esi,edi,ebp
	ret
Execute endp


;*******************************************************************************
;
;Check if hardware break point executed.
;
;*******************************************************************************
IsHardBreak proc near
	pushad
	mov esi,offset HBRKTable
	mov ecx,4
nextitem:
	cmp [esi].HBRK.HBRK_Flags,1+2
	jnz @@1hb
	mov bx,[esi].HBRK.HBRK_Handle
	mov ax,0b02h
	@callint31
	jc @@1hb
	test ax,1
	jnz @@8hb
@@1hb:	
	add esi,size HBRK
	dec ecx
	jnz nextitem
	clc
	jmp done
	;
@@8hb:
	stc			;yes
	;
done:
	popad
	ret
IsHardBreak endp

;--- ESP -> E/IP, CS, E/FLAGS

SaveRegsInt proc near
	;
	;Retrieve general registers.
	;
	push ds
	mov ds,cs:[g_dsreg]
	mov Debuggee.cpu._Eax,eax
	mov Debuggee.cpu._Ebx,ebx
	mov Debuggee.cpu._Ecx,ecx
	mov Debuggee.cpu._Edx,edx
	mov Debuggee.cpu._Esi,esi
	mov Debuggee.cpu._Edi,edi
	mov Debuggee.cpu._Ebp,ebp
	pop eax
	mov Debuggee.cpu._Ds,ax
	mov Debuggee.cpu._Es,es
	mov Debuggee.cpu._Fs,fs
	mov Debuggee.cpu._Gs,gs

	mov bExecuting,0

if ?DPMI16
	pop ax
	movzx eax,ax
else
	pop eax
endif
	cmp BreakFlag,-1
	jnz @F
	cmp ExceptionFlag,-1
	jnz @F
	dec eax 			   ;account for int 3 instruction length.
@@:
	mov Debuggee.cpu._Eip,eax
if ?DPMI16
	pop ax
else
	pop eax
endif
	mov Debuggee.cpu._Cs,ax
if ?DPMI16
	pop ax
	movzx eax,ax
else
	pop eax
endif
	and ah,not 1			;reset trace flag
	mov Debuggee.cpu._Efl,eax
	mov Debuggee.cpu._Ss,ss
	mov Debuggee.cpu._Esp,esp

	push ds
	pop es
if ?RMDBGHLP
	mov g_fRealMode, 0
endif
	lss esp,fword ptr [DebuggerESP]
	ret
SaveRegsInt endp

;*******************************************************************************
;Catch INT 0's.
;*******************************************************************************
Int00Handler proc near

	@switchcs
	cmp cs:bExecuting,0
	jz @@Oldi00
	push ds
	mov ds,cs:[g_dsreg]
	mov ExceptionFlag,0
	pop ds
	jmp SaveRegsInt
@@Oldi00:
	jmp cs:[OldInt00]
Int00Handler endp

;*******************************************************************************
;Catch INT 75 (IRQ 13)
;*******************************************************************************
Int75Handler proc near

	@switchcs
	cmp cs:bExecuting,0
	jz @@Oldi75
	push ds
	mov ds,cs:[g_dsreg]
	mov ExceptionFlag,16
	pop ds
	push eax
	mov al,20h
	out 20h,al
	out 0A0h,al
	pop eax
if ?DPMI16
	push ebp
	movzx ebp,sp
	or byte ptr [ebp+4].IRETS._Efl+1,1
	pop ebp
else
	or byte ptr [esp].IRETS._Efl+1,1
endif
	sti
	@iret
@@Oldi75:
	jmp cs:[OldInt75]
Int75Handler endp

;*******************************************************************************
;Catch single instruction trace and debug register traps.
;*******************************************************************************
Int01Handler proc near

	@switchcs
Int01HandlerEx::
	cmp cs:bExecuting,0
	jz @@Oldi01
	push ds
	mov ds,cs:[g_dsreg]
	or TraceFlag,-1
	pop ds
	jmp SaveRegsInt
;
@@Oldi01:
	jmp cs:[OldInt01]
Int01Handler endp



;*******************************************************************************
;Catch INT 3's.
;*******************************************************************************
Int03Handler proc near

	@switchcs
	cmp cs:bExecuting,0
	jz @F
	push ds
	mov ds,cs:[g_dsreg]
	or BreakFlag,-1
	pop ds
	jmp SaveRegsInt
;
@@:
	jmp cs:[OldInt03]
Int03Handler endp

;--- general exception handling

SaveRegsExc proc

	cmp cs:bExecuting,0
	jz internalexc
stopexec:
	push ds
	mov ds,cs:[g_dsreg]
	mov bExecuting,0
	;
	;Retrieve general registers.
	;
	mov Debuggee.cpu._Eax,eax
	mov Debuggee.cpu._Ebx,ebx
	mov Debuggee.cpu._Ecx,ecx
	mov Debuggee.cpu._Edx,edx
	mov Debuggee.cpu._Esi,esi
	mov Debuggee.cpu._Edi,edi
	mov Debuggee.cpu._Ebp,ebp
	pop eax
	mov Debuggee.cpu._Ds,ax
	mov Debuggee.cpu._Es,es
	mov Debuggee.cpu._Fs,fs
	mov Debuggee.cpu._Gs,gs
	pop eax				; throw away return address
	pop eax				; get exc#

	mov ebp,ss
	lar ebp,ebp
	test ebp,400000h
	mov ebp, esp 		;make stack addresable.
	jnz @F
	movzx ebp, bp
@@:

;--- status here:
;--- ax=exc#
;--- 32bit: ebp-> EXCFRAME
;--- 16bit: ebp-> EXCFRAME16

	cmp al,1
	jnz isnot1
	or TraceFlag,-1
	jmp flagsdone
isnot1:
	cmp al,3
	jnz isnot3
	or BreakFlag,-1
	jmp flagsdone
isnot3:
	mov ExceptionFlag,al
	cmp al,16
	jnz isnot16
	fnclex
isnot16:
flagsdone:
	;
	;Fetch original Flags:CS:EIP
	;
if ?DPMI16
	movzx eax,[ebp].EXCFRAME16._eflags
	and ah,not 1
	mov Debuggee.cpu._Efl,eax
	mov ax,[ebp].EXCFRAME16._cs
	mov Debuggee.cpu._Cs,ax
	movzx eax,[ebp].EXCFRAME16._eip
else
	mov eax,[ebp].EXCFRAME._eflags
	and ah,not 1
	mov Debuggee.cpu._Efl,eax
	mov eax,[ebp].EXCFRAME._cs
	mov Debuggee.cpu._Cs,ax
	mov eax,[ebp].EXCFRAME._eip
endif
	cmp BreakFlag,-1
	jnz @F
	cmp ExceptionFlag,-1
	jnz @F
	dec eax 				 ;account for int 3 instruction length.
@@:
	mov Debuggee.cpu._Eip,eax

;	invoke String2File, CStr("SaveRegsExc MS 1",13,10)

if ?DPMI16
	movzx eax, [ebp].EXCFRAME16._esp
	mov Debuggee.cpu._Esp, eax
	mov ax, [ebp].EXCFRAME16._ss
	mov Debuggee.cpu._Ss, ax
else
	mov eax, [ebp].EXCFRAME._esp
	mov Debuggee.cpu._Esp, eax
	mov eax, [ebp].EXCFRAME._ss
	mov Debuggee.cpu._Ss, ax
endif
	push ds
	pop es
if ?RMDBGHLP
	mov g_fRealMode, 0
endif
	;
	;Now modify origional CS:EIP,SS:ESP values and return control
	;to this code via interupt structure to restore stacks.
	;
	mov eax, [DebuggerESP]
if ?DPMI16
	mov [ebp].EXCFRAME16._esp, ax
	mov ax, [DebuggerSS]
	mov [ebp].EXCFRAME16._ss, ax
	mov [ebp].EXCFRAME16._eip,lowword(offset @@returnexx)
	@loadcs eax
	mov [ebp].EXCFRAME16._cs,ax
	and byte ptr [ebp].EXCFRAME16._eflags+1,not 1
else
	mov [ebp].EXCFRAME._esp, eax
	mov ax, [DebuggerSS]
	mov [ebp].EXCFRAME._ss, eax
	mov [ebp].EXCFRAME._eip,offset @@returnexx
	mov [ebp].EXCFRAME._cs,cs
	and byte ptr [ebp].EXCFRAME._eflags+1,not 1
endif
	@retf
	;
@@returnexx:	;Now return control to exec caller.
	@switchcs
	retn
internalexc:
if ?INTPMEXC
	cmp cs:g_bTrapIntExc,0
	jz @F
  if 1
	push ds
	mov ds,cs:[g_dsreg]
	mov [DebuggerESP],offset loadstack-204h
	mov dword ptr [loadstack-204h],offset fatalexit
	mov [DebuggerSS],ds
	pop ds
	jmp stopexec
  else
	pop eax
	pop ecx
	jmp fatalexit
  endif
@@:
endif
	retn 4
if ?INTPMEXC
fatalexit:
if 1
	mov cl,ExceptionFlag
else
	mov ds,[g_dsreg]
	push ds
	pop ss
	mov esp,offset loadstack - 200h
	push ds
	pop es
endif
	add cl,'0'
	cmp cl,'9'
	jbe @F
	add cl, 7
@@:
	mov [bIntExc],cl
	movzx eax, Debuggee.cpu._Cs
	invoke Word2Ascii, eax, offset bIntExcCS
	invoke DWord2Ascii, Debuggee.cpu._Eip, offset bIntExcEIP
	mov edx,offset szInternalExc
	mov ah,9
	@callint21
	mov ah,0
	int 16h
if ?RMDBGHLP
	call DeinitRMDbgHelper
endif
	mov ax,4CFFh
	@callint21
endif

SaveRegsExc endp


Exc00Handler:
	@switchcs
	push 0
	call SaveRegsExc
	jmp cs:[OldExc00]
Exc01Handler:
	@switchcs
	push ds
	mov ds,cs:[g_dsreg]
;--- is exception caused by hardware watchpoints
	call IsHardBreak
	jnc @F
	mov ExceptionFlag,1	;then it is ours
	pop ds
	jmp isourexc
@@:
	pop ds
	push ebp
	mov ebp,ss
	lar ebp,ebp
	test ebp,400000h
	mov ebp,esp 		;make stack addresable.
	jnz @F
	movzx ebp,bp
@@:
;--- is exception caused by trace flag?
if ?DPMI16
	test byte ptr [ebp+4].EXCFRAME16._eflags+1,1
else
	test byte ptr [ebp+4].EXCFRAME._eflags+1,1
endif
	pop ebp
	jz isourexc		;no, so it is ours (opcodes CD 01 or F1)
;--- has break key been pressed
	cmp cs:[bBreakKeyFlag],-1
	jz isourexc
;--- is single-step mode on?
	cmp cs:[bExecuteFlags],0
	jz @F				;no, so this exc belongs to debuggee!!!
isourexc:
	push 1
	call SaveRegsExc
@@:
	jmp cs:[OldExc01]

Exc03Handler:
	@switchcs
	push 3
	call SaveRegsExc
	jmp cs:[OldExc03]
Exc04Handler:
	@switchcs
	push 4
	call SaveRegsExc
	jmp cs:[OldExc04]
Exc05Handler:
	@switchcs
	push 5
	call SaveRegsExc
	jmp cs:[OldExc05]
Exc06Handler:
	@switchcs
	push 6
	call SaveRegsExc
	jmp cs:[OldExc06]
Exc07Handler:
	@switchcs
	push 7
	call SaveRegsExc
	jmp cs:[OldExc07]
Exc0BHandler:
	@switchcs
	push 11
	call SaveRegsExc
	jmp cs:[OldExc0B]
Exc0CHandler:
	@switchcs
	push 12
	call SaveRegsExc
	jmp cs:[OldExc0C]
Exc0DHandler:
	@switchcs
	push 13
	call SaveRegsExc
	jmp cs:[OldExc0D]
Exc0EHandler:
	@switchcs
	push 14
	call SaveRegsExc
	jmp cs:[OldExc0E]
Exc10Handler:
	@switchcs
	push 16
	call SaveRegsExc
	jmp cs:[OldExc10]

;--- for internal page error checks set a temporary page exc handler

SetIntExc0E proc
	pushad
	mov ax,0202h
	mov bl,0Eh
	@callint31
if ?DPMI16
	movzx edx,dx
endif
	mov dword ptr [dfDbgeeExc0e+0],edx
	mov word ptr [dfDbgeeExc0e+4],cx
	@loadcs ecx
	mov edx, offset IntExc0E
	mov ax,0203h
	@callint31
	popad
	ret
SetIntExc0E endp

ResetIntExc0E proc
	pushad
	mov cx, word ptr cs:[dfDbgeeExc0e+4]
	mov edx, dword ptr cs:[dfDbgeeExc0e+0]
	mov ax,0203h
	mov bl,0Eh
	@callint31
	popad
	ret
ResetIntExc0E endp

;--- this is the internal page exception handler. will be set by
;--- ReadMemory/WriteMemory

IntExc0E proc
	@switchcs
	push ebp
	mov ebp,ss
	lar ebp,ebp
	test ebp,400000h
	mov ebp,esp 		;make stack addressable.
	jnz @F
	movzx ebp,bp
@@:
	push eax
	mov eax, cs:dwExcProc
if ?DPMI16
	mov [ebp+1*4].EXCFRAME16._eip,ax
	mov [ebp+1*4].EXCFRAME16._cs,cs
else
	mov [ebp+1*4].EXCFRAME._eip,eax
	mov [ebp+1*4].EXCFRAME._cs,cs
endif
	pop eax
	pop ebp
	@retf
IntExc0E endp
;
;--- catch timer interrupts. the trap helper doesnt need them, but it will
;--- make sure the debuggee cannot gain control while the helper executes
;
Int08Handler proc near
	@switchcs
	cmp cs:[bExecuting],0
	jnz @F
	jmp cs:[SavedInt08]
@@:
	jmp cs:[OldInt08]
Int08Handler endp

;*******************************************************************************
;
;This should receive ALL keyboard interrupts before anything else gets to see
;them.
;
;*******************************************************************************
Int09Handler proc near
	@switchcs
	pushs eax,ebx,ebp,ds
	mov ds,cs:[g_dsreg]
;
;Update the key table.
;
	in al,60h		   ;get the scan code.
	mov ah,[bScanCode]
	mov [bPrevScanCode],ah
	mov [bScanCode],al
	mov bl,al
	and ebx,7Fh 		;isolate scan code.
	test al,80h
	jnz @F
	bts KeyTable,ebx
	jmp bitset
@@:
	btr KeyTable,ebx
bitset:
;
;Check if anything is running.
;
	cmp bExecuting,0
	jz @@oldbc
;
;Check if our break combination is set.
;
	mov ebx,offset BreakKeyList
	cmp dword ptr [ebx],0		;check if any keys in the list.
	jz breakkey_checked
nextitem:
	cmp dword ptr [ebx],0		;End of the list?
	jz breakkey_pressed
	mov eax,[ebx]				;Get scan code.
	bt KeyTable,eax
	jnc breakkey_checked
	add ebx,4
	jmp nextitem
;
;--- reset the key combination causing the break
;
breakkey_pressed:
	mov ebx,offset BreakKeyList
nextitem2:
	cmp dword ptr [ebx],0		;End of the list?
	jz @F
	mov eax,[ebx]
	btr KeyTable,eax
	add ebx,4
	jmp nextitem2
@@:
;
;Want to break into the program so swollow this key press.
;
if 0
	in al,61h
	mov ah,al
	or al,80h			;clear keyboard
	out 61h,al
	xchg ah,al
	out 61h,al			;code we got.
endif
;
;--- we are on the LPMS, the application stack is unknown
;--- set trace flag, this should cause an exception 01
;--- (at least if debuggee is in protected mode)
;
	mov ebp,ss
	lar ebp,ebp
	test ebp,400000h
	mov ebp,esp
	jnz @F
	movzx ebp,bp
@@:
	or byte ptr [ebp+4*4].IRETS._Efl+1,1
	or bBreakKeyFlag,-1
swallow_key:
	mov al,20h
	out 20h,al			;re-enable interupts.
	pops eax,ebx,ebp,ds
	sti
	@iret
@@oldbc:
;--- the trap helper is running, dont allow Ctrl-Break
;--- that is, swallow E0 46/E0 C6 combinations
	cmp bl,46h
	jnz @F
	cmp bPrevScanCode, 0E0h
	jnz @F
	push ds
	push 40h
	pop ds
	and byte ptr ds:[96h],not 2	;reset E0 flag
	pop ds
	jmp swallow_key
@@:
breakkey_checked:
;
;Pass control to the original handler.
;
	pops eax,ebx,ebp,ds
	cmp cs:[bExecuting],0
	jnz @F
	jmp cs:[SavedInt09]
@@:
	jmp cs:[OldInt09]
Int09Handler endp

;*******************************************************************************
;INT 21h handler to catch int get/set calls
;*******************************************************************************
Int21Handler proc far
	@switchcs
	pushfd
if ?STOPAT4G
	cmp ax,0FF00h				;dos4gw call
	jnz no4g
	cmp dx,0078h
	jnz no4g
	test cs:[g_fDPMIClient],4	;is it the first such call?
	jnz no4g
	push ds
	mov ds,cs:[g_dsreg]
	or [g_fDPMIClient],4
	pop ds
	push ebp
	mov ebp,ss
	lar ebp,ebp
	test ebp,400000h				;Default bit set?
	mov ebp,esp
	jnz @F
	movzx ebp,bp
@@:
	or byte ptr [ebp+2*4].IRETS._Efl+1,1 ;set trace flag
	pop ebp
no4g:
endif
if 1
	cmp ah,25h
	jnz @F
	push esi
	mov esi, offset InterruptTab
	.while (cs:[esi].excstr.bExc != -1)
		.if (al == cs:[esi].excstr.bExc)
			mov esi, cs:[esi].excstr.pOldVec
			push es
			mov es,cs:[g_dsreg]
			mov es:[esi+?SEGOFS],ds
if ?DPMI16
			mov es:[esi+0],dx
else
			mov es:[esi+0],edx
endif
			pop es
			pop esi
			jmp @@reti21
		.endif
		add esi, sizeof excstr
	.endw
	pop esi
@@:
	cmp ah,35h
	jnz @F
	push esi
	mov esi, offset InterruptTab
	.while (cs:[esi].excstr.bExc != -1)
		.if (al == cs:[esi].excstr.bExc)
			mov esi, cs:[esi].excstr.pOldVec
			mov es, cs:[esi+?SEGOFS]
if ?DPMI16
			mov bx, cs:[esi+0]
else
			mov ebx, cs:[ebx+0]
endif
			pop esi
			jmp @@reti21
		.endif
		add esi, sizeof excstr
	.endw
	pop esi
@@:
endif
@@oldi21:
	popfd
	jmp cs:[OldInt21]
@@reti21:
	popfd
	push ebp
	mov ebp,ss
	lar ebp,ebp
	test ebp,400000h				;Default bit set?
	mov ebp,esp
	jnz @F
	movzx ebp,bp
@@:
	and byte ptr [ebp+4].IRETS._Efl,not 1 ;clear carry.
	pop ebp
	@iret
Int21Handler endp
;
;--- int 31 handler to catch get/set exc/int vector calls
;
Int31Handler proc far
	@switchcs
	push ds
	mov ds,cs:[g_dsreg]
	cmp bExecuting,0
	jz @@oldi31
if ?STOPATPM
	test g_fDPMIClient,3	;had we stopped in prot mode already?
	jnz nofirstpmbrk
	or g_fDPMIClient,2
	push ebp
	mov ebp,ss
	lar ebp,ebp
	test ebp,400000h				;Default bit set?
	mov ebp,esp
	jnz @F
	movzx ebp,bp
@@:
	or byte ptr [ebp+2*4].IRETS._Efl+1,1 ;set trace flag
	pop ebp
nofirstpmbrk:
endif
if ?DJGPP
	cmp cs:g_bIsDjgpp,0
	jz @F
	test cs:bExecuting,2	;have we stopped alread in prot-mode?
	jz @F
	test esp,0FFFF0000h	;is HIWORD(esp) set already?
	jz @F
	or byte ptr [esp+1*4].IRETS._Efl+1,1 ;set trace flag
@@:
endif
	cmp ax,0202h		;get EXC vector
	jnz @F
	push esi
	mov esi, offset ExceptionTab
	.while ([esi].excstr.bExc != -1)
		.if ((bl == [esi].excstr.bExc) && ([esi].excstr.bFirst))
			mov esi, [esi].excstr.pOldVec
			add esi, sizeof fword
			mov cx, [esi+4]
if ?DPMI16
			mov dx, [esi+0]
else
			mov edx, [esi+0]
endif
			pop esi
			jmp @@reti31
		.endif
		add esi, sizeof excstr
	.endw
	pop esi
	jmp @@oldi31
@@:
	cmp ax,0203h				;set EXC vector
	jnz @F
	push esi
	mov esi, offset ExceptionTab
	.while ([esi].excstr.bExc != -1)
		.if ((bl == [esi].excstr.bExc) && ([esi].excstr.bFirst))
			mov esi, [esi].excstr.pOldVec
			add esi, sizeof fword
			mov [esi+4],cx
if ?DPMI16
			mov [esi+0],dx
else
			mov [esi+0],edx
endif
			pop esi
			jmp @@reti31
		.endif
		add esi, sizeof excstr
	.endw
	pop esi
	jmp @@oldi31
@@:
	cmp ax,0204h				;Get INT vector?
	jnz @F
	push esi
	mov esi, offset InterruptTab
	.while ([esi].excstr.bExc != -1)
		.if ((bl == [esi].excstr.bExc) && ([esi].excstr.bFirst))
			mov esi, [esi].excstr.pOldVec
			mov cx, [esi+?SEGOFS]
if ?DPMI16
			mov dx, [esi+0]
else
			mov edx, [esi+0]
endif
			pop esi
			jmp @@reti31
		.endif
		add esi, sizeof excstr
	.endw
	pop esi
	jmp @@oldi31
@@:
	cmp ax,0205h				;Set INT vector?
	jnz @F
	push esi
	mov esi, offset InterruptTab
	.while ([esi].excstr.bExc != -1)
		.if ((bl == [esi].excstr.bExc) && ([esi].excstr.bFirst))
			mov esi, [esi].excstr.pOldVec
			mov [esi+?SEGOFS],cx
if ?DPMI16
			mov [esi+0],dx
else
			mov [esi+0],edx
endif
			pop esi
			jmp @@reti31
		.endif
		add esi, sizeof excstr
	.endw
	pop esi
	jmp @@oldi31
@@:
@@oldi31:
	pop ds
	jmp cs:[OldInt31]
@@reti31:
	pop ds
	push ebp
	mov ebp,ss
	lar ebp,ebp
	test ebp,400000h				;Default bit set?
	mov ebp,esp
	jnz @F
	movzx ebp,bp
@@:
	and byte ptr [ebp+4].IRETS._Efl,not 1 ;clear carry.
	pop ebp
	@iret

Int31Handler  endp

;--- break caused by int 41h, ax=83h (exception)

int41exc proc
if ?DPMI16
	push word ptr cs:[Debuggee.cpu._Efl]
	push cs:[Debuggee.cpu._Cs]
	push word ptr cs:[Debuggee.cpu._Eip]
else
	push cs:[Debuggee.cpu._Efl]
	push word ptr 0
	push cs:[Debuggee.cpu._Cs]
	push cs:[Debuggee.cpu._Eip]
endif
	jmp Int01HandlerEx
int41exc endp

;--- break caused by int 41h, ax=F003h/0040h

int41break proc
if ?DPMI16
	pushf
	push cs:[Debuggee.cpu._Cs]
	push word ptr cs:[Debuggee.cpu._Eip]
else
	pushfd
	push word ptr 0
	push cs:[Debuggee.cpu._Cs]
	push cs:[Debuggee.cpu._Eip]
endif
	jmp Int01HandlerEx
int41break endp

;--- int 41h handler proc

I41_FORCEDGO equ 0
I41_HIDEUNTILBREAK equ 1

Int41Handler proc
	@switchcs
	cmp cs:[bExecuting],0
	jz default
	cmp ax,004Fh		;debugger present?
	jz int41_4F
if I41_FORCEDGO
	cmp ax,0040h		;breakpoint CX:BX?
	jz int41_40
	cmp ax,0F003h		;breakpoint CX:EBX?
	jz int41_F003
endif
	cmp ax,0059h		;start NE task? CX:BX=entry
	jz int41_59
	cmp ax,0159h		;start PE task? CX:EBX=entry
	jz int41_159
	cmp ax,007Fh		;DS_CheckFault
	jz int41_7F
	cmp ax,0083h		;exception?
	jz int41_83
	cmp ax,0002h		;display string at ds:esi
	jz int41_2
	cmp ax,0012h		;display string at ds:si
	jz int41_12
default:
	jmp cs:[OldInt41]
int41_4F:
if I41_HIDEUNTILBREAK
	cmp cs:[bExecuting],1
	jnz default
endif
	mov ax,0F386h
	@iret
int41_7F:
if ?DEBUGLEVEL
	push ds
	mov ds,cs:[g_dsreg]
	invoke String2File, CStr("int 41, ax=7Fh occured, CX=")
	invoke DWord2File, ecx
	invoke String2File, CStr(", BX=")
	invoke DWord2File, ebx
	invoke String2File, CStr(13,10)
	pop ds
endif
	test cx,10h			;FIRST chance = 8, LAST chance = 10h
	jz @F
	xor ax,ax			;we want LAST chance only!
@@:
	@iret
int41_83:
	push ds
	mov ds,cs:[g_dsreg]
	mov ExceptionFlag,bl
	mov Debuggee.cpu._Eip,edx
	mov Debuggee.cpu._Efl,edi
	mov Debuggee.cpu._Cs,cx
if ?DEBUGLEVEL
	invoke String2File, CStr("int 41, ax=83h occured, EBX=")
	invoke DWord2File, ebx
	invoke String2File, CStr(13,10)
endif
	mov ecx,cs
	mov edx,offset int41exc
	pop ds
	@iret


int41_59:
	push ds
	mov ds,cs:[g_dsreg]
	mov DebugModule, es
;	pop ds
;	@iret
	movzx ebx, bx
	jmp @F
int41_159:
	push ds
	mov ds,cs:[g_dsreg]
	mov DebugModule, esi
;	pop ds
;	@iret

;int41_F003:
;int41_40:
;	push ds
;	mov ds,cs:[g_dsreg]
if ?DEBUGLEVEL
	invoke String2File, CStr("int 41, ax=40h/F003h occured, CS:EIP=")
	invoke DWord2File, ecx
	invoke String2File, CStr(":")
	invoke DWord2File, ebx
	invoke String2File, CStr(13,10)
endif
@@:
	mov [Debuggee.cpu._Cs],cx
if 0;?DPMI16
	movzx ebx,bx
endif
	mov [Debuggee.cpu._Eip],ebx
	pop ds
	mov ecx,cs
	mov ebx,offset int41break
	@iret

int41_12:
int41_2:
	pushad
	cmp ax,12h
	jnz @F
	movzx esi,si
@@:
	cmp cs:[bExecuting],1		;dont stop if debuggee not running
								;or just loading
	jz msg_to_wd
	push es
	push ds
	mov edx,esi
	xor ecx,ecx
	.while (byte ptr [edx+ecx])
		inc ecx
	.endw
	call StartLog
	call WriteLog
	call EndLog
	pop ds
	pop es
	popad
	@iret
msg_to_wd:
	mov edi,offset ProgCommand
	push es
	mov es,cs:[g_dsreg]
	mov es:pErrorMessage, edi
	mov ecx,100h
@@:
	lodsb
	stosb
	and al,al
	loopnz @B
;	mov es:pErrorMessage, CStr("abcdefg")
	pop es
	popad
	jmp SaveRegsInt

Int41Handler endp

GetPrivateProfileStringA proto stdcall :ptr byte, :ptr byte, :ptr byte, :ptr byte, :dword, :ptr byte

;*******************************************************************************
;
;Read config file if one exists.
;
;*******************************************************************************
ReadConfig proc near

local	szVar[16]:byte
;
;Try in the current directory.
;
	mov edx, offset szConfigFile
	mov ax,3D00h
	mov cx,0
	int 21h
	jc @@0rc
	mov ebx, eax
	mov ah,3Eh
	int 21h
;	invoke DisplayMsg, CStr("config file found in current dir",13,10)
	jmp @@3rc
;
;Get the execution path and use it to find the configuration file.
;
@@0rc:
;	invoke DisplayMsg, CStr("searching config in execution path",13,10)
	mov ebx, g_psp
	mov ax,6
	int 31h
	push cx
	push dx
	pop edx
	mov bx,@flat:[edx+2ch]
	mov ax,6
	int 31h
	push cx
	push dx
	pop edi
ife ?FLAT
if	?DPMI16
	push es
	push @flat
	pop es
else
	sub edi, [__baseadd]
endif
endif
	or ecx,-1
	xor al,al
@@4rc:
	repne scasb
	cmp byte ptr @flat:[edi],0
	jnz @@4rc
if ?DPMI16
	pop es
endif
	add edi,3
	mov esi,edi
	mov edi,offset ConfigName
if ?DPMI16
	push ds
	push @flat
	pop ds
endif
	invoke strcpy,edi,esi
if ?DPMI16
	pop ds
endif
	invoke strlen,edi
	mov esi,edi
	add edi,eax
@@1rc:
	dec edi
	cmp esi,edi
	jnc @@2rc
	cmp byte ptr [edi],"\"
	jnz @@1rc
@@2rc:
	mov byte ptr [edi+1],0
	mov edi,esi
	mov esi,offset szConfigFile
	invoke strcat,edi,esi
	;

	mov edx, offset ConfigName
	mov ax,3D00h
	mov cx,0
	int 21h
	jc @@9rc
	mov ebx, eax
	mov ah,3Eh
	int 21h
;	invoke DisplayMsg, CStr("config file found in execution path",13,10)
;
;config file exists so fetch our variables.
;
@@3rc:
	.if ( g_bLoader )
		invoke GetPrivateProfileStringA, addr szOptions, CStr("Loader"),
			CStr("1"), addr szVar, sizeof szVar, addr ConfigName
		.if (eax)
			mov al,szVar
			sub al,'0'
			mov g_bLoader,al
		.endif
	.endif
	invoke GetPrivateProfileStringA, addr szOptions, CStr("Debug"),
		CStr("0"), addr szVar, sizeof szVar, addr ConfigName
	.if (eax)
		mov al,szVar
		sub al,'0'
		jc @F
		cmp al,2
		jnb @F
		mov g_bDebugLevel,al
@@:
	.endif
if ?INTPMEXC
	invoke GetPrivateProfileStringA, addr szOptions, CStr("TrapIntExc"),
		CStr("0"), addr szVar, sizeof szVar, addr ConfigName
	.if (eax)
		mov al,szVar
		sub al,'0'
		mov g_bTrapIntExc,al
	.endif
endif
if ?DPMI16
	invoke GetPrivateProfileStringA, addr szOptions, CStr("UseCsAlias"),
		CStr("1"), addr szVar, sizeof szVar, addr ConfigName
	.if (eax)
		mov al,szVar
		sub al,'0'
		mov g_bUseCsAlias,al
	.endif
endif
	invoke GetPrivateProfileStringA, addr szOptions, CStr("Breakkeys"),
		CStr(), addr szVar, sizeof szVar, addr ConfigName
	.if (eax)
		lea esi, szVar
		mov ecx, sizeof BreakKeyList / 4
		mov edi, offset BreakKeyList
@@:
		push ecx
		invoke Ascii2Bin, esi
		pop ecx
		jc @F
		stosd
		mov esi, edx
		loop @B
@@:
	.endif
;
@@9rc:
;	invoke DisplayMsg, CStr("exit readconfig",13,10)
	ret
ReadConfig endp

;*******************************************************************************
;
;Loads the timer with value specified.
;
;On Entry:
;
;AX - Value to load timer with.
;
;On Exit:
;
;All registers preserved (except AL).
;
;*******************************************************************************
if 0
LoadTimer proc near
	cli
	jmp @@8lt
@@8lt:
	jmp @@9lt
@@9lt:
	push ax
	mov al,36h
	out 43h,al
	pop ax
	jmp @@0lt
@@0lt:
	jmp @@1lt
@@1lt:
	out 40h,al
	mov al,ah
	jmp @@2lt
@@2lt:
	jmp @@3lt
@@3lt:
	out 40h,al
	in al,21h
	and al,not 1
	out 21h,al
	sti
	ret
LoadTimer endp
endif

DWord2File proc stdcall dwNum:DWORD

	cmp g_bDebugLevel,0
	jz exit
	pushad
	push es
	push ds
	pop es					;es may have any value!
	mov edi, offset szTemp
	mov ecx,4
	mov esi, dwNum
	bswap esi
@@:
	push ecx
	mov eax, esi
	shr esi,8
	invoke Byte2Ascii, eax, edi
	mov edi, eax
	pop ecx
	loop @B
	invoke String2File, addr szTemp
	pop es
	popad
exit:
	ret
DWord2File endp

;--- dump bytes at linear address pBytes to file

Dump2File proc stdcall pszPrefix:ptr byte, pBytes:ptr, dwLength:dword, bSkipLF:dword

	call StartLog
	mov esi,pBytes
	mov ecx,dwLength
nextline:
	push ecx
	push esi
	mov edi,offset DebugBuffer
	push edi
	mov ecx,80
	mov al," "
	rep stosb
	pop edi
	mov esi,pszPrefix
	mov ecx,80
@@:
	lodsb
	stosb
	and al,al
	loopnz @B
	dec edi
	pop esi
	pop ecx

	xor edx,edx
	lea ebx, [edi + 16*3 + 2]

@@1rf:
	or ecx,ecx
	jz @@2rf
	cmp edx,16
	jz @@2rf
	mov al,@flat:[esi]
	inc esi
	inc edx
	dec ecx
	mov ah,al
	cmp ah," "
	jnb @F
	mov ah,"."
@@:
	mov [ebx],ah
	inc ebx
	push ecx
	invoke Byte2Ascii, eax, edi
	mov edi,eax
	pop ecx
	inc edi
	jmp @@1rf
	;
@@2rf:
	mov edi, ebx
	mov byte ptr [edi],13
	inc edi
	mov byte ptr [edi],10
	inc edi
	push ecx
	mov edx,offset DebugBuffer
	sub edi,edx
	mov ecx,edi
	call WriteLog
	pop ecx
	or ecx,ecx
	jnz nextline

	.if (!bSkipLF)
		mov DebugBuffer,13
		mov DebugBuffer+1,10
		mov edx,offset DebugBuffer
		mov ecx,2
		call WriteLog
	.endif

	call EndLog

@@ballsrf:
	ret
Dump2File endp

if 1;?DEBUGLEVEL

reqstr struct
bReq	db ?
pReq	dd ?
reqstr	ends

@reqstr macro x
local y
	.const
y	db @CatStr(!",@SubStr(x,5),!"),0
	.code
	reqstr <?REQ,y>
	?REQ = ?REQ + 1
endm

ReqTab label reqstr
	?REQ = 6
	@reqstr <REQ_GET_SYS_CONFIG>
	@reqstr <REQ_MAP_ADDR>
if ?V19
	@reqstr <REQ_ADDR_INFO>
endif
	@reqstr <REQ_CHECKSUM_MEM >
	@reqstr <REQ_READ_MEM>
	@reqstr <REQ_WRITE_MEM >
	@reqstr <REQ_READ_IO   >
	@reqstr <REQ_WRITE_IO  >
if ?V19
	@reqstr <REQ_READ_CPU  >
	@reqstr <REQ_READ_FPU  >
	@reqstr <REQ_WRITE_CPU >
	@reqstr <REQ_WRITE_FPU >
endif
	@reqstr <REQ_PROG_GO   >
	@reqstr <REQ_PROG_STEP >
	@reqstr <REQ_PROG_LOAD >
	@reqstr <REQ_PROG_KILL >
	@reqstr <REQ_SET_WATCH >
	@reqstr <REQ_CLEAR_WATCH>
	@reqstr <REQ_SET_BREAK	>
	@reqstr <REQ_CLEAR_BREAK>
	@reqstr <REQ_GET_NEXT_ALIAS>
	?REQ = 30
	@reqstr <REQ_GET_LIB_NAME  >
	@reqstr <REQ_GET_ERR_TEXT  >
	@reqstr <REQ_GET_MESSAGE_TEXT>
	@reqstr <REQ_REDIRECT_STDIN  >
	@reqstr <REQ_REDIRECT_STDOUT >
	?REQ = 36
	@reqstr <REQ_READ_REGS >
	@reqstr <REQ_WRITE_REGS >
	@reqstr <REQ_MACHINE_DATA>

SIZEREQTAB equ ($ - ReqTab) / sizeof reqstr

szLF db 13,10,0

TranslateReq proc stdcall pszReq:ptr byte

	invoke String2File, offset szReq
	mov edx, pszReq
	mov al,[edx]
	and al,7Fh
	mov edi, offset ReqTab
	mov ecx, SIZEREQTAB
	.while (ecx)
		.if (al == [edi].reqstr.bReq)
			invoke String2File, [edi].reqstr.pReq
			.break
		.endif
		add edi, sizeof reqstr
		dec ecx
	.endw
	invoke String2File, offset szLF
	ret
TranslateReq endp
endif

;*******************************************************************************
;Display contents of request buffer to file for debugging.
;*******************************************************************************
DumpRequest2File proc near
	pushad
	mov esi,ReqAddress
	mov esi,@flat:[esi+0]		;point to data.
if 1;?DEBUGLEVEL
	invoke TranslateReq, offset ReqBuffer
endif
	invoke Dump2File, offset szReq, esi, ReqLength, 0
	popad
	ret
DumpRequest2File endp

;--- display error reply to file

DumpError2File proc near stdcall
	pushad
	invoke Dump2File, offset szError, esi, 1, 0
	popad
	ret
DumpError2File endp

;*******************************************************************************
;write contents of reply tp file
;*******************************************************************************
DumpReply2File proc near
	pushad
	mov esi,ReqAddress
	mov ecx,@flat:[esi+4]
	mov esi,@flat:[esi+0]
	invoke Dump2File, offset szReply, esi, ecx, 0
	popad
	ret
DumpReply2File endp

;*******************************************************************************
;
;Change the border colour. Provided mainly for simplistic debugging.
;
;On Entry:
;
;AL 	- colour to set.
;
;Returns:
;
;ALL registers preserved.
;
;*******************************************************************************
Bord proc near
	push ax
	push dx
	mov ah,al
	mov dx,3dah
	in al,dx
	mov dl,0c0h
	mov al,11h
	out dx,al
	mov al,ah
	out dx,al
	mov al,20h
	out dx,al
	pop dx
	pop ax
	ret
Bord endp

Byte2Ascii proc near stdcall uses edi number:dword, pBuffer:dword

	mov edi, pBuffer
	mov eax,number
	push eax
	shr al,4
	call Nibble
	pop eax
	call Nibble
	mov eax, edi
	ret
Nibble:
	and al,0Fh
	add al,'0'
	cmp al,'9'
	jbe @F
	add al,7
@@:
	stosb
	retn
Byte2Ascii endp

Word2Ascii proc near stdcall number:dword, pBuffer:dword
	movzx eax, byte ptr number+1
	Invoke Byte2Ascii, eax, pBuffer
	Invoke Byte2Ascii, number, eax
	ret
Word2Ascii endp

DWord2Ascii proc near stdcall number:dword, pBuffer:dword
	movzx eax, word ptr number+2
	Invoke Word2Ascii, eax, pBuffer
	Invoke Word2Ascii, number, eax
	ret
DWord2Ascii endp

;--- convert numeric string to decimal value
;--- return value in eax, ptr behind number in edx
;--- C if no valid digit found

Ascii2Bin proc near stdcall uses esi pszNumber:ptr byte

	mov esi, pszNumber
	xor edx,edx
	.while (byte ptr [esi] == ' ')
		inc esi
	.endw
	mov cl,0
@@:
	cmp byte ptr [esi],0
	jz done
	lodsb
	and al,al
	jz done
	sub al,'0'
	jc done
	cmp al,9
	ja done
	inc cl
	movzx eax,al
	add edx,edx
	lea edx,[edx+edx*4]
	add edx,eax
	jmp @B
done:
	mov eax,edx
	mov edx,esi
	cmp cl,1
	ret
Ascii2Bin endp

;--- copy string from DS:strg1 to ES:strg2
;--- returns string length incl 0 in eax

strcpy proc c uses esi edi strg1:ptr byte,strg2:ptr byte

	mov esi,strg2	  ;quellstring
	mov edi,strg1
@@:
	lodsb
	stosb
	and al,al
	jnz @B
	mov eax, edi
	sub eax, strg1
	ret
strcpy endp

strcat proc c uses esi edi string1:ptr byte,string2:ptr byte

	xor eax,eax
	mov ecx,-1
	mov edi,string2
	repne scasb
	push ecx
	mov edi,string1
	repne scasb
	dec edi
	pop ecx
	not ecx
	mov esi,string2
	shr ecx,1
	rep movsw
	adc ecx,ecx
	rep movsb
	mov eax,string1
	ret
strcat endp

strlen proc c strg:ptr byte

	mov edx,edi
	mov edi,strg
	xor ecx,ecx
	dec ecx
	mov al,00
	repne scasb
	not ECX
	dec ECX
	mov eax,ecx
	mov edi,edx
	ret
strlen endp

if ?DLL
mainCRTStartup proc stdcall hModule:dword, dwReason:dword, reserved:dword
else
mainCRTStartup proc c public
endif
if ?FLAT
  if ?DLL
	cmp dwReason, 1		;DLL_PROCESS_ATTACH?
	jz @F
	ret
@@:
	mov [g_dsreg],ds
	mov eax, hModule
  else
	mov [g_dsreg],ds
	xor edx, edx
	mov ax,4B82h		;DPMILDR API: get module handle
	int 21h
	jnc @F
	mov eax, esi		;with LOADPE, esi = handle of HXHELP.EXE
	mov g_bLoader, 0
@@:
  endif
	mov [g_dwHelperStart],eax	;start of hxhelp module
	mov esi, eax
	mov eax, [esi+3Ch]
	add eax, esi
	mov eax, [eax].IMAGE_NT_HEADERS.OptionalHeader.SizeOfImage
	lea eax, [esi+eax]
else
	mov [g_dsreg],ds
	mov dx,ds
	mov cl,1
	mov ax,4b88h		;DPMILDR API: get 16-bit module handle
	int 21h
	jc error
	movzx eax,ax
	mov g_hModuleHelper,eax
	mov ax,6
	mov bx,ds
	int 31h
	push cx
	push dx
	pop eax
	mov [g_dwHelperStart],eax
  if ?DPMI16
	movzx ebp,sp
	add eax,ebp
  else
	add eax,esp
  endif
endif
	mov [g_dwHelperEnd], eax

;--- clear .data?

ife ?FLAT
	push ds
	pop es
endif
	mov edi, offset WatchTable
	mov ecx, offset loadstack - offset WatchTable
	shr ecx, 2
	xor eax, eax
	rep stosd

	mov ah,62h
	int 21h
	mov [g_psp], ebx	;selector PSP
	mov ax,3306h
	int 21h
	cmp bx,3205h		;running on NT/2K/XP?
	jnz @F
	mov g_bIsNT,1
@@:
	mov ax,1600h
	int 2fh
	cmp al,0
	jz @F
	mov g_bIsWin9x,1
@@:
if ?CLOSE5
	mov ebx,5			;WD seems to open WD.EXE! This file
	mov ah,3Eh			;is then inherited by HXHELP.EXE
	int 21h
endif
if ?DPMI16
	push ds
	pop es
	mov ax,0
	mov cx,2			;allocate 2 descriptors
	int 31h
	jnc @F
	invoke DisplayMsg, CStr("out of LDT descriptors",13,10)
	mov ax,4cffh
	int 21h
@@:
	mov ebx,eax
	or cx,-1
	or dx,-1
	mov ax,8
	int 31h
	mov [g_flatsel],ebx
	mov @flat,ebx
	add ebx,8
	mov edi,offset ProgName	;use this as temp buffer
	push ebx
	mov ebx,cs
	mov ax,000Bh
	int 31h
	pop ebx
	mov g_cs16alias,ebx
	and byte ptr [di+6],not 40h
	mov ax,000Ch
	int 31h

	mov al, g_bIsNT
	or al, g_bIsWin9x
	jz @F
	or g_bUseCsAlias,-1	;use csalias on winnt and win9x
@@:
else
  ife ?FLAT
	mov [g_flatsel],@flat
  else
	mov ecx, ds
	lar eax, ecx
	test ah,4		;is DS expand down?
	jz noflatneeded
	mov ax,0
	mov cx,1
	int 31h
	jc noflatneeded	;this is not fatal
	mov [g_flatsel],eax
	mov ebx,eax
	xor ecx,ecx
	xor edx,edx
	mov ax,7
	int 31h
	dec ecx
	dec edx
	mov ax,8
	int 31h
noflatneeded:
  endif
endif
	call main
	push eax
if ?DPMI16
	mov ebx, g_cs16alias
	mov ax,1
	int 31h		;free descriptor
	push 0
	pop @flat
	sub ebx,8
	mov ax,1
	int 31h		;free descriptor
else
 if ?FLAT
	mov ebx,g_flatsel
	and ebx,ebx
	jz @F
	mov ax,1
	int 31h
@@:
 endif
endif
	pop eax
if ?DLL
	mov eax,1
error:
	ret
else
error:
	mov ah,4ch
	cmp word ptr [OldInt21+?SEGOFS],0
	jz @F
	@callint21
@@:
	int 21h
endif
mainCRTStartup endp

	end mainCRTStartup
