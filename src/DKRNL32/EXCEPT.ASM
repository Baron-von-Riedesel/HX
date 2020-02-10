
;--- structured exception handling
;--- implements: 
;--- SetUnhandledExceptionFilter()
;--- UnhandledExceptionFilter()
;--- RaiseException()

	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:none

	.nolist
	include winbase.inc
	include dkrnl32.inc
	include excpt.inc
	include macros.inc
	include heap32.inc
	include tlhelp32.inc
	.list

	option dotname

TIBSEG segment use16
TIBSEG ends

	assume fs:TIBSEG	;declare FS=TIB a 16 bit segment (saves space)

?NOSEH		equ 0	;std=0, 1=dont install SEH

?CHECKKD    equ 0	;std=0, 1=dont install if kernel debugger present.
					;this shouldnt be set normally because an app
					;may rely on exceptions. The debugger will always
					;be notified if UnhandledExceptionFilter is called
?CATCHEXC01	equ 1	;std=1, catch debug exceptions
?CATCHEXC03	equ 1	;std=1, catch breakpoint opcodes
?CATCHEXC04	equ 1	;std=1, catch integer overflow exceptions
?CATCHEXC05	equ 1	;std=1, catch bound exceptions
?CATCHEXC0C equ 1	;std=1, stack overflows will generate an exc 0E,
					;but accessing SS:[0-3FFh] when ED bit is set will cause 
					;exc 0C!
?CATCHEXC11 equ 1	;std=1, support alignment exceptions 11h
?FLOATSUPP	equ 1	;std=1, support floating point exceptions 10h

;--- best would be to mask IRQ 0D and rely on exception 10h
;--- but regretably this doesnt work on many platforms (HDPMI does!)

?IRQ0DSUPP	equ 0	;std=0, 1=install handler for int 75h.
					;since there is no way to switch stacks back
					;it's a not so good idea to use INT 75h at all.

?USECLIENTSTACK	equ 0	;std=0, dont set to 1!

DS_CheckFault equ 7Fh	;BX=fault, CX=fault mask, out:ax=0 -> normal handling
DEBUG_FAULT_TYPE_FIRST	equ 08h
DEBUG_FAULT_TYPE_LAST	equ 10h
DS_TrapFault  equ 83h	;fault at CX:EDX, fault=BX esi=error code edi=flags            
						;returns replacement CS:EIP in CX:EDX

?CONTEIP equ 1	;test
?CONTESP equ 1	;test

ife ?FLAT
        public _USESEH            ;um dies fuer NE/MZ-Files einzubinden
_USESEH equ 12345678h
endif

ife ?NOSEH

.BASE$IA segment dword public 'DATA'
	dd offset InitException
.BASE$IA ends
.BASE$XA segment dword public 'DATA'
	dd offset ExitException
.BASE$XA ends


if ?FLAT eq 0
DGROUP  group .BASE$IA, .BASE$XA, _TEXT, _DATA
endif

endif

EXCDESC struct
bException db ?
oldhandler dq ?
newhandler dd ?
win32exc   dd ?
EXCDESC ends

MYEXC struct
rEip	dd ?
rCS		dd ?
dwExcNo	dd ?	;4 parameters for RaiseException
dwFlags	dd ?
numArgs	dd ?
pArgs	dd ?
MYEXC ends

RtlUnwind proto stdcall :ptr EXCEPTION_REGISTRATION, :DWORD, :ptr EXCEPTION_RECORD, :DWORD

	.DATA

g_dwCurrEsp dd 0

protoTOP_LEVEL_EXCEPTION_FILTER typedef proto :DWORD
LPTOP_LEVEL_EXCEPTION_FILTER typedef ptr protoTOP_LEVEL_EXCEPTION_FILTER

;--- the default unhandled exception filter proc (process specific!)
;--- set by SetUnhandledExceptionFilter()

uhefilter LPTOP_LEVEL_EXCEPTION_FILTER NULL

exclist label EXCDESC
exc00   EXCDESC <00h,0,offset _exc00, EXCEPTION_INT_DIVIDE_BY_ZERO>
if ?CATCHEXC01
exc01   EXCDESC <01h,0,offset _exc01, EXCEPTION_SINGLE_STEP>
endif
if ?CATCHEXC03
exc03   EXCDESC <03h,0,offset _exc03, EXCEPTION_BREAKPOINT>
endif
if ?CATCHEXC04
exc04   EXCDESC <04h,0,offset _exc04, EXCEPTION_INT_OVERFLOW>
endif
if ?CATCHEXC05
exc05   EXCDESC <05h,0,offset _exc05, EXCEPTION_ARRAY_BOUNDS_EXCEEDED>
endif
exc06   EXCDESC <06h,0,offset _exc06, EXCEPTION_ILLEGAL_INSTRUCTION>
if ?CATCHEXC0C
exc0C   EXCDESC <0Ch,0,offset _exc0C, EXCEPTION_STACK_OVERFLOW>
endif   
exc0D   EXCDESC <0Dh,0,offset _exc0D, EXCEPTION_ACCESS_VIOLATION>
exc0E   EXCDESC <0Eh,0,offset _exc0E, EXCEPTION_ACCESS_VIOLATION>
if ?FLOATSUPP
exc10   EXCDESC <10h,0,offset _exc10, 0>
endif
if ?CATCHEXC11
exc11   EXCDESC <11h,0,offset _exc11, EXCEPTION_DATATYPE_MISALIGNMENT>
endif
        db -1

if ?IRQ0DSUPP
oldint75 df 0
dwExcEip dd 0
endif
if ?FLOATSUPP
bIrq0DMasked db 0
	public g_bFPUPresent
