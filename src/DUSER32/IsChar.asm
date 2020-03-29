
        .386
if ?FLAT
        .MODEL FLAT, stdcall
else
        .MODEL SMALL, stdcall
endif
		option casemap:none
ifndef __POASM__        
        option proc:private
endif        

        include winbase.inc
		include macros.inc

        .CODE

IsCharAlphaA proc public character:BYTE
		
		xor eax, eax
		mov cl, character
		.if ((cl >= 'A' && cl <= 'Z') || (cl >= 'a' && cl <= 'z'))
			inc eax
		.endif
;		@strace	<"IsCharAlphaA(", character, ")=", eax>
		ret
        align 4
IsCharAlphaA endp

IsCharAlphaW proc public character:WORD
		
		xor eax, eax
		mov cx, character
		.if ((cl >= 'A' && cl <= 'Z') || (cl >= 'a' && cl <= 'z'))
			inc eax
		.endif
;		@strace	<"IsCharAlphaW(", character, ")=", eax>
		ret
        align 4
IsCharAlphaW endp

IsCharAlphaNumericA proc public character:BYTE
		
		xor eax, eax
		mov cl, character
		.if ((cl >= '0' && cl <= '9') || (cl >= 'A' && cl <= 'Z') || (cl >= 'a' && cl <= 'z'))
			inc eax
		.endif
;		@strace	<"IsCharAlphaNumericA(", character, ")=", eax>
		ret
        align 4
IsCharAlphaNumericA endp

IsCharAlphaNumericW proc public character:WORD
		
		xor eax, eax
		mov cx, character
		.if ((cl >= '0' && cl <= '9') || (cl >= 'A' && cl <= 'Z') || (cl >= 'a' && cl <= 'z'))
			inc eax
		.endif
;		@strace	<"IsCharAlphaNumericA(", character, ")=", eax>
		ret
        align 4
IsCharAlphaNumericW endp

        end

