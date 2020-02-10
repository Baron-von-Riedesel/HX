
	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:none
	option proc:private

	include winbase.inc
	include dkrnl32.inc

	.CODE

InterlockedIncrement proc public pVariable:dword

	mov eax,pVariable
	call EnterSerialization
	inc dword ptr [eax]
il1::
	mov eax, [eax]
	call LeaveSerialization
	ret
	align 4

InterlockedIncrement endp

InterlockedDecrement proc public pVariable:dword

	mov eax,pVariable
	call EnterSerialization
	dec dword ptr [eax]
	jmp il1
	align 4

InterlockedDecrement endp

InterlockedExchange proc public lpVariable:ptr dword, value:DWORD

	mov ecx,lpVariable
	mov eax, value
	xchg eax, [ecx]
	ret
	align 4

InterlockedExchange endp

InterlockedExchangeAdd proc public lpVariable:ptr dword, value:DWORD

	call EnterSerialization
	mov ecx,lpVariable
	mov edx, value
	mov eax, [ecx]
	add [ecx], edx
	call LeaveSerialization
	ret
	align 4

InterlockedExchangeAdd endp

InterlockedCompareExchange proc public lpVariable:ptr dword, value:DWORD, comperand:DWORD

	call EnterSerialization
	mov ecx,lpVariable
	mov edx, comperand
	mov eax, value
	cmp edx, [ecx]
	jnz @F
	xchg eax, [ecx]
@@:
	call LeaveSerialization
	ret
	align 4

InterlockedCompareExchange endp

	end