g_bFPUPresent  db 0
endif
g_cntStack	db 0
g_bDebug	db 0

	align 4

g_Args		dd 0, 0

ife ?USECLIENTSTACK
g_myexc	MYEXC <>
g_Eflags dd ?
;g_ErrCode dd ?
endif

	public g_defaultregistration

g_defaultregistration label dword
	dd -1
	dd offset _defaultexceptionhandler
	dd 0
	dd -1

	.CONST

szFatalExit	db "dkrnl32: fatal exit!",lf,0
excstr	db lf
	db "dkrnl32: exception %X, flags=%X occured at %X:%X",lf
	db 9,"ax=%X bx=%X cx=%X dx=%X",lf
	db 9,"si=%X di=%X bp=%X sp=%X",lf
	db 0

	.CODE

?PROTECT equ 1	;don't allow exceptions during module search
?EXTMOD equ 0	;std=0

GetModuleForEip proc rEip:dword, pME:ptr MODULEENTRY32        

if ?PROTECT
	xor edx, edx
	push offset exception_read
	push fs:[edx]
	mov fs:[edx], esp
endif

	mov edx, pME
	mov [edx].MODULEENTRY32.dwSize, sizeof MODULEENTRY32
	invoke Module32First, 0, edx
	.while (eax)
		mov ecx, rEip
		mov eax, pME
		mov edx, [eax].MODULEENTRY32.modBaseAddr
		add edx, [eax].MODULEENTRY32.modBaseSize
		.if ((ecx >= [eax].MODULEENTRY32.modBaseAddr) && (ecx < edx))
ifdef _DEBUG
			@trace <"Module: ">
			@tracedw [eax].MODULEENTRY32.modBaseAddr
			@trace <" ">
			lea ecx, [eax].MODULEENTRY32.szModule
			@trace ecx
			@trace <13,10>
endif           
			mov eax, 1
			.break
		.endif
if ?EXTMOD
		sub esp,120h
		mov ecx, esp
		lea edx, [eax].MODULEENTRY32.szModule
		invoke _sprintf, ecx, CStr(<9,"%X Siz=%X Name='%s'",lf>), \
			[eax].MODULEENTRY32.modBaseAddr, [eax].MODULEENTRY32.modBaseSize, edx
		invoke Display_szString, esp
		add esp,120h
endif
		invoke Module32Next, 0, pME
	.endw
if ?PROTECT
	xor edx, edx
	pop fs:[edx]
	pop ecx			;adjust stack (offset exception)
endif
	ret
if ?PROTECT
done:
	xor eax, eax
	pop fs:[eax]
	pop ecx
	ret
exception_read:
	mov eax, [esp+12]	;get context
	mov [eax].CONTEXT.rEip, offset done
	@strace <"*** exception caught inside GetModuleForEip()">
	xor eax, eax		;== _XCPT_CONTINUE_EXECUTION
	retn
endif
	align 4

GetModuleForEip endp        

MakeErrorString proc uses ebx pExceptInfo:dword, pszText:ptr BYTE

	mov ebx, pExceptInfo
	mov edx, [ebx].EXCEPTION_POINTERS.ExceptionRecord
	mov ecx, [ebx].EXCEPTION_POINTERS.ContextRecord
	push [ecx].CONTEXT.rEsp
	push [ecx].CONTEXT.rEbp
	push [ecx].CONTEXT.rEdi
	push [ecx].CONTEXT.rEsi
	push [ecx].CONTEXT.rEdx
	push [ecx].CONTEXT.rEcx
	push [ecx].CONTEXT.rEbx
	push [ecx].CONTEXT.rEax
	push [edx].EXCEPTION_RECORD.ExceptionAddress
	push [ecx].CONTEXT.SegCs
	push [edx].EXCEPTION_RECORD.ExceptionFlags
	push [edx].EXCEPTION_RECORD.ExceptionCode
	push offset excstr
	push pszText
	call _sprintf
	add esp,14*4
	ret
	align 4

MakeErrorString endp

;--- no need to preserve ebx, esi, edi inside the next proc

myueproc proc pExceptInfo:dword

local szText[160]:byte

if 0
	@strace <"default unhandled exception proc(", pExceptInfo, ") ebp=", ebp>
endif
	invoke MakeErrorString, pExceptInfo, addr szText
	invoke Display_szString, addr szText

	mov ecx, pExceptInfo
	mov ecx, [ecx].EXCEPTION_POINTERS.ExceptionRecord
	.if (([ecx].EXCEPTION_RECORD.ExceptionCode == EXCEPTION_ACCESS_VIOLATION) && ([ecx].EXCEPTION_RECORD.NumberParameters == 2) && (g_bHost == HF_HDPMI))
		invoke _sprintf, addr szText, CStr(<9,"exception caused by access to memory address %X",lf>), \
			dword ptr [ecx].EXCEPTION_RECORD.ExceptionInformation+4
		invoke Display_szString, addr szText
	.endif

if 1
;--- display module where exception happened
	mov ecx, pExceptInfo
	mov ecx, [ecx].EXCEPTION_POINTERS.ExceptionRecord
	sub esp, sizeof MODULEENTRY32
	invoke GetModuleForEip, [ecx].EXCEPTION_RECORD.ExceptionAddress, esp
	.if (eax)
		mov edx, esp
		mov ecx, pExceptInfo
		mov ecx, [ecx].EXCEPTION_POINTERS.ExceptionRecord
		mov eax, [ecx].EXCEPTION_RECORD.ExceptionAddress
		sub eax, [edx].MODULEENTRY32.modBaseAddr
		invoke _sprintf, addr szText, CStr(<9,"ip = Module '%s'+%X",lf>), \
			addr [edx].MODULEENTRY32.szModule, eax
		invoke Display_szString, addr szText
	.endif
	add esp, sizeof MODULEENTRY32
