
;--- implements FormatMessageA

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

RT_MESSAGETABLE equ 11

MSGTABENTRY struct
dwFrom	dd ?
dwTo	dd ?
dwOffs	dd ?
MSGTABENTRY ends

	.CODE

if ?FLAT

enumcb2 proc uses esi ebx hModule:DWORD, lpszType:ptr byte, lpszName:ptr byte, wLang:sword, lParam:dword

	invoke FindResourceEx, hModule, lpszType, lpszName, wLang
	.if (eax)
		invoke LoadResource, hModule, eax
		.if (eax)
			mov edx, lParam
			mov edx, [edx+0]
			mov esi, eax
			mov ebx, eax
			lodsd
			mov ecx, eax
			.while (ecx)
				.if ((edx >= [esi].MSGTABENTRY.dwFrom) && (edx <= [esi].MSGTABENTRY.dwTo))
					sub edx, [esi].MSGTABENTRY.dwFrom
					mov esi, [esi].MSGTABENTRY.dwOffs
					add esi, ebx
					xor ecx, ecx
					.while (edx)
						mov cx, [esi]
						add esi, ecx
						dec edx
					.endw
					mov ecx,lParam
					mov [ecx+4],esi
					xor eax,eax
					ret
				.endif
				add esi, sizeof MSGTABENTRY
				dec ecx
			.endw
		.endif
	.endif
	@mov eax,1
	ret
	align 4

enumcb2 endp

enumcb proc hModule:DWORD, lpszType:ptr byte, lpszName:ptr byte, lParam:dword

	invoke EnumResourceLanguages, hModule, lpszType, lpszName, offset enumcb2, lParam
	ret
	align 4

enumcb endp

endif

;--- understands:
;--- %%, %n
;--- %0: stop the scanning without adding a LF
;--- %n[!<format_specifier>!] (n = 1 .. 99), specifier=s|d|u|x

FormatString proc uses ebx esi edi lpOut:ptr byte, lpFormat:ptr byte, pArguments:ptr, bIsWide:dword, nSize:dword, bArgsWide:dword, dwMaxLine:dword

local dwMin:dword
local lastWS:dword
local lastNL:dword

	mov dwMin, 0
	mov lastWS, 0
	mov edi, lpOut
	mov lastNL, edi
	mov esi, lpFormat
	mov ebx,1
	.if (bIsWide)
		inc ebx
	.endif
	mov ecx, nSize
	.while (ecx)
		mov al,[esi]
		add esi,ebx
		.break .if (!al)
		.if (al == '%')
			mov al,[esi]
			add esi,ebx
			.break .if (!al)
			.if (al == '%')
				stosb
				dec ecx
			.elseif ((al == 'n') || (al == 'N'))
				mov al,10
				mov lastNL, edi
				stosb
				dec ecx
			.elseif (al == '0')	;"%0"
				mov al,0
				stosb
				dec ecx
			.elseif ((al > '0') && (al <= '9'))
				sub al,'0'
				mov dl,[esi]
				.if ((dl >= '0') && (dl <= '9'))
					mov ah,10
					mul ah
					sub dl,'0'
					add al,dl
					add esi,ebx
				.endif
				movzx eax,al
				dec eax
				mov edx, pArguments
				mov edx, [edx+4*eax]
				mov al,'s'     ;s is default!
				mov ah,[esi]
				.if (ah == '!')
					add esi,ebx
					mov al,[esi]
					.if (al)
;--- skip a number before 'd', 'u', 's', 'x'
						add esi,ebx
						.while ((al >= '0') && (al <= '9'))
							sub al,'0'
							movzx eax, al
							mov dwMin, eax
							mov al, [esi]
							add esi,ebx
						.endw
						mov ah,[esi]
						.if (ah == '!')
							add esi,ebx
						.endif
					.endif
				.endif
				or al,20h
				.if (al == 's')
				   .while (ecx && (byte ptr [edx]))
						mov al,[edx]
						stosb
						inc edx
						add edx,[bArgsWide]
						dec ecx
				   .endw
				.elseif ((al == 'd') || (al == 'u'))
					mov eax, edx
					push esi
					push ecx
					push edi
					mov esi, dwMin
					call __dw2aDX
					pop edx
					mov eax, edi
					sub eax, edx
					pop ecx
					pop esi
					sub ecx, eax
					jbe done
				.elseif (al == 'x')
					.break .if (ecx < 8)
					mov eax, edx
					push ecx
					call __dw2aX
					pop ecx
					sub ecx,8
				.endif
			.endif
		.elseif ((al == 13) || (al == 10))
			mov lastNL, edi
			.if (dwMaxLine == 0)
				stosb
				dec ecx
			.endif
		.else
			.if ((al == ' ') || (al == 9))
				mov lastWS, edi
			.endif
			stosb
			dec ecx
		.endif
		mov edx, dwMaxLine
		.if (edx && edx != FORMAT_MESSAGE_MAX_WIDTH_MASK)
			mov eax, edi
			sub eax, lastNL
			.if ( eax > edx )
				mov edx,lastWS
				.if (edx && edx > lastNL)
					mov byte ptr [edx],10
					mov lastNL, edx
				.endif
			.endif
		.endif
	.endw
	.if (ecx)
		stosb
	.endif
done:        
	ret
	align 4

