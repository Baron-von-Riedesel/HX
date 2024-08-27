
;--- this is helper code to prevent Open Watcom's runtime
;--- from including the MessageBoxA() API if a text mode DOS binary is
;--- to be created with HX's Win32 emulation code.

	.386
	.model flat

	.code

MessageBoxA proc stdcall uses esi hWnd:dword, pszText1:ptr, pszText2:ptr, dwFlags:dword
	mov esi, pszText1
	call dispesi
	call dispcrlf
	mov esi, pszText2
	call dispesi
	call dispcrlf
	ret
dispesi:
	lodsb
	cmp al,0
	jz done
	mov dl,al
	mov ah,2
	int 21h
	jmp dispesi
done:
	retn
dispcrlf:
	mov ah,2
	mov dl,13
	int 21h
	mov ah,2
	mov dl,10
	int 21h
	retn
MessageBoxA endp

	end
