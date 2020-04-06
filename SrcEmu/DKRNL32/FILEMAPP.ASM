
;--- implements:
;--- CreateFileMappingA
;--- CreateFileMappingW
;--- MapViewOfFileEx
;--- MapViewOfFile
;--- UnmapViewOfFile
;--- FlushViewOfFile
;--- OpenFileMappingA
;--- OpenFileMappingW

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

	option dotname

if 0
.BASE$XA segment dword public 'DATA'
		dd offset FreeMappingObjects
.BASE$XA ends
endif

	.CODE

CreateFileMappingA proc public uses ebx hFile:DWORD, lpFileMappingAttributes:DWORD, dwProtect:DWORD,
			dwMaximumSizeHigh:DWORD, dwMaximumSizeLow:DWORD, lpName:ptr BYTE

	@strace <"CreateFileMappingA enter">
;----------------------------- if it's a named object, check existance
	.if (lpName)
		invoke KernelHeapFindObject, lpName, SYNCTYPE_FILEMAPP
		.if (eax)
			mov eax, edx
			jmp done
		.endif
		invoke SetLastError, ERROR_SUCCESS
	.endif
	.if (hFile != -1)
		mov ecx, dwMaximumSizeLow
		mov edx, dwMaximumSizeHigh
		or edx, ecx
		.if (!edx)
			invoke GetFileSize, hFile, NULL
			.if (!eax)
				invoke SetLastError, ERROR_FILE_INVALID
				xor eax, eax
				jmp done
			.endif
			mov dwMaximumSizeLow, eax
		.endif
	.endif
	.if (!dwMaximumSizeLow)
		xor eax, eax
		jmp done
	.endif
	invoke KernelHeapAllocObject, sizeof FILEMAPOBJ, lpName
	.if (eax)
		mov ebx, eax
		mov dword ptr [ebx-4], offset destructor
		mov [ebx].FILEMAPOBJ.dwType, SYNCTYPE_FILEMAPP
		.if (hFile != -1)
			invoke DuplicateHandle, 0, hFile, 0, addr [ebx].FILEMAPOBJ.hFile,\
				0, 0,DUPLICATE_SAME_ACCESS
			.if (!eax)
				invoke KernelHeapFree, ebx
				xor eax, eax
				jmp done
			.endif
		.else
			mov [ebx].FILEMAPOBJ.hFile, -1
		.endif
		mov ecx, dwMaximumSizeLow
		mov [ebx].FILEMAPOBJ.dwSize, ecx
		mov [ebx].FILEMAPOBJ.pView, NULL
		mov [ebx].FILEMAPOBJ.dwFlags, NULL
		mov [ebx].FILEMAPOBJ.dwRefCnt, 1
		mov ecx, dwProtect
		mov [ebx].FILEMAPOBJ.dwProtect, ecx
		mov eax, ebx
	.endif
done:
ifdef _DEBUG
	.if (!lpName)
		mov ecx, CStr("NULL")
	.else
		mov ecx, lpName
	.endif
endif
	@strace <"CreateFileMappingA(", hFile, ", ", lpFileMappingAttributes, ", ", dwProtect, ", size=", dwMaximumSizeHigh, ":", dwMaximumSizeLow, ", name=", &ecx, ")=", eax>
	ret
	align 4

CreateFileMappingA endp

CreateFileMappingW proc public hFile:DWORD, lpFileMappingAttributes:DWORD, dwProtect:DWORD,
			dwMaximumSizeHigh:DWORD, dwMaximumSizeLow:DWORD, lpName:ptr WORD

	@strace <"CreateFileMappingW">
	mov eax, lpName
	.if (eax)
		call ConvertWStr
	.endif
	invoke CreateFileMappingA, hFile, lpFileMappingAttributes, dwProtect,\
		dwMaximumSizeHigh, dwMaximumSizeLow, eax
	ret
	align 4

CreateFileMappingW endp

;--- flush file mapping object in EBX

_flushfmobj proc uses esi edi dwBase:dword, dwSize:dword, bResetPageFlags:dword

