
;--- the RTC timer code is divided in 2 parts
;--- that's just to avoid the linker to include all the
;--- timer code if it is not used 

	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option proc:private
	option casemap:none

	include winbase.inc
	include dkrnl32.inc
	include macros.inc

	.DATA

	public g_OldIrq08

g_OldIrq08	df 0
g_bMask		db 0	;mask (port 0A1h)
g_bStatRTC	db 0	;value of CMOS RAM 0Bh (status RTC)
g_dwRTCTicks dd 0

	.CODE

;--- the timer may have been deactivated when another program
;--- has been executed. reactivate it

_SetRTCTimer proc public

	.if (word ptr g_OldIrq08+4)
		@noints
		in al,0A1h
		mov g_bMask, al
		and al,not 1		;enable RTC interrupts
		out 0A1h, al

		in al, 21h
		and al, not 4		;enable slave PIC interrupts
		out 021h, al

		mov al,0Ch
		out 70h, al			;read RTC status register C
		xchg ebx, ebx		;just to ensure there is no int ack outstanding
		in al, 71h

		mov al,0Bh
		out 70h, al			;read RTC status register B
		xchg ebx, ebx
		in al, 71h
		mov g_bStatRTC,al
		or al,40h			;enable periodic interrupts
		out 71h, al

		mov dword ptr @flat:[049Ch],-1	;deactivate int 15h, ah=86
		@restoreints
	.endif
	ret
	align 4

_SetRTCTimer endp

;--- restore previous values of RTC timer

_RestoreRTCTimer proc public

	.if (word ptr g_OldIrq08+4)
		@noints
		mov al,0Bh
		out 70h, al
		mov al,g_bStatRTC		;restore RTC status register B
		out 71h, al
		in al,0A1h
		mov ah, g_bMask
		and ah, 1
		and al, not 1
		or al, ah
		out 0A1h, al			;restore PIC value for RTC interrupts
		@restoreints
	.endif
	ret
	align 4
_RestoreRTCTimer endp

	end

