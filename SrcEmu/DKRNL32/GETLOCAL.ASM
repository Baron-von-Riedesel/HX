
;--- GetLocaleInfoA()

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

?MAXLCL equ 64	;max size of locale asciiz string (including 0)

CINFO struct
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
CINFO ends

;date format
; 0=MM DD YY
; 1=DD MM YY
; 2=YY MM DD
;currency format
;   bit 2 = set if currency symbol replaces decimal point
;   bit 1 = number of spaces between value and currency symbol
;   bit 0 = 0 if currency symbol precedes value
;           1 if currency symbol follows value
;time format
;bit 0: 0 if 12-hour clock
;       1 if 24-hour clock
;case map routine
;   (FAR CALL, AL = character to map to upper case [>= 80h])

	.DATA

g_dwCountry dd 0
;--- address of g_cinfo must be even, so DX is never -1. See Int 21h, ax=3800h
g_cinfo CINFO <0,'$',',','.','/',':'>
	align 4
bInit	db 0

	.const

localetable label word
	dw LOCALE_ILANGUAGE				;added 12.2020
;LOCALE_SLANGUAGE
;LOCALE_SABBREVLANGNAME
;LOCALE_SNATIVELANGNAME
	dw LOCALE_ICOUNTRY
;LOCALE_SCOUNTRY
;LOCALE_SABBREVCTRYNAME
;LOCALE_SNATIVECTRYNAME
;LOCALE_IDEFAULTLANGUAGE
;LOCALE_IDEFAULTCOUNTRY
	dw LOCALE_IDEFAULTCODEPAGE
;LOCALE_SLIST
;LOCALE_IMEASURE
	dw LOCALE_SDECIMAL
	dw LOCALE_STHOUSAND
;LOCALE_SGROUPING
;LOCALE_IDIGITS
;LOCALE_ILZERO
;LOCALE_SNATIVEDIGITS
	dw LOCALE_SCURRENCY
;LOCALE_SINTLSYMBOL
;LOCALE_SMONDECIMALSEP
;LOCALE_SMONTHOUSANDSEP
;LOCALE_SMONGROUPING
	dw LOCALE_ICURRDIGITS
;LOCALE_IINTLCURRDIGITS
	dw LOCALE_ICURRENCY
;LOCALE_INEGCURR

	dw LOCALE_SDATE		;date separator, max 4
	dw LOCALE_STIME		;time separator, max 4
	dw LOCALE_SSHORTDATE;short date with placeholders
	dw LOCALE_SLONGDATE	;long date with placeholders d,dd,ddd,dddd,M,MM,MMM,MMMM,y,yy,yyy,yyyy,yyyyy
	dw LOCALE_IDATE		;0,1 or 2
	dw LOCALE_ILDATE	;0,1 or 2
	dw LOCALE_ITIME		;0 (AM/PM) or 1 (24-hour)
	dw LOCALE_ICENTURY	;0 (2 digit) or 1 (4 digits)
	dw LOCALE_ITLZERO	;0 or 1 (leading zeros for hours)
	dw LOCALE_IDAYLZERO	;0 or 1 (leading zeros for days)
	dw LOCALE_IMONLZERO	;0 or 1 (leading zeros for months)
;LOCALE_S1159			;string for AM
;LOCALE_S2359			;string for PM
	dw LOCALE_SDAYNAME1
	dw LOCALE_SDAYNAME2
	dw LOCALE_SDAYNAME3
	dw LOCALE_SDAYNAME4
	dw LOCALE_SDAYNAME5
	dw LOCALE_SDAYNAME6
	dw LOCALE_SDAYNAME7
	dw LOCALE_SABBREVDAYNAME1
	dw LOCALE_SABBREVDAYNAME2
	dw LOCALE_SABBREVDAYNAME3
	dw LOCALE_SABBREVDAYNAME4
	dw LOCALE_SABBREVDAYNAME5
	dw LOCALE_SABBREVDAYNAME6
	dw LOCALE_SABBREVDAYNAME7
	dw LOCALE_SMONTHNAME1
	dw LOCALE_SMONTHNAME2
	dw LOCALE_SMONTHNAME3
	dw LOCALE_SMONTHNAME4
	dw LOCALE_SMONTHNAME5
	dw LOCALE_SMONTHNAME6
	dw LOCALE_SMONTHNAME7
	dw LOCALE_SMONTHNAME8
	dw LOCALE_SMONTHNAME9
	dw LOCALE_SMONTHNAME10
	dw LOCALE_SMONTHNAME11
	dw LOCALE_SMONTHNAME12
	dw LOCALE_SABBREVMONTHNAME1
	dw LOCALE_SABBREVMONTHNAME2
	dw LOCALE_SABBREVMONTHNAME3
	dw LOCALE_SABBREVMONTHNAME4
	dw LOCALE_SABBREVMONTHNAME5
	dw LOCALE_SABBREVMONTHNAME6
	dw LOCALE_SABBREVMONTHNAME7
	dw LOCALE_SABBREVMONTHNAME8
	dw LOCALE_SABBREVMONTHNAME9
	dw LOCALE_SABBREVMONTHNAME10
	dw LOCALE_SABBREVMONTHNAME11
	dw LOCALE_SABBREVMONTHNAME12
