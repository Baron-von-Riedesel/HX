
	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:none
	option proc:private

	include winbase.inc
	include macros.inc

	.CODE

RequestWakeupLatency proc public latency:DWORD

	@mov eax, 1
	@strace <"RequestWakeupLatencyA(", latency, ")=", eax>
	ret
	align 4

RequestWakeupLatency endp

	end

