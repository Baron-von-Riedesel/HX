
	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:none
	option proc:private

	include winbase.inc
	include dpmi.inc
	include winerror.inc
	include macros.inc

	.DATA

g_dwLCID	dd 409h
g_wCountry	dw -1

	.const

lcidtab label dword
	dw 2, 0C0Ch	;french-canadian
	dw 3, 40Ah	;latin-america
	dw 7, 419h	;Russia
	dw 31,413h	;Netherlands
	dw 32,813h	;Belgium
	dw 33,40Ch	;France
	dw 34,40Ah	;Spain
	dw 39,410h	;Italy / San Marino / Vatican City
	dw 41,807h	;Switzerland
	dw 42,405h	;Tjekia / Slovakia
	dw 45,406h	;Denmark
	dw 46,41Dh	;Sweden
	dw 47,414h	;Norway
	dw 48,415h	;Poland
	dw 49,407h	;Germany
	dw -1

	.CODE

country2lcid proc uses esi

	mov cx, g_wCountry
	mov esi, offset lcidtab
@@:
	lodsd
	cmp ax,cx
	jz found
	cmp ax,-1
	jnz @B
	ret
found:
	shr eax, 16
	mov g_dwLCID, eax
	ret

country2lcid endp

GetCountryInfo proc uses ebx edi

local	dossel:dword
local	dosaddr:dword
local	rmcs:RMCS

	cmp g_wCountry, -1
	jnz exit
	mov bx,2h
	mov ax,0100h
	int 31h
	jc exit
	mov dossel,edx
	mov rmcs.rDS,ax
	movzx eax,ax
	shl eax, 4
	mov dosaddr, eax
	xor ecx,ecx
	mov rmcs.rDX,cx
	mov rmcs.rSSSP,ecx
	mov rmcs.rFlags,cx
	mov rmcs.rAX,3800h	;get country info
	mov bx,0021h
	mov ax,0300h
	lea edi, rmcs
	int 31h
	jc @F
	test byte ptr rmcs.rFlags,1
	jnz @F
	mov ax, rmcs.rBX
	mov g_wCountry, ax
	call country2lcid
@@:
	mov edx,dossel
	mov ax,0101h
	int 31h
exit:
	ret
	align 4

GetCountryInfo endp

GetUserDefaultLCID proc public

	call GetCountryInfo
	mov eax, g_dwLCID
	@strace <"GetUserDefaultLCID()=",eax>
	ret
	align 4

GetUserDefaultLCID endp

GetSystemDefaultLCID proc public

	call GetCountryInfo
	mov eax, g_dwLCID
	@strace <"GetSystemDefaultLCID()=",eax>
	ret
	align 4

GetSystemDefaultLCID endp

;--- following functions return a LANGID
;--- which is the LoWord() of a LCID

GetUserDefaultLangID proc public

	invoke GetUserDefaultLCID
	movzx eax,ax
	@strace <"GetUserDefaultLangID()=",eax>
	ret
	align 4

GetUserDefaultLangID endp

GetSystemDefaultLangID proc public

	invoke GetSystemDefaultLCID
	movzx eax,ax
	@strace <"GetSystemDefaultLangID()=",eax>
	ret
	align 4

GetSystemDefaultLangID endp

GetUserDefaultUILanguage proc public

	invoke GetUserDefaultLangID
	@strace <"GetUserDefaultUILanguage()=",eax>
	ret
	align 4

GetUserDefaultUILanguage endp

GetSystemDefaultUILanguage proc public

	invoke GetSystemDefaultLangID
	@strace <"GetSystemDefaultUILanguage()=",eax>
	ret
	align 4

GetSystemDefaultUILanguage endp

GetThreadLocale proc public

	invoke GetSystemDefaultLCID
	@strace <"GetThreadLocale()=", eax>
	ret
	align 4

GetThreadLocale endp

EnumCalendarInfoA proc public pEnumProc:ptr, lcid:DWORD, caid:DWORD, catype:DWORD

	@traceX <"EnumCalendarInfoA() *** unsupp ***",13,10>
	xor eax, eax
	ret
	align 4

EnumCalendarInfoA endp

	end
