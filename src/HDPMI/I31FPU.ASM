
;--- ax=0Exx (fpu support)
;--- todo: check if FPU really exists (on 80386)

	.386P

	include hdpmi.inc
	include external.inc

	option proc:private

_TEXT32 segment

;*** coprocessor functions 0Exxh ***

FPU_NOFPU	equ 00h
FPU_80287	equ 20h
FPU_80387	equ 30h
FPU_80487	equ 40h

FPU_MPV	equ 01h		;virtual MP bit
FPU_EMV	equ 02h		;virtual EM bit
FPU_MPR	equ 04h		;real MP bit
FPU_EMR	equ 08h		;real EM bit

	@ResetTrace
        
i31f0E proc public
	pop ebx			;restore EBX (saved by int31api)	
	cmp al,1
	jz setcostate

i31f0E endp		;fall through

;--- int 31h, ax=0900h
;--- out: flags in AX

getcostate proc
	smsw ax
	shr al,1
	and al, FPU_MPV or FPU_EMV
	or al, FPU_80387 or FPU_MPR   ;set fpu 80387 + fpu exists
	xor ah,ah
	ret
	align 4
getcostate endp

;--- int 31h, ax=0901h
;--- BX=coprocessor bit flags

setcostate proc
	push ebx
	push eax
	and bl,FPU_MPV or FPU_EMV		;bit 0+1
	shl bl,1
	smsw ax
	and al,not (CR0_MP + CR0_EM)
	or al,bl
	lmsw ax
	pop eax
	pop ebx
	ret
	align 4
setcostate endp

_TEXT32 ends

	end
