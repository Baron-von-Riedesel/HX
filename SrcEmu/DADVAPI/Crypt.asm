
;--- implements Cryptxxx functions

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

CryptGenRandom proc public hProfile:DWORD, dwLen:DWORD, lpBuffer:ptr BYTE
	xor eax, eax
	@strace <"CryptGenRandom( ", hProfile, ", ", dwLen, ", ", lpBuffer, ")=", eax, " *** unsupp ***">
	ret
	align 4
CryptGenRandom endp

CryptAcquireContextA proc public hProfile:DWORD, pszContainer:ptr BYTE, pszProvider:ptr BYTE, dwProvType:DWORD, dwFlags:DWORD
	xor eax, eax
	@strace <"CryptAcquireContextA(", hProfile, ", ", pszContainer, ", ", pszProvider, ", ",  dwProvType, ", ", dwFlags, ")=", eax, " *** unsupp ***">
	ret
	align 4
CryptAcquireContextA endp

CryptAcquireContextW proc public hProfile:DWORD, pszContainer:ptr WORD, pszProvider:ptr WORD, dwProvType:DWORD, dwFlags:DWORD
	xor eax, eax
	@strace <"CryptAcquireContextW(", hProfile, ", ", pszContainer, ", ", pszProvider, ", ",  dwProvType, ", ", dwFlags, ")=", eax, " *** unsupp ***">
	ret
	align 4
CryptAcquireContextW endp

CryptReleaseContext proc public hProfile:DWORD, dwFlags:DWORD
	xor eax, eax
	@strace <"CryptReleaseContext(", hProfile, ", ", dwFlags, ")=", eax, " *** unsupp ***">
	ret
	align 4
CryptReleaseContext endp

CryptCreateHash proc public hProv:DWORD, Alg_Id:DWORD, hKey:DWORD, dwFlags:DWORD, phHash:DWORD
	xor eax, eax
	@strace <"CryptCreateHash(", hProv, ", ", Alg_Id, ", ", hKey, ", ", dwFlags, ", ", phHash, ")=", eax, " *** unsupp ***">
	ret
	align 4
CryptCreateHash endp

CryptDestroyHash proc public hHash:DWORD
	xor eax, eax
	@strace <"CryptDestroyHash(", hHash, ")=", eax, " *** unsupp ***">
	ret
	align 4
CryptDestroyHash endp

CryptHashData proc public hHash:DWORD, pbData:ptr BYTE, dwDataLen:DWORD, dwFlags:DWORD
	xor eax, eax
	@strace <"CryptHashData(", hHash, ", ", pbData, ", ", dwDataLen, ", ", dwFlags, ")=", eax, " *** unsupp ***">
	ret
	align 4
CryptHashData endp

CryptDestroyKey proc public hKey:DWORD
	xor eax, eax
	@strace <"CryptDestroyKey(", hKey, ")=", eax, " *** unsupp ***">
	ret
	align 4
CryptDestroyKey endp

CryptDeriveKey proc public hProv:DWORD, Algid:DWORD, hBaseData:DWORD, dwFlags:DWORD, phKey:ptr DWORD
	xor eax, eax
	@strace <"CryptDeriveKey(", hProv, ", ", Algid, ", ", hBaseData, ", ", dwFlags, ", ", phKey, ")=", eax, " *** unsupp ***">
	ret
	align 4
CryptDeriveKey endp

CryptGenKey proc public hProv:DWORD, Algid:DWORD, dwFlags:DWORD, phKey:ptr DWORD
	xor eax, eax
	@strace <"CryptGenKey(", hProv, ", ", Algid, ", ", dwFlags, ", ", phKey, ")=", eax, " *** unsupp ***">
	ret
	align 4
CryptGenKey endp

CryptGetUserKey proc public hProv:DWORD, dwKeySpec:DWORD, phUserKey:ptr DWORD
	xor eax, eax
	@strace <"CryptGetUserKey(", hProv, ", ", dwKeySpec, ", ", phUserKey, ")=", eax, " *** unsupp ***">
	ret
	align 4
CryptGetUserKey endp

CryptImportKey proc public hProv:DWORD, pbData:ptr BYTE, dwDataLen:DWORD, hPubKey:DWORD, dwFlags:DWORD, phKey:ptr DWORD
	xor eax, eax
	@strace <"CryptImportKey(", hProv, ", ", pbData, ", ", dwDataLen, ", ", hPubKey, ", ", dwFlags, ", ", phKey, ")=", eax, " *** unsupp ***">
	ret
	align 4
CryptImportKey endp

CryptExportKey proc public hKey:DWORD, hExpKey:DWORD, dwBlobType:DWORD, dwFlags:DWORD, pbData:ptr BYTE, pdwDataLen:ptr DWORD
	xor eax, eax
	@strace <"CryptExportKey(", hKey, ", ", hExpKey, ", ", dwBlobType, ", ", dwFlags, ", ", pbData, ", ", pdwDataLen, ")=", eax, " *** unsupp ***">
	ret
	align 4
CryptExportKey endp

CryptEncrypt proc public hKey:DWORD, hHash:DWORD, Final:DWORD, dwFlags:DWORD, pbData:ptr BYTE, pdwDataLen:ptr DWORD, dwBufLen:DWORD
	xor eax, eax
	@strace <"CryptEncrypt(", hKey, ", ", hHash, ", ", Final, ", ", dwFlags, ", ", pbData, ", ", pdwDataLen, ", ", dwBufLen, ")=", eax, " *** unsupp ***">
	ret
	align 4
