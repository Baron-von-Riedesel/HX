
;--- emulation int 21h, ah=3F/40 for 16bit.
;--- this is some limited support for 16-bit clients in dkrnl32.
;--- since the dos api doesnt support 32 bit pointers for 16-bit clients
;--- some descriptor magic has to be done. It's implemented just for
;--- the basic read/write functions, for any other DOS functions the app
;--- itself must ensure that HIWORD of pointers is ZERO.

	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:none
	option proc:private
	option dotname

	include winbase.inc
	include macros.inc
	include dpmi.inc

if ?CLEARHIGHEBP

?CHKSIZE equ 8000h

	.CODE

;--- input: 
;--- ah=dos function (3F=read, 40=write)
;--- ebx = handle
;--- ecx = size
;--- ds:edx -> buffer

simint21 proc public uses ebx ecx edx

local	base:dword
local	limit:dword
local	sel:dword
local	rlength:dword
local	dsreg:dword
local	func:dword
local	dwRdWr:dword
local	pBuffer:dword
local	handle:dword
local	numBytes:dword

	mov func,eax
	mov handle,ebx
	mov numBytes,ecx
	mov pBuffer,edx
	sub eax,eax
	mov dwRdWr,eax
	mov sel,eax
	mov dsreg,ds
	mov cx,1
	mov ax,0		;alloc scratchselector
	int 31h
	jc sm1_er_pm1
	mov sel,eax
	mov ebx,ds
	mov ax,6		;Get Base
	int 31h
	jc sm1_er_pm2
	push cx
	push dx
	pop eax
	add eax,pBuffer
	mov base,eax   ;linear address of buffer
	lsl eax,ebx
	mov limit,eax
	mov ds,sel
nextchunk:				   ;<---
						   ;1. set base of ds
	mov ebx,ds
	mov eax,base
	add eax,dwRdWr
	push eax
	pop dx
	pop cx
	mov ax,7		;Set Base
	int 31h
	jc sm1_er_pm3

	mov eax,limit
	mov ecx,dwRdWr
	add ecx,pBuffer
	sub eax,ecx
	jae @F
	lar ecx,ebx
	shr ecx,8
	or cl,08h	   ;data-> code segment
	mov ax,9		;SetAccRights
	int 31h
	xor eax,eax
@@:
	cmp eax,?CHKSIZE-1
	jbe @F
	mov eax,?CHKSIZE-1
@@:
	push eax
	pop dx
	pop cx
	mov ax,8	;Set Limit
	int 31h
	jc sm1_er_pm4

	mov eax,numBytes	;3. ecx = _min(length,?CHKSIZE)
	and eax,eax
	jz done1
	mov ecx,?CHKSIZE
	sub eax,ecx
	jnc @F				;remaining size is larger?
	add ecx,eax
	sub eax,eax
@@:
	mov rlength,ecx
	mov numBytes,eax
	push ds				;4. selector cache update
	pop ds
	xor edx,edx
	mov ebx,handle
	mov eax,func
	int 21h
	jc sm1_er
	movzx eax,ax
	add dwRdWr,eax
	cmp ax,?CHKSIZE
	jz nextchunk
done1:
	mov eax,dwRdWr
	clc
	jmp done
sm1_er_pm1:
ifdef _DEBUG
	mov eax,333
	jmp sm1_er_pm
endif
sm1_er_pm2:
ifdef _DEBUG
	mov eax,334
	jmp sm1_er_pm
endif
sm1_er_pm3:
ifdef _DEBUG
	mov eax,335
	jmp sm1_er_pm
endif
sm1_er_pm4:
ifdef _DEBUG
	mov eax,336
	jmp sm1_er_pm
endif
	mov eax,333
sm1_er_pm:
sm1_er:
	stc
done:
	pushfd
	mov ds,dsreg
	mov ebx,sel
	and ebx,ebx
	jz @F
	push eax
	mov ax,1	;Free Desc
	int 31h
	pop eax
@@:
	popfd
	ret
	align 4
simint21 endp

endif
	end
