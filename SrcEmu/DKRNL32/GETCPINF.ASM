
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

MAX_DEFAULTCHAR equ 2
MAX_LEADBYTES	equ 12

CPINFO struct
maxcharsize dd ?
defaultchar db MAX_DEFAULTCHAR dup (?)
leadbyte	db MAX_LEADBYTES   dup (?)
CPINFO ends

	.CODE

GetCPInfo proc public uses edi cp:dword,pCPInfo:dword

if 0
	mov eax, cp
	.if (eax == CP_ACP)
		invoke GetACP
	.elseif (eax == CP_OEMCP)
		invoke GetOEMCP
	.endif
endif
	mov edi,pCPInfo
	mov eax, 1
	mov [edi].CPINFO.maxcharsize, eax
	mov word ptr [edi].CPINFO.defaultchar, '?'
	xor ecx,ecx
	mov dword ptr [edi].CPINFO.leadbyte+0, ecx
	mov dword ptr [edi].CPINFO.leadbyte+4, ecx
	mov dword ptr [edi].CPINFO.leadbyte+8, ecx
	@strace <"GetCPInfo(", cp, ", ", pCPInfo, ")=", eax>
	ret
GetCPInfo endp

	end

