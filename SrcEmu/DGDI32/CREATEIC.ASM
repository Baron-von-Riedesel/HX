
;--- implements CreateICA() and CreateICW()

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

CreateICA proc public uses ebx lpszDriver:ptr BYTE, lpszDevice: ptr BYTE, lpszOut:ptr BYTE, lpInitData:ptr

		xor eax, eax
		@strace	<"CreateICA(", lpszDriver, ", ", lpszDevice, ", ", lpszOut, ", ", lpInitData, ")=", eax>
		ret
        align 4
CreateICA endp

CreateICW proc public lpszDriver:ptr WORD, lpszDevice: ptr WORD, lpszOut:ptr WORD, lpInitData:ptr

		xor eax, eax
		@strace	<"CreateICW(", lpszDriver, ", ", lpszDevice, ", ", lpszOut, ", ", lpInitData, ")=", eax>
		ret
        align 4
CreateICW endp

		end
