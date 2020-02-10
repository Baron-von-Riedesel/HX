
	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
DGROUP group _TEXT
endif
	option casemap:none
	option proc:private

	include winbase.inc
	include dkrnl32.inc
	include dpmi.inc
	include macros.inc

	option dotname

TIBSEG segment use16
TIBSEG ends
	assume fs:TIBSEG	;declare FS=TIB a 16 bit segment (saves space)

?USESHARE	equ 0	;0=open log file in compat mode
?USEAUX		equ 1	;1=use AUX for debug output if it is a file
?USEDOSMEM	equ 1	;1=use a buffer (in conv mem) for output strings
?BUFFERED	equ 0	;1=use buffered output

if ?BUFFERED
?DOSBUFFSIZ	equ 4000h
else
?DOSBUFFSIZ	equ 400h
endif

?DBG2DOS	equ 1	;std=1, 1=output to dos if no debugger present?
					;should be set to 1 to log output of other dlls 

@setmypsp macro
local nopspchange
	mov ah,51h
	int 21h
	push ebx
	cmp bx, word ptr cs:g_psp
	jz nopspchange
	mov ebx, cs:g_psp
	mov ah,50h
	int 21h
nopspchange:
	endm

@restorepsp macro
local nopspchange
	pop ebx
	cmp bx,word ptr cs:g_psp
	jz nopspchange
	mov ah,50h
	int 21h
nopspchange:
	endm


.BASE$IA SEGMENT dword public 'DATA'
		DD offset InstallDebugLog
.BASE$IA ENDS

.BASE$XA SEGMENT dword public 'DATA'
;        DD offset DeinstallDebugLog
.BASE$XA ENDS

	.DATA

g_oldint41	df 0
g_bInit		db 0

	align 4

if ?DBG2DOS
g_hLogOut		dd -1
g_psp			dd 0
g_dwDebugFlags	dd 0	;flags received from DKRNLDBG env variable
g_dwScrnPos		dd 0
  if ?USEDOSMEM
g_DosSel		dd 0
g_DosSeg		dd 0
    if ?BUFFERED
g_dwCnt			dd 0
    endif
  endif
g_szLogFile		db MAX_PATH dup (0)
externdef g_bDebugger:byte
g_bDebugger		db 0
endif

	.code

if ?DBG2DOS

IncScr  proc
	mov cl,8
	mov ebx,cs:[g_dwScrnPos]
	push ds
if ?FLAT
	mov ds,cs:[g_csalias]
else
	mov ds,cs:[g_flatsel]
endif
nextchar:
	inc byte ptr [ebx]
	cmp byte ptr [ebx],'9'
	jbe done
	mov byte ptr [ebx],'0'
	dec ebx
	dec ebx
	dec cl
	jnz nextchar
done:
	pop ds
	ret
IncScr  endp

InitScr proc
	movzx eax,byte ptr [VIOROWS]	;number of rows-1
	dec byte ptr [VIOROWS]		;decrease the number of rows
	movzx ecx,word ptr [VIOCOLS]	;number of columns
	mul ecx
	dec ecx
	add eax,ecx
	shl eax,1
	add eax,0B8000h
	mov g_dwScrnPos,eax
	mov cl,8
nextchar:
	mov byte ptr @flat:[eax],'0'
	dec eax
	dec eax
	dec cl
	jnz nextchar
	ret
	align 4
InitScr endp

if ?USEDOSMEM

flushDosBuff proc bForce:dword

if ?BUFFERED
	.if ((cs:g_dwCnt > (?DOSBUFFSIZ - 400h)) || (bForce && cs:g_dwCnt))
endif        
		sub esp,sizeof RMCS+2
		mov edi, esp
		push es
		push ss
		pop es
		mov es:[edi].RMCS.rAX, 4000h
		mov eax, cs:[g_hLogOut]
		mov es:[edi].RMCS.rBX, ax
if ?BUFFERED
		push ds
		mov ds,cs:[g_csalias]
		mov ecx, g_dwCnt
		mov g_dwCnt, 0
		pop ds