CryptEncrypt endp

CryptDecrypt proc public hKey:DWORD, hHash:DWORD, Final:DWORD, dwFlags:DWORD, pbData:ptr BYTE, pdwDataLen:ptr DWORD
	xor eax, eax
	@strace <"CryptDecrypt(", hKey, ", ", hHash, ", ", Final, ", ", dwFlags, ", ", pbData, ", ", pdwDataLen, ")=", eax, " *** unsupp ***">
	ret
	align 4
CryptDecrypt endp

CryptSetKeyParam proc public hKey:DWORD, dwParam:DWORD, pbData:ptr BYTE, dwFlags:DWORD
	xor eax, eax
	@strace <"CryptSetKeyParam(", hKey, ", ", dwParam, ", ", pbData, ", ", dwFlags, ")=", eax, " *** unsupp ***">
	ret
	align 4
CryptSetKeyParam endp

CryptGetKeyParam proc public hKey:DWORD, dwParam:DWORD, pbData:ptr BYTE, pdwDataLen:ptr DWORD, dwFlags:DWORD
	xor eax, eax
	@strace <"CryptGetKeyParam(", hKey, ", ", dwParam, ", ", pbData, ", ", pdwDataLen, ", ", dwFlags, ")=", eax, " *** unsupp ***">
	ret
	align 4
CryptGetKeyParam endp

CryptSetProvParam proc public hKey:DWORD, dwParam:DWORD, pbData:ptr BYTE, dwFlags:DWORD
	xor eax, eax
	@strace <"CryptSetProvParam(", hKey, ", ", dwParam, ", ", pbData, ", ", dwFlags, ")=", eax, " *** unsupp ***">
	ret
	align 4
CryptSetProvParam endp

CryptGetProvParam proc public hKey:DWORD, dwParam:DWORD, pbData:ptr BYTE, pdwDataLen:ptr DWORD, dwFlags:DWORD
	xor eax, eax
	@strace <"CryptGetProvParam(", hKey, ", ", dwParam, ", ", pbData, ", ", pdwDataLen, ", ", dwFlags, ")=", eax, " *** unsupp ***">
	ret
	align 4
CryptGetProvParam endp

CryptSetHashParam proc public hHash:DWORD, dwParam:DWORD, pbData:ptr BYTE, dwFlags:DWORD
	xor eax, eax
	@strace <"CryptSetHashParam(", hHash, ", ", dwParam, ", ", pbData, ", ", dwFlags, ")=", eax, " *** unsupp ***">
	ret
	align 4
CryptSetHashParam endp

CryptGetHashParam proc public hHash:DWORD, dwParam:DWORD, pbData:ptr BYTE, pdwDataLen:ptr DWORD, dwFlags:DWORD
	xor eax, eax
	@strace <"CryptGetHashParam(", hHash, ", ", dwParam, ", ", pbData, ", ", pdwDataLen, ", ", dwFlags, ")=", eax, " *** unsupp ***">
	ret
	align 4
CryptGetHashParam endp

CryptVerifySignatureA proc public hHash:DWORD, pbSignature:ptr BYTE, dwSigLen:DWORD, hPubKey:DWORD, sDescription:ptr BYTE, dwFlags:DWORD
	xor eax, eax
	@strace <"CryptVerifySignatureA(", hHash, ", ", pbSignature, ", ", dwSigLen, ", ", hPubKey, ", ", sDescription, ", ", dwFlags, ")=", eax, " *** unsupp ***">
	ret
	align 4
CryptVerifySignatureA endp

CryptSignHashA proc public hHash:DWORD, dwKeySpec:DWORD, sDescription:ptr BYTE, dwFlags:DWORD, pbSignature:ptr BYTE, pdwSigLen:ptr DWORD
	xor eax, eax
	@strace <"CryptSignHashA(", hHash, ", ", dwKeySpec, ", ", sDescription, ", ", dwFlags, ", ", pbSignature, ", ", pdwSigLen, ")=", eax, " *** unsupp ***">
	ret
	align 4
CryptSignHashA endp

CryptEnumProvidersA proc public dwIndex:DWORD, pdwReserved:ptr DWORD, dwFlags:DWORD, pdwProvType:ptr DWORD, pszProvName:ptr BYTE, pcbProvName:ptr DWORD
	xor eax, eax
	@strace <"CryptEnumProvidersA(", dwIndex, ", ", pdwReserved, ", ", dwFlags, ", ", pdwProvType, ", ", pszProvName, ", ", pcbProvName, ")=", eax, " *** unsupp ***">
	ret
	align 4
CryptEnumProvidersA endp

SystemFunction036 proc public uses edi ebx buffer:ptr, dwLen:DWORD

	.data
wOfs dw 0
	.code
	movzx ebx, wOfs
	mov ecx, dwLen
	mov edi, buffer
	.while (ecx)
		mov al,[ebx+0F0000h]
		neg al
		stosb
		inc bx
		dec ecx
	.endw
	mov wOfs, bx
	mov eax, 1
	@strace <"SystemFunction036( ", buffer, ", ", dwLen, ")=", eax>
	ret
	align 4
SystemFunction036 endp

	end
