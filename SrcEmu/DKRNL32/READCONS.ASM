
	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:none

	include winbase.inc
	include wincon.inc
	include macros.inc
	include dkrnl32.inc

extern __DEFCTRLHANDLER:ABS

	.DATA

;lastkey  dd 0

	.CODE

ReadConsoleA proc uses ebx edi handle:dword,pChar:ptr byte,maxRead:dword,pRead:ptr dword,res:dword

		xor eax,eax
		mov ecx,maxRead
		mov ebx,handle
		mov edx,pChar
		and ecx,ecx
		jz done
if ?NONULLHDL
		bt word ptr g_bProcessed, bx
else
		bt g_bProcessed, ebx
endif
		jnc rawmode
		mov ah,3Fh
		int 21h
		jnc done
		invoke SetLastError, eax
		xor eax, eax
		jmp exit
rawmode:
		mov edi,edx
rc_1:
		push ecx
		xor al,al
if 0
		mov ah,10h
		int 16h
else
  if 1
		sub esp,sizeof INPUT_RECORD
@@:
		mov edx,esp
		push 0
		invoke ReadConsoleInputA, handle, edx, 1, esp
		pop eax
		and eax,eax
		jz @B
		cmp [esp].INPUT_RECORD.EventType, KEY_EVENT	;skip other events
		jnz @B
		cmp [esp].INPUT_RECORD.Event.KeyEvent.bKeyDown,0
		jz @B
		mov al,byte ptr [esp].INPUT_RECORD.Event.KeyEvent.AsciiChar
		add esp,sizeof INPUT_RECORD
  else
@@:
		mov ah,11h
		int 16h
		jnz @F
		invoke Sleep,0
		jmp @B
@@:
		mov ah,10h
		int 16h
  endif
endif
		pop ecx
		cmp al,00
		jz rc_1
		cmp al,0E0h
		jz rc_1
		stosb
		test g_consoleflags, ENABLE_ECHO_INPUT
		jz @F
		push eax
		push ebx
		push ecx
		int 29h
		pop ecx
		pop ebx
		pop eax
@@:
		test g_consoleflags, ENABLE_LINE_INPUT
		jz @F
		cmp al,13
		loopnz rc_1
@@:
		mov eax,edi
		sub eax, pChar
done:
		mov ecx,pRead
		mov [ecx],eax
		@mov eax,1
exit:
		@strace <"ReadConsoleA(", handle, ", ", pChar, ", ", maxRead, ", ", pRead, ", ", res, ")=", eax>
		ret
		align 4
ReadConsoleA endp

	end