local	dwESP:DWORD
local	dwPages:DWORD
local	dwWritten:DWORD

	.if (([ebx].FILEMAPOBJ.pView) && ([ebx].FILEMAPOBJ.dwProtect != PAGE_READONLY))
		mov eax, [ebx].FILEMAPOBJ.dwSize
		mov ecx, eax
		shr eax, 12
		test cx, 0FFFh
		jz @F
		inc eax
@@:
		mov dwPages, eax
		.if ([ebx].FILEMAPOBJ.hFile != HFILE_ERROR)
			mov dwESP, esp
			add eax, eax		;2 bytes/page
			add eax, 4
			and al, 0FCh
			sub esp, eax
			@loadesp esi
			invoke VirtualGetPageAttr, [ebx].FILEMAPOBJ.pView, esi, dwPages
			.if (eax && (word ptr [esi] & 10h)) ;dirty bit supplied?
				xor edi, edi
				mov ecx, dwPages
				.while (ecx)
					lodsw
					and al, 50h			;10h=, 40h=dirty
					.if (al == 50h)
						push ecx
						mov edx, edi
						add edx, [ebx].FILEMAPOBJ.dwOffset
						invoke SetFilePointer,[ebx].FILEMAPOBJ.hFile,\
							edx, NULL, 0
						mov edx, [ebx].FILEMAPOBJ.pView
						add edx, edi
						invoke WriteFile, [ebx].FILEMAPOBJ.hFile,\
							edx, 1000h, addr dwWritten, 0
						pop ecx
					.endif
					add edi, 1000h
					dec ecx
				.endw
			.else
				invoke SetFilePointer,[ebx].FILEMAPOBJ.hFile,\
					[ebx].FILEMAPOBJ.dwOffset, NULL, 0
				invoke WriteFile, [ebx].FILEMAPOBJ.hFile,\
					[ebx].FILEMAPOBJ.pView, [ebx].FILEMAPOBJ.dwSizeReal,\
					addr dwWritten, 0
			.endif
			mov esp, dwESP
if 0
;--- this code is required if share is not loaded (plain dos)???
			.if (bResetPageFlags)
				invoke DuplicateHandle, 0, [ebx].FILEMAPOBJ.hFile, 0, addr dwWritten,\
					0, 0,DUPLICATE_SAME_ACCESS
				.if (eax)
					mov eax, dwWritten
					xchg eax, [ebx].FILEMAPOBJ.hFile
					invoke CloseHandle, eax
				.endif
			.endif
endif
		.endif
;---- reset dirty bits
		.if (bResetPageFlags)
			mov ecx, dwPages
			shl ecx, 12
			invoke VirtualSetPageAttr, [ebx].FILEMAPOBJ.pView, ecx, 10h, 50h
		.endif
	.endif
	ret
	align 4

_flushfmobj endp

destructor proc uses ebx pThis:DWORD

	@strace <"destructor filemapobj enter">
	mov ebx, pThis
	xor eax, eax
	cmp [ebx].FILEMAPOBJ.dwRefCnt,eax
	jz @F
	dec [ebx].FILEMAPOBJ.dwRefCnt
	jnz done					;exit, there are more references
@@:
	.if ( [ebx].NAMEDOBJECT.lpName )
		invoke KernelHeapUnlinkObject, ebx
	.endif
	or [ebx].FILEMAPOBJ.dwFlags, FMO_CLOSED
	.if ([ebx].FILEMAPOBJ.dwFlags & FMO_MAPPED)
		jmp done				;it's mapped, dont free it
	.endif
	invoke _flushfmobj,0,0,0
	.if ([ebx].FILEMAPOBJ.pView)
		invoke VirtualFree, [ebx].FILEMAPOBJ.pView, NULL, MEM_RELEASE
		mov [ebx].FILEMAPOBJ.pView, NULL
	.endif
	.if ([ebx].FILEMAPOBJ.hFile != HFILE_ERROR)
		invoke CloseHandle, [ebx].FILEMAPOBJ.hFile
		mov [ebx].FILEMAPOBJ.hFile, HFILE_ERROR
	.endif
	@mov eax, 1
done:
	@strace <"destructor filemapobj exit=", eax>
	ret
	align 4

destructor endp

