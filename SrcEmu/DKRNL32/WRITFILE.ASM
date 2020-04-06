
	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option proc:private
	option casemap:none

	include winbase.inc
	include winioctl.inc
	include wincon.inc
	include macros.inc
	include dkrnl32.inc

	.CODE

if ?CLEARHIGHEBP
simint21 proto 	;emulate int 21h for 32bit clients
endif

SetLastError proto stdcall :dword

WriteFile proc public uses ebx esi edi handle:dword, pBuffer:dword,
		numBytes:dword, lpWritten:ptr dword, lpOverlapped:ptr OVERLAPPED

	mov eax, lpWritten
	mov dword ptr [eax],0
	mov ebx, handle
	cmp ebx, 010000h
	ja isspecial
	call dowrite
exit:
ifdef _DEBUG
	mov edx, lpWritten
	mov edx, [edx]
	@strace <"WriteFile(", handle, ", ", pBuffer, ", ", numBytes, ", ", lpWritten, ", ", lpOverlapped, ")=", eax, " - bytes written=", edx>
endif
	ret

isspecial:
	push offset exit
	.if (ebx == -1)
	.elseif ([ebx].SYNCOBJECT.dwType == SYNCTYPE_PIPE)
		mov ebx, [ebx].PIPE.dwfh
		jmp  dowrite
	.elseif ([ebx].SYNCOBJECT.dwType == SYNCTYPE_FILE)
		.if ([ebx].FILE.flags & (FF_DISK or FF_DRIVE or FF_DEVICE))
			invoke [ebx].FILE.pHandler, handle, FILE_WRITE_ACCESS, pBuffer, numBytes,\
				0, 0, lpWritten, lpOverlapped
			retn
		.endif
	.endif
	mov ax,6	;error "invalid handle"
	jmp error

dowrite:
	mov edx,pBuffer
	mov ecx,numBytes
	bt g_bIsConsole, ebx
	jnc @F
	invoke _WriteConsole, ebx, edx, ecx, lpWritten
	retn
@@:
if ?NONULLHDL
	bt word ptr g_bProcessed,bx
else
	bt g_bProcessed,ebx
endif
	jnc rawmode
processedmode:
	mov esi, edx
	.while (ecx)
		push ecx
		lodsb
		cmp al,10
		jnz @F
		mov al,13
		call write1char
		mov al,10
@@:
		call write1char
		pop ecx
		jc error
		dec ecx
	.endw
	mov eax, esi
	sub eax,pBuffer
	jmp writedone
rawmode:
	mov esi, lpOverlapped
	.if (esi)
		push ecx
		push edx
		invoke SetFilePointerEx, ebx, qword ptr [esi].OVERLAPPED.Offset_, NULL, FILE_BEGIN
		pop edx
		pop ecx
	.endif
	mov ah,40h
if ?CLEARHIGHEBP
	call simint21
else
	int 21h
endif
	jc error
sigexit:
	.if (esi)
		push eax
		mov [esi].OVERLAPPED.InternalHigh, eax
		invoke SetEvent, [esi].OVERLAPPED.hEvent
		pop eax
	.endif
writedone:
	mov ecx, lpWritten
	mov [ecx], eax
done:
	mov eax,1
	retn
error:
	movzx eax,ax
	invoke SetLastError,eax
	xor eax,eax
	retn
	align 4
write1char:
	push eax
	mov edx,esp
	@mov ecx,1
	mov ah,40h
if ?CLEARHIGHEBP
	call simint21
else
	int 21h
endif
	pop edx
	retn
	align 4

WriteFile endp

	END