;LOCALE_SPOSITIVESIGN
;LOCALE_SNEGATIVESIGN
;LOCALE_IPOSSIGNPOSN
;LOCALE_INEGSIGNPOSN
;LOCALE_IPOSSYMPRECEDES
;LOCALE_IPOSSEPBYSPACE
;LOCALE_INEGSYMPRECEDES
;LOCALE_INEGSEPBYSPACE
;LOCALE_IFONTSIGNATURE
;LOCALE_SSIS0639LANGNAME
;LOCALE_SSIS03166CTRYNAME

	dw LOCALE_SENGLANGUAGE			;added 12.2020: english name of language
	dw LOCALE_SENGCOUNTRY			;added 12.2020: english name of country
	dw LOCALE_STIMEFORMAT			;added 12.2020
	dw LOCALE_IDEFAULTANSICODEPAGE
;LOCALE_ITIMEMARKPOSN
;LOCALE_SYEARMONTH
;LOCALE_SENGCURRNAME
;LOCALE_SNATIVECURRNAME
	dw LOCALE_ICALENDARTYPE			;added 12.2020
size_localetable equ ($-localetable)/sizeof word

localefuncs label dword
	dd get_ilanguage
	dd get_icountry
	dd get_idefcp
	dd get_sdecimal
	dd get_sthousand
	dd get_scurrency
	dd get_icurrdigits
	dd get_icurrency

	dd get_sdate
	dd get_stime
	dd get_sshortdate
	dd get_slongdate
	dd get_idate
	dd get_ildate
	dd get_itime
	dd get_icentury
	dd get_itlzero
	dd get_idaylzero
	dd get_imonlzero
;	dd get_s1159
;	dd get_s2359
	dd get_sdaynames
	dd get_sdaynames
	dd get_sdaynames
	dd get_sdaynames
	dd get_sdaynames
	dd get_sdaynames
	dd get_sdaynames
	dd get_sabbrdaynames
	dd get_sabbrdaynames
	dd get_sabbrdaynames
	dd get_sabbrdaynames
	dd get_sabbrdaynames
	dd get_sabbrdaynames
	dd get_sabbrdaynames
	dd get_smonthnames
	dd get_smonthnames
	dd get_smonthnames
	dd get_smonthnames
	dd get_smonthnames
	dd get_smonthnames
	dd get_smonthnames
	dd get_smonthnames
	dd get_smonthnames
	dd get_smonthnames
	dd get_smonthnames
	dd get_smonthnames
	dd get_sabbrmonthnames
	dd get_sabbrmonthnames
	dd get_sabbrmonthnames
	dd get_sabbrmonthnames
	dd get_sabbrmonthnames
	dd get_sabbrmonthnames
	dd get_sabbrmonthnames
	dd get_sabbrmonthnames
	dd get_sabbrmonthnames
	dd get_sabbrmonthnames
	dd get_sabbrmonthnames
	dd get_sabbrmonthnames

	dd get_senglanguage
	dd get_sengcountry
	dd get_stimeformat
	dd get_idefansicp
	dd get_icalendartype

	include locales.inc

	.CODE

	align 4

get_sabbrmonthnames:
	mov esi,offset smonthnames
	sub ebx,LOCALE_SABBREVMONTHNAME1
	mov ecx,3
	jmp daymonthnames
get_smonthnames:
	mov esi,offset smonthnames
	sub ebx,LOCALE_SMONTHNAME1
	mov ecx,20
	jmp daymonthnames
