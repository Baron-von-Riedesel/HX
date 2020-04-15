
;--- implementation of the Win32 registry API.
;--- it's very simple, the values are stored in private profile files.
;--- currently branches HKEY_CLASSES_ROOT, HKEY_CURRENT_USER and
;--- HKEY_LOCAL_MACHINE are supported.

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
	include winreg.inc
	include macros.inc
	include dadvapi.inc

MAXVALUEBUFFER equ 2048

GetUserNameA proto stdcall :DWORD, :DWORD

HREGKEY	struct
dwType		dd ?
pszFile		dd ?
pszKey  	dd ?
;pszStdValue dd ?
HREGKEY	ends

TYPE_REGKEY	equ <"REGK">

REGREGION struct
hKey    dd ?
pszRoot dd ?
pszFile dd ?
pszPath	dd ?
REGREGION ends

	.DATA

regions	label REGREGION
	REGREGION <HKEY_CLASSES_ROOT,  CStr("HKEY_CLASSES_ROOT"), CStr("CLASSES"), 0>
	REGREGION <HKEY_CURRENT_USER, CStr("HKEY_CURRENT_USER"), -1,  0>
	REGREGION <HKEY_LOCAL_MACHINE, CStr("HKEY_LOCAL_MACHINE"), CStr("SYSTEM"),  0>
endregions label byte
        
	.CODE

dw2a proc
	xor ecx, ecx	;???
	push eax
	shr eax, 16
	call w2asc
	pop eax
w2asc::
	push eax
	shr eax, 8
	call b2asc
	pop eax
b2asc::
	mov ah,al
	shr al, 4
	call nib2asc
	mov al,ah
nib2asc:
	and al,0Fh
	cmp al,10
	sbb al,69h
	das
	stosb
	ret
	align 4

dw2a endp

a2dw proc
	mov cl,8
nextc:
	shl eax,4
	mov dl,[esi]
	cmp dl,'9'
	jbe @F
	or dl,20h
	sub dl,27h
@@:
	sub dl,'0'
	or al,dl
	inc esi
	dec cl
	jnz nextc
	ret
a2b::
	mov cl,2
	jmp nextc
	align 4

a2dw endp

;--- in:
;--- edi -> REGREGION

