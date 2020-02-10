
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

?DOSWAIT	equ 0	;std=1, 1=wait in DOS (prevents thread switches!)

	.DATA

cntChars db 0

	.DATA?

buffer	db 256 dup (?)

	.CODE

if ?CLEARHIGHEBP	;for 16bit clients
simint21 proto
endif

SetLastError proto stdcall :dword

ReadFile proc public uses ebx esi edi handle:dword, pBuffer:dword,
		numBytes:dword, lpRead:ptr dword, lpOverlapped:ptr OVERLAPPED

local	ir:INPUT_RECORD

		@strace <"ReadFile(", handle, ", ", pBuffer, ", ", numBytes, ", ", lpRead, ", ", lpOverlapped, ") enter">
		mov eax,lpRead
		mov dword ptr [eax],0
		mov ebx,handle
		mov esi, lpOverlapped
if ?NONULLHDL
  ifdef _DEBUG
		and ebx, ebx
		jnz @F
		@strace <"ReadFile called with invalid handle 0">
		int 3
		mov ax,2
		jmp error
@@:
  endif
endif
		cmp ebx, 10000h
		ja isspecial
doread:
		mov edi,pBuffer
		mov ecx,numBytes
		.if (bx == 0000h)
			push ecx
			mov dl,0
			mov ax,4400h
			int 21h
			pop ecx
			test dl,80h
			jz isfile
if ?DOSWAIT
			test g_consoleflags, ENABLE_LINE_INPUT
			jz issingleinput
			mov edx,edi
			mov ah,3fh
if ?CLEARHIGHEBP
			call simint21
else
			int 21h
endif
			jc error
			push eax
			invoke FlushConsoleInputBuffer, handle
			pop eax
			jmp readdone
issingleinput:
endif
			call readconline
			jmp readdone
		.endif
isfile:
		.if (esi)
			push ecx
			invoke SetFilePointerEx, ebx, qword ptr [esi].OVERLAPPED.Offset_, NULL, FILE_BEGIN
			pop ecx
		.endif
		mov edx,edi
		mov ah,3fh
if ?CLEARHIGHEBP
		call simint21
else
		int 21h
endif
		jc error
		.if (esi)
			push eax
			mov [esi].OVERLAPPED.InternalHigh, eax
			invoke SetEvent, [esi].OVERLAPPED.hEvent
			pop eax
		.endif
readdone:
		mov ecx,lpRead
		mov [ecx],eax
done:
		mov eax,1
exit:
ifdef _DEBUG
		mov edx, lpRead
		mov edx, [edx]
		mov ecx, lpOverlapped
		jecxz @F
		mov ecx, dword ptr [ecx].OVERLAPPED.Offset_
@@:
endif
		@strace <"ReadFile(", handle, ", ", pBuffer, ", ", numBytes, ", ", lpRead, ", ", lpOverlapped, ")=", eax, " - bytes read=", edx, " ovofs=", ecx>
		ret
error:
		movzx eax,ax
		invoke SetLastError,eax
		xor eax, eax
		jmp exit
echochar:
		.if (g_consoleflags & ENABLE_ECHO_INPUT)
			push eax
			mov dl,al
			mov ah,2
			int 21h
			.if (al == 13)
				mov dl,10
				mov ah,2
				int 21h
			.endif
			pop eax
		.endif
		retn
		align 4

;--- special file handles
;--- ebx=handle
;--- esi=overlapped

isspecial:
		.if (ebx == -1)
		.elseif ([ebx].SYNCOBJECT.dwType == SYNCTYPE_PIPE)
			.while (1)
				push ebx
				mov ebx,[ebx].PIPE.dwfh
				xor edx,edx
				xor ecx,ecx
				mov ax,4201h			;get current file pos
				int 21h
				pop ebx
				jc error
				push dx
				push ax
				pop eax
				.break .if (eax != [ebx].PIPE.dwPos)
				invoke Sleep, 0
			.endw
			push esi
			xor esi, esi
			push eax
			call EnterSerialization
			invoke SetFilePointer, [ebx].PIPE.dwfh, [ebx].PIPE.dwPos, 0, 0
			push ebx
			mov	ebx,[ebx].PIPE.dwfh
			mov edx,pBuffer
			mov ecx,numBytes
			mov ah,3Fh
			int 21h
			pop	ebx
			.if (!CARRY?)
				add [ebx].PIPE.dwPos, eax
				mov esi, eax
			.endif
			pop eax
			invoke SetFilePointer, [ebx].PIPE.dwfh, eax, 0, 0
			call LeaveSerialization
			mov eax, esi
			pop esi
			jmp readdone
		.elseif ([ebx].SYNCOBJECT.dwType == SYNCTYPE_FILE)
			.if ([ebx].FILE.flags & (FF_DISK or FF_DRIVE or FF_DEVICE))
				invoke [ebx].FILE.pHandler, handle, FILE_READ_ACCESS, 0, 0,\
					pBuffer, numBytes, lpRead, esi
				jmp exit
			.endif
		.endif
		mov ax,6	;error "invalid handle"
		jmp error
		align 4

readconline:
		test g_consoleflags, ENABLE_LINE_INPUT
		jz @F
		mov edi, offset buffer
		mov ecx, 256
@@:
		mov esi, ecx
		mov eax, INFINITE
		.while (esi)
			.if (cntChars)
				mov al,[edi]
				dec cntChars
			.else
				invoke WaitForSingleObject, ebx, eax
				.if (!(g_consoleflags & ENABLE_LINE_INPUT))
					.break .if (eax != WAIT_OBJECT_0)
				.endif
@@:
				push 0
				invoke ReadConsoleInput, ebx, addr ir, 1, esp
				pop eax
				cmp ir.EventType, KEY_EVENT
				jnz @B
				cmp ir.Event.KeyEvent.bKeyDown, 0
				jz @B
				mov ax,ir.Event.KeyEvent.AsciiChar
				cmp al, 0
				jz @B
				.if (g_consoleflags & ENABLE_LINE_INPUT)
					.if ((al == 08) || (al == 7Fh))
						.if (esi < 256)
							inc esi
							dec edi
							call echochar
							mov al,' '
							call echochar
							mov al,8
							call echochar
						.endif
						jmp processed
					.endif
				.endif
				call echochar
			.endif
			stosb
			dec esi
			.if ((al == 13) && esi)
				mov al,10
				stosb
				dec esi
			.endif
processed:
			.if (g_consoleflags & ENABLE_LINE_INPUT)
				.if ((al == 13) || (al == 10))
					mov cntChars,0
					.break
				.endif
				mov eax, INFINITE
			.else
				mov eax, 0
			.endif
		.endw
		.if (g_consoleflags & ENABLE_LINE_INPUT)
			mov eax, edi
			mov esi, offset buffer
			sub eax, esi		;current bytes in buffer
			mov edi, pBuffer
			mov ecx, numBytes
			cmp eax, ecx
			jnc @F
			mov ecx, eax		;get the lower value in ecx
@@:
			sub eax, ecx
			rep movsb
			push edi
			mov edi, offset buffer
			mov ecx, eax
			mov cntChars, cl
			rep movsb
			pop edi
		.endif
		mov eax, edi
		sub eax, pBuffer
		mov ecx, numBytes
		cmp eax, ecx
		jbe @F
		mov eax, ecx
@@:
		retn
		align 4

ReadFile endp


	END
