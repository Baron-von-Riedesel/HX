
;--- implements:
;--- GetStdHandle
;--- SetStdHandle

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
	include wincon.inc
	include macros.inc
	include dkrnl32.inc

.BASE$IA SEGMENT dword public 'DATA'
	DD offset Install
.BASE$IA ENDS

	.DATA

g_stdhdl label dword
if ?NONULLHDL
	dd 10000h, 1, 2
else
	dd 0, 1, 2
endif

;g_bIsDevice dd 8 dup (0)
g_bIsConsole dd 8 dup (0)

		.CODE

Install proc uses ebx
	xor ebx, ebx
	.while (ebx < 5)
		invoke GetFileType, ebx
		cmp al, FILE_TYPE_CHAR
		jz @F
		btr g_bProcessed, ebx
		inc ebx
		.continue
@@:
;		bts g_bIsDevice, ebx
		mov ax,4400h
		int 21h
		jc @F
		test dl,10h	;is it an "int 29h" device?
		jz @F
		bts g_bIsConsole, ebx
@@:
		inc ebx
	.endw
	invoke SetIntensityBackground	;set 16 background colors

if 1
_SetDefaultAttribute proto
	call _SetDefaultAttribute
endif
	ret
	align 4
Install endp

gethandletabptr proc uses eax
	mov ah,62h
	int 21h
	push ds
	mov ds,ebx
	movzx ebx,word ptr ds:[36h]
	shl ebx,4
	movzx eax,word ptr ds:[34h]
	add ebx,eax
	pop ds
	ret
	align 4
gethandletabptr endp

GetStdHandle proc public typ:dword

	mov ecx,typ
	sub ecx, STD_INPUT_HANDLE	;== -10 -> 0, -1, -2
	neg ecx
	cmp ecx, 3
	jnb error
	mov eax, [ecx*4+offset g_stdhdl]
if ?NONULLHDL
	and eax, eax
	jnz @F
	mov eax,10000h
@@:
endif
exit:
	@strace <"GetStdHandle(", typ, ")=", eax>
	ret
error:
	mov eax,-1
	jmp exit
	align 4

GetStdHandle endp

IsFileHandle proc

if ?NONULLHDL
	cmp ecx, 10000h
	stc
	jz @F
endif
	cmp ecx, 1000h
@@:
	ret
	align 4
IsFileHandle endp

;--- it needn't be a file, it can be a screen buffer!

SetStdHandle proc public uses ebx typ:dword, handle:dword

	mov ecx,typ
	sub ecx, STD_INPUT_HANDLE	;== -10 -> 0, -1, -2
	neg ecx
	cmp ecx, 3
	jnb error
	mov eax, ecx
	mov ecx, handle
	invoke IsFileHandle
	jc @F
	cmp [ecx].SCREENBUF.dwType, TYPE_SCREENBUF
	jnz error
	mov [eax*4+offset g_stdhdl], ecx
	jmp done
@@:
	.if (ecx == [eax*4+offset g_stdhdl])
		jmp done
	.endif
	mov [eax*4+offset g_stdhdl], ecx
	call gethandletabptr	;get linear address of handle table in ebx
	.if (byte ptr @flat:[ebx+eax] != -1)
		pushad
		mov ebx, eax
		mov ah,3Eh
		int 21h
		popad
	.endif
	mov ecx, eax
	mov ebx, handle
	mov ah,46h
	int 21h
	jc error
done:
	@mov eax, 1
exit:
	@strace <"SetStdHandle(", typ, ", ", handle, ")=", eax>
	ret
error:
	xor eax,eax
	jmp exit
	align 4

SetStdHandle endp

	end
