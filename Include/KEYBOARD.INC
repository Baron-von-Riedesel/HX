
;*** keyboard scan & make codes ***

__ESC_MAKE         = 01h
;--- 1234567890á' -> 02,03,04,05,06,07,08,09,0A,0B,0C,0D
__BACKSPACE        = 0Eh
__TAB_MAKE         = 0Fh
;--- QWERTZUIOP+ -> 10,11,12,13,14,15,16,17,18,19,1A,1B
__RETURN_MAKE      = 1Ch
__CNTL_LEFT_MAKE   = 1Dh
__CNTL_RIGHT_MAKE  = 1Dh    ;exactly: E0 1D
;--- ASDFGHJKL™Ž  -> 1E,1F,20,21,22,23,24,25,26,27,28
;--- ^ -> 29
__SHIFT_LEFT_MAKE  = 2Ah
;--- # -> 2B
;--- YXCVBNM,.- -> 2C,2D,2E,2F,30,31,32,33,34,35
__SHIFT_RIGHT_MAKE = 36h
;--- ??? -> 37h
__ALT_LEFT_MAKE    = 38h
__ALT_RIGHT_MAKE   = 38h    ;exactly: E0 38
__SPACE_MAKE       = 39h
__CAPSLOCK_SCAN    = 3Ah

__F1_MAKE        = 3bh
__F2_MAKE        = 3ch
__F3_MAKE        = 3dh
__F4_MAKE        = 3eh
__F5_MAKE        = 3fh
__F6_MAKE        = 40h
__F7_MAKE        = 41h
__F8_MAKE        = 42h
__F9_MAKE        = 43h
__F10_MAKE       = 44h

__NUMLOCK_SCAN   = 45h
__SCROLL_SCAN    = 46h

__HOME_MAKE      = 47h
__CURSOR_UP      = 48h
__PAGE_UP        = 49h
__CURSOR_LEFT    = 4Bh
__NUMPAD5_MAKE   = 4Ch
__CURSOR_RIGHT   = 4Dh
__END_MAKE       = 4Fh
__CURSOR_DOWN    = 50h
__PAGE_DOWN      = 51h
__INS_MAKE       = 52h
__DEL_MAKE       = 53h

__GREYMINUS      = 4Ah
__GREYPLUS       = 4Eh
__GREYMULTIPLY   = 37h
;__GREYDIVIDE     = 35h		;numpad/ returns scan code 0E0!!!
;							;that's the same as numpad-Enter
__CTRL_GREYMINUS = 8Eh
__CTRL_GREYPLUS  = 90h
__CTRL_GREYMULTIPLY = 96h
__CTRL_GREYDIVIDE = 95h

__GREYRETURN     = 0E0h		;ctrl-__GREYRETURN gives same scan code
							;but ascii code 0A instead of 0D!

__F1_SHIFT      = 54h
__F2_SHIFT      = 55h
__F3_SHIFT      = 56h
__F4_SHIFT      = 57h
__F5_SHIFT      = 58h
__F6_SHIFT      = 59h
__F7_SHIFT      = 5ah
__F8_SHIFT      = 5bh
__F9_SHIFT      = 5ch
__F10_SHIFT     = 5dh

__F1_CTRL       = 5eh
__F2_CTRL       = 5fh
__F3_CTRL       = 60h
__F4_CTRL       = 61h
__F5_CTRL       = 62h
__F6_CTRL       = 63h
__F7_CTRL       = 64h
__F8_CTRL       = 65h
__F9_CTRL       = 66h
__F10_CTRL      = 67h

__F1_ALT        = 68h
__F2_ALT        = 69h
__F3_ALT        = 6ah
__F4_ALT        = 6bh
__F5_ALT        = 6ch
__F6_ALT        = 6dh
__F7_ALT        = 6eh
__F8_ALT        = 6fh
__F9_ALT        = 70h
__F10_ALT       = 71h

__ALT_1			= 78h
__ALT_2			= 79h

__F11_MAKE       = 57h        ;f11-f12 make codes (int 09) differ from scan codes (int 16)
__F12_MAKE       = 58h

__F11_SCAN       = 85h
__F12_SCAN       = 86h
__F11_SHIFT      = 87h
__F12_SHIFT      = 88h
__F11_CTRL       = 89h
__F12_CTRL       = 8Ah
__F11_ALT        = 8Bh
__F12_ALT        = 8Ch

__CTRL_TAB_MAKE		= 94h

__CTRL_CURSOR_LEFT  = 73h
__CTRL_CURSOR_RIGHT = 74h
__CTRL_END_MAKE     = 75h
__CTRL_PAGE_DOWN    = 76h
__CTRL_HOME_MAKE    = 77h
__CTRL_PAGE_UP      = 84h
__CTRL_CURSOR_UP    = 8Dh
__CTRL_NUMPAD5_MAKE = 8Fh
__CTRL_CURSOR_DOWN  = 91h
__CTRL_INS_MAKE     = 92h
__CTRL_DEL_MAKE     = 93h

__ALT_CURSOR_UP    = 98h
__ALT_CURSOR_LEFT  = 9bh
__ALT_CURSOR_RIGHT = 9dh
__ALT_CURSOR_DOWN  = 0A0h

__CTRL_A = 01h
__CTRL_B = 02h
__CTRL_C = 03h
__CTRL_D = 04h
__CTRL_E = 05h
__CTRL_F = 06h
__CTRL_G = 07h
__CTRL_H = 08h
__CTRL_I = 09h
__CTRL_J = 0Ah
__CTRL_K = 0Bh
__CTRL_L = 0Ch
__CTRL_M = 0Dh
__CTRL_N = 0Eh
__CTRL_O = 0Fh
__CTRL_P = 10h
__CTRL_Q = 11h
__CTRL_R = 12h
__CTRL_S = 13h
__CTRL_T = 14h
__CTRL_U = 15h
__CTRL_V = 16h
__CTRL_W = 17h
__CTRL_X = 18h
__CTRL_Y = 19h
__CTRL_Z = 1Ah

__ALT_X  = 2D00h         ;