endif
		mov es:[edi].RMCS.rCX, cx
		mov es:[edi].RMCS.rDX, 0
		mov eax, cs:[g_DosSeg]
		mov es:[edi].RMCS.rDS, ax
		mov es:[edi].RMCS.rSSSP,0
		mov es:[edi].RMCS.rFlags,0
		mov bx,21h
		xor ecx,ecx
		mov ax,0300h
		int 31h
		pop es
		add esp,sizeof RMCS+2
if ?BUFFERED
	.endif
endif
	ret
	align 4
flushDosBuff endp

endif

;--- OpenLogFile(), called by int 41h handler

OpenLogFile proc uses ds esi ebx
	mov ecx, cs:[g_csalias]
	jecxz @F
	mov ds, ecx
@@:
	mov ebx,g_hLogOut
	.if (bx == 1)		;if current logfile is stdout, we're done
		jmp exit
	.endif
	.if (bx != -1)
		mov ah,3Eh
		int 21h
		mov g_hLogOut, -1
	.endif
if ?USEAUX
	@mov ebx,3
	mov ax,4400h
	int 21h
	jc @F
	mov eax, ebx
	test dl,80h			;is AUX a file?
	jz dbgfound			;then assume it is ours!
	mov ah,3Eh			;else close AUX
	int 21h
@@:
endif
	mov esi, offset g_szLogFile
if ?USESHARE
	mov bx,0041h		;write-only, inherit, deny none
else
	mov bx,0001h		;write-only, inherit, compat mode
endif
	.if (byte ptr g_dwDebugFlags & DBGF_FLUSH)
		or bh,40h		;autocommit on every write (XP?)
	.endif
	mov dx,11h			;action (create if not exist/open)
	mov cx,0			;create attributes
	mov ax,6C00h		;extended open 
	int 21h
	jnc dbgfound
	mov g_hLogOut, 1
	jmp exit
dbgfound:
	mov g_hLogOut,eax
	call SetLogPtrToEOF
exit:
	ret
	align 4
OpenLogFile endp

;---- int 41h handler. dont assume SS/DS/ES==FLAT!

myint41 proc

	cmp cs:[g_bIsActive], 1
	jnz exit
	cmp ax,0002h
	jz is0002
	cmp ax,0159h
	jz is0159
exit:
	jmp fword ptr cs:[g_oldint41]
is0159:
	push eax
	mov eax,fs:[THREAD_INFORMATION_BLOCK.pProcess]
	and [eax].PROCESS.wFlags, not PF_LOCKED
	pop eax
	@iret
is0002:
	cmp cs:[g_bDebugger],0
	jnz exit
	pushad
	mov edx, cs:[g_indosaddr]
	and edx, edx
	jz @F
if ?FLAT
	cmp byte ptr cs:[edx],0
else
	push ds
	mov ds, cs:g_flatsel
	cmp byte ptr ds:[edx],0
	pop ds
endif
	jnz skip_output
@@:
	.if ((cs:g_hLogOut == -1) && (cs:g_szLogFile == 0))
		jmp skip_output
	.endif
	push ds
	mov ds, cs:[g_csalias]
	mov g_bIsActive, 0
	pop ds
	@setmypsp
	xor ecx, ecx
	.if (esi)
		.if (cs:[g_hLogOut] == -1)
			invoke OpenLogFile
		.endif
if ?USEDOSMEM
		cmp cs:[g_DosSel],0
		jnz @F
		mov ax, 100h
		mov bx, ?DOSBUFFSIZ/16
		int 31h
		jc error1
		push ds
		mov ds,cs:[g_csalias]
		mov g_DosSel, edx
		mov g_DosSeg, eax
		pop ds
@@:
		push es
		mov es, cs:[g_DosSel]
		mov ecx, ?DOSBUFFSIZ
  if ?BUFFERED
		mov edi, cs:g_dwCnt
		sub ecx, edi
  else
		xor edi, edi
  endif
		cld
@@:
		lodsb
		stosb
		and al,al
		loopnz @B
		dec edi
		pop es
		mov ecx, edi
  if ?BUFFERED
		push ds
		.if (cs:g_csalias)
			mov ds, cs:g_csalias
		.endif
		sub ecx, g_dwCnt
		mov g_dwCnt, edi
		pop ds
  endif
else
		.while (byte ptr [esi+ecx])
			inc ecx
		.endw
endif
	.endif
	.if (!ecx)	;a null string: set log file ptr to eof
		call OpenLogFile
	.else
