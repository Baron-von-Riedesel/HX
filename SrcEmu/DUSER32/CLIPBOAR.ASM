
;--- clipboard implementation
;--- best viewed with tabsize 4

	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:none
	option proc:private

	include winbase.inc
	include winuser.inc
	include duser32.inc
	include macros.inc

HXVDD	equ 1	;1=support Windows clipboard on NT platforms

if HXVDD
	include hxvdd.inc
endif

	.DATA

LISTITEM	struct
pNext		dd ?
dwFormat	dd ?
dwHandle	dd ?
LISTITEM	ends

g_pList	 dd 0
g_hOwner dd 0

if HXVDD
hVdd	dd 0
endif

	.CODE
    
OpenClipboard proc public hWindow:DWORD

	@serialize_enter
	xor eax, eax
	.if (g_hOwner == 0)
		mov edx, hWindow	;fixme: hWindow can be NULL!
		mov g_hOwner, edx
		inc eax
if HXVDD
		invoke HXLoadVDD
		and eax, eax
		jz no_vdd
		mov hVdd, eax
		mov edx, VDD_OPENCLIPBOARD
		call HXDispatch
no_vdd:
		mov eax,1
endif
	.endif
	@serialize_exit
	@strace <"OpenClipboard(", hWindow, ")=", eax>
	ret
	align 4

OpenClipboard endp

CloseClipboard proc public

if HXVDD
	.if ( hVdd )
		mov edx, VDD_CLOSECLIPBOARD
		call HXDispatch
	.endif
endif
	xor eax, eax
	.if (g_hOwner)
		mov g_hOwner, 0
		inc eax
	.endif
	@strace <"CloseClipboard()">
	ret
	align 4

CloseClipboard endp

;--- internal function, ebx = LISTITEM

FreeClipboardHandle proc
	xor ecx, ecx
	xchg ecx, [ebx].LISTITEM.dwHandle
	.if (ecx)
		invoke GlobalFree, ecx
	.endif
	ret
	align 4
FreeClipboardHandle endp

EmptyClipboard proc public uses ebx

if HXVDD
	.if ( hVdd )
		mov edx, VDD_EMPTYCLIPBOARD
		call HXDispatch
	.endif
endif
	mov  ebx, g_pList
	.while (ebx)
		invoke FreeClipboardHandle
		mov ebx, [ebx].LISTITEM.pNext
	.endw
	@mov eax, 1
exit:
	@strace <"EmptyClipboard()=", eax>
	ret
	align 4

EmptyClipboard endp

AddFormat proc uFormat:dword			
	invoke GlobalAlloc, GMEM_FIXED, sizeof LISTITEM
	.if (eax)
		@serialize_enter
		mov ecx, g_pList
		mov g_pList, eax
		mov [eax].LISTITEM.pNext, ecx
		mov ecx, uFormat
		mov [eax].LISTITEM.dwFormat, ecx
		mov [eax].LISTITEM.dwHandle, 0
		@serialize_exit
	.endif
	ret
AddFormat endp

;--- used internally: should return LISTITEM in EDX if eax != 0

IsClipboardFormatAvailable proc public uFormat:dword

if HXVDD
	.if ( hVdd )
		mov edx, VDD_ISCLIPBOARDFORMATAVAILABLE
		mov ecx, uFormat
		call HXDispatch
		and eax, eax
		jnz exit
	.endif
endif
	mov ecx, uFormat
	mov edx, g_pList
	xor eax, eax
	.while (edx)
		.if (ecx == [edx].LISTITEM.dwFormat)
			inc eax
			jmp found
		.endif
		mov edx, [edx].LISTITEM.pNext
	.endw
	.if (ecx < CF_MAX)
		invoke AddFormat, ecx
		mov edx, eax
		.if (eax)
		   @mov eax,1
		.endif
	.endif
found:
exit:
	@strace <"IsClipboardFormatAvailable(", uFormat, ")=", eax>
	ret
	align 4

IsClipboardFormatAvailable endp

GetClipboardData proc public uFormat:DWORD

if HXVDD
	.if ( hVdd )
		mov edx, VDD_GETCLIPBOARDDATA
		mov ecx, uFormat
		call HXDispatch
		and eax, eax
		jnz exit
	.endif
endif
	mov ecx, uFormat
	mov edx, g_pList
	xor eax, eax
	.while (edx)
		.if (ecx == [edx].LISTITEM.dwFormat)
			mov eax, [edx].LISTITEM.dwHandle
			.break
		.endif
		mov edx, [edx].LISTITEM.pNext
	.endw
