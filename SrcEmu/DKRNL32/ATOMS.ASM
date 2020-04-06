
;--- implements:
;--- [Global]AddAtomA
;--- [Global]DeleteAtomA
;--- [Global]GetAtomNameA
;--- [Global]FindAtomA

	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif

	option proc:private
	option casemap:none

	include winbase.inc
	include wincon.inc
	include dkrnl32.inc
	include macros.inc


LPATOM	typedef ptr CAtom

CAtom	struct
pNext	LPATOM	?
dwValue	DWORD	?
dwRef	DWORD	?
szValue	BYTE 1 dup (?)
CAtom	ends

	.data

pAtoms	dd 0
wValue	dw 0

	.CODE

GlobalAddAtomA proc public lpString:ptr BYTE
GlobalAddAtomA endp

AddAtomA proc public uses esi edi lpString:ptr BYTE

	mov edi,lpString
	cmp edi,10000h
	jb error
	mov esi, pAtoms
	.while (esi)
		invoke lstrcmpi, addr [esi].CAtom.szValue, edi
		.if (!eax)
			inc [esi].CAtom.dwRef
			mov eax, [esi].CAtom.dwValue
			jmp done
		.endif
		mov esi,[esi].CAtom.pNext
	.endw
	invoke lstrlen, edi
	add eax, sizeof CAtom
	invoke KernelHeapAlloc, eax
	and eax,eax
	jz error
	mov esi, eax
	mov [esi].CAtom.dwRef,1
	inc wValue
	movzx ecx, wValue
	or ch,0C0h
	mov [esi].CAtom.dwValue, ecx
	invoke lstrcpy, addr [esi].CAtom.szValue, lpString
	mov ecx,pAtoms
	mov [esi].CAtom.pNext, ecx
	mov pAtoms, esi
	mov eax, [esi].CAtom.dwValue
	jmp done
error:
	xor eax,eax
done:
	@trace <"AddAtomA(">
ifdef _DEBUG
	mov    ecx, lpString
	.if (ecx >= 10000h)
		@trace ecx
	.else
		@tracedw ecx
	.endif
endif
	@strace	<")=", eax>
	ret
	align 4

AddAtomA endp

GlobalDeleteAtom proc public atom:DWORD
GlobalDeleteAtom endp

DeleteAtom proc public atom:DWORD

	mov edx, pAtoms
	lea ecx, pAtoms
	movzx eax, word ptr atom
	.while (edx)
		.if (eax == [edx].CAtom.dwValue)
			dec [edx].CAtom.dwRef
			.if (ZERO?)
				mov eax, [edx].CAtom.pNext
				mov [ecx].CAtom.pNext, eax
				invoke KernelHeapFree, edx
			.endif
			xor eax,eax
			jmp done
		.endif
		mov ecx, edx
		mov edx, [edx].CAtom.pNext
	.endw
done:
	@strace <"DeleteAtom(", atom, ")=", eax>
	ret
	align 4

DeleteAtom endp

GlobalGetAtomNameA proc public atom:DWORD, lpBuffer:ptr byte, nSize:DWORD
GlobalGetAtomNameA endp

GetAtomNameA proc public atom:DWORD, lpBuffer:ptr byte, nSize:DWORD

	mov edx, pAtoms
	movzx eax, word ptr atom
	.while (edx)
		.if (eax == [edx].CAtom.dwValue)
			invoke lstrcpyn, lpBuffer, addr [edx].CAtom.szValue, nSize
			invoke lstrlen, lpBuffer
			jmp done
		.endif
		mov edx,[edx].CAtom.pNext
	.endw
	xor eax,eax
done:
	@strace <"GetAtomNameA(", atom, ", ", lpBuffer, ", ", nSize, ")=", eax>
	ret
	align 4

GetAtomNameA endp

;--- find atom,

GlobalFindAtomA proc public lpString:ptr byte
GlobalFindAtomA endp

FindAtomA proc public uses esi lpString:ptr byte

	mov eax, lpString
	cmp eax, 10000h
	jb error
	mov esi, pAtoms
	.while (esi)
		invoke lstrcmpi, addr [esi].CAtom.szValue, lpString
		.if (!eax)
			mov eax, [esi].CAtom.dwValue
			jmp done
		.endif
		mov esi, [esi].CAtom.pNext
	.endw
error:
	xor eax, eax
done:
	@trace <"FindAtomA(">
ifdef _DEBUG
	mov    ecx,lpString
	.if (ecx >= 10000h)
		@trace ecx
	.else
		@tracedw ecx
	.endif
endif
	@trace <")=">
	@tracedw eax
	@trace <13,10>
	ret
	align 4

FindAtomA endp

end

