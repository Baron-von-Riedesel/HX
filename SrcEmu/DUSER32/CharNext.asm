
;--- CharNextA/W, CharPrevA/W, CharPrevExA

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
;        include winuser.inc
		include macros.inc

        .CODE

CharNextA proc public lpsz:ptr BYTE
        mov eax, lpsz
        .if (byte ptr [eax])
            inc eax
        .endif
;		@strace	<"CharNextA(", lpsz, ")=", eax>
        ret
        align 4
CharNextA endp

CharNextExA proc public CodePage:WORD, lpsz:ptr BYTE, dwFlags:DWORD
        mov eax, lpsz
        .if (byte ptr [eax])
            inc eax
        .endif
;		@strace	<"CharNextExA(", CodePage, ", ", lpsz, ", ", dwFlags, ")=", eax>
        ret
        align 4
CharNextExA endp

CharNextW proc public lpsz:ptr WORD
        mov eax, lpsz
        .if (word ptr [eax])
            inc eax
            inc eax
        .endif
;		@strace	<"CharNextW(", lpsz, ")=", eax>
        ret
        align 4
CharNextW endp

CharPrevA proc public lpszStart:ptr BYTE, lpszCurr:ptr BYTE
        mov eax, lpszCurr
        .if (eax > lpszStart)
            dec eax
        .endif
;		@strace	<"CharPrevA(", lpszStart, ", ", lpszCurr, ")=", eax>
        ret
        align 4
CharPrevA endp

CharPrevExA proc public CodePage:WORD, lpszStart:ptr BYTE, lpszCurr:ptr BYTE, dwFlags:DWORD
        mov eax, lpszCurr
        .if (eax > lpszStart)
            dec eax
        .endif
;		@strace	<"CharPrevExA(", CodePage, ", ", lpszStart, ", ", lpszCurr, ", ", dwFlags, ")=", eax>
        ret
        align 4
CharPrevExA endp

CharPrevW proc public lpszStart:ptr WORD, lpszCurr:ptr WORD
        mov eax, lpszCurr
        .if (eax > lpszStart)
            dec eax
            dec eax
        .endif
;		@strace	<"CharPrevW(", lpszStart, ", ", lpszCurr, ")=", eax>
        ret
        align 4
CharPrevW endp

        end

