
	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:none
	option proc:private

	include windef.inc
	include winbase.inc
	include macros.inc

SE_ERR_NOASSOC	equ 31

	.CODE

SHCreateDirectoryExW proc public hwnd:ptr, path:ptr WORD, security:ptr
	invoke CreateDirectoryW, path, security
	.if ( eax )
		mov eax, S_OK
	.else
		invoke GetLastError
		;todo: translate error code in return code
		mov eax, ERROR_FILE_EXISTS
	.endif
	@strace <"SHCreateDirectoryExW(", hwnd, ", ", path, ", ", security, ")=", eax>
	ret
SHCreateDirectoryExW endp

SHGetSpecialFolderLocation proc public hwndOwner:dword, nFolder:dword, ppidl:ptr DWORD

local	dwEsp:dword
local	szPath[MAX_PATH]:byte

	xor eax, eax
	mov ecx, ppidl
	mov [ecx], eax
	mov eax, E_FAIL
	@strace <"SHGetSpecialFolderLocation(", hwndOwner, ", ", nFolder, ", ", ppidl, ")=", eax>
	ret
	align 4

SHGetSpecialFolderLocation endp

SHBrowseForFolderA proc public pPtr:ptr

	mov eax, E_FAIL
	@strace <"SHBrowseForFolderA(", pPtr, ")=", eax>
	ret
	align 4

SHBrowseForFolderA endp

SHGetDesktopFolder proc public pPtr:ptr

	mov ecx, pPtr
	mov dword ptr [ecx],0
	mov eax, E_FAIL
	@strace <"SHGetDesktopFolder(", pPtr, ")=", eax>
	ret
	align 4

SHGetDesktopFolder endp

SHGetFolderPathA proc public hwndOwner:dword, nFolder:dword, hToken:dword, dwFlags:dword, pszPath:ptr BYTE

	mov eax, E_INVALIDARG
	@strace <"SHGetFolderPathA(", hwndOwner, ", ", nFolder, ", ", hToken, ", ", dwFlags, ", ", pszPath, ")=", eax, "*** unsupp ***">
	ret
	align 4

SHGetFolderPathA endp

SHGetFolderPathW proc public hwndOwner:dword, nFolder:dword, hToken:dword, dwFlags:dword, pszPath:ptr WORD

	mov eax, E_INVALIDARG
	@strace <"SHGetFolderPathW(", hwndOwner, ", ", nFolder, ", ", hToken, ", ", dwFlags, ", ", pszPath, ")=", eax, "*** unsupp ***">
	ret
	align 4

SHGetFolderPathW endp

SHGetSpecialFolderPathA proc public hwndOwner:dword, lpszPath:ptr BYTE, nFolder:dword, fCreate:dword

	mov eax, E_INVALIDARG
	@strace <"SHGetSpecialFolderPathA(", hwndOwner, ", ", lpszPath, ", ", nFolder, ", ", fCreate, ")=", eax, "*** unsupp ***">
	ret
	align 4

SHGetSpecialFolderPathA endp

	end
