
	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:none
	option proc:private

	include winbase.inc
	include macros.inc

C_BLANK equ     ' '             ; ASCII space character
C_TAB   equ     09h             ; ASCII horizontal tab character
C_QUOTE equ     '"'             ; ASCII (double) Quote Charater
C_BACKSLASH equ '\'             ; ASCII backward slash character
C_CR    equ     0dh

DELIM   MACRO   target
;	cmp al,C_CR        ;; Test for end-of-line character
;	je target
	or al,al           ;; Either Carriage Return or Null
	je target
	ENDM

	.CODE

_setargv proc uses esi edi ebx pSrc:ptr WORD, argc:ptr dword

local   argv:dword

	mov eax, pSrc
;--- EDI will count the number of arguments
;--- EDX will count the number of items needed for the arguments
;--- (not including the null terminators)
	xor edi,edi
	xor edx,edx
	mov esi,eax
	jmp arg110
nextarg: 				;<--- next argument
	push ebx			;length last argument
arg110:
	lodsw
	cmp al,C_BLANK
	je arg110
	cmp al,C_TAB
	je arg110
	DELIM done_pars2	;exit if EOL
	inc edi 			;Another argument
	xor ebx,ebx 		;EBX will count characters in argument
	sub esi,2			;back up to reload character
	push esi			;save start of argument
nextchar: 				;<--- next char
	lodsw
	cmp al,C_BLANK		;end of argument
	je nextarg
	cmp al,C_TAB
	je nextarg			;white space terminates argument
	DELIM done_pars		;exit if EOL
	and ebx,ebx 		;start of argument?
	jnz @F
	cmp al,C_QUOTE
	je do_quote
@@:
	cmp al,C_BACKSLASH
	jnz @F
	cmp word ptr [esi],C_QUOTE
	jnz @F
	add esi,2
@@:
	inc ebx
	inc edx 			;1 char
	jmp nextchar		;--->
do_quote: 				;handle C_QUOTE
	pop eax
	push esi			;set new start
nextitem_qu:			;<--- next char inside quoted string
	lodsw
	DELIM done_pars
	cmp al,C_QUOTE
	jne @F
	cmp word ptr [esi],C_QUOTE
	jne nextchar		; end of quoted portion of string
	add esi,2
@@:
	cmp al,C_BACKSLASH
	jnz @F
	cmp word ptr [esi],C_QUOTE
	jnz @F
	add esi,2
@@:
	inc ebx
	inc edx
	jmp nextitem_qu 	;--->

done_pars: 				; parsing done
	push ebx			; length last argument
done_pars2:
;--- addresses and sizes of arguments are onto the stack!
	mov ecx, argc
	mov [ecx],edi		; Store number of arguments
	add edx,edi 		; add terminator bytes
	shl edx, 1
	shl edi,2			; each pointer needs 4 bytes
	add edx,edi 		; add space for pointers to space for chars

	invoke GlobalAlloc, GMEM_FIXED, edx
	and eax,eax
	jz setargv_ex

	mov argv,eax
	mov ecx,argc
	mov ecx,[ecx]
	add edi,eax 		; edi -> behind vector table (strings)
	lea ebx,[edi-4]
	jecxz nostrings
	mov edx,ecx
nextstring: 			;<---
	pop ecx 			;length
	pop esi 			;address
	mov [ebx],edi
	sub ebx,4
nextc:
	lodsw
	cmp al,C_QUOTE
	jz is_quote
	cmp al,C_BACKSLASH
	jnz @F
is_quote:
	cmp word ptr [esi],C_QUOTE
	jz nextc
@@:
	stosw
	loop nextc

	xor ax,ax
	stosw
	dec edx
	jnz nextstring  	;--->
nostrings:
	mov eax,argv		;return 
setargv_ex:
	ret
	align 4

_setargv endp


CommandLineToArgvW proc public lpCmd:ptr WORD, pArgc:ptr DWORD

	invoke _setargv, lpCmd, pArgc
	@strace <"CommandLineToArgvW(", lpCmd, ", ", pArgc, ")=", eax>
	ret
	align 4

CommandLineToArgvW endp

	end
