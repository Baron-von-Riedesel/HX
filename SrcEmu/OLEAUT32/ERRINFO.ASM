
	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:none
	option proc:private

	.nolist
	.nocref
	include winbase.inc
	include winuser.inc
	include objbase.inc
	include oleauto.inc
	include macros.inc
	.list
	.cref

	.DATA

;--- todo: errorinfo is thread-specific!

g_pErrorInfo dd 0

	.CODE

SetErrorInfo proc public dwRes:DWORD, pErrorInfo:ptr

	.if (pErrorInfo)
		invoke vf(pErrorInfo, IUnknown, AddRef)
	.endif
	.if (g_pErrorInfo)
		invoke vf(g_pErrorInfo, IUnknown, Release)
	.endif
	mov eax, pErrorInfo
	mov g_pErrorInfo, eax
	mov eax, S_OK
	@strace <"SetErrorInfo(", dwRes, ", ", pErrorInfo, ")=", eax>
	ret
	align 4

SetErrorInfo endp

GetErrorInfo proc public dwRes:DWORD, ppErrorInfo:ptr ptr

	xor eax, eax
	xchg eax, g_pErrorInfo
	.if (eax == NULL)
		mov eax, S_FALSE
	.else
		mov ecx, ppErrorInfo
		mov [ecx], eax
		mov eax, S_OK
	.endif
	@strace <"GetErrorInfo(", dwRes, ", ", ppErrorInfo, ")=", eax>
	ret
	align 4

GetErrorInfo endp

	end
