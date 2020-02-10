
	.386
if ?FLAT
	.model flat, stdcall
else
	.model small, stdcall
endif
	option casemap:none
	option proc:private
	option dotname

?EARLYTZGET	equ 1	;get time zone info from TZ very early because
					;some programs set TZ to NULL and I have no clue why!

	include winbase.inc
	include macros.inc

if ?EARLYTZGET
.BASE$IA SEGMENT dword public 'DATA'
		DD offset tzset
.BASE$IA ENDS
endif

	.code

;--- get an integer from [edx] into eax

getint proc uses ecx
	mov cl,2
	mov al,0
	.while (cl)
		mov ch,[edi]
		.break .if ((ch < '0') || (ch > '9'))
		sub ch,'0'
		mov ah,10
		mul ah
		add al,ch
		inc edi
		dec cl
	.endw
	movzx eax,al
	ret
	align 4
getint endp

tzset proc public

local	szTZBuff[16]:byte

	.data
 
g_timediff	dq 0			;difference in 100 ns
g_tdmin		dd 0			;difference in minutes
g_szTZ		db 4 dup (0)	;time zone name
g_szDLS		db 4 dup (0)	;daylight saving name
bTZisSet	db FALSE        

	.code

	.if (!bTZisSet)
		pushad
		xor esi, esi
		invoke GetEnvironmentVariableA, CStr("TZ"), addr szTZBuff, sizeof szTZBuff
		.if (eax)
			mov eax,dword ptr szTZBuff
			and eax,0FFFFFFh
			mov dword ptr g_szTZ, eax
			mov bh,0
			lea edi,szTZBuff+3
			mov cl,[edi]
			.if (cl == '-')
				dec bh
				inc edi
			.elseif (cl == '+')
				inc edi
			.endif
			call getint
			mov ecx,60
			mul ecx 	   ;hours -> minutes
			mov g_tdmin,eax
			mul ecx		;minutes -> seconds
			mov esi,eax
			.if (byte ptr [edi] == ':')
				inc edi
				call getint
				mul ecx
				add esi, eax
				.if (byte ptr [edi] == ':')
					inc edi
					call getint
					add esi, eax
				.endif
			.endif
			.if (bh == -1)
				neg esi
				neg g_tdmin
			.endif
			.if (byte ptr [edi])
				mov eax, [edi]
				and eax, 0FFFFFFh
				mov dword ptr g_szDLS, eax
			.endif
		.endif
		mov eax, esi
		mov ecx, 1000*1000*10	;1 s == 1000 * 1000 * 10 (100 ns units)
		imul ecx
		mov dword ptr g_timediff+0, eax
		mov dword ptr g_timediff+4, edx
		mov bTZisSet, TRUE
		popad
	.endif
	ret
	align 4
tzset endp


localtosystem proc public
if ?FLAT
	call tzset
	add eax, dword ptr g_timediff+0
	adc edx, dword ptr g_timediff+4
endif
	ret
	align 4
localtosystem endp

systemtolocal proc public
if ?FLAT
	call tzset
	sub eax, dword ptr g_timediff+0
	sbb edx, dword ptr g_timediff+4
endif
	ret
	align 4
systemtolocal endp


setdatename proc uses ecx
	xor ecx, ecx
	mov [edx+0],ecx
	mov [edx+4],ecx
	mov cl,3
	.repeat
		mov [edx],al
		inc edx
		inc edx
		shr eax,8
		dec cl
	.until (!cl)
	ret
	align 4
setdatename endp

GetTimeZoneInformation proc public pTime:dword

	invoke RtlZeroMemory, pTime, sizeof TIME_ZONE_INFORMATION
	invoke tzset
	mov ecx, pTime
	mov eax, g_tdmin
	mov [ecx].TIME_ZONE_INFORMATION.Bias,eax
	mov eax, dword ptr g_szTZ
	lea edx, [ecx].TIME_ZONE_INFORMATION.StandardName
	call setdatename
	mov eax, dword ptr g_szDLS
	lea edx, [ecx].TIME_ZONE_INFORMATION.DaylightName
	call setdatename
	mov [ecx].TIME_ZONE_INFORMATION.DaylightBias,-60

	.if (g_szTZ)
		@mov eax,TIME_ZONE_ID_STANDARD
	.else
		@mov eax,TIME_ZONE_ID_UNKNOWN
	.endif
	@strace <"GetTimeZoneInformation(", pTime, ")=", eax>
	ret
	align 4

GetTimeZoneInformation endp

	end
