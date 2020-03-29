
;--- functions included:

;--- RegisterClassA
;--- RegisterClassExA
;--- UnregisterClassA
;--- GetClassLongA
;--- SetClassLongA
;--- GetClassInfoA
;--- GetClassInfoExA
;--- GetClassNameA

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
		include wincon.inc
		include macros.inc
		include duser32.inc

WC_DIALOG	equ 8002h

		.DATA

LLENTRY	struct
pNext	dd ?
LLENTRY	ends

g_pWndClasses LLENTRY <NULL>;start of linked list of registered window classes
g_bInit		db 0

		.CODE

freeallclasses proc
		mov edx, g_pWndClasses
		.while (edx)
			push [edx].LLENTRY.pNext
			invoke free, edx
			pop edx
		.endw
		ret
		align 4
freeallclasses endp

InitDC proto

RegisterClassA proc public uses ebx esi edi pWndClass:ptr WNDCLASS

local	aClass:dword

		.if (!g_bInit)
			mov g_bInit, TRUE
			invoke atexit, offset freeallclasses
		.endif
		mov ebx, pWndClass
		invoke FindAtomA, [ebx].WNDCLASS.lpszClassName
		.if (!eax)
			invoke AddAtomA, [ebx].WNDCLASS.lpszClassName
		.endif
		.if (eax)
			mov aClass, eax
			lea edi, g_pWndClasses
			mov esi, [edi].LLENTRY.pNext
			.while (esi)
				.if ([esi+sizeof LLENTRY].WNDCLASSEX.lpszClassName == eax)
					jmp @exit
				.endif
				mov edi, esi
				mov esi,[esi].LLENTRY.pNext
			.endw
			mov eax, sizeof WNDCLASSEX + sizeof LLENTRY
			add eax, [ebx].WNDCLASS.cbClsExtra
			invoke malloc2, eax
			.if (eax)
				mov [edi].LLENTRY.pNext, eax
				mov esi, eax
				mov [esi].LLENTRY.pNext, 0
				add esi, sizeof LLENTRY + 4		;skip the cbSize field
				invoke RtlMoveMemory, esi, ebx, sizeof WNDCLASS
				mov ecx, [esi].WNDCLASS.hbrBackground
				.if ((ecx > 0) && (ecx < 22))
					dec ecx
					invoke GetSysColorBrush, ecx
					mov [esi].WNDCLASS.hbrBackground, eax
				.endif
				mov eax, aClass
				mov [esi].WNDCLASS.lpszClassName, eax
			.endif
		.endif
@exit:
		@strace	<"RegisterClassA(", pWndClass, ")=", eax>
ifdef _DEBUG
		mov edx, pWndClass
		@strace <"[csr=", [edx].WNDCLASS.hCursor, ", brush=", [edx].WNDCLASS.hbrBackground, "]"> 
endif
		ret
		align 4

RegisterClassA endp

RegisterClassExA proc public uses ebx esi edi pWndClass:ptr WNDCLASSEX

local	aClass:dword

		mov ebx, pWndClass
		invoke FindAtomA, [ebx].WNDCLASSEX.lpszClassName
		.if (!eax)
			invoke AddAtomA, [ebx].WNDCLASSEX.lpszClassName
		.endif
		.if (eax)
			mov aClass, eax
			lea edi, g_pWndClasses
			mov esi, [edi].LLENTRY.pNext
			.while (esi)
				.if ([esi+sizeof LLENTRY].WNDCLASSEX.lpszClassName == eax)
					jmp @exit
				.endif
				mov edi, esi
				mov esi,[esi].LLENTRY.pNext
			.endw
			mov eax, sizeof WNDCLASSEX + sizeof LLENTRY
			add eax, [ebx].WNDCLASSEX.cbClsExtra
			invoke malloc2, eax
			.if (eax)
				mov [edi].LLENTRY.pNext, eax
				mov esi, eax
				mov [esi].LLENTRY.pNext, 0
				add esi, sizeof LLENTRY
				invoke RtlMoveMemory, esi, ebx, sizeof WNDCLASSEX
				mov ecx, [esi].WNDCLASSEX.hbrBackground
				.if ((ecx > 0) && (ecx < 22))
					dec ecx
					invoke GetSysColorBrush, ecx
					mov [esi].WNDCLASSEX.hbrBackground, eax
				.endif
				mov eax, aClass
				mov [esi].WNDCLASSEX.lpszClassName, eax
			.endif
		.endif
@exit:
		@strace	<"RegisterClassExA(", pWndClass, ")=", eax>
ifdef _DEBUG
		mov edx, pWndClass
		@strace <"[csr=", [edx].WNDCLASSEX.hCursor, ", brush=", [edx].WNDCLASSEX.hbrBackground, "]"> 
endif
		ret
		align 4

RegisterClassExA endp

;--- returns pointer to WNDCLASSEX in EAX or NULL

_FindClass	proc public aAtom:DWORD

		lea ecx, g_pWndClasses
		mov edx, [ecx].LLENTRY.pNext
		mov eax, aAtom
		.while (edx)
			.if ([edx+sizeof LLENTRY].WNDCLASSEX.lpszClassName == eax)
				lea eax, [edx + sizeof LLENTRY]
				ret
			.endif
			mov ecx, edx
			mov edx, [edx].LLENTRY.pNext
		.endw
		xor eax, eax
		ret
		align 4
