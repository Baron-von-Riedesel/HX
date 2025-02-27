
;--- clock() returns timer in EAX in ms, 1 ms resolution
;--- for OW register calling, assemble with: JWasm -Gr -zf1 clock.asm

	.386
	.model flat
ifdef __JWASM__
	option casemap:none
endif

	.code

_GetTimerValue proc private
tryagain:
	mov edx,ds:[46ch] 
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
	test cl,40h		;was latch valid?
	jnz tryagain
	cmp edx,ds:[046ch]	;did an interrupt occur while reading ports?
	jnz tryagain		;then do it again!
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
_GetTimerValue endp

clock proc public
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
	adc edx, 0
	ret
clock endp

	end
