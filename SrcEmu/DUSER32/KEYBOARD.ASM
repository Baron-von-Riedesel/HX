
;--- keyboard functions:
;--- GetKeyState
;--- GetAsyncKeyState
;--- GetKeyboardType
;--- ToAscii
;--- ToAsciiEx
;--- ToUnicode
;--- GetKeyboardState
;--- SetKeyboardState
;--- MapVirtualKeyA
;--- MapVirtualKeyExA
;--- VkKeyScanExA
;--- VkKeyScanA
;--- OemKeyScan
;--- GetKeyboardLayout
;--- LoadKeyboardLayoutA
;--- GetKeyboardLayoutNameA
;--- GetKeyboardLayoutList
;--- GetKeyNameTextA



	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:none
	option proc:private

	include winbase.inc
;	include winuser.inc
	include macros.inc
	include vk.inc

wsprintfA proto C :dword, :dword, :VARARG

	.DATA

	public g_keypress
	public g_keytoggle

g_keypress	dd 8 dup (0)	;key press state (256 bits)
							;will be bit 30 of lParam of WM_KEYDOWN
g_keytoggle	dd 8 dup (0)	;key toggle state (256 bits

;---------------0----5----0----5----0----5----0
g_vkflags	dd 11000011111111110000000000000000b
			dd 00000000000001111111000001111111b
			dd 00000000000000000000000000000000b

	.CODE

_GetKeyTable proto        

	include vktable.inc

;--- return value is SHORT!
;--- values returned are:
;--- bit  0: key toggled
;--- bit 15: key pressed

GetKeyState proc public uses edi vkey:dword

if 0
	mov eax,vkey
	mov edi, offset keys1
	mov ecx, 4
	repnz scasb
	jnz other_key
	add cl,4				;3->7, 2->6, 1->5, 0->4
	mov ax,@flat:[417h]
	shr al,cl				;insert is 80h in AL (toggle)
	and al,1
	shr ah,cl
	shl ah,7
	or al,ah
	movsx eax,al
	jmp exit
other_key:
	invoke _GetKeyTable
	mov edx, eax
	mov edi, offset keys2
	mov ecx, 3
	mov eax,vkey
	.while (ecx)
		cmp al,[edi]
		jz found
		add edi, 3
		dec ecx
	.endw
	mov eax, vkey
	mov ecx, 256
	mov edi, offset vktable
	repnz scasb
	jnz @F
	dec edi
	sub edi, offset vktable
	bt [edx], edi
	jmp setbit
@@:
	xor eax, eax
	jmp exit
found:
	mov al,[edi+1]
	bt [edx], eax
	jc setbit
	mov al,[edi+2]
	bt [edx], eax
setbit:
	setc al
	shl al,7
	movsx eax,al
endif
	movzx ecx, byte ptr vkey
	bt g_keypress, ecx
	setc al
	bt g_keytoggle, ecx
	setc ah
	shl al,7
	or al,ah
	movsx ax,al
	movzx eax,ax
exit:
	@strace <"GetKeyState(", vkey, ")=", eax>
	ret
	align 4

GetKeyState endp

;--- currently just call the sync version

GetAsyncKeyState proc public vkey:dword

	invoke GetKeyState,vkey
	@strace <"GetAsyncKeyState(", vkey, ")=", eax>
	ret
	align 4

GetAsyncKeyState endp

;--- the key state table contains a byte for each virtual key code
;--- but the key bitfields we get from the dkrnl32 keyboard driver
;--- is scan-code oriented.
;--- that's why a helper table (vktable) is needed for fast
;--- translation sc -> vkc

GetKeyboardState proc public uses edi pKeyState:ptr

	mov edi, pKeyState
	xor ecx, ecx
	.while (ch == 0)
		bt g_keytoggle, ecx
		setc al
		bt g_keypress, ecx
		setc ah
;		shl ah,6
		shl ah,7
		or al,ah
		mov [edi+ecx],al
		inc ecx
	.endw
if 0
	mov al,80h
	mov ah,0
	.if ([edi+VK_RMENU] & al)
		mov  [edi+VK_MENU],al
;		mov  [edi+VK_CONTROL],al	;VK_RMENU is translated to CTRL+ALT
		mov [edi+VK_RMENU],ah
	.endif
	.if ([edi+VK_LMENU] & al)
		mov  [edi+VK_MENU],al
		mov [edi+VK_LMENU],ah
	.endif
	.if (([edi+VK_LSHIFT] & al) || ([edi+VK_RSHIFT] & al))
		mov [edi+VK_SHIFT],al
		mov [edi+VK_LSHIFT],ah
		mov [edi+VK_RSHIFT],ah
	.endif
	.if (([edi+VK_LCONTROL] & al) || ([edi+VK_RCONTROL] & al))
		or [edi+VK_CONTROL],al
		mov [edi+VK_LCONTROL],ah
		mov [edi+VK_RCONTROL],ah
	.endif
endif
	@mov eax, 1
	@strace <"GetKeyboardState(", pKeyState, ")=", eax>
	ret
	align 4

GetKeyboardState endp

;--- set toggle and press bits of all keys

SetKeyboardState proc public pKeyState:ptr

	mov edx, pKeyState
	xor ecx, ecx
	.while (ch == 0)
		mov al,[edx+ecx]
		.if (al & 1)
			bts g_keytoggle, ecx
		.else
			btr g_keytoggle, ecx
		.endif
		.if (al & 80h)
			bts g_keypress, ecx
		.else
			btr g_keypress, ecx
		.endif
		inc ecx
	.endw
	@mov eax, 1
	@strace <"SetKeyboardState(", pKeyState, ")=", eax>
	ret
	align 4

SetKeyboardState endp

GetKeyboardType proc public nTypeFlag:dword

	mov ecx, nTypeFlag
	.if (ecx == 0)
		mov eax, 4
	.elseif (ecx == 1)
		mov eax, 1
	.else
		mov eax, 12
	.endif
	@strace <"GetKeyboardType(", nTypeFlag, ")=", eax>
	ret
	align 4

GetKeyboardType endp

;--- the 256-byte KeyState array isn't used currently!
;--- once it is used TranslateMessage has to be changed accordingly!
;--- usually uScanCode is HIWORD(lParam) of a WM_KEYDOWN/WM_KEYUP message

ToAscii proc public uses ebx edi uVirtKey:dword, uScanCode:dword, lpKeyState:ptr, lpChar:ptr word, uFlags:dword

	invoke _GetKeyTable
	mov ebx, eax		;keystate bits
	mov edi, edx		;ascii table
;	mov edx, lpKeyState
	mov ecx, uScanCode
	and ecx, 7Fh
	movzx eax,byte ptr [edi+ecx]
	mov edx, lpChar
	mov [edx],ax
ifdef _DEBUG
	mov edx, eax
endif
	and al,al
	setnz al
	@strace <"ToAscii(", uVirtKey, ", ", uScanCode, ", ", lpKeyState, ", ", lpChar, ", ", uFlags, ")=", eax, " ", edx>
	ret
	align 4

ToAscii endp

ToAsciiEx proc public uVirtKey:dword, uScanCode:dword, lpKeyState:ptr, lpChar:ptr word, uFlags:dword, dwhkl:dword

	invoke ToAscii, uVirtKey, uScanCode, lpKeyState, lpChar, uFlags
	@strace <"ToAsciiEx(", uVirtKey, ", ", uScanCode, ", ", lpKeyState, ", ", lpChar, ", ", uFlags, ", ", dwhkl, ")=", eax>
	ret
	align 4

ToAsciiEx endp

;--- the 256-byte KeyState array isn't used currently!
;--- once it is used TranslateMessage has to be changed accordingly!

ToUnicode proc public uses ebx edi uVirtKey:dword, uScanCode:dword, lpKeyState:ptr, lpChar:ptr word, cchBuff:dword, uFlags:dword

	invoke _GetKeyTable
	mov ebx, eax		;keystate bits
	mov edi, edx		;ascii table
;	mov edx, lpKeyState
	mov ecx, uScanCode
	and cl,7Fh
	movzx eax,byte ptr [edi+ecx]
	mov edx, lpChar
	mov [edx],ax
ifdef _DEBUG
	mov edx, eax
endif
	and al,al
	setnz al
	@strace <"ToUnicode(", uVirtKey, ", ", uScanCode, ", ", lpKeyState, ", ", lpChar, ", ", cchBuff, ", ", uFlags, ")=", eax, " ", edx>
	ret
	align 4

ToUnicode endp

;--- single key translation:
;--- type 0: uCode = virtual key code, out = scan code
;--- type 1: uCode = scan code, out = virtual key code
;--- type 2: uCode = virtual key code, out = ascii code

MapVirtualKeyA proc public uses edi uCode:DWORD, uMapType:DWORD

	xor eax, eax
	mov ecx, uMapType
	.if (ecx == 0)
;--- uCode is a virtual key code, out is scan code
		mov eax, uCode
		mov ecx, 256
		mov edi, offset vktable
		repnz scasb
		jnz error
		dec edi
		sub edi, offset vktable
		mov eax, edi
	.elseif (ecx == 1)
;--- uCode is a scan code to be translated into a virtual key code
		invoke _GetKeyTable
		xor eax, eax
		mov ecx, uCode
		cmp ecx, 60h
		jnc exit
		bt [g_vkflags],ecx
		jnc @F
		mov al,[ecx + edx]
		and al,al
		jz @F
		.if ((al >= 'a') && (al <= 'z'))
			sub al,20h
		.endif
		jmp exit
@@:
		mov al, byte ptr [ecx + vktable]
	.elseif (ecx == 2)
;--- uCode is a virtual key code, out is ascii
		mov eax, uCode
		.if ((eax >= '0') && (eax <= '9'))
			;
		.elseif ((eax >= 'A') && (eax <= 'Z'))
			;
		.else
			mov ecx, 60h
			mov edi, offset vktable
			repnz scasb
			.if (ZERO?)
				invoke _GetKeyTable
				lea eax, [edi-1]
				sub eax, offset vktable
				movzx eax, byte ptr [eax+edx]
			.else
				xor eax, eax
			.endif
		.endif
	.endif
exit:
	@strace <"MapVirtualKeyA(", uCode, ", ", uMapType, ")=", eax>
	ret
error:
	xor eax,eax
	jmp exit
	align 4

MapVirtualKeyA endp

MapVirtualKeyExA proc public uCode:DWORD, uMapType:DWORD, dwhkl:DWORD

	invoke MapVirtualKeyA, uCode, uMapType
	@strace <"MapVirtualKeyAEx(", uCode, ", ", uMapType, ", ", dwhkl, ")=", eax>
	ret
	align 4

MapVirtualKeyExA endp

;--- translate a character to a VK key code (low byte) and the high byte
;--- gets: 01=shift, 02=ctrl, 04=alt

VkKeyScanExA proc public ch_:dword, dwhkl:dword

	movzx eax, byte ptr ch_
	@strace <"VkKeyScanExA(", ch_, ", ", dwhkl, ")=", eax>
	ret
	align 4

VkKeyScanExA endp

;--- returns a WORD value:
;--- low byte: VK code
;--- high byte: shift state

VkKeyScanA proc public ch_:dword

	movzx eax, byte ptr ch_
	@strace <"VkKeyScanA(", ch_, ")=", eax>
	ret
	align 4

VkKeyScanA endp

;--- returns a DWORD value:
;--- low word: OEM scan code
;--- high word: shift state

OemKeyScan proc public wOemChar:word

	movzx eax, wOemChar
	invoke MapVirtualKeyA, eax, 0
	.if ( !eax )	;no translation?
		dec eax		;then return -1!
	.endif
	@strace <"OemKeyScanA(", wOemChar, ")=", eax>
	ret
	align 4

OemKeyScan endp

GetKeyboardLayout proc public idThread:DWORD

	invoke GetUserDefaultLCID
	push ax
	push ax
	pop eax
	@strace <"GetKeyboardLayout(", idThread, ")=", eax>
	ret
	align 4

GetKeyboardLayout endp

;--- if nBuff==0, return the needed size to hold the array

GetKeyboardLayoutList proc public uses edi nBuff:dword, lpList:ptr HKL

	.if (nBuff == 0)
		@mov eax,1
	.else
		invoke GetUserDefaultLCID
		mov edi, lpList
		stosw
		stosw
		@mov eax,1
	.endif
	@strace <"GetKeyboardLayoutList(", nBuff, ", ", lpList, ")=", eax>
	ret
	align 4

GetKeyboardLayoutList endp

LoadKeyboardLayoutA proc public pwszKLID:ptr BYTE, Flags:DWORD

	invoke GetUserDefaultLCID
	push ax
	push ax
	pop eax
	@strace <"LoadKeyboardLayoutA(", pwszKLID, ", ", Flags, ")=", eax>
	ret
	align 4

LoadKeyboardLayoutA endp

GetKeyboardLayoutNameA proc public pwszKLID:ptr BYTE

	invoke GetUserDefaultLCID
	invoke wsprintfA, pwszKLID,CStr("0x%X"), eax
	@strace <"GetKeyboardLayoutNameA(", pwszKLID, ")=", eax>
	ret
	align 4

GetKeyboardLayoutNameA endp

GetKeyNameTextA proc public lParam:dword, lpString:ptr BYTE, nSize:dword

	xor eax, eax
	@strace <"GetKeyNameTextA(", lParam, ", ", lpString, ", ", nSize, ")=", eax, " *** unsupp ***">
	ret
	align 4

GetKeyNameTextA endp

	end

