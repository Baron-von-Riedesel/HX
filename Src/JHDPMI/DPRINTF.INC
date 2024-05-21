
;--- dprintf for debug displays

@dprintf macro text:req,args:vararg
local sym
	.data
sym db text,10,0
	.code
	.386
ifb <args>
	invoke dprintf, offset sym
else
	invoke dprintf, offset sym, args
endif
endm

;--- i64toa(long long n, char * s, int base);
;--- convert 64-bit long long to string

;--- number: eax
;--- esi=outbuf ptr
;--- ebx=base

di64toa proc stdcall

	push edi
	mov ch,0
	mov edi, ebx
	mov ebx, esi
	cmp edi,-10
	jne @F
	neg edi
	and eax,eax
	jns @F
	neg eax
	mov ch,'-'
@@:
	add ebx,11
	mov byte ptr [ebx],0
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
	pop edi
	ret

di64toa endp

	.data
d_szTmp db 12 dup(?)
	.code

;--- dprintf uses low-level I/O in any case
;--- SS is unknown.

dprintf proc c fmt:ptr, args:vararg

local flag:byte
local longarg:byte
local size_:dword
local fillchr:dword

	pushad
	mov eax, ss
	lar eax, eax
	bt eax, 22
	jc @F
	movzx ebp, bp
@@:
	cld
	lea edi,args
@@L335:
	mov esi,fmt
nextchar:
	lodsb
	or al,al
	je done
	cmp al,'%'
	je formatitem
	call handle_char
	jmp nextchar
done:
	popad
	ret

formatitem:
	push offset @@L335
	xor edx,edx
	mov [longarg],dl
	mov bl,1
	mov cl,' '
	cmp BYTE PTR [esi],'-'
	jne @F
	dec bl
	inc esi
@@:
	mov [flag],bl
	cmp BYTE PTR [esi],'0'
	jne @F
	mov cl,'0'
	inc esi
@@:
	mov [fillchr],ecx
	mov ebx,edx

	.while ( byte ptr [esi] >= '0' && byte ptr [esi] <= '9' )
		lodsb
		sub al,'0'
		movzx eax,al
		imul ecx,ebx,10		;ecx = ebx * 10
		add eax,ecx
		mov ebx,eax
	.endw

	mov [size_],ebx
	cmp BYTE PTR [esi],'l'
	jne @F
	mov [longarg],1
	inc esi
@@:
	lodsb
	mov [fmt],esi
	cmp al,'x'
	je handle_x
	cmp al,'X'
	je handle_x
	cmp al,'d'
	je handle_d
	cmp al,'u'
	je handle_u
	cmp al,'s'
	je handle_s
	cmp al,'c'
	je handle_c
	and al,al
	jnz @F
	pop eax
	jmp done
handle_c:
	mov eax,ss:[edi]
	add edi, 4
@@:
	call handle_char
	retn

handle_s:
	mov esi,ss:[edi]
	add edi,4
	jmp print_string
handle_d:
handle_i:
	mov ebx,-10
	jmp @F
handle_u:
	mov ebx, 10
	jmp @F
handle_x:
	mov ebx, 16
@@:
	mov eax,ss:[edi]
	add edi,4
	lea esi, d_szTmp
	call di64toa	; eax=number, esi=ptr, ebx=base
	mov esi, eax
	call print_string
	retn

print_string:		;print string ESI, size EAX
	mov eax, esi
	.while byte ptr [esi]
		inc esi
	.endw
	sub esi, eax
	xchg eax, esi
	mov ebx,size_
	sub ebx,eax
	.if flag == 1
		.while sdword ptr ebx > 0
			mov eax, [fillchr]
			call handle_char	;print leading filler chars
			dec ebx
		.endw
	.endif

	.while byte ptr [esi]
		lodsb
		call handle_char	;print char of string
	.endw

	.while sdword ptr ebx > 0
		mov eax, [fillchr]
		call handle_char	;print trailing spaces
		dec ebx
	.endw
	retn


handle_char:
	mov dl, al
	mov ax, 0
	int 41h
	retn

dprintf endp
