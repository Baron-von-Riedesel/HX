        
;--- load a PE file within a MZ binary

		.386
        .model small

		include winnt.inc

		.code

;--- PE image must have been loaded by the application
;--- no imports are allowed.

;--- 1. alloc memory and copy section contents
;--- 2. resolve base fixups
;--- 3. get flat code/data descriptor
;--- 4. set CS,SS,DS,ES flat
;--- 5. call entry point for app/dlls
;--- 6. return (for dlls) with Carry if dll returned with eax=0

;--- pHdr: -> IMAGE_NT_HEADERS, then array of IMAGE_SECTION_HEADERS
;--- pImage: raw image data

LoadPE	proc stdcall public pHdr:ptr, pImage:ptr

	pushad

	mov		esi, pHdr
    mov		eax, [esi].IMAGE_NT_HEADERS.OptionalHeader.SizeOfImage
    mov		ecx, eax
    shr		eax, 16
    mov		ebx, eax
    push 	esi
    mov		ax,501h
    int		31h
    pop		esi
    jc		error
    mov		edi, ebx
    shl		edi, 16
    mov		di, cx
    
    movzx	ecx, [esi].IMAGE_NT_HEADERS.FileHeader.NumberOfSections
    lea		ebx, [esi+sizeof IMAGE_NT_HEADERS]
    push	es
    push	gs
    pop		es

    .while (ecx)
    	push edi
        push esi
        push ecx
        add edi, [ebx].IMAGE_SECTION_HEADER.VirtualAddress
        mov edx, pImage
        mov eax, [ebx].IMAGE_SECTION_HEADER.PointerToRawData
        sub eax, [esi].IMAGE_NT_HEADERS.OptionalHeader.SizeOfHeaders
        mov ecx, [ebx].IMAGE_SECTION_HEADER.SizeOfRawData
        shr ecx, 2
        add edx, eax
        mov esi, edx
        rep movsd
        pop ecx
        pop esi
        pop edi
    	add ebx, sizeof IMAGE_SECTION_HEADER
    	dec ecx
    .endw
    pop es

;--- relocations

    push	ds
    push	ebp

    mov		ebp, edi
	sub		ebp, [esi].IMAGE_NT_HEADERS.OptionalHeader.ImageBase
    mov		ecx, [esi].IMAGE_NT_HEADERS.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_BASERELOC*8].Size_
    mov		esi, [esi].IMAGE_NT_HEADERS.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_BASERELOC*8].VirtualAddress
    add		esi, edi
    add		ecx, esi
    
    push	gs
    pop		ds

	xor		edx, edx
nextpage:
	cmp		esi, ecx
    jnc		reloc_done
    push	ecx
	mov		ebx, [esi+0]
	mov		ecx, [esi+4]
	add		ecx, esi
	add		esi, 8
    add		ebx, edi		;add conv. base to address
	xor		eax, eax
nextreloc:
	lodsw	
	test	ah,0F0h
	jz		ignreloc
	and		ah,0Fh
	add		[eax+ebx], ebp
ignreloc: 
	cmp 	esi, ecx
	jb		nextreloc
    pop		ecx
	jmp		nextpage
reloc_done:
	pop		ebp
	pop		ds

;--- alloc flat code/data descriptor

    mov		cx,2
	mov		ax,0
    int		31h
    jc		error
    mov		ebx,eax
    xor		ecx,ecx
    xor		edx,edx
    mov		ax,7
    int		31h		;set base to 0
    dec		ecx
    dec		edx
    mov		ax,8
    int		31h		;set limit to -1
    mov		eax,cs
    lar		eax,eax
    shr		eax,8
    mov		ecx,eax
    mov		ax,9
    int		31h
    add		ebx,8
    xor		ecx,ecx
    xor		edx,edx
    mov		ax,7
    int		31h		;set base to 0
    dec		ecx
    dec		edx
    mov		ax,8
    int		31h
    mov		eax,ss
    lar		eax,eax
    shr		eax,8
    mov		ecx,eax
    mov		ax,9
    int		31h
    sub		ebx,8

;--- search EIP, store it in EDI
;--- search characteristics, store it in ESI

	mov		esi,pHdr
    add		edi,[esi].IMAGE_NT_HEADERS.OptionalHeader.AddressOfEntryPoint
    movzx	esi,[esi].IMAGE_NT_HEADERS.FileHeader.Characteristics
    
;--- set DS,ES,SS to flat

	push	ds
    push	es
    
    mov		ecx,esp
    push	ss
    push	ecx
    push	ebx
    mov		ebx,ss
    mov		ax,6
    int		31h
    pop		ebx
    mov		eax,ecx
    shl		eax,16
    mov		ax,dx
    add		eax,esp
	lea		edx,[ebx+8]
    mov		ss,edx
    mov		esp,eax
    mov		ds,edx
    mov		es,edx

;--- DS, ES and SS are flat now
;--- now call app/dll entry point

	push	ebx
	mov		ebx,cs
    mov		ax,6
    int		31h
    pop		ebx
    mov		eax,ecx
    shl		eax,16
    mov		ax,dx
    add		eax,offset backfromflat
    push	cs
    push	offset backtosegmented
    test	esi, IMAGE_FILE_DLL
    jz		isapp

    push	0
    push	1		;DLL_PROCESS_ATTACH
    push	pImage
    push	eax
    push	ebx		;push flat CS
	push	edi
    retf
backfromflat:
	retf
backtosegmented:
    lss		esp,[esp]
    pop		es
    pop		ds
    cmp		eax,1	;eax==0 means error
error:
	popad
	ret
isapp:
	push ebx
	push edi
    retf
    
LoadPE endp

	END