MapViewOfFileEx proc public uses ebx hFileMap:DWORD, dwDesiredAccess:DWORD, dwFileOffsetHigh:DWORD,
			dwFileOffsetLow:DWORD, dwNumberOfBytesToMap:DWORD, lpBaseAddress:ptr

local	dwRead:DWORD

	@strace <"MapViewOfFileEx(", hFileMap, ", ", dwDesiredAccess, ", ofs=", dwFileOffsetHigh, ":", dwFileOffsetLow, ", size=", dwNumberOfBytesToMap, ", base=", lpBaseAddress, ")">
	mov ebx, hFileMap
;------------------------------- dont allow files > 4 GB
	cmp dwFileOffsetHigh,0
	jnz error
	mov eax, dwFileOffsetLow
;------------------------------- dont allow remapping (offset change)
	.if ([ebx].FILEMAPOBJ.dwFlags & FMO_MAPPED)
		mov ecx, dwNumberOfBytesToMap
		.if (eax == [ebx].FILEMAPOBJ.dwOffset)
			.if ((!ecx) || (ecx <= [ebx].FILEMAPOBJ.dwSizeReal))
				mov eax, [ebx].FILEMAPOBJ.pView
				jmp done
			.endif
		.endif
		jmp error
	.endif
	mov [ebx].FILEMAPOBJ.dwOffset, eax

if 0
;--------------------------- MEM_RESERVE is not correct, but the VirtualAlloc
;--------------------------- will in any case commit the region. With MEM_RESERVE
;--------------------------- we may avoid the zeroinit, so the DIRTY bits arent set
	invoke VirtualAlloc, lpBaseAddress, [ebx].FILEMAPOBJ.dwSize, MEM_RESERVE, [ebx].FILEMAPOBJ.dwProtect
	.if (!eax)
		jmp error
	.endif
else
;--------------------------- MEM_RESERVE cannot be used any longer since
;--------------------------- if dpmi host is v1.0 it will in fact reserve
;--------------------------- pages only.
;--------------------------- So we alloc a memory region and try to clear dirty
;--------------------------- bits. this will work for 1.0 hosts either
;;	invoke VirtualAlloc, lpBaseAddress, [ebx].FILEMAPOBJ.dwSize, MEM_COMMIT, [ebx].FILEMAPOBJ.dwProtect
;--------------------------- 17.4.2004: we need MEM_RESERVE or MEM_COMMIT !!!
;--------------------------- if lpBaseAddress is != NULL
	invoke VirtualAlloc, lpBaseAddress, [ebx].FILEMAPOBJ.dwSize, MEM_RESERVE or MEM_COMMIT, [ebx].FILEMAPOBJ.dwProtect
	.if (!eax)
		jmp error
	.endif
;--------------------------- this call tries to clear dirty bits
	push eax
	invoke VirtualSetPageAttr, eax, [ebx].FILEMAPOBJ.dwSize, 0, 40h
	pop eax
endif
	mov [ebx].FILEMAPOBJ.pView, eax
;	invoke VirtualFindBlock, eax
;	.if (eax)
;		mov [eax].MBLOCK.dwCookie, ebx
;	.endif
;;	invoke ZeroMemory, [ebx].FILEMAPOBJ.pView, [ebx].FILEMAPOBJ.dwSize
	mov ecx, dwNumberOfBytesToMap
	.if (!ecx)
		mov ecx, [ebx].FILEMAPOBJ.dwSize
	.endif
	mov [ebx].FILEMAPOBJ.dwSizeReal, ecx
	.if ([ebx].FILEMAPOBJ.hFile != HFILE_ERROR)
		invoke SetFilePointer,[ebx].FILEMAPOBJ.hFile,\
			[ebx].FILEMAPOBJ.dwOffset, NULL, 0
		invoke ReadFile, [ebx].FILEMAPOBJ.hFile, [ebx].FILEMAPOBJ.pView,\
			[ebx].FILEMAPOBJ.dwSizeReal, addr dwRead, 0
	.endif
	mov eax, [ebx].FILEMAPOBJ.pView
	or [ebx].FILEMAPOBJ.dwFlags, FMO_MAPPED
	jmp done