endif

if ?CONTEIP

externdef byt2asc:near ;display AL into [edi]

;--- display [eip], 12 bytes
	invoke lstrcpy, addr szText, CStr(<9,"[eip] = ">)
	mov ecx, pExceptInfo
	mov ecx, [ecx].EXCEPTION_POINTERS.ExceptionRecord
	mov ebx, [ecx].EXCEPTION_RECORD.ExceptionAddress
	invoke IsBadReadPtr, ebx, 12
	and eax, eax
	jnz @F
	mov ecx, 12
	lea edi, szText+9
	.repeat
		push ecx
		mov al, [ebx]
		inc ebx
		mov dl,0
		call byt2asc
		mov al,' '
		stosb
		pop ecx
	.untilcxz
	mov ax, 0Ah
	stosw
	invoke Display_szString, addr szText
@@:
endif

if ?CONTESP

externdef __dw2aX:near ;display EAX into [edi]

;--- display [esp], 6 dwords
	invoke lstrcpy, addr szText, CStr(<9,"[esp] = ">)
	mov ecx, pExceptInfo
	mov esi, [ecx].EXCEPTION_POINTERS.ContextRecord
if 1
	mov ebx, [esi].CONTEXT.SegSs
	xor edi, edi
	mov ax,6	;in case SS isn't flat (pretty rare)
	int 31h
	jc @F
	shrd edi, ecx, 16
	mov di, dx
@@:
	mov ebx, edi
	add ebx, [esi].CONTEXT.rEsp
else
	mov ebx, [esi].CONTEXT.rEsp
endif
	invoke IsBadReadPtr, ebx, 6*4
	and eax, eax
	jnz @F
	mov ecx, 6
	lea edi, szText+9
	.repeat
		push ecx
		mov eax, [ebx]
		add ebx, 4
		mov dl,0
		call __dw2aX
		pop ecx
		mov al,' '
		stosb
	.untilcxz
	mov ax, 10
	stosw
	invoke Display_szString, addr szText
@@:
endif

ife ?FLAT
	mov ax,6
	mov ebx,cs
	int 31h
	shrd edx, ecx, 16
	invoke _sprintf, addr szText, CStr(<9,"base address=%X",lf>), edx
	invoke Display_szString, addr szText
endif
	mov ecx, pExceptInfo
if 0
	@trace <"ecx=">
	@tracedw ecx
	@trace <", ebp=">
	@tracedw ebp
	@trace <13,10,"[ecx.ER]=">
endif        
	mov ecx, [ecx].EXCEPTION_POINTERS.ExceptionRecord
if 0
	@tracedw ecx
	@trace <13,10,"[ecx.ER.Code]=">
endif
	mov eax, [ecx].EXCEPTION_RECORD.ExceptionCode
if 0
	@tracedw eax
	@trace <13,10>
endif        
	test eax, eax
	.if (SIGN? || ([ecx].EXCEPTION_RECORD.ExceptionFlags & 1))
		mov eax, EXCEPTION_EXECUTE_HANDLER
	.else
		mov eax, EXCEPTION_CONTINUE_EXECUTION
	.endif
;	@strace <"default unhandled exception proc exit">
	ret
	align 4

myueproc endp

SetUnhandledExceptionFilter proc public pFilterProc:ptr

	mov eax,pFilterProc
	xchg eax,uhefilter
	@strace <"SetUnhandledExceptionFilter(", pFilterProc, ")=", eax>
	ret
	align 4

SetUnhandledExceptionFilter endp

;--- transform win32 exc to dpmi exc

GetExcNo proc uses esi pExceptptr:ptr EXCEPTION_POINTERS

	mov ecx, pExceptptr
	mov ecx, [ecx].EXCEPTION_POINTERS.ExceptionRecord
	mov eax,[ecx].EXCEPTION_RECORD.ExceptionCode
	.if ((eax == EXCEPTION_ACCESS_VIOLATION) && ([ecx].EXCEPTION_RECORD.NumberParameters))
		mov ax,14
		jmp exit
	.endif
	mov esi,offset exclist
next:
	cmp [esi.EXCDESC.bException],-1
	jz notfound
	cmp eax,[esi.EXCDESC.win32exc]
	jz found
	add esi,sizeof EXCDESC
	jmp next
found:
	movzx ax,[esi].EXCDESC.bException
	ret
notfound:
	mov ax,1Fh
exit:
	ret
	align 4

GetExcNo endp


UnhandledExceptionFilter proc public uses ebx pExceptInfo:ptr EXCEPTION_POINTERS

local	szText[160]:byte

ifdef _DEBUG
	mov ecx, pExceptInfo
	mov edx, [ecx].EXCEPTION_POINTERS.ExceptionRecord
endif
	@strace <"UnhandledExceptionFilter(", ecx, " [ER=", edx, ", CR=", [ecx].EXCEPTION_POINTERS.ContextRecord, "]">
	@strace <"ExcRec: Code=", [ecx].EXCEPTION_RECORD.ExceptionCode, " Flgs=", [ecx].EXCEPTION_RECORD.ExceptionFlags, " Addr=", [ecx].EXCEPTION_RECORD.ExceptionAddress, " cntP=", [ecx].EXCEPTION_RECORD.NumberParameters>

