
;*** get memory status

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
	include dpmi.inc

;--- ?SAFEFREEPHYS: if phys mem is >= 16 MB
;--- round it down to next full 64 kb block.
;--- Some apps alloc all of free physical memory, which may
;--- then fail with VirtualAlloc if host is 0.9

?SAFEFREEPHYS	equ 1

	.CODE

GlobalMemoryStatus proc public uses esi edi pMemStat:ptr MEMORYSTATUS

local   buffer:MEMINFO

	mov esi,pMemStat
	lea edi,buffer
	mov ax,0500h
	int 31h
	jc error
	mov eax,[edi].MEMINFO.totalPhys			;total physical pages
	shl eax,12
	mov [esi].MEMORYSTATUS.dwTotalPhys, eax	;in bytes
	mov ecx,[edi].MEMINFO.maxLockable		;max lockable block
	mov eax,[edi].MEMINFO.unlocked			;free unlocked pages
	cmp eax,-1
	jnz @F
	mov eax,[edi].MEMINFO.freePhys			;free phys pages
	cmp eax,-1
	jnz @F
	mov eax,ecx
@@:
	cmp eax,ecx
	jbe @F
	mov eax,ecx
@@:
	shl eax,12
if ?SAFEFREEPHYS
	.if (eax & 0FF000000h)
		sub eax, 10000h
		and eax, 0FFFF0000h
	.endif
endif
	mov [esi].MEMORYSTATUS.dwAvailPhys, eax		;free physical memory (bytes)
	mov eax,[edi].MEMINFO.swapFile				;swap file pages
	cmp eax,-1
	jnz @F
	xor eax,eax
@@:
	shl eax,12
	mov [esi].MEMORYSTATUS.dwTotalPageFile, eax	;in bytes
	and eax, eax
	jz @F
	xor eax, eax
	mov ecx, [edi].MEMINFO.freeUnlocked
	cmp ecx,-1
	jz @F
	mov edx, [edi].MEMINFO.maxLockable
	cmp edx,-1
	jz @F
	sub ecx, edx
	jc @F
	shl ecx, 12
	mov eax, ecx
@@:
	mov [esi].MEMORYSTATUS.dwAvailPageFile, eax	;in bytes
	mov eax,[esi].MEMORYSTATUS.dwTotalPhys
	add eax,[esi].MEMORYSTATUS.dwTotalPageFile
	mov [esi].MEMORYSTATUS.dwTotalVirtual, eax	;total virtual (bytes)
if 0
	mov eax,[esi].MEMORYSTATUS.dwAvailPhys
	add eax,[esi].MEMORYSTATUS.dwAvailPageFile
else
	mov eax,[edi].MEMINFO.maxBlock
endif
	mov [esi].MEMORYSTATUS.dwAvailVirtual, eax	;avail. virtual (bytes)

	mov [esi].MEMORYSTATUS.dwMemoryLoad, 50
	mov eax,[esi].MEMORYSTATUS.dwAvailVirtual
	mov ecx,100
	mul ecx
	mov ecx,[esi].MEMORYSTATUS.dwTotalVirtual
	jecxz @F
	div ecx
	sub eax,100
	neg eax
	mov [esi].MEMORYSTATUS.dwMemoryLoad, eax
@@:
;--- to work around a bug in SCPPN.EXE
if 1
	cmp [esi].MEMORYSTATUS.dwAvailPageFile,0
	jnz @F
	mov [esi].MEMORYSTATUS.dwAvailPageFile,200000h
	mov [esi].MEMORYSTATUS.dwTotalPageFile,200000h
@@:
endif
	@mov eax,1
	jmp exit
error:
	cld
	lea edi,[esi].MEMORYSTATUS.dwMemoryLoad
	mov ecx,(sizeof MEMORYSTATUS - 4) / 4
	xor eax,eax
	rep stosd
exit:
	@trace <"GlobalMemoryStatus phys(avail/total)=">
	@tracedw [esi].MEMORYSTATUS.dwAvailPhys
	@trace <"/">
	@tracedw [esi].MEMORYSTATUS.dwTotalPhys
	@trace <" virt=">
	@tracedw [esi].MEMORYSTATUS.dwAvailVirtual
	@trace <"/">
	@tracedw [esi].MEMORYSTATUS.dwTotalVirtual
	@trace <" pgfil=">
	@tracedw [esi].MEMORYSTATUS.dwAvailPageFile
	@trace <"/">
	@tracedw [esi].MEMORYSTATUS.dwTotalPageFile
	@trace <" load=">
	@tracedw [esi].MEMORYSTATUS.dwMemoryLoad
	@trace <13,10>
	ret
GlobalMemoryStatus endp

	end