get_sabbrdaynames:
	mov esi,offset sdaynames
	sub ebx,LOCALE_SABBREVDAYNAME1
	mov ecx,3
	jmp daymonthnames
get_sdaynames:
	mov esi,offset sdaynames
	sub ebx,LOCALE_SDAYNAME1
	mov ecx,20
daymonthnames:
	.while ebx
@@:
		lodsb
		and al,al
		jnz @B
		dec ebx
	.endw
@@:
	lodsb
	stosb
	and al,al
	loopnz @B
	.if al
		mov al,0
		stosb
	.endif
	retn
get_senglanguage:
	mov esi,offset senglanguage
	mov ecx,sizeof senglanguage
	rep movsb
	retn
get_sengcountry:
	mov esi,offset sengcountry
	mov ecx,sizeof sengcountry
	rep movsb
	retn
get_stimeformat:
	mov esi,offset stimeformat
	mov ecx,sizeof stimeformat
	rep movsb
	retn
get_slongdate:
get_sshortdate:
	mov esi,offset sshortdate
	mov ecx,sizeof sshortdate
	rep movsb
	retn
get_ilanguage:
	mov eax,ilanguage
	jmp gli_1
get_icalendartype:
	mov eax,icalendartype
	jmp gli_1
get_idefansicp:
	invoke GetACP
gli_1:
	test ebx,LOCALE_RETURN_NUMBER
	jnz return_number
	invoke __dw2aD
	mov al, 0
	stosb
gli_2:
	retn
return_number:
	stosd
	retn
get_idefcp:
	invoke GetOEMCP
	jmp gli_1
get_icountry:
	mov eax, g_dwCountry
	jmp gli_1
get_idate:
get_ildate:
	movzx eax, g_cinfo.date_fmt
	jmp gli_1
get_itime:
	movzx eax, g_cinfo.time_fmt
	jmp gli_1
get_icurrency:
	movzx eax, g_cinfo.curr_fmt
	jmp gli_1
get_icentury:
get_itlzero:
get_idaylzero:
get_imonlzero:
	xor eax,eax
	jmp gli_1
get_sthousand:
	mov ax, word ptr g_cinfo.th_sep
	stosw
	retn
get_sdecimal:
	mov ax, word ptr g_cinfo.dec_sep
	stosw
	retn
get_sdate:
	mov ax, word ptr g_cinfo.date_sep
	stosw
	retn
get_stime:
	mov ax, word ptr g_cinfo.time_sep
	stosw
	retn
get_scurrency:
	mov eax, dword ptr g_cinfo.curr_sym
@@:
	stosb
	and al,al
	jz gli_2
	shr eax,8
	jmp @B
get_icurrdigits:
	movzx eax, g_cinfo.curr_sdig
	jmp gli_1

	align 4

GetLocaleInfoA proc public uses ebx esi edi lcid:dword,
			 lctype:dword, pString:ptr BYTE, cString:dword

ifdef _DEBUG
local tpString:dword
endif
local	szTmp[?MAXLCL]:byte

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

	mov edi,offset localetable
	mov ecx,size_localetable
	mov eax,lctype
	repnz scasw
	jnz failed
;	mov edx, edi
	mov edi, pString
	.if !cString
		lea edi, szTmp
	.endif
ifdef _DEBUG
	mov tpString, edi
	mov byte ptr [edi],0
else
	mov pString, edi
endif

	inc ecx
	sub ecx,size_localetable
	neg ecx

	mov ebx,lctype
	call dword ptr [ecx*4+offset localefuncs]

	mov eax, edi
ifdef _DEBUG
	sub eax, tpString
else
	sub eax, pString
endif
	jmp exit
failed:
	invoke SetLastError, ERROR_INVALID_PARAMETER
	xor eax,eax
exit:
ifdef _DEBUG
	.if eax
		@strace <"GetLocaleInfoA(", lcid, ", ", lctype, ", ", pString, ", ", cString, ")=", eax, "[", &tpString, "]">
	.else
		@strace <"GetLocaleInfoA(", lcid, ", ", lctype, ", ", pString, ", ", cString, ")=", eax>
	.endif
endif
	ret
	align 4

GetLocaleInfoA endp

IsValidLocale proc public lcid:dword, flags:dword

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