;--- if a debugger has been detected, notify it of the exception

	.if (g_bDebug)
		invoke GetExcNo, pExceptInfo
		mov bx, ax
		.if (ax == 1Fh)
			invoke MakeErrorString, pExceptInfo, addr szText
			invoke OutputDebugString, addr szText
		.endif
		mov cx,DEBUG_FAULT_TYPE_LAST
		mov ax,DS_CheckFault
		int 41h
		.if (ax)
			push edi
			mov edx, pExceptInfo
			mov ecx, [edx].EXCEPTION_POINTERS.ContextRecord
			mov edx, [ecx].CONTEXT.rEip
			mov edi, [ecx].CONTEXT.EFlags
			mov ecx, [ecx].CONTEXT.SegCs
			mov ax, DS_TrapFault
			int 41h
			pop edi
			mov eax, pExceptInfo
			mov eax, [eax].EXCEPTION_POINTERS.ContextRecord
			.if (edx != [eax].CONTEXT.rEip)
				mov [eax].CONTEXT.rEip, edx
				mov [eax].CONTEXT.SegCs, ecx
				mov eax, EXCEPTION_CONTINUE_EXECUTION
				jmp done
			.endif
		.endif
	.endif
	mov eax, EXCEPTION_CONTINUE_SEARCH
	.if (uhefilter)
		@strace <"calling UEF proc ", uhefilter>
		invoke uhefilter, pExceptInfo
		@strace <"UEF proc returned with eax=", eax>
	.endif
	.if (eax != EXCEPTION_CONTINUE_EXECUTION)
;		.if (g_bFPUPresent)
;			fninit
;		.endif
		test byte ptr g_dwDebugFlags, DBGF_TEXTMODE
		jz @F
		push eax
		mov ax,3
		int 10h
		pop eax
@@:
		.if ( eax == EXCEPTION_CONTINUE_SEARCH )
			@strace <"calling default UEF proc">
			invoke myueproc, pExceptInfo
			@strace <"calling FatalAppExitA">
			invoke FatalAppExitA, 0, addr szFatalExit
		.else
			@strace <"calling RtlUnwind">
			mov eax, offset behind_unwind
			invoke RtlUnwind, -1, eax, 0, 0
behind_unwind:
			invoke ExitProcess, -1
		.endif
	.endif
done:
	ret
	align 4

UnhandledExceptionFilter endp

InitException proc

	pushad

	invoke IsDebuggerPresent
	test eax,eax
	setnz al
	mov g_bDebug,al
if ?CHECKKD
	.if (al)
		jmp done
	.endif
endif
	test byte ptr g_dwFlags,DKF_NODBGHOOK
	jz @F
	mov exc01.bException,-2
	mov exc03.bException,-2
@@:
	mov esi,offset exclist
@@:
	mov bl,[esi].EXCDESC.bException
	cmp bl,-1
	jz exit
	cmp bl,-2
	jz skip
	mov ax,0202h
	int 31h
	mov dword ptr [esi].EXCDESC.oldhandler+0,edx
	mov dword ptr [esi].EXCDESC.oldhandler+4,ecx
	test byte ptr g_dwFlags,DKF_NOEXCHOOK
	jnz skip
	mov ecx,cs
	mov edx,[esi].EXCDESC.newhandler
	mov ax,0203h
	int 31h
skip:
	add esi,sizeof EXCDESC
	jmp @B
exit:
if ?FLOATSUPP
	mov ax,0E00h	;this function will fail on NT platforms
	int 31h
	jnc @F
	int 11h			;here FPU is bit 1
	shl al,1		;so shift it to bit 2
@@:
	and al,4		;FPU present?
	mov g_bFPUPresent,al
if ?IRQ0DSUPP
	in al,0A1h
	and al,not 20h	;unmask int 75h
	out 0A1h,al
	mov bl,75h		;int 75h is a IRQ! SS will be LPMS!
	mov ax,0204h
	int 31h
	mov dword ptr oldint75+0,edx
	mov word ptr oldint75+4,cx
	mov ecx, cs
	mov edx, offset myint75
	mov ax,0205h
	int 31h
else
	mov ax,0e00h	;get FPU status
	int 31h
	mov ebx,eax
	or bl,1		;client uses FPU
	mov ax,0e01h
	int 31h
;--- one cannot rely on NE bit causing exception 10h for dpmi clients
;--- but at least mask IRQ 13 for HDPMI
	smsw ax
	test al,20h		;NE bit set?
	jz @F
if 0
	cmp g_bHost, HF_HDPMI
	jnz @F
endif
	in al,0A1h
	test al,20h		;is masked already?
	jnz @F
	or al,20h
	out 0A1h,al		;mask IRQ 0D
	mov bIrq0DMasked, 1
@@:
endif
endif
if 0
;--- this should happen for every task/thread
;--- so moved now to kernel32.asm
;	mov fs:[THREAD_INFORMATION_BLOCK.pvExcept],-1
endif
done:
	popad
	ret
	align 4

InitException endp

ExitException proc

	pushad
	@strace <"ExitException enter">
	mov esi,offset exclist
next:
	mov bl,[esi.EXCDESC.bException]
	cmp bl,-1
	jz exit
	mov ecx,dword ptr [esi.EXCDESC.oldhandler+4]
	jecxz @F
	mov edx,dword ptr [esi.EXCDESC.oldhandler+0]
	mov ax,0203h
	int 31h
@@:
	add esi,sizeof EXCDESC
	jmp next
exit:
if ?FLOATSUPP
if ?IRQ0DSUPP
	mov cx,word ptr oldint75+4
	jcxz @F
	mov edx, dword ptr oldint75+0
	mov bl,75h
	mov ax,0205h
	int 31h
@@:
else
	cmp bIrq0DMasked,0
	jz @F
	in al,0A1h
	and al,not 20h
	out 0A1h,al