fillregionpath proc        

	.if (![edi].REGREGION.pszPath)
		invoke LocalAlloc, LMEM_FIXED, MAX_PATH
		and eax, eax
		jz exit
		mov [edi].REGREGION.pszPath, eax
		invoke GetModuleHandle, CStr("ADVAPI32")
		mov ecx, eax
		invoke GetModuleFileName, ecx, [edi].REGREGION.pszPath, MAX_PATH
		mov ecx, [edi].REGREGION.pszPath
		.while (eax)
			.break .if (byte ptr [ecx+eax] == '\')
			mov byte ptr [ecx+eax],0
			dec eax
		.endw
		sub esp,128
		mov eax, [edi].REGREGION.pszFile
		.if (eax == -1)
			mov eax, esp
			push 128
			invoke GetUserNameA, eax, esp
			pop eax
			mov eax, esp
		.endif
		invoke lstrcat, [edi].REGREGION.pszPath, eax
		add esp,128
	.endif
	@mov eax, 1
exit:
	ret
	align 4

fillregionpath endp        

;--- returns
;--- eax = key string
;--- edx = profile file name

getkeystring proc
	and ebx, ebx
	jz error
	cmp ebx, HKEY_CLASSES_ROOT
	jb @F
	cmp ebx, HKEY_DYN_DATA
	jbe defkey
@@:
	mov eax, [ebx].HREGKEY.pszKey
	mov edx, [ebx].HREGKEY.pszFile
	ret
defkey:
	push edi
	mov edi, offset regions
	.while (edi < offset endregions)
		.if (ebx == [edi].REGREGION.hKey)
			call fillregionpath
			mov eax, [edi].REGREGION.pszRoot
			mov edx, [edi].REGREGION.pszPath
			jmp exit
		.endif
		add edi, sizeof REGREGION
	.endw
	xor eax, eax
exit:
	pop edi
	ret
error:
	xor eax, eax
	ret
	align 4

getkeystring endp

;--- open/create a key

_RegOpenCreateKeyA proc uses ebx esi edi hKey:DWORD, lpszSubKey:ptr Byte, phkResult:ptr DWORD, bCreate:dword

local	dwValueLength:dword
local	szKey[MAX_PATH]:byte
local	szTemp[4]:byte
local	regreg:REGREGION

if ?USEWIN95REGAPI        
	test bRegistry, 1
	jz error
	int  3
	push phkResult
	push lpSubKey
	push hKey
	mov ax,100h
	call ddVmmEntry
	push dx
	push ax
	pop eax
exit:
	@strace <"_RegOpenCreateKeyA(", hKey, ", ", &lpSubKey, ", ", phkResult, ", ", bCreate, ")=", eax>
	ret
error:
	mov eax, ERROR_ACCESS_DENIED
	jmp exit
else
	mov ecx, phkResult
	mov dword ptr [ecx],0
	mov eax, ERROR_ACCESS_DENIED
	mov edx, hKey
	.if ((edx >= HKEY_CLASSES_ROOT) && (edx <= HKEY_DYN_DATA))
		mov edi, offset regions
		.while (edi < offset endregions)
			.if (edx == [edi].REGREGION.hKey)
				call keyfound
				jmp exit
			.endif
			add edi, sizeof REGREGION
		.endw
	.elseif (edx && ([edx].HREGKEY.dwType == TYPE_REGKEY))
		lea edi, regreg
		mov ecx, [edx].HREGKEY.pszKey
		mov [edi].REGREGION.pszRoot, ecx
		mov ecx, [edx].HREGKEY.pszFile
		mov [edi].REGREGION.pszPath, ecx
		call keyfound
	.endif
exit:
ifdef _DEBUG
	mov ecx, phkResult
endif
	@strace <"_RegOpenCreateKeyA(", hKey, ", ", &lpszSubKey, ", ", phkResult, ", ", bCreate, ")=", eax, " [", dword ptr [ecx], "]">
	ret
	align 4

;--- edi -> REGREGION
keyfound:                
	xor ebx, ebx
	.if (!lpszSubKey)
		mov ecx, phkResult
		mov edx, hKey
		mov [ecx], edx
		mov eax, ERROR_SUCCESS
		retn
	.endif
	call fillregionpath
	and eax, eax
	jz error8
	invoke lstrcpy, addr szKey, [edi].REGREGION.pszRoot
	invoke lstrcat, addr szKey, CStr("\")
	invoke lstrcat, addr szKey, lpszSubKey
;;	invoke GetPrivateProfileString, addr szKey, CStr("@"), CStr(""), addr szTemp, sizeof szTemp, [edi].REGREGION.pszPath
;--- if lpKeyname is NULL, the function tries to return all keys! However, 
;--- since we aren't interested in what the actual keys look like, the buffer
;--- is as small as possible!
	invoke GetPrivateProfileString, addr szKey, NULL, CStr(""), addr szTemp, sizeof szTemp, [edi].REGREGION.pszPath
	.if (!eax)
		cmp bCreate, eax
		jnz @F
		cmp dl,-1	;does "hidden" return value tell that there's a child key?
		jz subkeyfound
		mov eax, ERROR_FILE_NOT_FOUND	;=2
		retn
@@:
		invoke WritePrivateProfileString, addr szKey, CStr("@"), CStr(""), [edi].REGREGION.pszPath
		@strace <"WritePrivateProfileString()=", eax>
	.endif
subkeyfound:
	invoke lstrlen, addr szKey
	inc eax
	invoke LocalAlloc, LMEM_FIXED, eax
	and eax, eax
	jz error8
	mov ebx, eax
	invoke lstrcpy, ebx, addr szKey
	invoke LocalAlloc, LMEM_FIXED, sizeof HREGKEY
	and eax, eax
	jz error8
	mov edx, ebx
	mov ebx, eax
	mov ecx, [edi].REGREGION.pszPath
	mov [ebx].HREGKEY.dwType, TYPE_REGKEY
	mov [ebx].HREGKEY.pszFile, ecx
	mov [ebx].HREGKEY.pszKey, edx
;	mov [ebx].HREGKEY.pszStdValue, esi
	mov ecx, phkResult
	mov [ecx], ebx
	mov eax, ERROR_SUCCESS
	retn
error8:
	.if (ebx)
		invoke LocalFree, ebx
	.endif
	mov eax, ERROR_NOT_ENOUGH_MEMORY;=8
	retn
endif
	align 4

_RegOpenCreateKeyA endp

RegOpenKeyA proc public hKey:HKEY, lpszSubKey:ptr Byte, phkResult:ptr HKEY

	invoke _RegOpenCreateKeyA, hKey, lpszSubKey, phkResult, 0
	@strace <"RegOpenKeyA(", hKey, ", ", lpszSubKey, ", ", phkResult, ")=", eax>
	ret
	align 4

RegOpenKeyA endp

RegOpenKeyW proc public hKey:HKEY, lpszSubKey:ptr WORD, phkResult:ptr DWORD

	mov eax, lpszSubKey
	call ConvertWStr
	invoke _RegOpenCreateKeyA, hKey, eax, phkResult, 0
	@strace <"RegOpenKeyW(", hKey, ", ", lpszSubKey, ", ", phkResult, ")=", eax>
	ret
	align 4

RegOpenKeyW endp

RegOpenKeyExA proc public hKey:HKEY, lpszSubKey:ptr Byte, ulOptions:DWORD, samDesired:DWORD, phkResult:ptr HKEY

	invoke RegOpenKeyA, hKey, lpszSubKey, phkResult
	@strace <"RegOpenKeyExA(", hKey, ", ", &lpszSubKey, ", ", ulOptions, ", ", samDesired, ", ", phkResult, ")=", eax>
	ret
	align 4

RegOpenKeyExA endp

RegOpenKeyExW proc public hKey:HKEY, lpSubKey:ptr WORD, ulOptions:DWORD, samDesired:DWORD, phkResult:ptr DWORD

	mov eax, lpSubKey
	call ConvertWStr
	invoke RegOpenKeyA, hKey, eax, phkResult
	@strace <"RegOpenKeyExW(", hKey, ", ", lpSubKey, ", ", ulOptions, ", ", samDesired, ", ", phkResult, ")=", eax>
	ret
	align 4

RegOpenKeyExW endp

;--- RegCreateKey does not fail if the key already exists, it just
;--- opens it then

RegCreateKeyA proc public hKey:HKEY, lpSubKey:ptr Byte, phkResult:ptr HKEY

	invoke _RegOpenCreateKeyA, hKey, lpSubKey, phkResult, 1
	@strace <"RegCreateKeyA(", hKey, ", ", &lpSubKey, ", ", phkResult, ")=", eax>
	ret
	align 4

RegCreateKeyA endp

RegCreateKeyExA proc public hKey:HKEY, lpSubKey:ptr Byte, dwReserved:DWORD,
		lpClass:ptr byte, dwOptions:DWORD, samDesired:DWORD,
		lpSecurityAttributes:ptr, phkResult:ptr HKEY, lpdwDisposition:ptr DWORD

	invoke RegCreateKeyA, hKey, lpSubKey, phkResult
;	mov ecx, lpdwDisposition
;	mov [ecx],???
	@strace <"RegCreateKeyExA(", hKey, ", ", &lpSubKey, ", ", dwReserved, ", ", lpClass, ", ",	dwOptions, ")=", eax>
	ret
	align 4

RegCreateKeyExA endp

RegCreateKeyW proc public hKey:HKEY, lpSubKey:ptr WORD, phkResult:ptr HKEY

	mov eax, lpSubKey
	call ConvertWStr
	invoke _RegOpenCreateKeyA, hKey, eax, phkResult, 1
	@strace <"RegCreateKeyW(", hKey, ", ", lpSubKey, ", ", phkResult, ")=", eax>
	ret
	align 4

RegCreateKeyW endp

RegCreateKeyExW proc public hKey:HKEY, lpSubKey:ptr WORD, dwReserved:DWORD,
		lpClass:ptr WORD, dwOptions:DWORD, samDesired:DWORD,
		lpSecurityAttributes:ptr, phkResult:ptr HKEY, lpdwDisposition:ptr DWORD

	invoke RegCreateKeyW, hKey, lpSubKey, phkResult
	@strace <"RegCreateKeyExW(", hKey, ", ", lpSubKey, ", ", dwReserved, ", ", lpClass, ", ",  dwOptions, ")=", eax>
	ret
	align 4

RegCreateKeyExW endp


RegDeleteKeyA proc public uses ebx esi edi hKey:HKEY, lpSubKey:ptr Byte

local dwEsp:dword

	mov ebx, hKey
	call getkeystring
	and eax, eax
	jz error
	mov ebx, eax
	mov edi, edx
	invoke lstrlen, lpSubKey
	push eax
	invoke lstrlen, ebx
	pop ecx
	add eax, ecx
	add eax, 4
	and al,0FCh
	mov dwEsp, esp
	sub esp, eax
	mov esi, esp
	invoke lstrcpy, esi, ebx
	invoke lstrcat, esi, CStr("\")
	invoke lstrcat, esi, lpSubKey
	invoke WritePrivateProfileString, esi, NULL, NULL, edi
	mov esp, dwEsp
	and eax, eax
	jz error
	mov eax, ERROR_SUCCESS
exit:
	@strace <"RegDeleteKeyA(", hKey, ", ", &lpSubKey, ")=", eax>
	ret
error:
	mov eax, ERROR_ACCESS_DENIED
	jmp exit
	align 4

RegDeleteKeyA endp

RegDeleteKeyW proc public hKey:HKEY, lpSubKey:ptr WORD

	mov eax, lpSubKey
	call ConvertWStr
	invoke RegDeleteKeyA, hKey, eax
	@strace <"RegDeleteKeyW(", hKey, ", ", lpSubKey, ")=", eax>
	ret
	align 4

RegDeleteKeyW endp

;--- enumerating keys is difficult
;--- since the subkeys are different sections

RegEnumKeyA proc public hKey:HKEY, dwIndex:dword, lpSubKey:ptr Byte, dwMaxSize:dword

local ftime:FILETIME

	invoke RegEnumKeyExA, hKey, dwIndex, lpSubKey, addr dwMaxSize, 0, NULL, 0, addr ftime
	@strace <"RegEnumKeyA(", hKey, ", ", dwIndex, ", ", lpSubKey, ", ", dwMaxSize, ")=", eax>
	ret
	align 4

RegEnumKeyA endp

RegEnumKeyExA proc public uses ebx esi edi hKey:HKEY, dwIndex:dword, lpSubKey:ptr Byte, 
			pdwMaxSize:ptr dword, reserved:ptr DWORD, lpClass:ptr BYTE, lpdwClass:ptr DWORD, pFileTime:ptr FILETIME

local	dwLen:dword
local	currIndex:dword
local	rkey:HREGKEY
local	szBuffer[8192]:byte

	mov al,[szBuffer+4096]	;ensure stack is committed
	mov ebx, hKey
	.if ((ebx >= HKEY_CLASSES_ROOT) && (ebx <= HKEY_DYN_DATA))
		mov edi, offset regions
		.while (edi < offset endregions)
			.if (ebx == [edi].REGREGION.hKey)
				lea ebx,rkey
				mov [ebx].HREGKEY.dwType, TYPE_REGKEY
				mov eax,[edi].REGREGION.pszRoot
				mov [ebx].HREGKEY.pszKey, eax
				mov eax,[edi].REGREGION.pszFile
				mov [ebx].HREGKEY.pszFile, eax
				mov hKey, ebx
				jmp @F
			.endif
			add edi, sizeof REGREGION
		.endw
		jmp error
	.elseif ([ebx].HREGKEY.dwType != TYPE_REGKEY)
		jmp error
	.endif
@@:
	@strace <"RegEnumKeyExA enter, hKey=", ebx, ", dwIndex=", dwIndex>
;--- 1. parameter is NULL -> copy all section names into buffer!
	invoke GetPrivateProfileString, 0, 0, 0, addr szBuffer, sizeof szBuffer, [ebx].HREGKEY.pszFile
	.if (eax)
ifdef _DEBUG
		.if ([ebx].HREGKEY.pszKey)
			@strace <"RegEnumKeyExA: GetPrivateProfileString(", &[ebx].HREGKEY.pszFile, ", key=", &[ebx].HREGKEY.pszKey, ")=", eax>
		.else
			@strace <"RegEnumKeyExA: GetPrivateProfileString(", &[ebx].HREGKEY.pszFile, ")=", eax>
		.endif
		lea esi, szBuffer
		.while (byte ptr [esi])
			@strace <&esi>
			invoke lstrlen, esi
			add esi, eax
			inc esi
		.endw
endif
		invoke lstrlen, [ebx].HREGKEY.pszKey
		mov dwLen, eax
		and eax, eax
		jz error
		lea esi, szBuffer
		mov currIndex,-1
		.while (byte ptr [esi])
			@strace <"RegEnumKeyExA: string=", &esi>
			mov edi,[ebx].HREGKEY.pszKey
			mov ecx,dwLen
			call mystricmpn
			jnz nomatch
			cmp byte ptr [esi],'\'
			jnz nomatch
			inc esi
			mov edx,esi
			xor ecx,ecx
			;--- if there's another '\' in the item, it isn't a true subkey 
			.while (byte ptr [esi])
				lodsb
				cmp al,'\'
				jz nomatch
				inc ecx
			.endw
			mov esi,edx
			inc currIndex
			mov eax,dwIndex
			cmp eax, currIndex
			.if (ZERO?)
				@strace <"RegEnumKeyExA: string accepted">
				mov eax, pdwMaxSize
				.if (ecx < dword ptr [eax])
					mov [eax],ecx
					mov edi, lpSubKey
					rep movsb
					mov al,0
					stosb
					mov eax, ERROR_SUCCESS
				.else
					inc ecx
					mov [eax], ecx
					mov eax, ERROR_MORE_DATA
				.endif
				jmp exit
			.endif
nomatch:
			@strace <"RegEnumKeyExA: string rejected">
			.while (byte ptr [esi])
				inc esi
			.endw
			inc esi
		.endw
		mov eax, ERROR_NO_MORE_ITEMS
	.else
error:
		mov eax, ERROR_ACCESS_DENIED
	.endif
exit:   
	@strace <"RegEnumKeyExA(", hKey, ", ", dwIndex, ", ", lpSubKey, ", ", pdwMaxSize, ", ", lpClass, ", ", lpdwClass, ")=", eax>
	ret
	align 4

;--- esi -> string1
;--- edi -> string2
;--- ecx = size of string in edi
mystricmpn:
	lodsb
	and al,al    ;is string in buffer too short?
	jz @F
	mov ah,[edi]
	inc edi
	or ah,20h
	or al,20h
	cmp al,ah
	loopz mystricmpn
	retn
@@:
	dec esi
	inc al
	retn
	align 4

RegEnumKeyExA endp

RegEnumValueA proc public uses ebx edi hKey:HKEY, dwIndex:dword, lpValueName:ptr Byte, lpcValueName:ptr dword,
		lpReserved:ptr DWORD, lpType:ptr DWORD, lpData:ptr BYTE, lpcbData:ptr DWORD

local	dwKey:dword
local	dwFile:dword

	mov ebx, hKey
	call getkeystring
	and eax, eax
	jz error
	mov dwKey, eax
	mov dwFile, edx
	@strace <"RegEnumValueA: file=", &edx, " key=", &eax>
	sub esp,MAXVALUEBUFFER
	mov edi, esp
	mov word ptr [edi],0
	invoke GetPrivateProfileString, eax, NULL, CStr(""), edi, MAXVALUEBUFFER, edx
	@strace <"RegEnumValueA: GetPrivateProfileString()=", eax>
	mov ecx, eax
	mov edx, dwIndex
	.while (edx)
		.if (word ptr [edi] == '@' && ecx >= 2)		;don't count the '@' entry!
			add edi,2
			sub ecx,2
		.endif
		mov al,0
		repnz scasb
		.break .if (!ZERO?)				;no NUL found
		.break .if (byte ptr [edi] == 0);end of strings reached
		dec edx
	.endw
	.if (word ptr [edi] == '@' && ecx >= 2)		;don't count the '@' entry!
		add edi,2
	.endif
	.if ((!edx) && (byte ptr [edi]))
		mov edx, lpValueName
		.if (edx)
			mov ecx, lpcValueName
			mov ecx, [ecx]
			push edi
			.while (ecx)
				mov al, [edi]
				mov [edx], al
				.break .if (al == 0)
				inc edi
				inc edx
				dec ecx
			.endw
			pop edi
			sub edx, lpValueName
			mov ecx, lpcValueName
			mov [ecx], edx
		.endif
		.if (lpType)
			mov ecx, lpType
			mov dword ptr [ecx], REG_SZ
		.endif
		.if (lpData)
			mov ecx, lpcbData
			mov ecx, [ecx]
			invoke GetPrivateProfileString, dwKey, edi, CStr(""), lpData, ecx, dwFile
			@strace <"RegEnumValueA: GetPrivateProfileString()=", eax>
			mov ecx, lpcbData
			inc eax
			mov [ecx], eax
		.endif
		mov eax, ERROR_SUCCESS
	.else
		mov eax, ERROR_NO_MORE_ITEMS
	.endif
	add esp, MAXVALUEBUFFER
exit:
	@strace <"RegEnumValueA(", hKey, ", ", dwIndex, ", ", lpValueName, ")=", eax>
	ret
error:
	mov eax, ERROR_ACCESS_DENIED
	jmp exit
	align 4

RegEnumValueA endp

RegEnumKeyW proc public hKey:HKEY, dwIndex:dword, lpSubKey:ptr WORD, dwMaxSize:dword

	mov eax, lpSubKey
	call ConvertWStr
	invoke RegEnumKeyA, hKey, dwIndex, eax, dwMaxSize
	@strace <"RegEnumKeyW(", hKey, ", ", dwIndex, ", ", lpSubKey, ", ", dwMaxSize, ")=", eax>
	ret
	align 4

RegEnumKeyW endp

RegEnumKeyExW proc public hKey:HKEY, dwIndex:dword, lpSubKey:ptr WORD, 
			pdwMaxSize:ptr dword, px1:ptr DWORD, px2:ptr BYTE, px3:ptr DWORD, pFileTime:ptr FILETIME

	mov eax, lpSubKey
	call ConvertWStr
	invoke RegEnumKeyExA, hKey, dwIndex, eax, pdwMaxSize, px1, px2, px3, pFileTime
	@strace <"RegEnumKeyExW(", hKey, ", ", dwIndex, ", ", lpSubKey, ", ", pdwMaxSize, ", ...)=", eax>
	ret
	align 4

RegEnumKeyExW endp

RegEnumValueW proc public uses ebx hKey:HKEY, dwIndex:dword, lpValueName:ptr WORD, lpcValueName:ptr dword,
		lpReserved:ptr DWORD, lpType:ptr DWORD, lpData:ptr BYTE, lpcbData:ptr DWORD

	mov eax, lpValueName
	call ConvertWStr
	mov ebx, eax
	mov eax, lpcValueName
	call ConvertWStr
	invoke RegEnumValueA, hKey, dwIndex, ebx, eax, lpReserved, lpType, lpData, lpcbData
	@strace <"RegEnumValueW(", hKey, ", ", dwIndex, ", ", lpValueName, ")=", eax>
	ret
	align 4

RegEnumValueW endp

RegDeleteValueA proc public uses ebx hKey:HKEY, lpszValue:ptr Byte

	mov ebx, hKey
	call getkeystring
	and eax, eax
	jz error
	mov ecx, eax
	mov eax, lpszValue
	.if (!eax)
		mov eax, CStr("@")
	.endif
	invoke WritePrivateProfileString, ecx, eax, NULL, edx
	mov eax, ERROR_SUCCESS
exit:
	@strace <"RegDeleteValueA(", hKey, ", ", lpszValue, ")=", eax>
	ret
error:
	mov eax, ERROR_ACCESS_DENIED
	jmp exit
	align 4

RegDeleteValueA endp

RegDeleteValueW proc public hKey:HKEY, lpszValue:ptr WORD

	mov eax, lpszValue
	call ConvertWStr
	invoke RegDeleteValueA, hKey, eax
	@strace <"RegDeleteValueW(", hKey, ", ", lpszValue, ")=", eax>
	ret
	align 4

RegDeleteValueW endp

;--- only values of string type are supported
;--- if lpSubKey == NULL: get default value
;--- if lpValue == NULL: dont store data
;--- lpdwSize: is never NULL
;---  in: contains max size of buffer
;---  out: size of string (including terminating 0)

RegQueryValueA proc public uses ebx esi edi hKey:HKEY, lpSubKey:ptr Byte, lpValue:ptr BYTE, lpdwSize:ptr SDWORD

	mov ebx, hKey
	call getkeystring
	and eax, eax
	jz error
	mov esi, eax
	mov edi, edx
	mov ecx, lpdwSize
	mov edx, [ecx]
	mov ecx, lpValue
	.if (!ecx)
		mov edx, 512
		sub esp, edx
		mov ecx, esp
	.endif
	mov eax, lpSubKey
	.if (!eax)
		mov eax, CStr("@")
	.endif
	invoke GetPrivateProfileString, esi, eax, CStr(""), ecx, edx, edi
	.if (!lpValue)
		add esp, 512
	.endif
	.if (eax)
		inc eax
		mov ecx, lpdwSize
		.if (lpValue)
			mov edx, [ecx]
			mov [ecx], eax
			.if (eax > edx)
				mov eax, ERROR_MORE_DATA
			.else
				mov eax, ERROR_SUCCESS
			.endif
		.else
			mov [ecx], eax
			mov eax, ERROR_SUCCESS
		.endif
	.else
		mov eax, ERROR_FILE_NOT_FOUND
	.endif
exit:
	@strace <"RegQueryValueA(", hKey, ", ", lpSubKey, ", ", lpValue, ", ", lpdwSize, ")=", eax>
	ret
error:
	mov eax, ERROR_ACCESS_DENIED
	jmp exit
	align 4

RegQueryValueA endp

RegQueryValueW proc public hKey:HKEY, lpwszSubKey:ptr WORD, lpwszValue:ptr WORD, lpdwSize:ptr SDWORD

	mov eax, lpwszSubKey
	call ConvertWStr
	mov lpwszSubKey, eax
	mov eax, lpwszValue
	and eax, eax
	jz @F
	call ConvertWStr
@@:
	invoke RegQueryValueA, hKey, lpwszSubKey, eax, lpdwSize
	@strace <"RegQueryValueW(", hKey, ", ", lpwszSubKey, ", ", lpwszValue, ", ", lpdwSize, ")=", eax>
	ret
	align 4

RegQueryValueW endp

;--- only values of string type are supported
;--- lpValueName may be NULL (requests the "default" value)
;--- lpType, lpData(+lpcbData) may be NULL

RegQueryValueExA proc public uses ebx esi edi hKey:HKEY, lpszValueName:ptr Byte, lpReserved:LPDWORD,
		lpType:ptr DWORD, lpData:ptr BYTE, lpcbData:ptr DWORD

local	szBuffer[MAXVALUEBUFFER]:byte
local	dwSize:DWORD

	mov ebx, hKey
	call getkeystring
	and eax, eax
	jz error
	mov esi, eax
	mov edi, edx

	mov ecx, lpcbData	;lpcbData might be NULL if lpData is NULL
	and ecx, ecx
	jnz @F
	lea ecx, dwSize
	mov dword ptr [ecx],0
@@:
	mov eax, lpszValueName
	.if (!eax)
		mov eax, CStr("@")
	.endif
	lea ebx, szBuffer
	invoke GetPrivateProfileString, esi, eax, CStr(""), ebx, sizeof szBuffer, edi

;--- if value is a string, DL=1, else DL=0

	.if (eax)
		.if (eax == 14 && dword ptr [ebx] == "rowd" && word ptr [ebx+4] == ":d")
			lea esi, [ebx+6]
			call a2dw
			mov [ebx], eax
			mov eax, 4
			mov edi, REG_DWORD
		.elseif (dword ptr [ebx] == ":xeh")
			lea esi, [ebx+4]
			xor ecx,ecx
			.while (byte ptr [esi])
				push ecx
				call a2b
				pop ecx
				mov [ebx+ecx],al
				inc ecx
				.break .if (byte ptr [esi] != ',')
				inc esi
			.endw
			mov eax, ecx
			mov edi, REG_BINARY
		.else
			inc eax
			mov edi, REG_SZ
		.endif
		mov ecx, lpcbData
		.if (lpData)
			mov esi, [ecx]
			mov [ecx], eax
			mov ecx, eax
			cmp ecx, esi
			jc @F
			mov ecx, esi     ;use the smaller value!
@@:
			.if (eax > esi)
				mov eax, ERROR_MORE_DATA
			.else
				mov eax, ERROR_SUCCESS
			.endif
			push eax
			invoke RtlMoveMemory, lpData, ebx, ecx
			pop eax
		.elseif (ecx)
			mov [ecx], eax
			mov eax, ERROR_SUCCESS
		.endif
		.if (eax == ERROR_SUCCESS)
			mov ecx, lpType
			jecxz @F
			mov [ecx], edi
@@:
		.endif
	.else
		mov eax, ERROR_FILE_NOT_FOUND
	.endif
exit:
ifdef _DEBUG
	mov ecx, lpszValueName
	and ecx, ecx
	jnz @F
	mov ecx, CStr("NULL")
@@:
endif
	@strace <"RegQueryValueExA(", hKey, ", ", &ecx, ", ", lpReserved, ", ", lpType, ", ", lpData, ", ", lpcbData, ")=", eax>
	ret
error:
	mov eax, ERROR_ACCESS_DENIED
	jmp exit
	align 4

RegQueryValueExA endp

RegQueryValueExW proc public hKey:HKEY, lpwszValueName:ptr WORD, lpReserved:DWORD, lpType:ptr DWORD, lpData:ptr WORD, lpcbData:ptr DWORD

local	dwTypeTmp:dword

	mov eax, lpwszValueName
	and eax, eax
	jz @F
	call ConvertWStr
@@:
	mov ecx, lpType
	and ecx, ecx
	jnz @F
	lea ecx, dwTypeTmp
	mov lpType, ecx
@@:
	invoke RegQueryValueExA, hKey, eax, lpReserved, lpType, lpData, lpcbData
	.if (eax == ERROR_SUCCESS)
		mov ecx, lpType
		.if (dword ptr [ecx] == REG_SZ)
			mov ecx, lpcbData
			invoke ConvertAStrN, lpData, lpData, dword ptr [ecx]
		.endif
	.endif
	@strace <"RegQueryValueExW(", hKey, ", ", lpwszValueName, ", ", lpReserved, ", ", lpType, ", ", lpData, ", ", lpcbData, ")=", eax>
	ret
	align 4

RegQueryValueExW endp

;--- RegSetValueA supports type REG_SZ only!

RegSetValueA proc public uses ebx hKey:HKEY, lpSubKey:ptr Byte, 
		dwType:DWORD, lpData:ptr BYTE, cbData:DWORD

	cmp dwType, REG_SZ
	jnz error
	mov ebx, hKey
	call getkeystring
	and eax, eax
	jz error
	mov ecx, eax
	mov eax, lpSubKey
	.if ((!eax) || (byte ptr [eax] == 0))
		mov eax, CStr("@")
	.endif
	invoke WritePrivateProfileString, ecx, eax, lpData, edx
	.if (eax)
		mov eax, ERROR_SUCCESS
	.else
		mov eax, ERROR_ACCESS_DENIED
	.endif
exit:
	@strace <"RegSetValueA(", hKey, ", ", lpSubKey, ", ", dwType, ", ", lpData, ", ", cbData, ")=", eax>
	ret
error:
	mov eax, ERROR_ACCESS_DENIED
	jmp exit
	align 4

RegSetValueA endp

;--- RegSetValueExA must support all types!
;--- the current implementation supports REG_SZ, REG_EXPAND_SZ and REG_DWORD

RegSetValueExA proc public uses ebx esi hKey:HKEY, lpValueName:ptr Byte, dwReserved:DWORD,
		dwType:DWORD, lpData:ptr BYTE, cbData:DWORD

local dwEsp:dword
local szTemp[16]:byte

	mov esi, lpData
	mov ecx, dwType
	mov dwEsp, esp
	.if (ecx == REG_BINARY)
		mov eax, cbData
		lea eax, [eax*2+eax+8]
		sub esp, eax
		mov esi, esp
		push edi
		mov edi, esi
		mov eax, ":xeh"
		stosd
		mov ebx, lpData
		mov ecx, cbData
		.while (ecx)
			mov al,[ebx]
			inc ebx
			call b2asc
			.if (ecx > 1)
				mov al,','
				stosb
			.endif
			dec ecx
		.endw
		mov al,0
		stosb
		pop edi
	.elseif (ecx == REG_DWORD)
		lea esi, szTemp
		mov dword ptr [esi+0], "rowd"
		mov word ptr [esi+4], ":d"
		push edi
		lea edi, [esi+6]
		mov ecx, lpData
		mov eax, [ecx]
		call dw2a
		mov al,0
		stosb
		pop edi
	.elseif (ecx != REG_SZ && ecx != REG_EXPAND_SZ)
		jmp error
	.endif
	mov ebx, hKey
	call getkeystring
	and eax, eax
	jz error
	mov ecx, eax
	mov eax, lpValueName
	.if (!eax)
		mov eax, CStr("@")
	.endif
	invoke WritePrivateProfileString, ecx, eax, esi, edx
	.if (eax)
		mov eax, ERROR_SUCCESS
	.else
		mov eax, ERROR_ACCESS_DENIED
	.endif
exit:
	mov esp, dwEsp
	@strace <"RegSetValueExA(", hKey, ", ", lpValueName, ", ", dwReserved, ", ", dwType, ", ", lpData, ", ", cbData, ")=", eax>
	ret
error:
	mov eax, ERROR_ACCESS_DENIED
	jmp exit
	align 4

RegSetValueExA endp

RegSetValueW proc public hKey:HKEY, lpSubKey:ptr WORD, 
		dwType:DWORD, lpData:ptr BYTE, cbData:DWORD

	mov eax, ERROR_ACCESS_DENIED
	@strace <"RegSetValueW(", hKey, ", ", lpSubKey, ", ", dwType, ", ", lpData, ", ", cbData, ")=", eax>
	ret
	align 4

RegSetValueW endp

RegSetValueExW proc public hKey:HKEY, lpValueName:ptr WORD, dwReserved:DWORD,
		dwType:DWORD, lpData:ptr BYTE, cbData:DWORD

	mov eax, ERROR_ACCESS_DENIED
	@strace <"RegSetValueExW(", hKey, ", ", lpValueName, ", ", dwReserved, ", ", dwType, ", ", lpData, ", ", cbData, ")=", eax>
	ret
	align 4
        
RegSetValueExW endp

RegCloseKey proc public uses ebx hKey:HKEY

	@strace <"RegCloseKey(", hKey, ") enter">
	mov eax, ERROR_ACCESS_DENIED
	mov ebx, hKey
	and ebx, ebx
	jz exit
	cmp ebx, HKEY_CLASSES_ROOT
	jb @F
	cmp ebx, HKEY_DYN_DATA
	jbe done
@@:
	.if ([ebx].HREGKEY.dwType == TYPE_REGKEY)
;		invoke LocalFree, [ebx].HREGKEY.pszStdValue
		invoke LocalFree, [ebx].HREGKEY.pszKey
		invoke LocalFree, ebx
done:
		mov eax, ERROR_SUCCESS
	.endif
exit:
	@strace <"RegCloseKey(", hKey, ")=", eax>
	ret
	align 4

RegCloseKey endp

RegQueryInfoKeyA proc public hKey:HKEY, lpclass:LPSTR, lpcClass:ptr DWORD,
		lpReserved:ptr DWORD, lpcSubKeys:ptr DWORD, lpcMaxSubKeyLen:ptr DWORD,
		lpcMaxClassLen:ptr DWORD, lpcValues:ptr DWORD, lpcMaxValueNameLen:ptr DWORD,
		lpcMaxValueLen:ptr DWORD, lpcbSecurityDescriptor:ptr DWORD,lpftLastWriteTime:ptr FILETIME

	mov eax, ERROR_ACCESS_DENIED
	@strace <"RegQueryInfoKeyA(", hKey, ", ", lpclass, ", ", lpcClass, ", ", lpReserved, ", ...)=", eax>
	ret
	align 4

RegQueryInfoKeyA endp

RegQueryInfoKeyW proc public hKey:HKEY, lpclass:ptr WORD, lpcClass:ptr DWORD,
		lpReserved:ptr DWORD, lpcSubKeys:ptr DWORD, lpcMaxSubKeyLen:ptr DWORD,
		lpcMaxClassLen:ptr DWORD, lpcValues:ptr DWORD, lpcMaxValueNameLen:ptr DWORD,
		lpcMaxValueLen:ptr DWORD, lpcbSecurityDescriptor:ptr DWORD,lpftLastWriteTime:ptr FILETIME

	mov eax, ERROR_ACCESS_DENIED
	@strace <"RegQueryInfoKeyW(", hKey, ", ", lpclass, ", ", lpcClass, ", ", lpReserved, ", ...)=", eax>
	ret
	align 4

RegQueryInfoKeyW endp

RegFlushKey proc public hKey:HKEY

	mov eax, ERROR_ACCESS_DENIED
	@strace <"RegFlushKey(", hKey, ")=", eax>
	ret
	align 4

RegFlushKey endp

RegSaveKeyA proc public hKey:HKEY, lpFile:ptr BYTE, lpSec:ptr

	mov eax, ERROR_ACCESS_DENIED
	@strace <"RegSaveKeyA(", hKey, ", ", lpFile, ", ", lpSec, ")=", eax>
	ret
	align 4

RegSaveKeyA endp

RegRestoreKeyA proc public hKey:HKEY, lpFile:ptr BYTE, dwFlags:dword

	mov eax, ERROR_ACCESS_DENIED
	@strace <"RegRestoreKeyA(", hKey, ", ", lpFile, ", ", dwFlags, ")=", eax>
	ret
	align 4

RegRestoreKeyA endp

RegNotifyChangeKeyValue proc public hKey:HKEY, bWatchSubtree:DWORD, dwNotifyFilter:dword, hEvent:HANDLE, fAsynchronous:DWORD

	mov eax, ERROR_ACCESS_DENIED
	@strace <"RegNotifyChangeKeyValue(", hKey, ", ", bWatchSubtree, ", ", dwNotifyFilter, ", ", hEvent, ", ", fAsynchronous, ")=", eax>
	ret
	align 4

RegNotifyChangeKeyValue endp

RegConnectRegistryA proc public lpMachineName:ptr BYTE, hKey:HKEY, phkResult:ptr HKEY

	mov eax, ERROR_ACCESS_DENIED
	@strace <"RegConnectRegistryA(", lpMachineName, ", ", hKey, ", ", phkResult, ")=", eax>
	ret
	align 4

RegConnectRegistryA endp

	end
