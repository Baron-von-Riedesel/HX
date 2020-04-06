
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

;--- void GetSystemInfo(lpSystemInfo)

GetSystemInfo proc public pInfo:ptr SYSTEM_INFO

	push ebx
	mov ax,0400h
	int 31h		;returns processor in CL
	pop ebx
	mov edx,pInfo
	mov [edx].SYSTEM_INFO.wProcessorArchitecture, PROCESSOR_ARCHITECTURE_INTEL
	mov [edx].SYSTEM_INFO.dwPageSize, 1000h
;	mov [edx].SYSTEM_INFO.lpMinimumApplicationAddress, 10000h
	mov [edx].SYSTEM_INFO.lpMinimumApplicationAddress, 110000h
;	mov [edx].SYSTEM_INFO.lpMaximumApplicationAddress, 0FFFFFFFFh
	mov [edx].SYSTEM_INFO.lpMaximumApplicationAddress, 0FEFFFFFFh
	mov [edx].SYSTEM_INFO.dwActiveProcessorMask, 1
	mov [edx].SYSTEM_INFO.dwNumberOfProcessors, 1
	mov [edx].SYSTEM_INFO.dwProcessorType, PROCESSOR_INTEL_PENTIUM
;	mov [edx].SYSTEM_INFO.dwAllocationGranularity, 1000h
	mov [edx].SYSTEM_INFO.dwAllocationGranularity, 10000h
	movzx ecx,cl
	mov [edx].SYSTEM_INFO.wProcessorLevel, cx
	mov [edx].SYSTEM_INFO.wProcessorRevision, 0
	@strace <"GetSystemInfo(", pInfo, ")=void">
	ret
	align 4

GetSystemInfo endp

	end

