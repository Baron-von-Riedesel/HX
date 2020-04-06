
;--- console fill functions
;--- implements:
;--- FillConsoleOutputAttribute
;--- FillConsoleOutputCharacterA
;--- FillConsoleOutputCharacterW

	.386

if ?FLAT
	.MODEL FLAT,stdcall
else
	.MODEL SMALL, stdcall
endif
	option proc:private
	option casemap:none

	include winbase.inc
	include wincon.inc
	include dkrnl32.inc
	include macros.inc

	.CODE

?CHECKMAX equ 1

FillConsoleOutputAttribute proc public uses edi hConOut:dword, attr:dword, nAttr:dword, koord:COORD, lpWritten:ptr dword

	movzx eax,word ptr [VIOCOLS]
	shl eax,1
	movzx ecx,koord.Y				   ;ypos
	mul ecx
	movzx ecx,koord.X				   ;xpos
	add eax,ecx
	add eax,ecx
	mov edi,eax
	invoke getscreenptr, hConOut
	add edi, eax
	mov ecx, nAttr
if ?CHECKMAX
	movzx edx,word ptr [VIOPAGESIZ]
	add eax,edx
	lea edx,[edi+2*ecx]
	sub eax,edx
	jnc @F
	neg eax
	shr eax,1
	sub ecx,eax
	jbe error
@@:
endif
	mov edx, edi
	jecxz done
	mov eax,attr
if ?FLAT eq 0
	push es
	push @flat
	pop es
endif
@@:
	inc edi
	stosb
	loop @B
if ?FLAT eq 0
	pop es
endif
done:
	mov ecx, lpWritten
	jecxz @F
	mov eax, edi
	sub eax, edx
	shr eax, 1
	mov [ecx],eax
@@:
	@mov eax,1
exit:
	@straceF DBGF_COUT,<"FillConsoleOutputAttribute(", hConOut, ", ", attr, ", ", nAttr, ", ", koord, ", ", lpWritten, ")=", eax>
	ret
error:
	xor eax,eax
	jmp exit
	align 4

FillConsoleOutputAttribute endp

FillConsoleOutputCharacterA proc public uses edi hConOut:dword, char:dword, nChar:dword, koord:COORD, lpWritten:ptr dword

	movzx eax,word ptr [VIOCOLS]
	shl eax,1
	movzx ecx,koord.Y				   ;ypos
	mul ecx
	movzx ecx,koord.X				   ;xpos
	add eax,ecx
	add eax,ecx
	mov edi,eax
	invoke getscreenptr, hConOut
	add edi, eax
	mov ecx, nChar
if ?CHECKMAX
	movzx edx,word ptr [VIOPAGESIZ]
	add eax,edx
	lea edx,[edi+2*ecx]
	sub eax,edx
	jnc @F
	neg eax
	shr eax,1
	sub ecx,eax
	jbe error
@@:
endif
	mov edx, edi
	jecxz done
	mov eax,char
if ?FLAT eq 0
	push es
	push @flat
	pop es
endif
@@:
	stosb
	inc edi
	loop @B
if ?FLAT eq 0
	pop es
endif
done:
	mov ecx, lpWritten
	jecxz @F
	mov eax, edi
	sub eax, edx
	shr eax, 1
	mov [ecx],eax
@@:
	@mov eax,1
exit:
	@straceF DBGF_COUT,<"FillConsoleOutputCharacterA(", hConOut, ", ", char, ", ", nChar, ", ", koord, ", ", lpWritten, ")=", eax>
	ret
error:
	xor eax,eax
	jmp exit
	align 4

FillConsoleOutputCharacterA endp

FillConsoleOutputCharacterW proc public hConOut:dword,char:dword,nChar:dword,koord:COORD,pWritten:ptr dword

	invoke FillConsoleOutputCharacterA, hConOut,char,nChar,koord,pWritten
	@straceF DBGF_COUT,<"FillConsoleOutputCharacterW(", hConOut, ", ", char, ", ", nChar, ", ", koord, ", ", pWritten, ")=", eax>
	ret
	align 4

FillConsoleOutputCharacterW endp

	end

