
;--- this code checks if windows nt/2k/xp is active
;--- and tries to install workarounds for bugs
;--- in the DPMI support of these environments.
;--- for other environments it exits immediately


	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option proc:private
	option casemap:none

	option dotname

	include winbase.inc
	include dkrnl32.inc
	include dpmi.inc
	include macros.inc

?LFNHLP	equ 1	;install LFN helper module for NT/2K/XP
if ?FLAT
?DYNLFN	equ 0	;1=load NTLFNHLP as a dll, 0=link statically
else
?DYNLFN	equ 0	;always 0
endif

	public __CHECKOS
__CHECKOS	equ 12345678h

;--- the .BASE$ segments contain initialization/termination
;--- code and work for both MZ and PE support

.BASE$IA SEGMENT dword public 'DATA'
	DD offset Install
.BASE$IA ENDS

.BASE$XA SEGMENT dword public 'DATA'
	DD offset Deinstall
.BASE$XA ENDS

ifdef ?OMF
DGROUP  group .BASE$IA, .BASE$XA
endif

IRETS struct
if ?CLEARHIGHEBP
rIP		dw ?
rCS		dw ?
rFlags	dw ?
else
rIP		dd ?
rCS		dd ?
rFlags	dd ?
endif
IRETS ends

LPFAR32 typedef  ptr far32
LPFAR16 typedef  ptr far16

	.DATA

dwDTASel	dd 0
dwDosSel	dd 0
wDosSeg		dw 0

if ?LFNHLP
  if ?DYNLFN
hLFNHlp		dd 0
  else
bLFNHlp		db 0 
  endif
endif

if ?FLAT
	.DATA
else
	.CODE
endif

	align 4
if ?CLEARHIGHEBP
oldvec21	LPFAR16 0
oldvec31	LPFAR16 0
?SEGOFFS	equ 2
else
oldvec21	LPFAR32 0
	align 4
oldvec31	LPFAR32 0
?SEGOFFS	equ 4
endif

	.CODE

int2160 proc
	pushad
	push es
if ?CLEARHIGHEBP
	movzx ebp, sp
	sub esp, sizeof RMCS + 2
else
	mov ebp, esp
	sub esp, sizeof RMCS + 2
endif        

rmcs	textequ <[ebp - (sizeof RMCS + 2)].RMCS>

	mov edx, cs:dwDosSel
	and edx, edx
	jnz @F
	mov bx,20h
	mov ax,100h
	int 31h
	jc fail
	push ds
	mov ds,cs:[g_csalias]
	mov dwDosSel, edx
	mov wDosSeg, ax
	pop ds
@@:
	mov es, edx
	xor edi, edi
@@:
	lodsb
	stosb
	and al,al
	jnz @B
	push ss
	pop es
if ?CLEARHIGHEBP
	movzx edi, sp
else
	mov edi, esp
endif
	xor ecx,ecx
	mov rmcs.rSSSP, ecx
	mov ax, wDosSeg
	mov rmcs.rDS, ax
	mov rmcs.rES, ax
	mov rmcs.rSI, cx
	mov rmcs.rDI, 100h
	mov rmcs.rAX, 6000h
	mov bx,0021h
	mov ax,0300h
	int 31h
	jc fail
	mov ax, rmcs.rAX
	test byte ptr rmcs.rFlags,1
	stc
	jnz fail2
	push ds
	mov ds, cs:dwDosSel
	mov esi, 100h
	mov edi, [ebp+4]
	mov es, [ebp+0]
	push eax
@@:
	lodsb
	stosb
	and al,al
	jnz @B
	pop eax
	pop ds
fail2:
	mov word ptr [ebp+4+1ch],ax
fail:
	mov esp, ebp
	pop es
	popad
	ret
	align 4

int2160 endp

int211a proc        
	pushad
	mov ebx,ds					;get base
	mov esi,edx
	mov ax,0006
	int 31h
	push cx
	push dx
	pop edx
	add esi,edx					;now linear address in esi
	mov ebx,cs:[dwDTASel]
	and ebx,ebx
	jnz @F
	mov cx,1
	mov ax,0					;alloc selector
	int 31h
	push ds
	mov ds,cs:[g_csalias]
	mov dwDTASel,eax
	pop ds
	mov ebx, eax
@@:
	push esi
	pop dx
	pop cx
	mov ax,0007					;set base
	int 31h
	mov dx,259
	xor ecx,ecx
	mov ax,0008					;set limit
	int 31h
	push ds
	mov ds,ebx
	xor edx,edx
	mov ah,1Ah
