
	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option proc:private
	option casemap:none
	option dotname

	include winbase.inc
	include dkrnl32.inc
	include macros.inc

if ?FLAT
.BASE$IA SEGMENT dword public 'DATA'
	DD offset init
.BASE$IA ENDS
.BASE$XA SEGMENT dword public 'DATA'
	DD offset deinit
.BASE$XA ENDS
endif

	.DATA

g_pszSysDir dd 0
g_dwSysLen	dd 0

	.CODE

;--- returns the directory where dkrnl32.dll has been loaded from
;--- without trailing '\'

GetSystemDirectoryA proc public pBuffer:ptr byte, nSize:DWORD

	.if (!g_pszSysDir)
		sub esp, 256
		invoke GetModuleHandle, CStr("KERNEL32")
		mov edx, esp
		invoke GetModuleFileName, eax, edx, 256
		.while (eax)
			dec eax
			mov dl,[esp+eax]
			.break .if ((dl == '\') || (dl == '/'))
		.endw
		mov byte ptr [esp+eax],0
		inc eax
		mov g_dwSysLen, eax
		invoke KernelHeapAlloc, eax
		.if (eax)
			mov g_pszSysDir, eax
			invoke lstrcpy, eax, esp
		.endif
		add esp, 256
	.endif
	mov ecx, g_pszSysDir
	mov eax, g_dwSysLen
	.if (ecx && (eax <= nSize))
		push eax
		invoke lstrcpy, pBuffer, g_pszSysDir
		pop eax
		dec eax
	.endif
	@strace <"GetSystemDirectoryA(", pBuffer, ", ", nSize, ")=", eax>
	ret
	align 4
GetSystemDirectoryA endp

GetSystemDirectoryW proc public pBuffer:ptr WORD, nSize:DWORD

	invoke GetSystemDirectoryA, pBuffer, nSize
	.if (eax && pBuffer)
		invoke ConvertAStr, pBuffer
	.endif
	@strace <"GetSystemDirectoryW(", pBuffer, ", ", nSize, ")=", eax>
	ret
	align 4
GetSystemDirectoryW endp

if ?FLAT
init proc
	test [g_bIntFl],IKF_PELDR	;DPMILD32 here?
	jz @F
	invoke GetSystemDirectoryA, 0, 0
	mov edx, g_pszSysDir
	mov ax,4B95h
	int 21h
@@:
	ret
init endp

deinit proc
	@strace <"system directory destructor enter">
	test [g_bIntFl],IKF_PELDR	;DPMILD32 here?
	jz @F
	xor edx, edx
	mov ax,4B95h
	int 21h
@@:
	ret
deinit endp

endif

	end
