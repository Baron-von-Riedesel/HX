
;--- convert ANSI to WIDE strings
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
		include macros.inc
		include duser32.inc

		.code

;--- ConvertWStr modifies ESP!!!
;--- It can only be used by PROCs without USES phrase!
;--- argument: wide string ptr in EAX

ConvertWStr proc public
		and eax, eax
		jz exit
		push eax
		invoke lstrlenW, eax
		add eax,3+1
		and al,0FCh
		pop ecx
		pop edx
		sub esp,eax
		mov eax,esp
		push edx
		push esi
		push edi
		mov edi, eax
		mov edx, eax
		mov esi, ecx
@@:
		lodsw
		stosb
		and ax,ax
		jnz @B
		mov eax, edx
		pop edi
		pop esi
exit:
		ret
		align 4
ConvertWStr endp

;-- function to convert an AString back to a WString
;-- the destination pointer may be NULL!
;-- max size in cchMax

ConvertAStrN proc public uses esi edi eax pszAStr:ptr byte, pszWStr:ptr word, cchMax:dword
		mov esi, pszAStr
		mov edi, pszWStr
		and edi, edi
		jz	exit
		mov ecx, cchMax
		xor eax,eax
		jecxz exit
nextchar:
		lodsb
		stosw
		and al,al
		loopnz nextchar
exit:
		ret
		align 4
ConvertAStrN endp

		end
