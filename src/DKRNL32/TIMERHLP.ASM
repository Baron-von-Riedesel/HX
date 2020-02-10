
	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:none
	option proc:private
	option dotname

	include winbase.inc
	include dkrnl32.inc
	include macros.inc

?RTCRES	equ 1	;use RTC timer for ms resolution on winNT/win9x?/DosEmu?

?INIT	equ 1

if ?INIT
.BASE$IA SEGMENT dword public 'DATA'
	DD offset Init
.BASE$IA ENDS
endif

	.data

g_dwGetTimerValue dd offset _GetTimerValue		  
g_dwGetTimerValuems dd offset _GetTimerValuems
if ?INIT
g_bInit	db 0
endif

	.code

;--- port 0043h
;--- bit 6-7: 11 = read back counter
;--- bit 4-5: 00 = read counter status (1 byte), then value (2 byte)
;--- bit 1-3: 001 = select counter 0
;--- bit 0: reserved

;--- the value returned is EDX (timer ticks) + AX (timer counter)
;--- in 1/1.193.180 sec units

_GetTimerValue proc
tryagain:
	@noints
	mov edx,@flat:[046ch] 
	mov al,0C2h		;read timer 0 status + value low/high
	out 43h, al
	xchg edx, edx
	in al,40h
	mov cl,al		;CL = status
	xchg edx, edx
	in al,40h
	mov ah, al		;AH = value low
	xchg edx, edx
	in al,40h		;AL = value high
	@restoreints
	test cl,40h		;was latch valid?
	jnz tryagain
	cmp edx,@flat:[046ch]	;did an interrupt occur in the meantime?
	jnz tryagain			;then do it again!
	xchg al,ah

;--- usually (counter mode 3) the timer is set to count down *twice*! 
;--- however, sometimes counter mode 2 is set!

	mov ch,cl
	and ch,0110B	;bit 1+2 relevant
	cmp ch,0110B	;counter mode 3?
	jnz @F

;--- in mode 3, PIN status of OUT0 will become bit 15

	shr ax,1
	and cl,80h
	or ah, cl
@@:

;--- now the counter is in AX (counts from FFFF to 0000)

	neg ax

;--- now the count is from 0 to FFFF

	ret
	align 4
_GetTimerValue endp

;--- this proc may be called during interrupt time, SS is unknown

_GetTimerValuems proc
	call _GetTimerValue

;--- the timer ticks are in EDX:AX, timer counts down 
;--- a 16bit value with 1,193,180 Hz -> 1193180/65536 = 18.20648 Hz
;--- which are 54.83 ms
;--- to convert in ms:
;--- 1. subticks in ms: AX / 1193
;--- 2. ticks in ms: EDX * 55
;--- 3. total 1+2

	push edx
	movzx eax,ax	;step 1
	cdq
	mov ecx, 1193
	div ecx
	mov ecx, eax
	pop eax 		;step 2
	mov edx, 55
	mul edx
	add eax, ecx	;step 3
	ret
	align 4
_GetTimerValuems endp

if ?RTCRES

;--- the RTC timer ticks with 1024 Hz
;--- to convert into ms:
;--- ticks * 1000 / 1024 -> ticks * 125 / 128

getrtctimerticks proc
	mov eax, g_dwRTCTicks
	mov ecx, 125
	mul ecx
	shr eax, 7
	ret
	align 4
getrtctimerticks endp

externdef g_cntTimer:dword
externdef g_OldIrq08:fword
InitRTCTimer proto

installrtctimer proc

	mov g_dwGetTimerValuems, offset getrtctimerticks
	inc g_cntTimer
	.if (!word ptr g_OldIrq08+4)
		invoke InitRTCTimer
	.endif
	jmp g_dwGetTimerValuems
	align 4

installrtctimer endp
endif

if ?INIT

Init proc

if ?RTCRES
	test byte ptr [g_dwFlags],DKF_USERTC
	jz @F
	mov g_dwGetTimerValuems, offset installrtctimer
@@:
endif
	ret
	align 4

Init endp

endif

	end
