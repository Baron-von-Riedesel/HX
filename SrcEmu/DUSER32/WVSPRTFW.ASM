
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

;--- the vsprintf used is type stdcall! 
;--- this will avoid that it is mistakenly used
;--- instead of the standard CRT vsprintf proc

		.CODE

vsprintf proto stdcall a1:dword, a2:dword, a3:dword		

wvsprintfW proc public a1:ptr WORD, a2:ptr WORD, a3:ptr

		invoke vsprintf, a1, a2, a3
		.if (eax)
			pushad
			mov ecx, eax
			mov esi, a1
			.while (ecx)
				movzx eax, byte ptr [esi+ecx]
				mov [esi+ecx*2],ax
				dec ecx
			.endw
			popad
		.endif
		@strace <"wvsprintfW(", a1, ", ", a2, ", ", a3, ")=", eax>
		ret

wvsprintfW endp

		end

