
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
        
E_FAIL	equ 80004005h        

        .CODE

LoadTypeLib proc public pszwFile:ptr WORD, pITypeLib:ptr DWORD

		@trace <"LoadTypeLib *** unsupp ***",13,10>
		mov eax,E_FAIL
        ret

LoadTypeLib endp

QueryPathOfRegTypeLib proc public guid:ptr BYTE, wVerMajor:DWORD, wVerMinor:DWORD, lcid:DWORD, lpbstrPathName:ptr DWORD

		@trace <"QueryPathOfRegTypeLib *** unsupp ***",13,10>
		mov eax,E_FAIL
        ret

QueryPathOfRegTypeLib endp

		end
