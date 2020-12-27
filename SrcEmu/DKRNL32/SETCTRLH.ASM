
;--- Ctrl-C handler

	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
DGROUP	group _TEXT
endif
	option casemap:none
	option proc:private

	include winbase.inc
	include wincon.inc
	include macros.inc
	include dkrnl32.inc

	option dotname

TIBSEG segment use16
TIBSEG ends
	assume fs:TIBSEG	;declare FS=TIB a 16 bit segment (saves space)

?SAVESEGREGS	equ 1	;NT's dosx and DOSEMU require 1
						;dpmione is better, but still modifies ES register
?LOCKTHREAD		equ 1	;don't allow thread switches
_CTRLBREAKVAR	equ 471h;this bios variable indicates ctrl-break                        
_CTRLBREAKFLAG  equ 80h	;and it is bit 7

;--- 2013/12: ?SETTHREAD default value changed from 1 to 0
?SETTHREAD		equ 0	;1=create break event thread inside SetConsoleCtrlHandler()

public	__DEFCTRLHANDLER
__DEFCTRLHANDLER	equ 12345678h

LENTRY  struct
pNext   dd ?
pProc   dd ?
LENTRY  ends

.BASE$IC segment dword public 'DATA'
        dd offset Install
.BASE$IC ends

.BASE$XC segment dword public 'DATA'
        dd offset Deinstall
.BASE$XC ends

ifdef ?OMF
DGROUP  group .BASE$IC, .BASE$XC
endif

	.DATA

if ?LOWLEVEL_CTRLBRK
externdef	g_bCtrlBrk:byte
endif

;--- most console flags are still global, valid for all handles
;--- only ENABLE_PROCESSED_xxxPUT flat is a handle attribute

g_pCtrlHandler	dd offset handler1
g_hCtrlThread	dd 0
g_hEvent		dd 0
handler1		LENTRY {0,offset stdctrlhandler}
g_oldint23		df 0
g_bIgnCtrlC		db 0

	.CODE

;--- thread for ctrl-c handling

waitsignal proc lParam:dword

	.while (1)
		invoke WaitForSingleObject, g_hEvent, INFINITE
		@strace <"SetConsoleCtrlHandler: signal received">
		call dispatchsignal
	.endw
	ret
	align 4
waitsignal endp

;--- create thread for ctrl-c handling

createsignalthread proc
	invoke CreateEvent, 0, 0, 0, 0
	and eax, eax
	jz @F
	mov g_hEvent, eax
	push 0
	invoke CreateThread, 0, 0, offset waitsignal, 0, 0, esp
	pop ecx
	mov g_hCtrlThread, eax
	@strace <"SetConsoleCtrlHandler: helper thread=", eax>
@@:
	ret
createsignalthread endp

;--- Win32 API SetConsoleCtrlHandler()
;--- pProc: handler routine - may be NULL
;--- bAdd: if TRUE, handler is added, else it is removed
;--- if pProc is NULL, bAdd==TRUE makes break events to be ignored
;--- and bAdd==FALSE will restore the standard break handling.

;--- it's valid to set the very same handler routine multiple times

SetConsoleCtrlHandler proc public pProc:ptr, bAdd:dword

	call EnterSerialization
	mov edx,pProc
	mov ecx,bAdd
	and edx, edx
	jnz @F
	mov g_bIgnCtrlC, cl
	@mov eax,1
	jmp exit
@@:
	and ecx,ecx
	jz remove
if ?SETTHREAD
	.if (!g_hCtrlThread)
		call createsignalthread
		and eax, eax
		jz exit
	.endif
endif
	invoke KernelHeapAlloc,sizeof LENTRY
	and eax,eax
	jz exit
	mov ecx,pProc
	mov [eax].LENTRY.pProc,ecx
	mov ecx,eax
	xchg ecx,g_pCtrlHandler
	mov [eax].LENTRY.pNext,ecx
	@mov eax,1
	jmp exit
remove:
	mov ecx,offset g_pCtrlHandler
	mov eax,[ecx]
@@:
	cmp [eax].LENTRY.pProc,edx
	jz found
	mov ecx,eax
	mov eax,[eax].LENTRY.pNext
	and eax,eax
	jnz @B
	jmp exit
found:
	mov edx,[eax].LENTRY.pNext
	mov [ecx].LENTRY.pNext,edx
	invoke KernelHeapFree,eax
exit:
	call LeaveSerialization
	@strace <"SetConsoleCtrlHandler(", pProc, ", ", bAdd, ")=", eax>
	ret
	align 4
SetConsoleCtrlHandler endp

