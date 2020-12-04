
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

	.DATA

	.CODE

GetNetworkParams proc public pFixedInfo:ptr, pOutbufLen:ptr
	xor eax, eax
	@strace <"GetNetworkParams(", pFixedInfo, ", ", pOutbufLen, ")=", eax>
	ret
	align 4
GetNetworkParams endp


DllMain proc public handle:dword,reason:dword,reserved:dword

	.if (reason == DLL_PROCESS_ATTACH)
	.elseif (reason == DLL_PROCESS_DETACH)
	.endif
	@mov eax,1
	ret
DllMain endp

	END DllMain

