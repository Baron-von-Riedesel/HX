
	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:none
	option proc:private

	include winbase.inc
	include dkrnl32.inc
	include macros.inc

	.code

DefineDosDeviceA proc public dwFlags:DWORD, lpDeviceName:ptr BYTE, lpTargetPath:ptr BYTE

	xor eax, eax
	@strace <"DefineDosDeviceA(", dwFlags, ", ", lpDeviceName, ", ", lpTargetPath, ")=", eax, " *** unsupp ***">
	ret
	align 4

DefineDosDeviceA endp

QueryDosDeviceA proc public lpDeviceName:ptr BYTE, lpTargetPath:ptr BYTE, ucchMax:DWORD

	xor eax, eax
	mov ecx, lpTargetPath
	mov [ecx],ax
	@strace <"QueryDosDeviceA(", lpDeviceName, ", ", lpTargetPath, ", ", ucchMax, ")=", eax, " *** unsupp ***">
	ret
	align 4

QueryDosDeviceA endp

	end
