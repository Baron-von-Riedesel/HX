
;--- implements CoCreateInstance
;--- implements CoCreateGuid

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
	include winuser.inc
	include objbase.inc
	include macros.inc

	.CONST

IID_IClassFactory GUID <00000001,0000,0000,<0C0h,00,00,00,00,00,00,46h>>

	.CODE

protoDllGetClassObject typedef proto :dword, :dword, :dword
LPFNDLLGETCLASSOBJECT typedef ptr protoDllGetClassObject

CoGetClassObject proc public uses esi pCLSID:ptr BYTE, dwContext:DWORD, pServerInfo:ptr, riid:ptr BYTE, ppv:ptr

local	lpfnDllGetClassObject:LPFNDLLGETCLASSOBJECT
local	hKey:dword
local	dwSize:dword
local	szKey[128]:BYTE
local	szTemp[MAX_PATH]:byte
local	szwClsid[40]:WORD
local	szClsid[40]:BYTE

	invoke StringFromGUID2, pCLSID, addr szwClsid, LENGTHOF szwClsid
	invoke WideCharToMultiByte, CP_ACP, 0, addr szwClsid, -1, addr szClsid, LENGTHOF szClsid, 0, 0
	invoke wsprintf, addr szKey, CStr("CLSID\%s\InProcServer32"), addr szClsid
	invoke RegOpenKey, HKEY_CLASSES_ROOT, addr szKey, addr hKey
	cmp eax,ERROR_SUCCESS
	jnz error
	mov dwSize, sizeof szTemp
	invoke RegQueryValue, hKey, NULL, addr szTemp, addr dwSize
	push eax
	invoke RegCloseKey, hKey
	pop eax
	.if (eax == ERROR_SUCCESS)
		invoke LoadLibrary, addr szTemp
		.if (eax)
			mov esi, eax
			invoke GetProcAddress, esi, CStr("DllGetClassObject")
			.if (eax)
				mov lpfnDllGetClassObject, eax
				invoke lpfnDllGetClassObject, pCLSID, offset IID_IClassFactory, addr ppv
				.if (!eax)
					jmp exit
				.endif
			.endif
			invoke FreeLibrary, esi
		.endif
	.endif
error:
	mov eax,E_FAIL
exit:
	@strace <"CoGetClassObject(", pCLSID, ", ", dwContext, ", ", pServerInfo, ", ", riid, ", ", ppv, ")=", eax, " ebx=", ebx, " edi=", edi>
	ret
	align 4
CoGetClassObject endp

CoCreateInstance proc public uses esi pCLSID:ptr BYTE, pUnknown:DWORD, dwContext:DWORD, riid:ptr BYTE, ppv:ptr

local	lpfnDllGetClassObject:LPFNDLLGETCLASSOBJECT
local	lpCF:dword
local	hKey:dword
local	dwSize:dword
local	szKey[128]:BYTE
local	szTemp[MAX_PATH]:byte
local	szwClsid[40]:WORD
local	szClsid[40]:BYTE

	@strace <"CoCreateInstance(", pCLSID, ", ", pUnknown, ", ", dwContext, ", ", riid, ", ", ppv, ") enter ebx=", ebx, " edi=", edi>
	invoke StringFromGUID2, pCLSID, addr szwClsid, LENGTHOF szwClsid
	invoke WideCharToMultiByte, CP_ACP, 0, addr szwClsid, -1, addr szClsid, LENGTHOF szClsid, 0, 0
	invoke wsprintf, addr szKey, CStr("CLSID\%s\InProcServer32"), addr szClsid
	invoke RegOpenKey, HKEY_CLASSES_ROOT, addr szKey, addr hKey
	cmp eax,ERROR_SUCCESS
	jnz error
	mov dwSize, sizeof szTemp
	invoke RegQueryValue, hKey, NULL, addr szTemp, addr dwSize
	push eax
	invoke RegCloseKey, hKey
	pop eax
	.if (eax == ERROR_SUCCESS)
		invoke LoadLibrary, addr szTemp
		.if (eax)
			mov esi, eax
			invoke GetProcAddress, esi, CStr("DllGetClassObject")
			.if (eax)
				mov lpfnDllGetClassObject, eax
				invoke lpfnDllGetClassObject, pCLSID, offset IID_IClassFactory, addr lpCF
				.if (!eax)
					invoke vf(lpCF, IClassFactory, CreateInstance), pUnknown, riid, ppv
					push eax
					invoke vf(lpCF, IUnknown, Release)
					pop eax
					.if (!eax)
						jmp exit
					.endif
				.endif
			.endif
			invoke FreeLibrary, esi
		.endif
	.endif
error:
	mov eax,E_FAIL
exit:
	@strace <"CoCreateInstance(", pCLSID, ", ", pUnknown, ", ", dwContext, ", ", riid, ", ", ppv, ")=", eax, " ebx=", ebx, " edi=", edi>
	ret
	align 4

CoCreateInstance endp

CoCreateGuid proc public pGUID:ptr BYTE

	mov eax,E_FAIL
	@strace <"CoCreateGuid(", pGUID, ")=", eax, " *** unsupp ***">
	ret
	align 4

CoCreateGuid endp

	end
