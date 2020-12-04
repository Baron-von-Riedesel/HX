
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

        .CODE

WNetGetUniversalNameW proc public lpLocalPath:ptr WORD, dwInfoLevel:DWORD, lpBuffer:ptr WORD, lpBufferSize:ptr DWORD
WNetGetUniversalNameW endp

WNetGetUniversalNameA proc public lpLocalPath:ptr BYTE, dwInfoLevel:DWORD, lpBuffer:ptr BYTE, lpBufferSize:ptr DWORD
		mov eax, ERROR_NO_NETWORK
        @strace <"WNetGetUniversalNameA(", lpLocalPath, ", ", dwInfoLevel, ", ", lpBuffer, ", ", lpBufferSize, ")=", eax>
        ret
        align 4
WNetGetUniversalNameA endp

WNetGetUserA proc public lpsz1:ptr, lpsz2:DWORD, lpdw1:ptr dword
		mov eax, ERROR_NO_NETWORK
        @strace <"WNetGetUserA(", lpsz1, ", ", lpsz2, ", ", lpdw1, ")=", eax>
        ret
        align 4
WNetGetUserA endp

WNetGetResourceInformationA proc public lpNetResource:ptr, lpBuffer:ptr, lpcbBuffer:ptr DWORD, lplpSystem:ptr ptr BYTE
		mov eax, ERROR_NO_NETWORK
        @strace <"WNetGetResourceInformationA(", lpNetResource, ", ", lpBuffer, ", ", lpcbBuffer, ", ", lplpSystem, ")=", eax>
        ret
        align 4
WNetGetResourceInformationA endp

WNetAddConnectionW proc public lpStr1:ptr WORD, lpStr2:ptr WORD, lpStr3:ptr WORD
WNetAddConnectionW endp

WNetAddConnectionA proc public lpStr1:ptr BYTE, lpStr2:ptr BYTE, lpStr3:ptr BYTE
		mov eax, ERROR_NO_NETWORK
        @strace <"WNetAddConnectionA(", lpStr1, ", ", lpStr2, ", ", lpStr3, ")=", eax>
        ret
        align 4
WNetAddConnectionA endp

WNetAddConnection2W proc public ptr1:ptr WORD, lpStr2:ptr WORD, lpStr3:ptr WORD, dw1:DWORD
WNetAddConnection2W endp

WNetAddConnection2A proc public ptr1:ptr BYTE, lpStr2:ptr BYTE, lpStr3:ptr BYTE, dw1:DWORD
		mov eax, ERROR_NO_NETWORK
        @strace <"WNetAddConnection2A(", ptr1, ", ", lpStr2, ", ", lpStr3, ", ", dw1, ")=", eax>
        ret
        align 4
WNetAddConnection2A endp

WNetCancelConnectionW proc public lpStr1:ptr WORD, bool1:dword
WNetCancelConnectionW endp

WNetCancelConnectionA proc public lpStr1:ptr BYTE, bool1:dword
		mov eax, ERROR_NO_NETWORK
        @strace <"WNetCancelConnectionA(", lpStr1, ", ", bool1, ")=", eax>
        ret
        align 4
WNetCancelConnectionA endp

WNetCancelConnection2W proc public lpStr1:ptr WORD, dw1:dword, bool1:dword
WNetCancelConnection2W endp

WNetCancelConnection2A proc public lpStr1:ptr BYTE, dw1:dword, bool1:dword
		mov eax, ERROR_NO_NETWORK
        @strace <"WNetCancelConnection2A(", lpStr1, ", ", dw1, ", ", bool1, ")=", eax>
        ret
        align 4
WNetCancelConnection2A endp

WNetGetConnectionW proc public lpStr1:ptr WORD, lpStr2:ptr WORD, lpdw1:ptr DWORD
WNetGetConnectionW endp

WNetGetConnectionA proc public lpStr1:ptr BYTE, lpStr2:ptr BYTE, lpdw1:ptr DWORD
		mov eax, ERROR_NO_NETWORK
        @strace <"WNetGetConnectionA(", lpStr1, ", ", lpStr2, ", ", lpdw1, ")=", eax>
        ret
        align 4
WNetGetConnectionA endp

WNetOpenEnumA proc public dwScope:DWORD, dwType:DWORD, dwUsage:DWORD, lpNetResource:ptr, lphEnum:ptr DWORD
		mov eax, ERROR_NO_NETWORK
        @strace <"WNetOpenEnumA(", ")=", eax>
        ret
        align 4
WNetOpenEnumA endp

WNetEnumResourceA proc public hEnum:DWORD, lpcCount:ptr, lpBuffer:ptr, lpBufferSize:ptr DWORD
		mov eax, ERROR_NO_NETWORK
        @strace <"WNetEnumResourceA(", ")=", eax>
        ret
        align 4
WNetEnumResourceA endp

WNetCloseEnum proc public hEnum:DWORD
		mov eax, ERROR_NO_NETWORK
        @strace <"WNetCloseEnum(", hEnum, ")=", eax>
        ret
        align 4
WNetCloseEnum endp

		end