FormatString endp

;--- dwFlags:
;--- low byte: maximum width of formatted output line
;--- nSize: MINIMUM number of bytes to allocate if flag "allocate buffer" is 1
;--- pArguments: if FORMAT_MESSAGE_ARGUMENT_ARRAY==1, it's a pointer
;---             to an array of (usually DWORD) values. If 0, it's a
;---             pointer to a va_list structure.

?MAXSIZE equ 2048

_FormatMessage proc public uses esi edi ebx dwFlags:DWORD, lpSource:ptr, dwMessageId:DWORD, dwLanguageId:DWORD, 
				lpBuffer:ptr byte, nSize:DWORD, pArguments:ptr, bIsWide:DWORD 

local	bFSIsWide:dword
local	dwTmp[2]:dword
local	Buffer[?MAXSIZE]:byte

	mov eax, bIsWide
	mov bFSIsWide, eax
	lea edi, [Buffer]
	mov ebx, dwFlags

	.if (ebx & FORMAT_MESSAGE_FROM_STRING)
		mov eax, lpSource
		jmp formstr
if ?FLAT
	.elseif (ebx & FORMAT_MESSAGE_FROM_HMODULE)
		.if (!lpSource)
			invoke GetModuleHandle,NULL
			mov lpSource,eax
		.endif
		mov eax, dwMessageId
		mov dwTmp[0],eax
		mov dwTmp[4],0
		invoke EnumResourceNames, lpSource, RT_MESSAGETABLE, enumcb, addr dwTmp
		mov eax, dwTmp[4]
		.if (!eax)
if 0
;--- this will work only if the kernel source is in a DLL (dkrnl32.dll)
			.if ( ( ebx & FORMAT_MESSAGE_FROM_SYSTEM ) && g_hKernel32 )
				mov eax, g_hKernel32
				mov lpSource, eax
				mov eax, dwMessageId
				mov dwTmp[0],eax
				mov dwTmp[4],0
				invoke EnumResourceNames, lpSource, RT_MESSAGETABLE, enumcb, addr dwTmp
				mov eax, dwTmp[4]
				and eax, eax
				jnz @F
			.endif
endif
			mov eax, dwMessageId
			jmp copyMsgId
		.endif
@@:
		movzx ecx, byte ptr [eax+2]
		mov bFSIsWide,ecx
		lea eax, [eax+4]
endif
formstr:

;--- eax -> string

		.if (ebx & FORMAT_MESSAGE_IGNORE_INSERTS)
			.if (!bFSIsWide)
				invoke lstrcpyn, edi, eax, ?MAXSIZE
			.else
				mov esi, eax
				push edi
				mov ecx, ?MAXSIZE
				jecxz nocopy
@@:
				lodsw
				stosb
				and ax,ax
				loopnz @B
nocopy:
				pop edi
			.endif
		.else
			mov ecx, pArguments
			.if (ecx && !(ebx & FORMAT_MESSAGE_ARGUMENT_ARRAY))
				mov ecx,[ecx]  ;correct?
			.endif
			movzx edx, bl
			invoke FormatString, edi, eax, ecx, bFSIsWide, ?MAXSIZE, bIsWide, edx
		.endif
	.else
copyMsgId:
		invoke lstrcpy, edi, CStr("MsgId: ")
		push edi
		add edi, 7
		mov eax, dwMessageId
		call __dw2aX
		movzx edx, bl
		.if ( edx && edx != FORMAT_MESSAGE_MAX_WIDTH_MASK )
			mov al,10
			stosb
		.endif
		mov al,0
		stosb
		pop edi
	.endif
	invoke lstrlen, edi
	mov esi, edi
	mov edi, lpBuffer
	mov ecx, nSize
	test ebx, FORMAT_MESSAGE_ALLOCATE_BUFFER
	jz @F
	inc eax
	mov ebx, eax
	invoke LocalAlloc, LMEM_FIXED or LMEM_ZEROINIT, eax
	and eax, eax
	jz error
	mov [edi], eax
	mov edi, eax
	mov ecx, ebx
	mov eax, ebx
	dec eax
@@:
	push eax
	invoke lstrcpyn, edi, esi, ecx
	pop eax
error:
	ret
	align 4

_FormatMessage endp

FormatMessageA proc public dwFlags:DWORD , lpSource:ptr, dwMessageId:DWORD , dwLanguageId:DWORD, 
				lpBuffer:ptr byte, nSize:DWORD , pArguments:ptr 

ifdef _DEBUG
	@trace <"FormatMessageA(">
	@tracedw dwFlags
	@trace <", ">
	.if (dwFlags & FORMAT_MESSAGE_FROM_STRING)
		@trace lpSource
	.else
		@tracedw lpSource
	.endif
	@trace <", ">
	@tracedw dwMessageId
	@trace <", ">
	@tracedw dwLanguageId
	@trace <", ">
	@tracedw lpBuffer
	@trace <", ">
	@tracedw nSize
	@trace <", ">
	@tracedw pArguments
	@trace <")",13,10>
endif        
	invoke _FormatMessage, dwFlags, lpSource, dwMessageId, dwLanguageId, lpBuffer, nSize, pArguments, 0
	@strace <"FormatMessageA()=", eax, " [", &lpBuffer, "]">
	ret
	align 4

FormatMessageA endp

	end

