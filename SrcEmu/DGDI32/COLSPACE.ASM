
        .386
if ?FLAT
        .MODEL FLAT, stdcall
else
        .MODEL SMALL, stdcall
endif
		option casemap:none
        option proc:private

        include winbase.inc
        include wingdi.inc
        include dgdi32.inc
        include macros.inc

        .CODE

CreateColorSpaceA proc public lpSpace:ptr

        xor eax, eax
		@strace <"CreateColorSpaceA(", lpSpace, ")=", eax, " *** unsupp">
        ret
		align 4
CreateColorSpaceA endp

CreateColorSpaceW proc public lpSpace:ptr

        xor eax, eax
		@strace <"CreateColorSpaceW(", lpSpace, ")=", eax, " *** unsupp">
        ret
		align 4
CreateColorSpaceW endp

		end
