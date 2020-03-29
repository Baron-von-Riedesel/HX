
		.386
if ?FLAT
		.MODEL FLAT, stdcall
else
		.MODEL SMALL, stdcall
endif
		option casemap:none
        option proc:private

		include winbase.inc
		include winuser.inc
		include wincon.inc
        include macros.inc
        include duser32.inc

		.code

GetPropA proc public hwnd:DWORD, lpString: ptr BYTE
		xor eax,eax
		@strace	<"GetPropA(", hwnd, ", ", lpString, ")=", eax>
		ret
        align 4
GetPropA endp

SetPropA proc public hwnd:DWORD, lpString: ptr BYTE, hData:DWORD
		xor eax,eax
		@strace	<"SetPropA(", hwnd, ", ", lpString, ", ", hData, ")=", eax>
		ret
        align 4
SetPropA endp

RemovePropA proc public hwnd:DWORD, lpString: ptr BYTE
		xor eax,eax
		@strace	<"RemovePropA(", hwnd, ", ", lpString, ")=", eax>
		ret
        align 4
RemovePropA endp

		end
        
