
;*** copy memory ***
;*** fill memory with byte ***
;*** zero memory ***

?XMMCOPY	equ 0	;use a faster copy proc on P4s

	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:none
	option proc:private

	include winbase.inc
	include dkrnl32.inc
	include macros.inc

	.CODE

RtlFillMemory proc public uses edi buffer:ptr BYTE, count:DWORD, cChar:DWORD

	mov edi,buffer
	mov al, byte ptr cChar
	mov ah,al
	push ax
	push ax
	pop eax
	mov ecx,count
	mov dl,cl
	shr ecx,2
	rep stosd
	mov cl,dl
	and cl,3
	rep stosb
	ret
	align 4

RtlFillMemory endp

RtlZeroMemory proc public buffer:ptr BYTE, count:DWORD
	invoke RtlFillMemory, buffer, count, 0
	ret
	align 4
RtlZeroMemory endp

RtlMoveMemory  proc public uses esi edi dest:ptr byte,src:ptr byte, count:dword

	mov edi,dest
	mov esi,src
	mov ecx,count
if 1
;--- check for overlapping regions
;--- if dst is below or equal src everything is ok
;--- if dst is above src but below src+count copy backwards
;--- else copy std
	lea edx,[esi+ecx-1]	;let point edx to end of src block
	cmp esi,edi 		;jump if src-beg >= dst
	jnc @F
	cmp edx,edi			;jump if src-end < dst
	jc @F
	mov esi, edx		;copy from end to begin
	lea edi, [edi+ecx-1]
	mov edx,ecx
	std
	and ecx,3
	rep movsb
	mov ecx,edx
	shr ecx,2
	sub esi,3
	sub edi,3
	rep movsd
	cld
	jmp sm1
@@:
endif
if ?XMMCOPY
	jmp [lpfnCopyProc]
endif
stdcopyproc::
	mov dl,cl
	shr ecx,2
	rep movsd
	mov cl,dl
	and cl,3
	rep movsb
sm1:
	mov eax,dest
	@strace <"RtlMoveMemory(", dest, ", ", src, ", ", count, ")=", eax>
	ret
	align 4

if ?XMMCOPY

	.DATA

lpfnCopyProc dd offset testcopyproc

	.CODE
	.XMM

testcopyproc:
	push ecx
	invoke IsProcessorFeaturePresent, PF_XMMI_INSTRUCTIONS_AVAILABLE
	.if (!eax)
		mov edx, offset stdcopyproc
	.else
		mov edx, offset xmmcopyproc
	.endif
	mov lpfnCopyProc, edx
	pop ecx
	jmp edx

xmmcopyproc:
	mov edx, ecx			;Keep a copy of count
	mov ecx, 8				;A trick that's faster than rep movsb...
	sub ecx, edi			;Align destination to qword
	and ecx, 111b 			;Get the low bits
	sub edx, ecx			;Update copy count
	neg ecx					;Set up to jump into the array
	add ecx, offset @@AlignDone
	jmp ecx					;Jump to array of movsb's

	align @WordSize
	repeat 8				;1 + 7, first used for alignment
		movsb				;Opcode A4
	endm
@@AlignDone:				;Destination is dword aligned
	mov ecx, edx			;Number of bytes left to copy
	shr ecx, 6				;Get 64-byte block count
	jz xmmdone
	push ebp
	push ebx
	mov eax, ecx
	and ecx, 0127
	shr eax, 7				;get number of 8 kB blocks
	mov ebp, ecx			;save this value in a register
	jz lastcacheblock
	align 4
nextcacheblock:
	mov cx, 1024-8		;do 1024/16*2 (=128) reads
@@:
	mov ebx, [esi + ecx * 8]
	sub ecx, 8
	jnz @B
	mov cl, 128			;128*64 = 8 kb block
	align 4
nextblock:
	movq mm0, [esi + 00]
	movq mm1, [esi + 08]
	movq mm2, [esi + 16]
	movq mm3, [esi + 24]
	movq mm4, [esi + 32]
	movq mm5, [esi + 40]
	movq mm6, [esi + 48]
	movq mm7, [esi + 56]
	movntq [edi + 00], mm0
	movntq [edi + 08], mm1
	movntq [edi + 16], mm2
	movntq [edi + 24], mm3
	movntq [edi + 32], mm4
	movntq [edi + 40], mm5
	movntq [edi + 48], mm6
	movntq [edi + 56], mm7
	add esi, 64
	add edi, 64
	dec ecx
	jnz nextblock
	sub eax, 1
	jc blocksdone
	jnz nextcacheblock
	mov ecx, ebp
lastcacheblock:
	and cl,cl
	jnz nextblock
blocksdone:
	pop ebx
	pop ebp
	sfence
	emms					;Set all FPU tags to empty
xmmdone:
	mov ecx, edx			;Has valid low 6 bits of the byte count
	and ecx, 3Fh			;Only look at the "remainder" bits
	rep movsb				;a P4's movsb is as fast as movsd 
	jmp sm1
endif
	align 4

RtlMoveMemory  endp

	end
