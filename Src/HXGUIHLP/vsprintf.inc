
;--- simple vsprintf for 32-bit (DOS, Windows)
;--- handles %x, %u, %d, %s only 

strlen proc c uses edi string:ptr
	mov ecx,-1
	mov edi,string
	mov al,0
	cld
	repnz scasb
	mov eax,ecx
	inc eax
	not eax
	ret
strlen endp

;--- convert long to string
;--- ltoa( long n, char * s, base n );

ltoa PROC c uses ebx edi number:dword, tbuffer:ptr byte, base:dword

	mov eax, number
	mov ebx, tbuffer
	mov edi, base
	mov ch,0
	cmp edi,-10
	jne @F
	mov edi,10
	and eax,eax
	jns @F
	neg eax
	mov ch,'-'
@@:
	add ebx,10
	mov BYTE PTR [ebx],0
	dec ebx
@@nextdigit:
	xor edx, edx
	div edi
	add dl,'0'
	cmp dl,'9'
	jbe @F
	add dl,7+20h
@@:
	mov [ebx],dl
	dec ebx
	and eax, eax
	jne @@nextdigit
	cmp ch,0
	je @F
	mov [ebx],ch
	dec ebx
@@:
	inc ebx
	mov eax,ebx
	ret

ltoa ENDP

vsprintf PROC c uses ebx esi edi buffer:ptr, fmt:ptr byte, args:ptr

local flag:byte
local longarg:byte
local size_:dword
local fillchr:dword
local szTmp[12]:byte

	mov ebx,args
	mov edi,buffer
contchar:
	mov esi,fmt
nextchar:
	lodsb
	or al,al
	je done
	cmp al,'%'
	je formatitem
	stosb
	jmp nextchar
done:
	mov eax, edi
	sub eax, buffer
	ret 

formatitem:
	xor edx,edx
	mov [longarg],dl
	mov ah,1
	mov cl,' '
	cmp BYTE PTR [esi],'-'
	jne @F
	dec ah
	inc esi
@@:
	mov [flag],ah
	cmp BYTE PTR [esi],'0'
	jne @F
	mov cl,'0'
	inc esi
@@:
	mov [fillchr],ecx
	mov [size_],edx

	.while ( byte ptr [esi] >= '0' && byte ptr [esi] <= '9' )
		lodsb
		sub al,'0'
		movzx eax,al
		imul ecx,edx,10		;ecx = edx * 10
		add eax,ecx
		mov edx,eax
	.endw

	mov [size_],edx
	cmp BYTE PTR [esi],'l'
	jne @F
	mov [longarg],1
	inc esi
@@:
	lodsb
	mov [fmt],esi
	or al,al
	je done
	cmp al,'u'
	je handle_u
	cmp al,'d'
	je handle_d
	cmp al,'s'
	je handle_s
	cmp al,'x'
	je handle_x
	cmp al,'X'
	je handle_x
handle_c:
	mov eax, [ebx]
	add ebx, 4
	stosb
	jmp contchar

handle_s:
	mov esi, [ebx]
	add ebx, 4
	jmp print_string

handle_d:
	mov dl, -10
	jmp handleint
handle_u:
	mov dl, 10
	jmp handleint
handle_x:
	mov dl, 16
handleint:
	mov eax,[ebx]
	add ebx,4
	lea ecx,[szTmp]
	movzx edx, dl
	invoke ltoa, eax, ecx, edx
	mov esi,eax

print_string:		;print string ESI

	push esi
	call strlen
	add esp,4
	mov edx, [size_]
	sub edx, eax
	cmp [flag],1
	jne print_string_chars

;--- preceding chars
	mov eax, [fillchr]
	jmp checkfill
@@:
	stosb
	dec edx
checkfill:
	or edx,edx
	jg @B

print_string_chars:
	.while (byte ptr [esi])
		movsb
	.endw

;--- trailing chars
	mov eax, [fillchr]
@@:
	or edx,edx
	jle contchar
	stosb
	dec edx
	jmp @B

vsprintf ENDP