@@:
endif
endif
	@strace <"ExitException exit">
	popad
	ret
	align 4

ExitException endp

;*** create an exception ***

	option prologue:none

RaiseException proc public dwExceptionCode:dword, dwExceptionFlags:dword,
		nNumArgs:dword, lpArguments: ptr

ifdef _DEBUG
	@trace <"RaiseException(">
	mov eax, [esp+4]	;dwExceptionCode
	@tracedw eax
	@trace <", ">
	mov eax, [esp+8]	;dwExceptionFlags
	@tracedw eax
	@trace <", ">
	mov eax, [esp+12]	;nNumArgs
	@tracedw eax
	@trace <", ">
	mov eax, [esp+16]	;lpArguments
	@tracedw eax
	@trace <")",13,10>
endif        

if 0
	and byte ptr [esp+8], 1	;reset bit 0 of dwExceptionFlags
endif

;--- a MYEXC structure has to be built onto the stack
;--- that's why EIP has to be poped, then CS:EIP to be pushed
;--- value of EAX is lost, but that shouldn't be a problem here

	pop    eax
	push   cs		;MYEXC.rCS
	push   eax		;MYEXC.rEip
if ?USECLIENTSTACK		  
calldoexc::
endif
	call   doexc2	;never returns
	align 4

RaiseException endp

	option prologue:prologuedef
        
ife ?USECLIENTSTACK
calldoexc:
	push cs:g_myexc.pArgs
	push cs:g_myexc.numArgs
	push cs:g_myexc.dwFlags
	push cs:g_myexc.dwExcNo
	push cs:g_myexc.rCS
	push cs:g_myexc.rEip
	push cs:g_Eflags
	popfd
	call doexc2		;doesn't return!
	align 4
endif

_defaultexceptionhandler proc c public pE:ptr EXCEPTION_RECORD, er:ptr EXCEPTION_REGISTRATION, pC:ptr CONTEXT

local	_ep:EXCEPTION_POINTERS

	mov eax, pE
	.if ([eax].EXCEPTION_RECORD.ExceptionFlags & _EH_UNWINDING)
		jmp exit
	.endif
	mov ecx, pC
	mov _ep.ExceptionRecord, eax
	mov _ep.ContextRecord, ecx
	invoke UnhandledExceptionFilter, addr _ep
exit:
	ret
	align 4

_defaultexceptionhandler endp

;*** ok, here we are in exception handling on the client (flat) stack
;*** registers are unchanged except cs:eip and esp

doexc2  proc except:MYEXC

local   excrec:EXCEPTION_RECORD

;--- for _SaveContext, build a CONTEXT_CTRL on the stack

	push ss						;current SS
	push esp 					;esp (to be adjusted yet)
	pushfd						;current EFlags
	push except.rCS				;current CS 
	push except.rEip			;current eip
	push [ebp+0]				;current ebp
ifdef _DEBUG
	pushad
	@trace <"*** exception ">
	@tracedw except.dwExcNo
	@trace <" EIP=">
	@tracedw except.rEip
	@trace <" EAX=">
	@tracedw eax
	@trace <" EBX=">
	@tracedw ebx
	@trace <" ECX=">
	@tracedw ecx
	@trace <" EDX=">
	@tracedw edx
	@trace <13,10," ESI=">
	@tracedw esi
	@trace <" EDI=">
	@tracedw edi
	mov ebx,fs
	movzx ebx,bx
	@trace <" FS=">
	@tracedw ebx
	@trace <" BaseFS=">
	mov ax,6
	int 31h
	push cx
	push dx
	pop eax
	@tracedw eax
	@trace <" FS:[0]=">
	@tracedw fs:[THREAD_INFORMATION_BLOCK.pvExcept]
	.if (except.numArgs)
		@trace <" arg[1]=">
		mov eax, except.pArgs
		@tracedw [eax+4]
	.endif
	@trace <13,10>
	popad
endif
	push eax
	mov eax, cs:g_dwCurrEsp
	and eax, eax
	jnz @F
	lea eax,except + sizeof MYEXC
@@:
	mov [esp+4].CONTEXT_CTRL.rEsp,eax
	pop eax
if ?GBLCURRENT        
	push cs:[g_hCurThread]
else
	sub esp,4
	push eax
	mov eax, fs:[THREAD_INFORMATION_BLOCK.pProcess]
	mov eax,[eax].PROCESS.hThread
	mov [esp+4],eax
	pop eax
endif
	call _SaveContext

	invoke GetCurrentProcess
	or byte ptr [eax].PROCESS.wFlags, PF_LOCKED
        
	mov eax, except.dwExcNo
	.if (eax >= STATUS_FLOAT_DENORMAL_OPERAND) && (eax <= STATUS_FLOAT_UNDERFLOW)
		fninit
	.endif
	mov g_dwCurrEsp, 0

	mov ax, 0901h	;enable interrupts
	int 31h

if 0;def _DEBUG
	sub esp, sizeof MODULEENTRY32
	invoke GetModuleForEip, except.rEip, esp
	add esp, sizeof MODULEENTRY32
	invoke _FlushLogFile
endif
	mov ecx, except.dwExcNo
	mov eax, except.dwFlags
	mov excrec.ExceptionCode, ecx
	mov excrec.ExceptionFlags, eax
	mov ecx, 0
	mov eax, except.rEip
	mov excrec.ExceptionRecord, ecx
	mov excrec.ExceptionAddress, eax
	mov ecx, except.numArgs
	mov excrec.NumberParameters, ecx
	mov esi, except.pArgs
	.if (esi)
		lea edi, excrec.ExceptionInformation
		rep movsd
	.endif
        
