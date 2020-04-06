
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
		include wingdi.inc
        include macros.inc
        include duser32.inc

if 0
COLOR_SCROLLBAR        = 0
COLOR_BACKGROUND       = 1
COLOR_ACTIVECAPTION    = 2
COLOR_INACTIVECAPTION  = 3
COLOR_MENU             = 4
COLOR_WINDOW           = 5
COLOR_WINDOWFRAME      = 6
COLOR_MENUTEXT         = 7
COLOR_WINDOWTEXT       = 8
COLOR_CAPTIONTEXT      = 9
COLOR_ACTIVEBORDER     = 10
COLOR_INACTIVEBORDER   = 11
COLOR_APPWORKSPACE     = 12
COLOR_HIGHLIGHT        = 13
COLOR_HIGHLIGHTTEXT    = 14
COLOR_BTNFACE          = 15
COLOR_BTNSHADOW        = 16
COLOR_GRAYTEXT         = 17
COLOR_BTNTEXT          = 18
endif

BRCACHEITEM struct
hBrush	dd ?
crColor	dd ?
BRCACHEITEM ends

		.data
        
darkbrush	BRCACHEITEM <0, 0404040h>
ltbrush		BRCACHEITEM <0, 0C0C0C0h>

		.const
        
brushtabptr label dword
		dd offset darkbrush	;0
		dd offset darkbrush	;1
		dd offset darkbrush	;2
		dd offset darkbrush	;3
		dd offset darkbrush	;4
		dd offset ltbrush	;5
		dd offset darkbrush	;6
		dd offset darkbrush	;7
		dd offset darkbrush	;8
		dd offset darkbrush	;9
		dd offset darkbrush	;10
		dd offset ltbrush	;11
		dd offset ltbrush	;12
		dd offset ltbrush	;13
		dd offset ltbrush	;13
		dd offset ltbrush	;14
		dd offset ltbrush	;15
		dd offset ltbrush	;16
		dd offset darkbrush	;17
		dd offset darkbrush	;18
endoftable equ ($ - brushtabptr) / 4
        
		.code

GetSysColorBrush proc public dwIndex:dword

        xor eax, eax
		mov ecx, dwIndex
        .if (ecx < endoftable)
        	mov ecx, [ecx*4 + offset brushtabptr]
        	mov eax, [ecx].BRCACHEITEM.hBrush
            .if (!eax)
            	push ecx
            	invoke CreateSolidBrush, [ecx].BRCACHEITEM.crColor
                pop ecx
                mov [ecx].BRCACHEITEM.hBrush, eax
            .endif
        .endif
exit:        
		@strace	<"GetSysColorBrush(", dwIndex, ")=", eax>
		ret
        align 4
GetSysColorBrush endp

GetSysColor proc public nIndex:dword
		mov ecx, nIndex
        xor eax, eax
        .if (ecx < endoftable)
        	mov ecx, [ecx*4 + offset brushtabptr]
        	mov eax, [ecx].BRCACHEITEM.crColor
        .endif
		@strace	<"GetSysColor(", nIndex, ")=", eax>
		ret
        align 4
GetSysColor endp

SetSysColors proc public x:dword, y:ptr dword, z:ptr COLORREF
		xor eax, eax
		@strace	<"SetSysColors(", x, ")=", eax>
		ret
        align 4
SetSysColors endp

		end
