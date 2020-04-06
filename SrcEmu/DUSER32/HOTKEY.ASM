
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

HKITEM	struct
pNext	dd 0
hwnd	dd 0
Id		dd 0
vk		dd 0
mod_	dd 0
HKITEM	ends

		.data

g_pHotKeys dd 0

		.code

;--- returns: eax=hwnd to send WM_HOTKEY msg
;--- edx=wParam
;--- ecx=lParam

_IsHotKey proc public pir:ptr INPUT_RECORD
		mov edx, pir
		movzx eax, [edx].INPUT_RECORD.Event.KeyEvent.wVirtualKeyCode
		mov ecx, [edx].INPUT_RECORD.Event.KeyEvent.dwControlKeyState
		xor edx, edx
		test ecx, LEFT_ALT_PRESSED or RIGHT_ALT_PRESSED
		setnz dh
		or dl,dh
		test ecx, LEFT_CTRL_PRESSED or RIGHT_CTRL_PRESSED
		setnz dh
		shl dh,1
		or dl,dh
		test ecx, SHIFT_PRESSED
		setnz dh
		shl dh,2
		or dl,dh
		movzx edx, dl
		mov ecx, g_pHotKeys
		@strace <"IsHotKey, vk=", eax, " mod=", edx>
		.while (ecx)
			@strace <"compare with vk=", [ecx].HKITEM.vk, " mod=", [ecx].HKITEM.mod_>
			.if ((eax == [ecx].HKITEM.vk) && (edx == [ecx].HKITEM.mod_))
				mov eax, [ecx].HKITEM.hwnd
				mov edx, pir
				.if ([edx].INPUT_RECORD.Event.KeyEvent.bKeyDown)
					xor edx, edx
				.else
					mov edx, [ecx].HKITEM.Id
				.endif
				mov ecx, [ecx].HKITEM.mod_
				ret
			.endif
			mov ecx, [ecx].HKITEM.pNext
		.endw
		xor  eax, eax
		ret
		align 4
_IsHotKey endp

RegisterHotKey proc public hwnd:HWND, id:dword, fsModifiers:dword, vk:dword

		invoke malloc, sizeof HKITEM
		.if (eax)
			mov ecx, hwnd
			mov edx, id
			mov [eax].HKITEM.hwnd, ecx
			mov [eax].HKITEM.Id, edx
			mov ecx, fsModifiers
			mov edx, vk
			mov [eax].HKITEM.mod_, ecx
			mov [eax].HKITEM.vk, edx
			@serialize_enter
			mov ecx, g_pHotKeys
			mov [eax].HKITEM.pNext, ecx
			mov g_pHotKeys, eax
			@serialize_exit
		.endif
		@strace	<"RegisterHotKey(", hwnd, ", ", id, ", ", fsModifiers, ", ", vk, ")=", eax>
		ret
		align 4
        
RegisterHotKey endp

UnregisterHotKey proc public uses ebx esi hwnd:HWND, id:dword

		@serialize_enter
		lea esi, g_pHotKeys
		mov ecx, [esi]
		xor eax, eax
		mov edx, hwnd
		mov ebx, id
		.while (ecx)
			.if ((edx == [ecx].HKITEM.hwnd) && (ebx == [ecx].HKITEM.Id))
				mov edx, [ecx].HKITEM.pNext
				mov [esi].HKITEM.pNext, edx
				invoke free, ecx
				.break
			.endif
			mov esi, ecx
			mov ecx, [ecx].HKITEM.pNext
		.endw
		@serialize_exit
		@strace	<"UnregisterHotKey(", hwnd, ", ", id, ")=", eax>
		ret
		align 4
UnregisterHotKey endp

		end
        
