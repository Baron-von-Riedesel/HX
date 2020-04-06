
	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option proc:private
	option casemap:none

	include winbase.inc
	include winnls.inc
	include winerror.inc
	include dkrnl32.inc
	include macros.inc

CINFO	struct
date_fmt	dw ?			;+0  date format
curr_sym	db 5 dup (?)	;+2  ASCIZ currency symbol string
th_sep		db 2 dup (?)	;+7  ASCIZ thousands separator
dec_sep		db 2 dup (?)	;+9  ASCIZ decimal separator
date_sep	db 2 dup (?)	;+11 ASCIZ date separator
time_sep	db 2 dup (?)	;+13 ASCIZ time separator
curr_fmt	db ?			;+15 currency format
curr_sdig	db ?			;+16 number of digits after decimal in currency
time_fmt	db ?			;+17 time format
dwCMProc	dd ?			;+18 address of case map routine
data_sep	db 2 dup (?)	;+22 ASCIZ data-list separator
rsvd		db 10 dup (?)	;+24 reserved
CINFO	ends

;date format
; 0=MM DD YY
; 1=DD MM YY
; 2=YY MM DD
;currency format
;	bit 2 = set if currency symbol replaces decimal point
;	bit 1 = number of spaces between value and currency symbol
;	bit 0 = 0 if currency symbol precedes value
;			1 if currency symbol follows value
;time format
;bit 0:	0 if 12-hour clock
;		1 if 24-hour clock
;case map routine
;	(FAR CALL, AL = character to map to upper case [>= 80h])

	.DATA

g_dwCountry dd 0
g_cinfo CINFO <0,'$',',','.','/',':'>
	align 4
bInit	db 0

	.CODE

GetLocaleInfoA proc public uses ebx edi lcid:dword,
			 lctype:dword, pString:ptr BYTE, cString:dword

local	szTmp[64]:byte

	@noints
	.if (!bInit)
		mov bInit, 1
		mov ax,3800h	;get current country info
		mov edx, offset g_cinfo
		int 21h
		movzx ebx,bx
		mov [g_dwCountry],ebx
	.endif
	@restoreints

	mov edi,offset jmptable
	mov ecx,sizejmptable/4
	mov eax, lctype
	repnz scasd
	jnz failed
	mov edx, edi
	mov edi, pString
	.if (!cString)
		lea edi, szTmp
		mov pString, edi
	.endif
	call dword ptr [edx+sizejmptable-4]
	jmp exit
failed:
	invoke SetLastError, ERROR_INVALID_PARAMETER
	xor eax,eax
exit:
	@strace <"GetLocaleInfoA(", lcid, ", ", lctype, ", ", pString, ", ", cString, ")=", eax>
	ret

	align 4

jmptable label dword
	dd LOCALE_IDEFAULTANSICODEPAGE
	dd LOCALE_IDEFAULTCODEPAGE
	dd LOCALE_ICOUNTRY
	dd LOCALE_IDATE
	dd LOCALE_ILDATE
	dd LOCALE_ITIME
	dd LOCALE_ICURRENCY
	dd LOCALE_STHOUSAND
	dd LOCALE_SDECIMAL
	dd LOCALE_SDATE
	dd LOCALE_SSHORTDATE
	dd LOCALE_STIME
	dd LOCALE_SCURRENCY
	dd LOCALE_ICURRDIGITS
sizejmptable equ $-jmptable
	dd getidefansicp
	dd getidefcp
	dd geticountry
	dd getidate
	dd getildate
	dd getitime
	dd geticurrency
	dd getsthousand
	dd getsdecimal
	dd getsdate
	dd getsshortdate
	dd getstime
	dd getscurrency
	dd geticurrdigits

getidefansicp:
	invoke GetACP
gli_1:
	invoke __dw2aD
	mov al, 0
	stosb
gli_2:
	mov eax, edi
	sub eax, pString
	retn
getidefcp:
	invoke GetOEMCP
	jmp gli_1
geticountry:
	mov eax, g_dwCountry
	jmp gli_1
getidate:
getildate:
	movzx eax, g_cinfo.date_fmt
	jmp gli_1
getitime:
	movzx eax, g_cinfo.time_fmt
	jmp gli_1
geticurrency:
	movzx eax, g_cinfo.curr_fmt
	jmp gli_1
getsthousand:
	mov ax, word ptr g_cinfo.th_sep
	stosw
	jmp gli_2
getsdecimal:
	mov ax, word ptr g_cinfo.dec_sep
	stosw
	jmp gli_2
getsshortdate:
getsdate:
	mov ax, word ptr g_cinfo.date_sep
	stosw
	jmp gli_2
getstime:
	mov ax, word ptr g_cinfo.time_sep
	stosw
	jmp gli_2
getscurrency:
	mov eax, dword ptr g_cinfo.curr_sym
@@:
	stosb
	and al,al
	jz gli_2
	shr eax,8
	jmp @B
geticurrdigits:
	movzx eax, g_cinfo.curr_sdig
	jmp gli_1

	align 4

GetLocaleInfoA endp

IsValidLocale proc public uses edi lcid:dword, flags:dword

	mov eax, 1		;do accept any locale
	@strace <"IsValidLocale(", lcid, ", ", flags, ")=", eax, " *** unsupp ***">
	ret
	align 4
IsValidLocale endp


EnumSystemLocalesA proc public pBuffer:dword, flags:dword
	xor eax,eax
	@strace <"EnumSystemLocalesA(", pBuffer, ", ", flags, ")=", eax, " *** unsupp ***">
	ret
	align 4
EnumSystemLocalesA endp

end