if 0;def _DEBUG
;--- if an exception occured while in process heap, make it free now
	invoke GetProcessHeap
	test [eax].HEAPDESC.flags, HEAP_NO_SERIALIZE
	jnz @F
	invoke ReleaseSemaphore, [eax].HEAPDESC.semaphor,1,0
@@:        
endif
	mov edi, fs:[THREAD_INFORMATION_BLOCK.pvExcept]
nextframe:
	or eax, -1
	cmp edi, eax
	jz exitloop
ifdef _DEBUG
	lea eax, [edi].EXCEPTION_REGISTRATION.ExceptionHandler
	invoke IsBadReadPtr, eax, 4
	.if (eax)
		invoke _GetCurrentThread
		invoke _defaultexceptionhandler, addr excrec, edi, [eax].THREAD.pContext
	.endif
	cmp [edi].EXCEPTION_REGISTRATION.ExceptionHandler, -1
else
	cmp [edi].EXCEPTION_REGISTRATION.ExceptionHandler, eax
endif
	jz exitloop
	@strace <"calling exception handler ", [edi].EXCEPTION_REGISTRATION.ExceptionHandler, ", esp=", esp>
if 1
	push ebp
endif
	mov esi, esp
ifdef _DEBUG
	invoke IsBadCodePtr, [edi].EXCEPTION_REGISTRATION.ExceptionHandler
	.if (eax)
		invoke _GetCurrentThread
		invoke _defaultexceptionhandler, addr excrec, edi, [eax].THREAD.pContext
	.endif
endif
	invoke _GetCurrentThread
	lea ecx, excrec
if 1 ;let EBP point to the very same stack frame (Borland C++!)
	lea ebp, [esp-6*4]
endif
	invoke [edi].EXCEPTION_REGISTRATION.ExceptionHandler, ecx,\
		edi, [eax].THREAD.pContext, 0
	@strace  <"returned from exception handler, eax=", eax, " esp=", esp>
	mov esp, esi
if 1
	pop ebp
endif
;--- may exit with
;--- eax == XCPT_CONTINUE_EXECUTION        
;--- eax == XCPT_CONTINUE_SEARCH

	cmp eax, _XCPT_CONTINUE_EXECUTION
	jz done
	mov edi, [edi].EXCEPTION_REGISTRATION.prev_structure
	jmp nextframe
exitloop:
done:
	call _GetCurrentThread
	push eax
	invoke GetCurrentProcess
	cli
	and byte ptr [eax].PROCESS.wFlags, not PF_LOCKED
	call _LoadContext
	align 4

doexc2  endp

;--- generic exception handler, interrupts disabled
;--- stack: ExceptionCode, dpmi eip/cs
;*** we switch stack back to client stack
;*** todo: first check if client stack ok;
;***       may not be the case if stack exception

?CLEARTIBPTR	= 0	;default!
if ?FLAT 
  if ?USECLIENTSTACK
?CLEARTIBPTR	= 1
  endif
endif

;--- these are the real dpmi exception handler entries

@exchandler macro x
_exc&x:
	push offset exc&x
	jmp  doexception
	endm

	@exchandler 00
if ?CATCHEXC01
	@exchandler 01
endif
if ?CATCHEXC03
	@exchandler 03
endif
if ?CATCHEXC04
	@exchandler 04
endif
if ?CATCHEXC05
	@exchandler 05
endif
	@exchandler 06
if ?CATCHEXC0C
	@exchandler 0C
endif
	@exchandler 0D
_exc0E:
	.if (cs:g_cntStack)
		push ds
		mov ds, cs:g_csalias
		dec g_cntStack
		pop ds
if ?CLEARHIGHEBP
		push ebp
		movzx ebp,sp
		mov [ebp+4].DPMIEXC.rEip, LOWWORD(offset afterstacktest)
		pop ebp
		db 66h
else
		mov [esp].DPMIEXC.rEip, offset afterstacktest
endif
		retf
	.endif
	push offset exc0E
	jmp doexception
if ?FLOATSUPP
	@exchandler 10
endif
if ?CATCHEXC11
	@exchandler 11
endif

;--- common entry for exceptions
;--- inp: SS:E/SP = excno, DPMIEXC (LPMS)

doexception proc

	cmp cs:[g_bIsActive],1
	jnb @F
	push eax
	mov eax,[esp+1*4]
	push dword ptr cs:[eax].EXCDESC.oldhandler+4
	push dword ptr cs:[eax].EXCDESC.oldhandler+0
	mov eax, [esp+2*4]
	retf 2*4
@@:
	pushad
if ?FLAT
	mov ebx,fs					;check for valid tib
	mov ax,0006
	int 31h
	jc notib
	push cx
	push dx
	pop esi
	cmp esi,fs:[THREAD_INFORMATION_BLOCK.ptibSelf]
	jz @F
notib:
;--- exception handler called without a valid TIB in FS
;--- this is possibly due to an exception in an IRQ handler
;--- and cannot be handled properly

	mov eax, cs:[g_hCurThread]        
	mov fs, cs:[eax].THREAD.dwTibSel
        
 if ?CLEARTIBPTR        
	mov esi, fs:[THREAD_INFORMATION_BLOCK.ptibSelf]
 endif        

@@:        
endif

if ?CLEARHIGHEBP
	movzx ebp,sp
	add ebp,8*4+1*4
else
	lea ebp,[esp+8*4+1*4]	;pushad, ExceptionCode
endif

?EXCPARM equ <dword ptr [ebp-4]>

;--------------------- clear this temporary to ensure we dont loop because
;--------------------- of an invalid client stack

if ?CLEARTIBPTR
	mov fs:[THREAD_INFORMATION_BLOCK.ptibSelf], 0