GenerateConsoleCtrlEvent proc public dwCtrlEvent:DWORD, dwProcessGroupId:DWORD
	@strace <"GenerateConsoleCtrlEvent(", dwCtrlEvent, ", ", dwProcessGroupId, ") enter">
	.if (dwCtrlEvent == CTRL_BREAK_EVENT)
		or byte ptr @flat:[_CTRLBREAKVAR],_CTRLBREAKFLAG
	.endif
	int 23h
	@strace <"GenerateConsoleCtrlEvent(", dwCtrlEvent, ", ", dwProcessGroupId, ") exit">
	ret
GenerateConsoleCtrlEvent endp

;--- default break handler routine

stdctrlhandler proc event:dword

	@strace <"stdctrlhandler(", event, ")">
if ?FLAT
	invoke GetModuleHandle, 0
	.if (eax)
		mov ecx, [eax+3Ch]
		lea ecx, [ecx+eax]
		mov ax,[ecx].IMAGE_NT_HEADERS.OptionalHeader.Subsystem
		cmp ax, IMAGE_SUBSYSTEM_WINDOWS_GUI
		jz exit
	.endif
endif
	.if ((!g_bIgnCtrlC) || (event == CTRL_BREAK_EVENT))
		@strace <"stdctrlhandler calls ExitProcess">
		invoke GetCurrentProcess
		test [eax].PROCESS.wFlags, PF_TERMINATING
		jnz @F
		invoke ExitProcess,0
@@:
	.endif
exit:
	ret
	align 4
stdctrlhandler endp

;--- dispatch break event to registered break handler routines.
;--- all registers have been saved in int23
;--- so no need to save them here again

dispatchsignal proc

	@strace <"dispatchsignal(break) enter, fs=", fs>
if ?LOCKTHREAD
	mov eax, fs:[THREAD_INFORMATION_BLOCK.pProcess]
	or [eax].PROCESS.wFlags,PF_LOCKED
endif
	mov bl,@flat:[_CTRLBREAKVAR]
	and bl,_CTRLBREAKFLAG
	and byte ptr @flat:[_CTRLBREAKVAR],not _CTRLBREAKFLAG
	mov esi,g_pCtrlHandler
	.while (esi)
		mov ebp,esp			;some handlers don't return with 'ret 4'
		.if (bl)
			push CTRL_BREAK_EVENT
		.else
			push CTRL_C_EVENT
		.endif
		call [esi].LENTRY.pProc
		mov esp,ebp
		.break .if (eax)	;has routine handled this event?
		mov esi,[esi].LENTRY.pNext
	.endw
if ?LOCKTHREAD
	mov eax,fs:[THREAD_INFORMATION_BLOCK.pProcess]
	and [eax].PROCESS.wFlags, not PF_LOCKED
endif
	@strace <"dispatchsignal(break) exit">
	ret
	align 4
dispatchsignal endp

;--- int 23h may be called from real-mode (then the LPMS is used)
;--- but it may be called by the protected-mode keyboard handler as well,
;--- which intercepts Ctrl-Break and Ctrl-C. In this case the application's
;--- standard stack is used (currently)

int23 proc

	cmp cs:[g_bIsActive],1	;kernel code active?
	jnb @F
	@iret
@@:
	pushad
if ?SAVESEGREGS
	push ds
	push es
	mov ds,cs:[g_csalias]
	push ds
	pop es
ife ?FLAT
	push gs
	mov gs,[g_flatsel]
endif
	push fs
	mov eax, [g_hCurThread]
	mov fs, [eax].THREAD.dwTibSel
endif
	.if (!g_hCtrlThread)
		call gethelperstack
		mov ecx,ss
		mov edx,esp
		push ds
		pop ss
		mov esp,eax
		push ecx
		push edx
		call createsignalthread
		lss esp,[esp]
		and eax, eax
		jz done
	.endif
	invoke SetEvent, g_hEvent
done:
if ?SAVESEGREGS
	pop fs
ife ?FLAT
	pop gs
endif
	pop es
	pop ds
endif
	popad
	@iret
	align 4
int23 endp

Install proc uses ebx
	@strace <"SetCtrlH.Install enter, will set int 23h">
	mov ax,204h		;get int 23h protected-mode interrupt vector
	mov bl,23h
	int 31h
if ?DPMI16
	movzx edx,dx
endif
	mov dword ptr g_oldint23+0, edx
	mov word ptr g_oldint23+4,cx
	mov ecx,cs
	mov edx,offset int23
	mov al,05h		;set int 23h protected-mode interrupt vector
	int 31h
	; reset BIOS ctrl-break flag
	and byte ptr @flat:[_CTRLBREAKVAR],not _CTRLBREAKFLAG
	ret
	align 4
Install endp

;--- int 23h need not to be reset, because this is done
;--- by dos/dpmi or DPMILD32.

Deinstall proc uses ebx
	mov cx,word ptr [g_oldint23+4]
	jcxz done
	mov edx,dword ptr [g_oldint23+0]
	mov ax,0205h	;restore int 23h protected-mode interrupt vector
	mov bl,23h
	int 31h
done:
	ret
Deinstall endp

	END