if ?USEDOSMEM
		invoke flushDosBuff, 0
else
		mov edx, esi
		mov ebx, cs:g_hLogOut
		mov ah,40h
		int 21h
endif
	.endif
	.if (byte ptr cs:g_dwDebugFlags & DBGF_SCRNFL)
		call IncScr
	.endif
error1:
	@restorepsp
	push ds
	mov ds,cs:[g_csalias]
	mov g_bIsActive, 1
	pop ds
skip_output:
	popad
	@iret

	align 4

myint41 endp

endif

if ?DBG2DOS

;--- PSP must be "our" PSP

SetLogPtrToEOF proc uses ebx
	mov ebx, cs:g_hLogOut
	xor ecx, ecx		;goto EOF
	xor edx, edx
	mov ax,4202h
	int 21h
	ret
	align 4
SetLogPtrToEOF endp

;--- all registers may be modified!
;--- int 41 already set to myint41!
;--- but g_hLogOut still -1

GetLogFileName proc

	invoke _GetEnvironmentVariableInt, CStr("DKRNLDBG")
	mov g_dwDebugFlags, eax
	.if (al & DBGF_SCRNFL)
		call InitScr
	.endif
	invoke GetEnvironmentVariable, CStr("DKRNLLOG"), addr g_szLogFile, sizeof g_szLogFile
ifdef _DEBUG
	.if (!eax)
		mov g_hLogOut,1
	.endif
endif
	mov ah,51h
	int 21h
	mov g_psp, ebx
	ret
	align 4
GetLogFileName endp

endif

_FlushLogFile proc public
if ?DBG2DOS
	push ebx
	mov ebx, g_hLogOut
	cmp ebx, -1
	jz @F
if 1
	mov ah,68h
	int 21h
else
	mov g_hLogOut, -1
	mov ah,3Eh
	int 21h
endif
@@:
	pop ebx
endif
	ret
	align 4
_FlushLogFile endp

;--- in release mode Install is called just once
;--- in debug mode it may be called several times

InstallDebugLog proc public

	test g_bInit,1
	jnz done
	or g_bInit,1
if ?DBG2DOS
	pushad

	invoke IsDebuggerPresent	;this call is NOT logged!
	mov g_bDebugger, al

	mov ax, 204h
	mov bl,41h
	int 31h
  if ?CLEARHIGHEBP
	movzx edx,dx
  endif
	mov dword ptr g_oldint41+0, edx
	mov word ptr g_oldint41+4, cx
	mov edx, offset myint41
	mov ecx, cs
	mov ax, 205h
	int 31h
	.if (!g_bDebugger)
		call GetLogFileName
	.endif
	popad
endif
done:
	ret
	align 4
InstallDebugLog endp

if ?DBG2DOS

;--- int 41h vector is restored already
;--- all registers may be modified herein

CloseLog proc
	cmp g_hLogOut,-1
	jz done
	cmp g_hLogOut,1
	jz done
	@setmypsp
if ?USEDOSMEM
  if ?BUFFERED
	invoke flushDosBuff, 1
  endif
endif
	mov ebx, g_hLogOut
	mov ah,3Eh
	int 21h
	mov g_hLogOut, -1
	@restorepsp
done:
	ret
	align 4
CloseLog endp
endif

DeinstallDebugLog proc public

	@strace <"dbgout destructor enter">
if ?DBG2DOS
	.if (word ptr g_oldint41+4)
		pushad
		mov bl, 41h
		mov ax, 204h
		int 31h
		cmp edx, myint41
		jnz @F
		mov edx,dword ptr g_oldint41+0
		xor ecx,ecx
		xchg cx, word ptr g_oldint41+4
		mov ax, 205h
		int 31h
@@:
		call CloseLog
if ?USEDOSMEM
		xor edx, edx
		xchg edx, g_DosSel
		and edx, edx
		jz @F
		mov ax,0101h
		int 31h
@@:
endif
		popad
	.endif
endif
	ret
	align 4

DeinstallDebugLog endp

OutputDebugStringA proc public uses esi pText:ptr BYTE

ifdef _DEBUG
	invoke InstallDebugLog		;install very early in debug mode
endif
	mov esi,pText
	mov ax,0002h
	int 41h
	ret
	align 4

OutputDebugStringA endp

	end