_FindClass	endp

UnregisterClassA proc public lpClassName:ptr BYTE, hInstance: dword

		invoke FindAtomA, lpClassName
		.if (eax)
			invoke _FindClass, eax
			.if (eax)
				mov eax,[edx].LLENTRY.pNext
				mov [ecx].LLENTRY.pNext, eax
				invoke free, edx
			.endif
		.endif
		@strace	<"UnregisterClassA(", &lpClassName, ")=", eax>
		ret
		align 4
        
UnregisterClassA endp

getclsofs proc
		.if (ecx == GCL_HBRBACKGROUND)
			lea eax, [edx].WNDCLASSEX.hbrBackground
		.elseif (ecx == GCL_HCURSOR)
			lea eax, [edx].WNDCLASSEX.hCursor
;		.elseif (ecx == GCL_HMODULE)
;			lea eax, [edx].WNDCLASSEX.hModule
		.elseif (ecx == GCL_CBWNDEXTRA)
			lea eax, [edx].WNDCLASSEX.cbWndExtra
		.elseif (ecx == GCL_CBCLSEXTRA)
			lea eax, [edx].WNDCLASSEX.cbClsExtra
		.elseif (ecx == GCL_WNDPROC)
			lea eax, [edx].WNDCLASSEX.lpfnWndProc
		.elseif (ecx == GCL_STYLE)
			lea eax, [edx].WNDCLASSEX.style
		.else
			xor eax, eax
		.endif
		ret
		align 4
getclsofs endp

GetClassLongA proc public hWnd:DWORD, nIndex:DWORD

		mov ecx, hWnd
		mov eax, [ecx].WNDOBJ.pWndClass
		.if (eax)
			mov edx, eax
			mov ecx, nIndex
			.if (sdword ptr ecx < 0)
				call getclsofs
				.if (eax)
					mov eax, [eax]
				.endif
			.else
				mov eax, [edx+ecx+sizeof WNDCLASSEX]
			.endif
		.endif
		@strace	<"GetClassLongA(", hWnd, ", ", nIndex, ")=", eax>
		ret
		align 4
GetClassLongA endp

SetClassLongA proc public hWnd:DWORD, nIndex:DWORD, newValue: dword

		mov ecx, hWnd
		mov eax, [ecx].WNDOBJ.pWndClass
		.if (eax)
			mov edx, eax
			mov ecx, nIndex
			.if (sdword ptr ecx < 0)
				call getclsofs
				.if (eax)
					mov ecx, eax
					mov eax, newValue
					xchg eax, [ecx]
				.endif
			.else
				mov eax, newValue
				xchg eax, [edx+ecx+sizeof WNDCLASSEX]
			.endif
		.endif
		@strace	<"SetClassLongA(", hWnd, ", ", nIndex, ", ", newValue, ")=", eax>
		ret
		align 4

SetClassLongA endp

GetClassInfoA proc public hInstance:DWORD, lpClassName:ptr BYTE, lpWndClass:ptr WNDCLASS

		mov eax, lpClassName
		test eax, 0FFFF0000h
		jnz isptr
		invoke FindAtomA, eax
isptr:	   
		.if (eax)
			invoke _FindClass, eax
			.if (eax)
				pushad
				mov edi, lpWndClass
				mov esi, eax
				mov ecx, sizeof WNDCLASS/4
				rep movsd
				popad
			.endif
		.else
			.if (lpClassName == WC_DIALOG)
;--- an application might expect this call to succeed in any case.
;--- so clear the structure to be safe
				invoke RtlZeroMemory, lpWndClass, sizeof WNDCLASS
				xor eax, eax
			.endif
		.endif
		@strace	<"GetClassInfoA(", hInstance, ", ", lpClassName, ", ", lpWndClass, ")=", eax>
		ret
		align 4
GetClassInfoA endp

GetClassInfoExA proc public hInstance:DWORD, lpszClass:ptr BYTE, lpwcx:ptr WNDCLASSEX

;--- the WNDCLASSEX structure contains a cbSize member at offset 0

		mov eax,lpwcx
		lea eax,[EAX].WNDCLASSEX.style
		invoke GetClassInfoA, hInstance, lpszClass, eax
		.if (eax)
			mov edx,lpwcx
			mov ecx,[eax].WNDCLASSEX.hIconSM
			mov [edx].WNDCLASSEX.hIconSM,ecx
		.endif
		@strace	<"GetClassInfoExA(", hInstance, ", ", lpszClass, ", ", lpwcx, ")=", eax>
		ret
		align 4
        
GetClassInfoExA endp

GetClassNameA proc public hwnd:DWORD, lpBuffer:ptr BYTE, nMaxBuffer:dword

		mov ecx, hwnd
		mov eax, [ecx].WNDOBJ.pWndClass
		invoke lstrcpyn, lpBuffer, [eax].WNDCLASSEX.lpszClassName, nMaxBuffer
		invoke lstrlen, lpBuffer
		@strace	<"GetClassNameA(", hwnd, ", ", lpBuffer, ", ", nMaxBuffer, ")=", eax>
		ret
		align 4
GetClassNameA endp

		end

