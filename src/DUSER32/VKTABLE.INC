
;--- table to translate scan codes to vk codes
;--- used by keyboard.asm
;--- [GetKeyState()        scans] no longer
;---  MapVirtualKey(xx, 1) direct
;---  MapVirtualKey(xx, 2) scans


;--- the index into this table is the scan code!

;--- it is a table of 2*128 bytes
;--- the first 128 bytes are std scancodes
;--- the second 128 bytes are extended scancodes
;--- best viewed with tabsize 4!

vktable label byte
	db -1
	db VK_ESCAPE
	db '1234567890'							;02-0B == 1234567890
	db VK_OEM_4, VK_OEM_6					;0C-0D == ·'
	db VK_BACK								;0E    == Backspace
	db VK_TAB								;0F    == tab
	db 'QWERTYUIOP'							;10-19 == qwertzuiop
	db VK_OEM_1, VK_OEM_PLUS				;1A-1B == Å+
	db VK_RETURN							;1C    == return
;	db VK_LCONTROL							;1D    == ctrl left
	db VK_CONTROL							;1D    == ctrl left
	db 'ASDFGHJKL'							;1E-26 == asdfghjkl
	db VK_OEM_3,VK_OEM_7,VK_OEM_5			;27-29 == îÑ^
;	db VK_LSHIFT							;2A    == shift left
	db VK_SHIFT								;2A    == shift left
	db VK_OEM_2								;2B    == #
	db 'ZXCVBNM'							;2C-32 == yxcvbnm
	db VK_OEM_COMMA							;33    == ,
	db VK_OEM_PERIOD						;34    == .
	db VK_OEM_MINUS							;35    == -        numpad/
;	db VK_RSHIFT							;36    == shift right
	db VK_SHIFT								;36    == shift right
	db VK_MULTIPLY							;37    ==          numpad*
;	db VK_LMENU								;38    == Alt (left)
	db VK_MENU								;38    == Alt (left)
	db VK_SPACE								;39    == space
	db VK_CAPITAL							;3A    == caps lock
	db VK_F1, VK_F2, VK_F3, VK_F4, VK_F5	;3B-3F
	db VK_F6, VK_F7, VK_F8, VK_F9, VK_F10	;40-44
	db VK_NUMLOCK, VK_SCROLL				;45-46 == num lock, scroll lock
	db VK_HOME								;47    == Pos1  (+ numpad7)
	db VK_UP								;48    == CsrUp (+ numpad8)
	db VK_PRIOR								;49    == PgUp  (+ numpad9)
	db VK_SUBTRACT							;4A    ==          numpad-
	db VK_LEFT								;4B    == CsrLt (+ numpad4) 
	db VK_CLEAR								;4C    ==          numpad5 
	db VK_RIGHT								;4D    == CsrRt (+ numpad6)
	db VK_ADD								;4E    ==          numpad+
	db VK_END								;4F    == End   (+ numpad1)
	db VK_DOWN								;50    == CsrDn (+ numpad2) 
	db VK_NEXT								;51    == PgDn  (+ numpad3)
	db VK_INSERT, VK_DELETE					;52-53
	db 0, 0									;54-55 == F1-F3 + Shift
	db VK_OEM_102							;56 == 
	db VK_F11, VK_F12						;57-58 == F11-F12       
	db 0,0									;59-5A
	db 5Bh,5Ch,5Dh,5Eh,5Fh					;5B-5F
	db 20h dup (0)							;60-7F

vktableEx label byte
	db 1Ch dup (0)
	db VK_RETURN							;1C == return numpad
	db VK_RCONTROL							;1D == ctrl right
	db 1Ah dup (0)
	db VK_RMENU								;38h == Alt right
	db 14 dup (0)
	db VK_HOME								;47h   == Pos1  (+ numpad7)
	db VK_UP								;48    == CsrUp (+ numpad8)
	db VK_PRIOR								;49    == PgUp  (+ numpad9)
	db 0
	db VK_LEFT								;4B    == CsrLt (+ numpad4) 
	db 0
	db VK_RIGHT								;4D    == CsrRt (+ numpad6)
	db 0
	db VK_END								;4F    == End   (+ numpad1)
	db VK_DOWN								;50    == CsrDn (+ numpad2) 
	db VK_NEXT								;51    == PgDn  (+ numpad3)
	db VK_INSERT, VK_DELETE					;52-53
	db 0, 0, 0								;54-56 == F1-F3 + Shift
	db 0, 0									;57-58
	db 27h dup (0)							;59-7F