if ?CLEARHIGHEBP
	pushf
else
	pushfd
endif        
	call cs:[oldvec21]
	pop ds
	popad
	ret
	align 4

int211a endp

int2171:
	mov al,00
IretWithCarry:
	stc
IretWithFlagsUpdate:
	push eax
	lahf
	and ah,1
if ?CLEARHIGHEBP
	push ebp
	movzx ebp,sp
	and byte ptr [ebp+2*4].IRETS.rFlags,not 1	;reset Carry
	or byte ptr [ebp+2*4].IRETS.rFlags,ah
	pop ebp
else
	and byte ptr [esp+1*4].IRETS.rFlags,not 1	;reset Carry
	or byte ptr [esp+1*4].IRETS.rFlags,ah
endif
	pop eax
	@iret
	align 4
        
;--- NT platforms have a buggy DOS API translation which
;--- forgets to set C for unsupported functions.
;--- So do this here, especially for LFN functions and "Set DTA"

myint21 proc
	cmp cs:g_bIsActive,1
	jb default
if ?DYNLFN								;only required if LFNHLP is dynlinked
	cmp ah,71h					;LFN function call?
	jz int2171
endif
ife ?CLEARHIGHEBP
	cmp ah,1ah					;set dta doesnt work
	jnz @F
	test edx,0FFFF0000h
	jz @F
	call int211a
	@iret
@@:
endif
	cmp ah,60h
	jnz @F
	call int2160
	jmp IretWithFlagsUpdate
@@:
default:
	stc
	jmp cs:[oldvec21]
	align 4

myint21 endp

;--- NT platforms have a very buggy dpmi server
;--- for example it doesnt set C for unsupported functions
;--- since this code uses dpmi functions 0504h, 0506h and 0507h
;--- ensure here that C is set in NT.

myint31 proc
	cmp ah,05
	jnz @F
	cmp al,4
	jae IretWithCarry
@@:
	jmp cs:[oldvec31]
	align 4

myint31 endp

Install proc stdcall uses ebx

	cmp g_bHost,HF_DPMIONE
	jz lfnhlpinstall
	cmp g_bHost,HF_WINNT
	jnz exit
	mov ax,0204h
	mov bl,21h
	int 31h
	mov dword ptr ds:oldvec21+0,edx
	mov word ptr ds:oldvec21+?SEGOFFS,cx
	mov edx,offset myint21
	mov ecx,cs
	mov ax,0205h
	int 31h

	mov ax,0204h
	mov bl,31h
	int 31h
	mov dword ptr ds:oldvec31+0,edx
	mov word ptr ds:oldvec31+?SEGOFFS,cx
	mov edx,offset myint31
	mov ecx,cs
	mov ax,0205h
	int 31h
lfnhlpinstall:
if ?LFNHLP
  if ?DYNLFN
	mov edx, CStr("NTLFNHLP.DLL")
	mov ax,4B00h
	int 21h
	jc @F
	mov hLFNHlp, eax
@@:
  else
InstallLFNHLP proto bCheckOS:DWORD
	invoke InstallLFNHLP, 0
	mov bLFNHlp, 1
;	includelib LFNHLPS.LIB
;	includelib NTLFNHLP.LIB
  endif
endif
exit:
	ret
	align 4

Install endp

Deinstall proc stdcall uses ebx

	@strace <"checkos destructor enter">
if ?LFNHLP
 if ?DYNLFN
	.if (hLFNHlp)
		mov edx, hLFNHlp
		mov ax,4B80h
		int 21h
	.endif
 else
	.if (bLFNHlp)
DeinstallLFNHLP proto
		call DeinstallLFNHLP
	.endif
 endif
endif
	mov cx,word ptr ds:oldvec21+?SEGOFFS
	jcxz @F
	mov cx,word ptr ds:oldvec21+?SEGOFFS
	mov edx,dword ptr ds:oldvec21+0
	mov bl,21h
	mov ax,0205h
	int 31h
@@:
	mov cx,word ptr ds:oldvec31+?SEGOFFS
	and cx,cx
	jz @F
	mov edx,dword ptr ds:oldvec31+0
	mov bl,31h
	mov ax,0205h
	int 31h
@@:
	xor edx,edx
	xchg edx,dwDosSel
	and edx,edx
	jz @F
	mov ax,0101h
	int 31h
@@:
	xor ebx,ebx
	xchg ebx,dwDTASel
	and ebx,ebx
	jz @F
	mov ax,0001h
	int 31h
@@:
	ret
	align 4

Deinstall endp

	END

