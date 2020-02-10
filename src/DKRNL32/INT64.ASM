
;--- 64bit integer math

	.386
if ?FLAT
	.model flat, stdcall
else
	.model small, stdcall
endif
	option casemap:none
	option proc:private

	include winbase.inc
	include dkrnl32.inc
	include macros.inc

	.CODE

;--- mul64
;--- parameters:
;--- multiplicant:parm1
;--- multiplicator:parm2

_mul64 proc public uses esi parm1:qword, parm2:dword

	mov esi,parm2
	xor esi,dword ptr parm1+4
	test dword ptr parm1+4,80000000h
	jz @F
	neg dword ptr parm1+4
	neg dword ptr parm1+0
	sbb dword ptr parm1+4,+0
@@:
	test parm2,80000000h
	jz @F
	neg parm2
@@:
	mov eax,parm2
	mul dword ptr parm1+0
	push edx
	mov ecx,eax
	mov eax,parm2
	mul dword ptr parm1+4
	add eax,[esp]
	test esi,80000000h
	jz @F
	neg eax
	neg ecx
	sbb eax,+0
@@:
	add esp,+4
	mov edx,eax
	mov eax,ecx
	ret
	align 4

_mul64 endp

;--- _div64

;--- parameters
;--- +08	:[in] QWORD (dividend)
;--- +10	;[in] QWORD (divisor)
;--- +18	;[in] BYTE (shift)

;--- locals
;--- l1     :hidword 1. mul
;--- l2     ;result 2. mul


_div64 proc public uses esi parm1:qword, parm2:qword, parm3:dword

local	l1:dword
local	l2:qword

	mov esi,dword ptr parm1+4
	test esi,80000000h
	jz @F
	neg dword ptr parm1+4
	neg dword ptr parm1+0
	sbb dword ptr parm1+4,+0
@@:
	mov eax,dword ptr parm2+0
	mul dword ptr parm1+0
	mov l1,edx

	mov eax,dword ptr parm2+0
	mul dword ptr parm1+4
	mov dword ptr l2+0,eax
	mov dword ptr l2+4,edx

	mov eax,dword ptr parm2+4
	mul dword ptr parm1+0
	xor ecx,ecx
	add eax,l1
	adc ecx,+0
	add eax,dword ptr l2+0
	adc ecx,+0
	mov l1,edx

	mov eax,dword ptr parm2+4
	mul dword ptr parm1+4
	add eax,l1
	adc edx,+0
	add eax,dword ptr l2+4
	adc edx,+0
	add eax,ecx
	adc edx,+0
	mov cl,byte ptr parm3
nextshift:
	cmp cl,1Fh
	jbe shiftdone
	sub cl,1Fh
	shrd eax,edx,1Fh
	shr edx,1Fh
	jmp nextshift
shiftdone:
	shrd eax,edx,cl
	shr edx,cl
	test esi,80000000h
	jz @F
	neg edx
	neg eax
	sbb edx,+0
@@:
	ret
	align 4

_div64 endp

	end
