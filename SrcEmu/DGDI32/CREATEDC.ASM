
;--- implements CreateDCA() and DeleteDC()

	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:none
	option proc:private

	include winbase.inc
	include wingdi.inc
	include dgdi32.inc
	include macros.inc

	.CODE

CreateDCA proc public uses ebx lpszDriver:ptr BYTE, lpszDevice: ptr BYTE, lpszOut:ptr BYTE, lpInitData:ptr

	mov eax, lpszDevice
	or eax, lpszOut
	or eax, lpInitData
	.if (eax)
		xor eax, eax
	.else
		invoke lstrcmpi, CStr("DISPLAY"), lpszDriver
		.if (!eax)
			invoke _GDImalloc2, sizeof DCOBJ
			.if (eax)
				mov ebx, eax
				invoke getdisplaydc
				.if (eax)
					invoke RtlMoveMemory, ebx, eax, sizeof DCOBJ
					xor ecx, ecx
					mov [ebx].DCOBJ.pStack, ecx
if 1
					.if ([ebx].DCOBJ.dwBpp <= 8)
						invoke _GDImalloc, 100h
						mov [ebx].DCOBJ.pColMap, eax
						mov [ebx].DCOBJ.bColMap, 1
						push edi
						mov edi, eax
						mov eax, 03020100h
						stosd
						mov eax, 07060504h
						stosd
						mov eax, 0F7F60908h
						stosd
						mov eax, 0FBFAF9F8h
						stosd
						mov eax, 0FFFEFDFCh
						stosd
						pop edi
					.else
						mov [ebx].DCOBJ.pColMap, ecx
						mov [ebx].DCOBJ.bColMap, cl
					.endif
endif
				.endif
				mov eax, ebx
			.endif
		.else
			xor eax, eax
		.endif
	.endif
	@strace <"CreateDCA(", lpszDriver, ", ", lpszDevice, ", ", lpszOut, ", ", lpInitData, ")=", eax>
	ret
	align 4
CreateDCA endp

CreateDCW proc public lpszDriver:ptr WORD, lpszDevice: ptr WORD, lpszOut:ptr WORD, lpInitData:ptr

	invoke lstrlenW, lpszDriver
	inc eax
	mov ecx, eax
	mov eax, lpszDriver
	call ConvertWStr
	invoke CreateDCA, eax, lpszDevice, lpszOut, lpInitData
	@strace <"CreateDCW(", lpszDriver, ", ", lpszDevice, ", ", lpszOut, ", ", lpInitData, ")=", eax>
	ret
	align 4
CreateDCW endp

DeleteDC proc public uses ebx hdc:DWORD

	mov eax, hdc
	.if (eax)
		.if ([eax].GDIOBJ.dwType == GDI_TYPE_DC)
			.if (eax == g_hdc)
				mov g_hdc, 0
			.endif
			mov ebx, eax
			.if ([ebx].DCOBJ.pStack)
				mov eax, [ebx].DCOBJ.pStack
				.while (eax)
					push [ebx].DCOBJ.pStack
					invoke _GDIfree, ebx
					pop ebx
				.endw
			.endif
			.if ([ebx].DCOBJ.pColMap)
				invoke _GDIfree, [ebx].DCOBJ.pColMap
			.endif
			invoke _GDIfree, ebx
			@mov eax, 1
		.else
			xor eax, eax
		.endif
	.endif
	@strace <"DeleteDC(", hdc, ")=", eax>
	ret
	align 4

DeleteDC endp

	end
