
	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:none

	include winbase.inc
	include macros.inc
	include dkrnl32.inc

	option proc:private
	option dotname

.BASE$IA SEGMENT dword public 'DATA'
	DD offset Install
.BASE$IA ENDS

.BASE$XA SEGMENT dword public 'DATA'
	DD offset Deinstall
.BASE$XA ENDS

	.DATA

oldint24 df 0

	.CODE

;--- int 24 (critical error) is called with locked protected mode stack
;--- with 4 kB size, so dont call too much

myint24 proc
if 0
	int 3
	pushad
	invoke GetCurrentProcess
	test [eax].PROCESS.dwErrMode, SEM_FAILCRITICALERRORS
	popad
	jnz retfail
	jmp fword ptr cs:oldint24	;doesnt work for win9x
retfail:
endif
	mov al,3   ;fail
	@iret
	align 4
myint24 endp

Install proc uses ebx
	mov ax,0204h
	mov bl,24h
	int 31h
if ?CLEARHIGHEBP
	movzx edx,dx
endif
	mov dword ptr oldint24+0,edx
	mov word ptr oldint24+4,cx
	mov ecx,cs
	mov edx,offset myint24
	mov ax,0205h
	int 31h
	ret
	align 4
Install endp

Deinstall proc uses ebx
	@strace <"SetErrorMode destructor enter">
	mov cx, word ptr oldint24+4
	jcxz done
	mov word ptr oldint24+4, 0
	mov edx,dword ptr oldint24+0
	mov bl,24h
	mov ax,0205h
	int 31h
done:
	ret
	align 4
Deinstall endp

SetErrorMode proc public fErrorMode:dword

if ?FLAT
	test g_bIntFl, IKF_PELDR
	jz @F
	mov edx,fErrorMode
	mov ax,4b93h			;tell PE loader what to do with module
	int 21h					;loading errors
@@:
endif
	invoke GetCurrentProcess
	mov ecx, eax
	mov eax,fErrorMode
	xchg ax, [ecx].PROCESS.wErrMode
	@strace <"SetErrorMode(", fErrorMode, ")=", eax>
	ret
	align 4
SetErrorMode endp

	END

