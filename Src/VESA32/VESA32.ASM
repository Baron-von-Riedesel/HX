
	.386
	.MODEL FLAT, stdcall
	option proc:private

	option casemap:none

	include winnt.inc
	include macros.inc
	include vesa32.inc

VesaInit proto
VesaExit proto

	.CODE

DllMain proc public hModule:dword,reason:dword,reserved:dword

	mov eax, reason
	.if (eax == DLL_PROCESS_ATTACH)
		call VesaInit
		@mov  eax,1
	.elseif (eax == DLL_PROCESS_DETACH)
		call VesaExit
	.endif
	ret
	align 4
DllMain endp

	END DllMain

