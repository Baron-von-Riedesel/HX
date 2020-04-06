
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
	include excpt.inc
	include macros.inc

TIBSEG segment use16
TIBSEG ends
	assume fs:TIBSEG	;declare FS=TIB a 16 bit segment (saves space)

;STATUS_UNWIND	equ 0C0000026h ;this is STATUS_INVALID_DISPOSITION!
STATUS_UNWIND	equ 0C0000027h

	.CODE

;*** this function is/was "undocumented"
;*** but described sufficiently by Matt Pietrek in MSJ 1997/01
;*** should unwind stack if exception occured and a "higher"
;*** handler has choosen to handle it

;--- from MSDN:
;--- PVOID TargetFrame [optional]
;--- PVOID TargetIp [optional] (ignored if TargetFrame is NULL)
;--- PEXCEPTION_RECORD ExceptionRecord [optional]
;--- PVOID ReturnValue


RtlUnwind proc public uses esi edi ebx TargetFrame:ptr EXCEPTION_REGISTRATION,
		TargetIp:DWORD, ExceptionRecord:ptr EXCEPTION_RECORD, return_value:dword

local	_er:EXCEPTION_RECORD

	@strace <"RtlUnwind(", TargetFrame, ", ", TargetIp, ", ", ExceptionRecord, ", ", return_value, ")">

	mov ecx, ExceptionRecord
	.if (!ecx)
		lea ecx, _er
		mov [ecx].EXCEPTION_RECORD.ExceptionCode, STATUS_UNWIND
		mov eax, [ebp+4]  ;current eip?
		mov [ecx].EXCEPTION_RECORD.ExceptionAddress, eax
		mov [ecx].EXCEPTION_RECORD.ExceptionRecord, 0
		mov [ecx].EXCEPTION_RECORD.NumberParameters, 0
		mov [ecx].EXCEPTION_RECORD.ExceptionInformation, 0
		mov ExceptionRecord, ecx
	.endif
	.if ( TargetFrame )
		mov [ecx].EXCEPTION_RECORD.ExceptionFlags, _EH_UNWINDING
	.else
		mov [ecx].EXCEPTION_RECORD.ExceptionFlags, _EH_UNWINDING or _EH_EXIT_UNWIND
	.endif

	mov edi, fs:[THREAD_INFORMATION_BLOCK.pvExcept]
	.while ((edi != -1) && (edi != TargetFrame))
		@strace <"RtlUnwind: calling exc handler ", [edi].EXCEPTION_REGISTRATION.ExceptionHandler, ", edi=", edi, ", esp=", esp >
		invoke _GetCurrentThread
		mov ecx, ExceptionRecord
		push ebp               ;for Borland, set EBP to a exc handler frame!
		mov esi, esp
		lea ebp, [esp-6*4]     ;see also except.asm
		invoke [edi].EXCEPTION_REGISTRATION.ExceptionHandler, \
			ecx, edi, [eax].THREAD.pContext, 0
		@strace <"RtlUnwind: returned from exc handler, edi=", edi, ", esp=", esp, ", esi=", esi >
		mov esp, esi
		pop ebp
		mov edi, [edi].EXCEPTION_REGISTRATION.prev_structure
		mov fs:[THREAD_INFORMATION_BLOCK.pvExcept],edi
	.endw
	@strace <"RtlUnwind: exit">
	ret
        
RtlUnwind endp

end