endif

;--- debugger first chance exception

if 1
	.if (cs:g_bDebug)
		mov ebx, ?EXCPARM
		movzx bx, cs:[ebx].EXCDESC.bException
		mov cx, DEBUG_FAULT_TYPE_FIRST
		mov ax, DS_CheckFault
		int 41h
		.if (ax)
if ?CLEARHIGHEBP
			movzx edx, [ebp].DPMIEXC.rEip
			movzx ecx, [ebp].DPMIEXC.rCS
else
			mov edx, [ebp].DPMIEXC.rEip
			mov ecx, [ebp].DPMIEXC.rCS
endif
			mov ebx, ?EXCPARM
			movzx bx, cs:[ebx].EXCDESC.bException
if ?CLEARHIGHEBP
			movzx esi, [ebp].DPMIEXC.errc
			movzx edi, [ebp].DPMIEXC.rEflags
else
			mov esi, [ebp].DPMIEXC.errc
			mov edi, [ebp].DPMIEXC.rEflags
endif
			mov ax, DS_TrapFault
			int 41h
if ?CLEARHIGHEBP
			.if ((dx != [ebp].DPMIEXC.rEip) || (cx != [ebp].DPMIEXC.rCS)) 
				mov [ebp].DPMIEXC.rEip, dx
				mov [ebp].DPMIEXC.rCS, cx
else
			.if ((edx != [ebp].DPMIEXC.rEip) || (ecx != [ebp].DPMIEXC.rCS)) 
				mov [ebp].DPMIEXC.rEip, edx
				mov [ebp].DPMIEXC.rCS, ecx
endif
				and byte ptr [ebp].DPMIEXC.rEflags+1,not 1
				jmp doexc_exit
			.endif
		.endif
	.endif

endif

;--- there may have been NO stack switch!
;--- that's why we cannot use the client stack to build a MYEXC frame!
;--- instead do:
;--- 1. save EFL, EIP, CS, ERRORCODE
;--- 2. clear IF
;--- 3. modify EIP
;--- 4. return to DPMI
;--- and then build the MYEXC frame when we're back onto our stack!

	push ds
if ?USECLIENTSTACK	;this only works if a switch to LPMS has occured
  ife ?CLEARHIGHEBP
	lds edi, fword ptr [ebp.DPMIEXC.rESP]	;get SS:ESP into ES:EDI
	sub edi,sizeof MYEXC			;make room for MYEXC
	mov [ebp.DPMIEXC.rESP],edi
  else
	lds di, dword ptr [ebp.DPMIEXC.rESP]
	movzx edi, di
	sub edi,sizeof MYEXC			;make room for MYEXC
	mov [ebp.DPMIEXC.rESP],di
  endif
	and byte ptr [ebp].DPMIEXC.rEflags+1,0FEH	;clear TF
else
	mov edi, offset g_myexc
	mov ds, cs:g_csalias
  ife ?CLEARHIGHEBP
	mov edx,[ebp.DPMIEXC.rEflags]
;	mov ebx,[ebp.DPMIEXC.errc]
  else
	movzx edx,[ebp.DPMIEXC.rEflags]
;	mov bx,[ebp.DPMIEXC.errc]
  endif
  if ?CATCHEXC01
	and dh,not 1		;clear TF in any case
  endif
	mov g_Eflags,edx
;	mov g_ErrCode,ebx
	and byte ptr [ebp].DPMIEXC.rEflags+1,0FCH	;clear TF/IF
endif

	mov eax,offset calldoexc		;set new EIP
	mov ecx,cs
ife ?CLEARHIGHEBP
	xchg eax,[ebp.DPMIEXC.rEip]
	xchg ecx,[ebp.DPMIEXC.rCS]
else
	xchg ax,[ebp.DPMIEXC.rEip]
	xchg cx,[ebp.DPMIEXC.rCS]
endif
	mov [edi].MYEXC.rEip,eax
	mov [edi].MYEXC.rCS,ecx
	mov ebx, ?EXCPARM
	mov ecx,[ebx].EXCDESC.win32exc
	.if (!ecx)
		call getfloatexc
	.endif
	mov [edi].MYEXC.dwExcNo,ecx

	xor eax,eax
	mov [edi].MYEXC.dwFlags,eax
	.if (([ebx].EXCDESC.bException == 0Eh) || ([ebx].EXCDESC.bException == 0Ch))
		mov [edi].MYEXC.numArgs,2
		mov [edi].MYEXC.pArgs,offset g_Args
		.if (g_bHost == HF_HDPMI)
			mov edx, cr2
			mov g_Args+1*4,edx
if ?FLAT
			and dx,0f000h
			lea ecx,[edx+1000h]
			cmp ecx,fs:[8]	;just one page below stack bottom?
			jnz @F
			invoke GetCurrentThread
			mov ecx,[eax].THREAD.hStack
			add ecx,2000h	;skip the reserved region
			cmp edx,ecx
			jb @F
			push es
			push ds
			pop es
			mov esi, edx
			mov ecx, 1000h
			invoke _SearchRegion, 0
			pop es
			and eax, eax
			jz @F
			mov ebx, esi
			mov esi, [eax].MBLOCK.dwBase
			sub ebx, esi
			mov ecx, 1
			push es
			push 9
			mov edx, esp
			push ss
			pop es
			mov ax,0507h
			int 31h
			pop edx
			pop es
			jc @F
			mov eax,[edi].MYEXC.rEip
			mov ecx,[edi].MYEXC.rCS
			mov [ebp].DPMIEXC.rEip, eax
			mov [ebp].DPMIEXC.rCS, ecx
			sub dword ptr fs:[8], 1000h
			jmp doexc_exit2
