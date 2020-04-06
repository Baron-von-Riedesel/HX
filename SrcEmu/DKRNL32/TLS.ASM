
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
	include macros.inc

TIBSEG segment use16
TIBSEG ends
	assume fs:TIBSEG	;declare FS=TIB a 16 bit segment (saves space)

?VERBOSE	equ 0
?FAST		equ 1

	.data

?TLSARRAYSIZE equ ?TLSSLOTS/32

g_tlsslots dd ?TLSARRAYSIZE dup (0)	;should be defined in PROCESS struct!

	.code

TlsAlloc proc public

	@mov eax,0
@@:
	bts g_tlsslots,eax
	jnc @F						  ;slot is free
	inc eax
	cmp eax,?TLSSLOTS
	jb @B
;	@mov eax,-1
	or eax,-1
@@:
	@strace <"TlsAlloc()=", eax>
	ret
	align 4
TlsAlloc endp

TlsFree proc public index:dword
	mov ecx,index
	mov edx, fs:[THREAD_INFORMATION_BLOCK.pvTLSArray]
	cmp ecx, ?TLSSLOTS
	jnb error
@@:
	btr g_tlsslots,ecx
	jnc error
	mov dword ptr [edx+ecx*4],0
	mov eax,1
exit:
	@strace <"TlsFree(", index, ")=", eax>
	ret
error:
	invoke SetLastError, ERROR_INVALID_PARAMETER
	xor eax,eax
	jmp exit
	align 4

TlsFree endp

TlsSetValue proc public index:dword,value:dword

	mov edx, fs:[THREAD_INFORMATION_BLOCK.pvTLSArray]
	mov ecx,index
	mov eax,value
	mov [edx+ecx*4],eax
	mov eax,1
	@strace <"TlsSetValue(", ecx, ", ", value, ")=", eax, " [", edx, "]">
	ret
	align 4
TlsSetValue endp

if ?FAST
option prologue:none
endif

TlsGetValue proc public index:dword

;;	invoke _GetCurrentThread
if ?FAST
	pop edx
	pop ecx
else
	mov edx, fs:[THREAD_INFORMATION_BLOCK.pvTLSArray]
	mov ecx,index
endif
	cmp ecx, ?TLSSLOTS
	jnb error
	mov dword ptr fs:[?LERROROFS],0
if ?FAST
	mov eax, fs:[THREAD_INFORMATION_BLOCK.pvTLSArray]
	mov eax,[eax+ecx*4]
else
	mov eax,[edx+ecx*4]
endif
exit:
;;	@strace <"TlsGetValue(", ecx, ")=", eax>
if ?VERBOSE
	ret
else
	jmp edx
endif
error:
	invoke SetLastError, ERROR_INVALID_PARAMETER
	xor eax, eax
	jmp exit
	align 4

TlsGetValue endp

	end