exit:
	@strace <"GetClipboardData(", uFormat, ")=", eax>
	ret
	align 4

GetClipboardData endp

;--- SetClipboardData returns dwHandle (which might be NULL!)

SetClipboardData proc public uFormat:DWORD, dwHandle:DWORD

if HXVDD
	.if ( hVdd )
		push ebx
		mov edx, VDD_SETCLIPBOARDDATA
		mov ecx, uFormat
		mov ebx, dwHandle
		call HXDispatch
		pop ebx
		jmp exit
	.endif
endif
	invoke IsClipboardFormatAvailable, uFormat
	.if (edx)
		mov eax, dwHandle
		xchg eax, [edx].LISTITEM.dwHandle
		.if (eax)
			invoke GlobalFree, eax
		.endif
		mov eax, dwHandle
	.else
		xor eax, eax
	.endif
exit:
	@strace <"SetClipboardData(", uFormat, ", ", dwHandle, ")=", eax>
	ret
	align 4

SetClipboardData endp

GetOpenClipboardWindow proc public
GetOpenClipboardWindow endp

GetClipboardOwner proc public
	mov eax, g_hOwner
	@strace <"GetClipboardOwner()=", eax>
	ret
	align 4
GetClipboardOwner endp

CountClipboardFormats proc public
	mov edx, g_pList
	xor eax, eax
	.while (edx)
		inc eax
		mov edx, [edx].LISTITEM.pNext
	.endw
	@strace <"CountClipboardFormats()=", eax>
	ret
	align 4
CountClipboardFormats endp

EnumClipboardFormats proc public format:DWORD

if HXVDD
	.if ( hVdd )
		mov edx, VDD_ENUMCLIPBOARDFORMATS
		mov ecx, format
		call HXDispatch
		jmp exit	;either use Windows or HX clipboard, but not both!
	.endif
endif
	mov ecx, format
	xor eax, eax
	mov edx, g_pList
	.while (edx)
		.if (ecx == 0)
			mov eax, [edx].LISTITEM.dwFormat
			.break
		.endif
		.if (ecx == [edx].LISTITEM.dwFormat)
			xor ecx, ecx
		.endif
		mov edx, [edx].LISTITEM.pNext
	.endw
exit:
	@strace <"EnumClipboardFormats(", format, ")=", eax>
	ret
	align 4

EnumClipboardFormats endp

GetClipboardFormatNameA proc public format:DWORD, lpszFormatName:ptr BYTE, cchMax:DWORD
	invoke IsClipboardFormatAvailable, format
	.if (eax)
		invoke GetAtomNameA, format, lpszFormatName, cchMax
	.endif
	@strace <"GetClipboardFormatNameA(", format, ", ", lpszFormatName, ", ", cchMax, ")=", eax>
	ret
	align 4
GetClipboardFormatNameA endp

RegisterClipboardFormatA proc public uses ebx esi lpszFormat:ptr BYTE

	xor esi,esi
	invoke FindAtomA, lpszFormat
	.if (!eax)
		inc esi
		invoke AddAtomA, lpszFormat
	.endif
	.if (eax)
		mov ebx, eax
		invoke IsClipboardFormatAvailable, ebx
		.if (!eax)
			invoke AddFormat, ebx
			.if (eax)
				mov eax, ebx
			.else	;out of memory?
				.if (esi)
					invoke DeleteAtom, ebx
				.endif
				xor eax, eax
			.endif
		.else
			mov eax,ebx
		.endif
	.endif
	@strace <"RegisterClipboardFormatA(", lpszFormat, ")=", eax>
	ret
	align 4
RegisterClipboardFormatA endp

SetClipboardViewer proc public hwndViewer:DWORD
	xor eax, eax
	@strace <"SetClipboardViewer(", hwndViewer, ")=", eax>
	ret
	align 4
SetClipboardViewer endp

ChangeClipboardChain proc public hwndRemove:DWORD, hwndNewNext:DWORD
	xor eax, eax
	@strace <"ChangeClipboardChain(", hwndRemove, ", ", hwndNewNext, ")=", eax>
	ret
	align 4
ChangeClipboardChain endp

GetPriorityClipboardFormat proc public lpdw:ptr DWORD, dw2:DWORD
	xor eax, eax
	@strace <"GetPriorityClipboardFormat(", lpdw, ", ", dw2, ")=", eax>
	ret
	align 4
GetPriorityClipboardFormat endp

	end

