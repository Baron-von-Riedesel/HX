
if ?FLAT
	.386
	.MODEL FLAT, stdcall

	option casemap:none
	option proc:private

	include winbase.inc
	include dkrnl32.inc

;--- currently only static TLS of the main EXE is
;--- handled here
;--- on error return 0, this will abort loading of dkrnl32

;--- IMAGE_TLS_DIRECTORY struct
;--- StartAddressOfRawData	DWORD	?
;--- EndAddressOfRawData	DWORD	?
;--- AddressOfIndex			DWORD	?
;--- AddressOfCallBacks		DWORD	?
;--- SizeOfZeroFill			DWORD	?
;--- Characteristics		DWORD	?
;--- IMAGE_TLS_DIRECTORY ends

	.DATA

tlsslot	dd -1

TIBSEG segment use16
TIBSEG ends
	assume fs:TIBSEG	;declare FS=TIB a 16 bit segment (saves space)

	.CODE

initstaticTLS proc public

	pushad
	invoke GetModuleHandle, NULL
	and eax, eax
	jz exit
	mov ebx, [eax].IMAGE_DOS_HEADER.e_lfanew
	add ebx, eax
	mov esi, [ebx].IMAGE_NT_HEADERS.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_TLS*sizeof IMAGE_DATA_DIRECTORY].VirtualAddress
	.if (esi)
		add esi, eax
		invoke IsBadWritePtr, [esi].IMAGE_TLS_DIRECTORY.AddressOfIndex, 4
		and eax, eax
		jnz error
		invoke TlsAlloc
		cmp eax, -1
		jz error
		mov edx, [esi].IMAGE_TLS_DIRECTORY.AddressOfIndex	
		mov ebx, eax
		mov [edx], eax
		call AllocData
	.endif
exit:
	popad
	ret
error:
	invoke RaiseException, ERROR_STATIC_INIT or 0C0000000h, 0, 0, 0
	popad
	ret
	align 4

initstaticTLS endp

;--- alloc data and store address in slot (ebx)
;--- init the data

AllocData proc
	invoke GetProcessHeap
	mov ecx, [esi].IMAGE_TLS_DIRECTORY.EndAddressOfRawData
	inc ecx
	sub ecx, [esi].IMAGE_TLS_DIRECTORY.StartAddressOfRawData
	push ecx
	add ecx, [esi].IMAGE_TLS_DIRECTORY.SizeOfZeroFill
	invoke HeapAlloc, eax, 0, ecx
	pop ecx
	and eax, eax
	jz error
	mov edx, fs:[THREAD_INFORMATION_BLOCK.pvTLSArray]
	mov ds:[edx + ebx * 4], eax
	mov edi, eax
	push esi
	mov esi, [esi].IMAGE_TLS_DIRECTORY.StartAddressOfRawData
	rep movsb
	pop esi
	mov ecx, [esi].IMAGE_TLS_DIRECTORY.SizeOfZeroFill
	xor eax, eax
	rep stosb
	ret
error:
	invoke RaiseException, ERROR_STATIC_INIT or 0C0000000h, 0, 0, 0
	ret
	align 4
AllocData endp

initstaticTLSthread proc public uses esi edi ebx
	invoke GetModuleHandle, NULL
	mov ecx, [eax].IMAGE_DOS_HEADER.e_lfanew
	add ecx, eax
	mov esi, [ecx].IMAGE_NT_HEADERS.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_TLS*sizeof IMAGE_DATA_DIRECTORY].VirtualAddress
	.if (esi)
		add esi, eax
		mov edx, [esi].IMAGE_TLS_DIRECTORY.AddressOfIndex	
		mov ebx, [edx]
		call AllocData
	.endif
	ret
initstaticTLSthread endp

endif

	end

