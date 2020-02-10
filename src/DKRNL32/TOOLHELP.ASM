
	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option proc:private
	option casemap:none

	include winbase.inc
	include tlhelp32.inc
	include dkrnl32.inc
	include macros.inc

	.CODE

CreateToolhelp32Snapshot proc public dwFlags:dword, dwProcess:dword

;--- since we use CloseHandle to close this handle
;--- and closehandle uses KernelHeapFree for this object, 
;--- just alloc some space

	invoke KernelHeapAlloc, 4
	@strace <"CreateToolhelp32Snapshot(", dwFlags, ", ", dwProcess, ")=", eax>
	ret
	align 4
CreateToolhelp32Snapshot endp

;--- inp: eax == MODULEENTRY32
;--- EDX=last module or NULL

ModuleHelper proc uses ebx esi edi

if ?FLAT
	push eax
	mov ax,4B83h
	int 21h
	pop ebx
	and eax,eax
	jz done
	push eax
	mov [ebx].MODULEENTRY32.hModule,eax
	mov [ebx].MODULEENTRY32.th32ModuleID,eax
	mov [ebx].MODULEENTRY32.modBaseAddr,eax
	mov [ebx].MODULEENTRY32.GlblcntUsage,ecx
	mov edx, eax
	add edx, [eax].IMAGE_DOS_HEADER.e_lfanew
	mov edx, [edx].IMAGE_NT_HEADERS.OptionalHeader.SizeOfImage
	mov [ebx].MODULEENTRY32.modBaseSize, edx
	lea edx,[ebx].MODULEENTRY32.szExePath
	invoke GetModuleFileNameA, eax, edx, MAX_PATH

	lea esi,[ebx.MODULEENTRY32.szExePath]
mh1:
	mov ecx,esi
@@:
	lodsb
	and al,al
	jz @F
	cmp al,':'
	jz mh1
	cmp al,'\'
	jz mh1
	jmp @B
@@:
	mov esi,ecx
	mov ecx,MAX_MODULE_NAME32+1
	lea edi,[ebx].MODULEENTRY32.szModule
@@:
	lodsb
	stosb
	and al,al
	loopnz @B

	push ebx
	mov ah,51h
	int 21h
	movzx eax,bx
	pop ebx
	mov [ebx].MODULEENTRY32.th32ProcessID,eax

	pop eax
done:
else
	xor eax, eax
endif
	ret
	align 4
ModuleHelper endp

SetEOF proc
	invoke SetLastError, ERROR_NO_MORE_FILES
	xor eax,eax
	ret
	align 4
SetEOF endp

Module32First proc public handle:dword,pModuleEntry:dword

	mov eax,pModuleEntry
	xor edx,edx
	call ModuleHelper
	and eax,eax
	jnz @F
	call SetEOF
@@:
	@strace <"Module32First(", handle, ", ", pModuleEntry, ")=", eax>
	ret
	align 4
Module32First endp

Module32Next proc public handle:dword,pModuleEntry:dword

	mov eax,pModuleEntry
	mov edx,[eax].MODULEENTRY32.hModule
	call ModuleHelper
	and eax,eax
	jnz @F
	call SetEOF
@@:
	@strace <"Module32Next(", handle, ", ", pModuleEntry, ")=", eax>
	ret
	align 4
Module32Next endp

Process32First proc public uses ebx handle:dword,pProcessEntry:dword

	mov ebx,pProcessEntry
	invoke GetCurrentProcessId
	mov [ebx].PROCESSENTRY32.th32ProcessID,eax
	invoke GetModuleHandle,0
	mov [ebx].PROCESSENTRY32.th32ModuleID,eax
	mov [ebx].PROCESSENTRY32.cntThreads,1
	mov [ebx].PROCESSENTRY32.dwFlags,0
	cmp [ebx].PROCESSENTRY32.dwSize, PROCESSENTRY32.szExeFile
	jbe @F
	invoke GetModuleFileNameA, [ebx].PROCESSENTRY32.th32ModuleID,\
		addr [ebx].PROCESSENTRY32.szExeFile,\
		sizeof PROCESSENTRY32.szExeFile
@@:
	@mov eax,1
	@strace <"Process32First(", handle, ", ", pProcessEntry, ")=", eax>
	ret
	align 4
Process32First endp

Process32Next proc public handle:dword,pProcessEntry:dword

	call SetEOF
	@strace <"Process32Next(", handle, ", ", pProcessEntry, ")=", eax>
	ret
	align 4
Process32Next endp

Thread32First proc public uses ebx handle:dword,pThreadEntry:dword

	mov ah,51h
	int 21h
	movzx eax,bx
	mov ebx,pThreadEntry
	mov [ebx].THREADENTRY32.th32OwnerProcessID, eax
	invoke GetCurrentThreadId
	mov [ebx].THREADENTRY32.th32ThreadID, eax
	mov [ebx].THREADENTRY32.tpBasePri, 0
	mov [ebx].THREADENTRY32.tpDeltaPri, 0
	mov [ebx].THREADENTRY32.dwFlags, 0
	mov eax,1
	@strace <"Thread32First(", handle, ", ", pThreadEntry, ")=", eax>
	ret
	align 4
Thread32First endp

Thread32Next proc public handle:dword,pThreadEntry:dword

	call SetEOF
	@strace <"Thread32Next(", handle, ", ", pThreadEntry, ")=", eax, " *** unsupp ***">
	ret
	align 4
Thread32Next endp

Heap32First proc public pHeapEntry:dword,procid:dword,heapid:dword

	call SetEOF
	@strace <"Heap32First(", pHeapEntry, ", ", procid, ", ", heapid, ")=", eax, " *** unsupp ***">
	ret
	align 4
Heap32First endp

Heap32Next proc public pHeapEntry:dword

	call SetEOF
	@strace <"Heap32Next(", pHeapEntry, ")=", eax, " *** unsupp ***">
	ret
	align 4
Heap32Next endp

Heap32ListFirst proc public handle:dword,pHeapListEntry:dword

	call SetEOF
	@strace <"Heap32ListFirst(", handle, ", ", pHeapListEntry, ")=", eax, " *** unsupp ***">
	ret
	align 4
Heap32ListFirst endp

Heap32ListNext proc public handle:dword,pHeapListEntry:dword

	call SetEOF
	@strace <"Heap32ListNext(", handle, ", ", pHeapListEntry, ")=", eax, " *** unsupp ***">
	ret
	align 4
Heap32ListNext endp

	end

