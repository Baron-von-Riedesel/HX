
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

.BASE$XA SEGMENT dword public 'DATA'
	DD offset ClearDeleteList
.BASE$XA ENDS

	.data

g_pDeleteFiles dd 0		;list of files to be deleted        

	.CODE

AddFileToDeleteList proc pszFile:ptr byte
	invoke lstrlen, pszFile
	add eax,5
	invoke LocalAlloc, LMEM_FIXED, eax
	.if (eax)
		push eax
		invoke lstrcpy, addr [eax+4], pszFile
		pop edx
		@noints
		mov ecx, edx
		xchg edx, g_pDeleteFiles
		mov [ecx], edx
		@restoreints
	.endif
	ret
	align 4

AddFileToDeleteList endp

ClearDeleteList proc uses esi

	@strace <"pipes destructor enter">
	xor esi, esi
	xchg esi, g_pDeleteFiles
	.while (esi)
		push dword ptr [esi]
		invoke DeleteFile, addr [esi+4]
		pop esi
	.endw
	ret
	align 4

ClearDeleteList endp

CreatePipe proc public uses ebx esi edi pReadPipe:ptr dword,pWritePipe:ptr dword,pSec:ptr dword,nSize:dword

local	szPath[MAX_PATH]:byte
local	szName[MAX_PATH]:byte

	invoke GetTempPathA, MAX_PATH, addr szPath		
	invoke GetTempFileNameA, addr szPath, CStr("~PP"), 0, addr szName
	.if (eax)
		xor ebx, ebx
		xor esi, esi
		or edi, -1
		invoke KernelHeapAlloc, sizeof PIPE
		and eax, eax
		jz fail
		mov ebx, eax
		invoke KernelHeapAlloc, sizeof PIPE
		and eax, eax
		jz fail
		mov esi, eax

		invoke CreateFileA, addr szName, GENERIC_READ or GENERIC_WRITE, FILE_SHARE_WRITE or FILE_SHARE_READ, 0,\
			OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0
		cmp eax, -1
		jz fail
		mov edi, eax
		push ebx
		mov ebx, eax
		mov ah, 45h
		int 21h
		pop ebx
		jc fail
		movzx eax,ax
		xor ecx, ecx
		mov dword ptr [ebx-4], offset destructor
		mov [ebx].PIPE.dwType, SYNCTYPE_PIPE
		mov [ebx].PIPE.dwfh, edi
		mov [ebx].PIPE.dwPos, ecx
		mov dword ptr [esi-4], offset destructor
		mov [esi].PIPE.dwType, SYNCTYPE_PIPE
		mov [esi].PIPE.dwfh, eax
		mov [esi].PIPE.dwPos, ecx
		mov [esi].PIPE.bWrite, 1
		mov ecx, pReadPipe
		mov [ecx], ebx
		mov ecx, pWritePipe
		mov [ecx], esi
		invoke AddFileToDeleteList, addr szName
		@mov eax, 1
	.endif
exit:
	@strace <"CreatePipe(", pReadPipe, ", ", pWritePipe, ", ", pSec, ", ", nSize, ")=", eax>
	ret
fail:
	.if (ebx)
		invoke KernelHeapFree, ebx
	.endif
	.if (esi)
		invoke KernelHeapFree, esi
	.endif
	.if (edi != -1)
		invoke CloseHandle, edi
		invoke DeleteFile, addr szName
	.endif
	xor eax, eax
	jmp exit
	align 4

CreatePipe endp

destructor proc uses ebx pThis:DWORD

	mov ebx, pThis
	.if ([ebx].PIPE.dwfh != HFILE_ERROR)
		invoke CloseHandle, [ebx].PIPE.dwfh
	.endif
	@mov eax, 1
	@strace <"destructor pipe(", pThis, ")=", eax >
	ret
	align 4

destructor endp

	end