error:
	xor eax, eax
done:
	@strace <"MapViewOfFileEx()=", eax>
	ret
	align 4

MapViewOfFileEx endp

MapViewOfFile proc public hFileMap:DWORD, dwDesiredAccess:DWORD, dwFileOffsetHigh:DWORD,
			dwFileOffsetLow:DWORD, dwNumberOfBytesToMap:DWORD

	invoke MapViewOfFileEx, hFileMap, dwDesiredAccess, dwFileOffsetHigh,\
			dwFileOffsetLow, dwNumberOfBytesToMap, NULL
	ret
	align 4

MapViewOfFile endp


UnmapViewOfFile proc public uses ebx lpBaseAddress:ptr

local	phe:PROCESS_HEAP_ENTRY

	mov phe.lpData,0
	invoke KernelHeapWalk, addr phe, SYNCTYPE_FILEMAPP
	.while (eax)
		.break .if (!eax)
		mov ecx, lpBaseAddress
		.if (ecx == [eax].FILEMAPOBJ.pView)
			and [eax].FILEMAPOBJ.dwFlags, NOT FMO_MAPPED
			.if ([eax].FILEMAPOBJ.dwFlags & FMO_CLOSED)
				invoke KernelHeapFree, eax
			.endif
			@mov eax, 1
			.break
		.endif
		invoke KernelHeapWalk, addr phe, SYNCTYPE_FILEMAPP
	.endw
	@strace <"UnmapViewOfFile(", lpBaseAddress, ")=", eax>
	ret
	align 4

UnmapViewOfFile endp

FlushViewOfFile proc public uses ebx lpBaseAddress:ptr, dwBytes:DWORD

local	phe:PROCESS_HEAP_ENTRY

	mov phe.lpData,0
	invoke KernelHeapWalk, addr phe, SYNCTYPE_FILEMAPP
	.while (eax)
		mov ecx, lpBaseAddress
		.if (ecx == [eax].FILEMAPOBJ.pView) 
			mov ebx, eax
			.if ([ebx].FILEMAPOBJ.dwFlags & FMO_MAPPED)
				invoke _flushfmobj, 0, 0, 1
			.endif
			@mov eax, 1
			.break
		.endif
		invoke KernelHeapWalk, addr phe, SYNCTYPE_FILEMAPP
	.endw
	@strace <"FlushViewOfFile(", lpBaseAddress, ", ", dwBytes, ")=", eax>
	ret
	align 4

FlushViewOfFile endp


OpenFileMappingA proc public dwDesiredAccess:DWORD, bInheritHandle:DWORD, lpName:ptr BYTE

	invoke KernelHeapFindObject, lpName, SYNCTYPE_FILEMAPP
	mov eax, edx
	@strace <"OpenFileMappingA(", dwDesiredAccess, ", ", bInheritHandle, ", ", &lpName, ")=", eax>
	ret
	align 4

OpenFileMappingA endp

OpenFileMappingW proc public dwDesiredAccess:DWORD, bInheritHandle:DWORD, lpName:ptr WORD

	mov eax, lpName
	call ConvertWStr
	invoke OpenFileMappingA, dwDesiredAccess, bInheritHandle, eax
	@strace <"OpenFileMappingW(", dwDesiredAccess, ", ", bInheritHandle, ", ", lpName, ")=", eax>
	ret
	align 4

OpenFileMappingW endp

if 0
;--- check if at program termination there are file mapping objects
;--- still open. close them now

;--- if it is to activate again, no longer use VirtualGetFileMapObject!
;--- Use KernelHeapFindObject instead!

FreeMappingObjects proc uses ebx

	@trace <"FreeMappingObjects enter",13,10>
	.while (1)
		invoke VirtualGetFileMapObject
		.break .if (!eax)
		mov ebx, [eax].MBLOCK.dwCookie
		and [ebx].FILEMAPOBJ.dwFlags, NOT FMO_MAPPED
		invoke KernelHeapFree, ebx	
	.endw
	@trace <"FreeMappingObjects exit",13,10>
	ret
	align 4

FreeMappingObjects endp
endif

	end