@@:
endif
		.endif

;--- test if the page access error is due to a stack overflow

		mov g_cntStack,1
		push ds
if ?CLEARHIGHEBP
		lds dx, [ebp].DPMIEXC.rSSSP
		movzx edx,dx
else
		lds edx, [ebp].DPMIEXC.rSSESP
endif
		mov eax, [edx-4]
		mov [edx-4], eax
afterstacktest::            
		pop ds
		mov al,g_cntStack
		mov g_cntStack,0
		.if (!al)
if ?CLEARHIGHEBP
			movzx eax,[ebp].DPMIEXC.rEsp
else
			mov eax,[ebp].DPMIEXC.rEsp
endif
			mov g_dwCurrEsp, eax
			call gethelperstack
			jnc @F
;--- a fatal exit because esp cannot be used and no memory available
			invoke FatalAppExitA, 0, addr szFatalExit
@@:
if ?CLEARHIGHEBP
			mov [ebp].DPMIEXC.rEsp, ax
else
			mov [ebp].DPMIEXC.rEsp, eax
endif
			mov [edi].MYEXC.dwExcNo, EXCEPTION_STACK_OVERFLOW
		.endif
	.else
		mov [edi].MYEXC.numArgs,eax
		mov [edi].MYEXC.pArgs,eax
if ?CATCHEXC0C
;--- this usually is NOT a stack overflow but an access of SS outside
;--- segment limits. With DKRNL32 this can only occur if SS descriptor
;--- has ED bit set.
  if 0
		.if ([ebx].EXCDESC.bException == 0Ch)
			mov eax,[ebp].DPMIEXC.rEsp
			mov g_dwCurrEsp, eax
			call gethelperstack
			mov [ebp].DPMIEXC.rEsp, eax
		.endif
  endif
endif
	.endif
doexc_exit2:
	pop ds

if ?CLEARTIBPTR
	mov fs:[THREAD_INFORMATION_BLOCK.ptibSelf], esi
endif
doexc_exit:
	popad
	add esp,4	 ;skip ?EXCPARM parameter
if ?CLEARHIGHEBP
	db 66h
endif
	retf
	align 4
        
doexception endp

if ?FLOATSUPP

if ?IRQ0DSUPP

myint75:
;--- the "real" eip may be on the stack, at least in
;--- XP, 9X and HDPMI. But modifying it to return to
;--- another address doesnt work - except for HDPMI.
;--- But even then it's a bad idea, because it only
;--- works if a stack switch has been done. This is
;--- *not* always true.
if 0
	cmp cs:[g_bHost], HF_HDPMI
	jnz nohdpmi
	pushad
 if ?CLEARHIGHEBP
	movzx ebp,sp
 else
	mov ebp,esp
 endif
	push ds
	mov ds,cs:g_csalias
 ifdef _DEBUG
	mov byte ptr ds:[0B8000h+24*80*2-4],'#'
 endif
	mov eax, [ebp+8*4].IRETDS.rCS
	test al,4							;CS in LDT?
	mov eax, [ebp+8*4].IRETDS.rEip		;then get eip of IRET frame
	jnz @F								;else a stack switch has occured
	mov eax, [ebp+8*4+sizeof IRETDS]	;and EIP is above IRET frame
@@:     
	mov [dwExcEip], eax
 if ?CLEARHIGHEBP		 
	mov word ptr [ebp+8*4+sizeof IRETDS], offset myint75ex
 else
	mov dword ptr [ebp+8*4+sizeof IRETDS], offset myint75ex
 endif
	pop ds
	popad
nohdpmi:
endif        
	push eax
	fninit		;clear the exception and continue
	mov al,00
	out 0F0h,al	;clear FPU interrupt
	mov al,20h
	out 0A0h,al
	out 20h,al
	pop eax
	@iret
	align 4
        
;--- hopefully the server has switched to our stack
;--- now build a MYEXC frame and call doexc2
;--- we should be able to safely reenable interrupts here

myint75ex:
ifdef _DEBUG
	push ds
	mov ds,cs:g_csalias
	mov byte ptr ds:[0B8000h+24*80*2-2],'+'
	pop ds
endif
	push 0			;pArgs
	push 0			;nArgs
	push 0			;flags
	push ecx
	call getfloatexc
	xchg ecx, [esp]	;excno	
	push eax
	mov eax, cs:[g_hCurThread]
	mov fs, cs:[eax].THREAD.dwTibSel
	pop eax
	push cs
	push cs:[dwExcEip]
	sti					;we only get called if interrupts were enabled
	call doexc2
endif						;endif IRQ0DSUPP

;--- return win32 exception in ECX

getfloatexc proc 

	push eax
	fnstsw ax
	mov ecx, EXCEPTION_FLT_STACK_CHECK
	test al,20h		;stack fault?
	jz @F
	mov ecx, EXCEPTION_FLT_INVALID_OPERATION
	test al,1		;invalid operation?
	jz @F
	mov ecx, EXCEPTION_FLT_DENORMAL_OPERAND
	test al,2		;denormal?
	jz @F
	mov ecx, EXCEPTION_FLT_DIVIDE_BY_ZERO
	test al,4		;zero divide?
	jz @F
	mov ecx, EXCEPTION_FLT_OVERFLOW
	test al,8		;overflow?
	jz @F
	mov ecx, EXCEPTION_FLT_UNDERFLOW
	test al,10h		;underflow?
	jz @F
	mov ecx, EXCEPTION_FLT_INEXACT_RESULT	;precision
@@:
	pop eax
	ret
	align 4

getfloatexc endp        

endif

	end
