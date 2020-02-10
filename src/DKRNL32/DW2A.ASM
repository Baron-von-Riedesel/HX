
	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:NONE
	option proc:private

;	include winbase.inc
;	include dkrnl32.inc

	.CODE

;--- convert an integer in eax to ascii, stores in edi
;--- 

	public byt2asc

__dw2aX proc public
	mov dl, 0
	jmp dw2a
__dw2aX endp

__dw2a proc public
	mov dl,1		;suppress leading zeros
__dw2a endp

dw2a proc
	xor ecx, ecx
	push eax
	shr eax, 16
	call w2asc
	pop eax
w2asc:
	push eax
	shr eax, 8
	call byt2asc
	pop eax
byt2asc::       ;<- render AL into [edi], dl=0
	mov ah,al
	shr al, 4
	call nib2asc
	mov al,ah
nib2asc:
	and al,0Fh
	add al,'0'
	cmp al,'9'
	jbe @F
	add al,'A' - '9' - 1
@@:
	.if (dl && (al == '0'))
		.if (ch || (cl == 7))
			stosb
		.endif
	.else
		inc ch
		stosb
	.endif
	inc cl
	ret
	align 4

dw2a endp

;--- display number in EAX decimal into [edi]
;--- 

__dw2aD proc public uses ebx esi ebp

	xor esi, esi
__dw2aD_0::
	mov bl,' '
__dw2aD_1::
	mov ecx,10
	mov ebp,esp
nextchar:
	or eax,eax
	je done
	cdq
	div ecx
	push edx
	jmp nextchar
done:
	mov ecx, ebp
	sub ecx, esp
	jnz @F
	push ecx	;push 0
	add ecx,4	;print at least a '0'
@@:     
	shr ecx, 2
	sub esi, ecx
	jbe nospaces
	mov al, bl
@@:     
	stosb
	dec esi
	jnz @B 
nospaces:
@@:
	pop eax
	add al,'0'
	stosb
	loop @B
	ret
	align 4

__dw2aD endp

;--- min size of number in ESI (will be filled with ' ')

__dw2aDX proc public uses ebx esi ebp

	jmp __dw2aD_0
	align 4

__dw2aDX endp

;--- min size of number in ESI (will be filled with value in BL)

__dw2aDY proc public uses ebx esi ebp

	jmp __dw2aD_1
	align 4

__dw2aDY endp

if 1; ifdef _DEBUG
;__dw2aDebug proc uses edi
if ?FLAT
;__dw2aDebug proc export uses edi
__dw2aDebug proc public uses edi
else
__dw2aDebug proc public uses edi esi
endif

local szNum[12];byte

	lea edi, szNum
	mov esi, edi
	call __dw2a
	mov al, 0
	stosb
	mov ax,2
	int 41h
;	invoke OutputDebugString, addr szNum
	ret
__dw2aDebug endp
endif

	end
