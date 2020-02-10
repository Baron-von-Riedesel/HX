
;--- table to translate scan codes to vk codes
;--- used by peekcon.asm

;--- VK_DIVIDE (numpad-/) is handled differently on win9x and winxp:
;--- on win9x VK_OEM_MINUS (code BD) is returned
;--- on winxp VK_DIVIDE (code 6F) is returned

;--- all combinations with ALT- are not used since
;--- the ALT key status is suppressed by dkrnl32!
;--- as well, some Ctrl key combinations are not required
;--- because the scancode has been translated back (i.e. Ctrl-Ins/Del)

;--- VK_OEM_1 to VK_OEM_8 vary:
;---
;---            US        |      GER
;--- OEM_X  VSC   ASC     | VSC   ASC
;-------------------------|--------------
;--- 1 BA    27    3B ;   |  1A    81 ue
;--- 2 BF    35    2F /   |  2B    23 #
;--- 3 C0    29    60 `   |  27    94 oe
;--- 4 DB    1A    5B [   |  0C    E1 sz
;--- 5 DC    2B    5C \   |  29    5E ^   (win98 SE gives asc=00)
;--- 6 DD    1B    5D ]   |  0D    27 '   (win98 SE gives asc=00)
;--- 7 DE    28    27 '   |  28    84 ae
;--- 8 DF                 |
;---
;--- VK_OEM_PLUS, _COMMA, _MINUS, _PERIOD:
;-----------------------------------------
;--- + BB    0D    2B +   |  1B    2B +
;--- , BC    33    2C ,   |  33    2C ,
;--- - BD    0C    2D -   |  35    2D -
;--- . BE    34    2E .   |  34    2E .

;--- the index into this table is the scan code!

vktable label byte
	db 0
    db VK_ESCAPE
    db '1234567890'							;02-0B == 1234567890
    db VK_OEM_4, VK_OEM_6					;0C-0D == ·'
    db VK_BACK 								;0E	   == Backspace
    db VK_TAB             					;0F    == tab
    db 0,0,0,0,0,0,0,0,0,0 		 			;10-19 == qwertzuiop
    db VK_OEM_1, VK_OEM_PLUS				;1A-1B == Å+
	db VK_RETURN							;1C    == return
    db VK_CONTROL							;1D    == ctrl left
    db 0,0,0,0,0,0,0,0,0					;1E-26 == asdfghjkl
    db VK_OEM_3,VK_OEM_7,VK_OEM_5			;27-29 == îÑ^
    db VK_SHIFT								;2A    == shift left
    db VK_OEM_2								;2B    == #
    db 0,0,0,0,0,0,0						;2C-32 == yxcvbnm
    db VK_OEM_COMMA							;33    == ,
    db VK_OEM_PERIOD						;34    == .
    db VK_OEM_MINUS							;35    == -        numpad/
    db VK_SHIFT								;36    == shift right
    db VK_MULTIPLY							;37    ==          numpad*
    db VK_MENU, VK_SPACE					;38-39 == Alt (left), space
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
    db VK_INSERT							;52    == Isrt (+ numpad-0)
    db VK_DELETE							;53    == Del (+ numpad-.)
    db 0, 0, 0								;54-56 == F1-F3 + Shift
    db VK_F11, VK_F12						;57-58 == F11-F12       
    db 0, 0									;59-5A
    db VK_LWIN, VK_RWIN, VK_APPS			;5B-5D
if 0    
    db VK_F6, VK_F7, VK_F8, VK_F9, VK_F10	;59-5D == F6-F10 + Shift
    db VK_F1, VK_F2, VK_F3, VK_F4, VK_F5	;5E-62 == F1-F5 + Ctrl
    db VK_F6, VK_F7, VK_F8, VK_F9, VK_F10	;63-67 == F6-F10 + Ctrl
    db VK_F1, VK_F2, VK_F3, VK_F4, VK_F5	;68-6C == F1-F5 + Alt
    db VK_F6, VK_F7, VK_F8, VK_F9, VK_F10	;6D-71 == F6-F10 + Alt
    db 00									;72
    db VK_LEFT, VK_RIGHT, VK_END			;73-75 == xx + Ctrl
    db VK_NEXT, VK_HOME						;76-77 == xx + Ctrl
    db 0,0,0,0,0,0,0,0						;78-7F
    db 0,0,0,0								;80-83
    db VK_PRIOR                     		;84    == PgUp + Ctrl
    db VK_F11, VK_F12						;85-86 == F11/F12
    db VK_F11, VK_F12						;87-88 == F11/F12 + Shift
    db VK_F11, VK_F12						;89-8A == F11/F12 + Ctrl
    db VK_F11, VK_F12						;8B-8C == F11/F12 + Alt
    db VK_UP								;8D    == CsrUp + Ctrl
    db 0									;8E
    db VK_CLEAR								;8F    == numpad5 + Ctrl
    db 0									;90
    db VK_DOWN								;91    == CsrDn + Ctrl
    db VK_INSERT, VK_DELETE					;92-93 == Ins/Del + Ctrl
    db 0, 0, 0, 0							;94-97
    db VK_UP								;98    == CsrUp + Alt
    db 0, 0 								;99-9A
    db VK_LEFT	 							;9B    == CsrLt + Alt 
	db 0									;9C
    db VK_RIGHT								;9D    == CsrRt + Alt 
    db 0, 0									;9E-9F
    db VK_DOWN								;A0    == CsrDn + Alt
endif    
lvksize equ $ - vktable    
