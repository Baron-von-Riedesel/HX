
;--- currently the destination must be a physical device DC (screen)
;--- and source must be a DC with a DIB

	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:none
	option proc:private

?COPYOPT equ 0
?SIMPLEINVERT equ 0
?CATCHEXC equ 0	;for debugging purposes

	include winbase.inc
	include wingdi.inc
	include dgdi32.inc
	include macros.inc

	.CODE

BitBlt proc public uses esi edi ebx hdcDest:DWORD, dwXDest:DWORD, dwYDest:DWORD, nWidth:DWORD, nHeight:DWORD,
				hdcSrc:DWORD, dwXSrc:DWORD, dwYSrc:DWORD, dwRop:DWORD

local	lpfnCopyProc:DWORD
local	dwSrcPitch:DWORD
local	dwOffset:DWORD
local	dwBpp:DWORD
local	dwWidth:DWORD
local	dwDestPitch:DWORD
local	dwHeight:DWORD
local	dwRestore:DWORD
ifdef _DEBUG
local	dwColorTrans:DWORD
endif
if ?CATCHEXC
local	dwEsp:DWORD
endif

	@strace <"BitBlt(", hdcDest, ", ", dwXDest, ", ", dwYDest, ", ", nWidth, ", ", nHeight, ", ", hdcSrc, ", ", dwXSrc, ", ", dwYSrc, ", ", dwRop, ") enter">
if ?CATCHEXC
	assume fs:nothing
	xor edx, edx
	push offset myexc
	push fs:[edx]
	mov fs:[edx], esp
	mov dwEsp, esp
endif
	cld		;direction flag might be set (SDL.DLL)
	mov dwRestore, offset _retn
	mov edi, hdcDest
	mov esi, hdcSrc
	xor eax, eax
	.if (esi && edi && (dwRop == SRCCOPY))
		mov ecx, [esi].DCOBJ.dwFlags
		or ecx, [edi].DCOBJ.dwFlags
		test cl,DCF_SCREEN
		jz @F
		invoke HideMouse
		mov dwRestore, offset ShowMouse
@@:
		mov ecx, [edi].DCOBJ.lPitch
		mov edx, [edi].DCOBJ.dwBpp
		mov eax, [edi].DCOBJ.dwHeight
		mov dwDestPitch, ecx
		mov dwBpp, edx
		mov dwHeight, eax

		mov eax, dwYDest
if ?MAPPING
		add eax, [edi].DCOBJ.ptViewportOrg.y
		@strace <"BitBlt(): dst bits=", [edi].DCOBJ.pBMBits, " pitch=", [edi].DCOBJ.lPitch, " viewport=", [edi].DCOBJ.ptViewportOrg.x, ", ", [edi].DCOBJ.ptViewportOrg.y>
endif
if 1
		and eax, eax
		jns @F
		add nHeight, eax   ;subtract from Y
		xor eax, eax
@@:
endif
if ?SIMPLEINVERT
		mov edx, [edi].DCOBJ.dwFlags
		xor edx, [esi].DCOBJ.dwFlags
		test edx, DCF_BOTTOM_UP
		jz @F
else
		test [edi].DCOBJ.dwFlags, DCF_BOTTOM_UP
		jz @F
endif
		add eax, nHeight
		dec eax
		neg dwDestPitch
@@:
		mul ecx
		mov ecx, eax
		mov eax, dwXDest
if ?MAPPING
		add eax, [edi].DCOBJ.ptViewportOrg.x
endif
if 1
		and eax, eax
		jns @F
		sub nWidth, eax
		xor eax, eax
@@:
endif
		mul dwBpp
		mov ebx, [edi].DCOBJ.pColorTab
		shr eax, 3
		add eax, ecx
		add eax, [edi].DCOBJ.pBMBits
		mov edi, eax

		mov eax, [esi].DCOBJ.lPitch
		mov dwSrcPitch, eax

		movzx eax, byte ptr dwBpp
		movzx ecx, byte ptr [esi].DCOBJ.dwBpp
ifdef _DEBUG
		mov dwColorTrans, eax
		mov byte ptr dwColorTrans+1,cl
endif
		cmp al,32
		ja error3
		cmp al,15		;convert 15 to 16
		setz dl
		add al,dl
		and al,0F8h		;dst determines bits 5-7
		shl eax,2
		cmp cl, 4
		jnz @F
		mov cl, 28h
@@:         
		and cl,038h
		shr ecx,1		;src determines bits (2-4)
		mov edx, [eax + ecx + offset copyprocs]
		mov lpfnCopyProc, edx
		mov eax, nWidth
		cmp eax, [esi].DCOBJ.dwWidth
		jbe @F
		mov eax, [esi].DCOBJ.dwWidth
@@:
		mov dwWidth, eax

		mov eax, nHeight
if 1
		mov ecx, [esi].DCOBJ.dwHeight
		cmp eax, ecx
		jbe @F
		mov eax, ecx
@@:
		cmp eax, dwHeight
		jbe @F
		mov eax, dwHeight
@@:
endif
		mov dwHeight, eax

		mov eax, dwXSrc
if ?MAPPING
		add eax, [esi].DCOBJ.ptViewportOrg.x
endif
		mul [esi].DCOBJ.dwBpp
		mov ecx, eax
		shr ecx, 3

		mov eax, dwYSrc 
if ?MAPPING
		add eax, [esi].DCOBJ.ptViewportOrg.y
endif
ife ?SIMPLEINVERT
		test [esi].DCOBJ.dwFlags, DCF_BOTTOM_UP
		jz @F
  if 0
		add eax, nHeight
  else
		mov edx, [esi].DCOBJ.dwHeight
		inc eax
		sub edx, eax
		jbe exit
		mov eax, edx
  endif
		neg dwSrcPitch
		@strace <"BitBlt: src inversion, eax=", eax, " ecx=", ecx>
@@:
endif
		mul [esi].DCOBJ.lPitch
		add eax, ecx
		add eax, [esi].DCOBJ.pBMBits 
ifdef _DEBUG
		mov edx, [esi].DCOBJ.pBMBits 
		@strace <"BitBlt(): dst=", edi, " src pitch=", dwSrcPitch, " viewport.y=", [esi].DCOBJ.ptViewportOrg.y, " pSrc=", edx, " pattern=", [edx+0], " ", [edx+4], " ", [edx+8]>
endif
		.if ([esi].DCOBJ.dwBpp == 1)
			mov ebx, hdcDest
			lea ebx, [ebx].DCOBJ._BkColor
		.elseif ([esi].DCOBJ.dwBpp <= 8)
			mov ebx, [esi].DCOBJ.pColorTab
		.endif
		mov esi, eax
ifdef _DEBUG
		mov ecx, dwHeight
		.if (ecx < nHeight)
			@strace <"BitBlt(): lines limited to ", ecx>
		.endif
endif

		.while (dwHeight)
			push edi
			push esi
			mov ecx, dwWidth
			call lpfnCopyProc
			pop esi
			pop edi
			add esi, dwSrcPitch
			add edi, dwDestPitch
			dec dwHeight
		.endw
		@mov eax, 1
ifdef _DEBUG
	.else
		@strace <"BitBlt() failed, unsupported parameters ***">
		int 3
endif
	.endif
exit:
if ?CATCHEXC
	mov esp,dwEsp
	pop fs:[0]
	pop ecx
endif
	call dwRestore
	@strace <"BitBlt(", hdcDest, ", ", dwXDest, ", ", dwYDest, ", ", nWidth, ", ", nHeight, ", ", hdcSrc, ", ", dwXSrc, ", ", dwYSrc, ", ", dwRop, ")=", eax, " colors=", dwColorTrans>
	ret
error3:					;no color conversion routine found
	@strace <"BitBlt() failed, bpp=", eax>
	xor eax,eax
	jmp exit
	align 4

if ?CATCHEXC
myexc:
	mov eax, [esp+12]	;get context
	mov [eax].CONTEXT.rEax, 0
	mov [eax].CONTEXT.rEip, offset exit
	xor eax,eax
	retn
	align 4
endif

copyprocs label dword
	dd blt1to01, blt8to01, blt16to01, blt24to01, blt32to01, blt4to01, 0, 0
	dd blt1to08, blt8to08, blt16to08, blt24to08, blt32to08, blt4to08, 0, 0
	dd blt1to16, blt8to16, blt16to16, blt24to16, blt32to16, blt4to16, 0, 0
	dd blt1to24, blt8to24, blt16to24, blt24to24, blt32to24, blt4to24, 0, 0
	dd blt1to32, blt8to32, blt16to32, blt24to32, blt32to32, blt4to32, 0, 0

?PALTRANS equ 1

	align 4
blt1to01:
blt4to01:
	shr ecx,3
	rep movsb
_retn:
	retn
blt8to01:
	retn
blt16to01:
	retn
blt24to01:
	retn
blt32to01:
	retn

	align 4
blt8to08:
if ?PALTRANS
	mov ebx, hdcDest
	cmp [ebx].DCOBJ.bColMap,0
	jnz usepaltrans
endif
if ?COPYOPT
	mov lpfnCopyProc, offset blt8to08_1
	cmp ecx, dwSrcPitch
	jnz @F
	cmp ecx, dwDestPitch
	jnz @F
	mov eax, ecx		;optimization possible: just do one movsd
	mul dwHeight
	mov dwHeight,1
	mov ecx, eax
	align 4
@@:
endif
blt8to08_1:
	mov dl,cl
	shr ecx,2
	rep movsd
	mov cl,dl
	and cl,3
	rep movsb
	retn

if ?PALTRANS
	align 4
;--- palette translation required, no optimization		  
usepaltrans:
	mov lpfnCopyProc, offset usepaltransX
	mov ebx, [ebx].DCOBJ.pColMap
	xor eax, eax
usepaltransX:
	lodsb
	mov al,[ebx+eax]
	stosb
	dec ecx
	jnz usepaltransX
	retn
endif

	align 4
blt16to16:
if ?COPYOPT
	mov lpfnCopyProc, offset blt16to16_1
	mov eax, ecx
	shl eax, 1
	cmp eax, dwSrcPitch
	jnz @F
	cmp eax, dwDestPitch
	jnz @F
	mov eax, ecx		;optimization possible: just do one movsd
	mul dwHeight
	mov dwHeight,1
	mov ecx, eax
	align 4
@@:
endif
blt16to16_1:
	shr ecx,1
	rep movsd
	adc cl,cl
	rep movsw
	retn

	align 4
blt24to24:
blt24to24_1:
	mov eax, ecx
	shr ecx, 1
	add ecx, eax
	rep movsw
	retn

	align 4
blt32to32:
if ?COPYOPT
	mov lpfnCopyProc, offset blt32to32_1
	mov eax, ecx
	shl eax, 2
	cmp eax, dwSrcPitch
	jnz @F
	cmp eax, dwDestPitch
	jnz @F
	mov eax, ecx		;optimization possible: just do one movsd
	mul dwHeight
	mov dwHeight,1
	mov ecx, eax
	align 4
@@:
endif
blt32to32_1:
	rep movsd
	retn

;--- now the conversion procs

	align 4
blt1to08:
	mov ah,80h
	.while (ecx)
		push ecx
		xor ecx,ecx
		test ah,[esi]
		setz cl
		mov al,[ebx+ecx*4]
		pop ecx
		stosb
		shr ah,1
		jnz @F
		inc esi
		mov ah,80h
@@:
		dec ecx
	.endw
	retn

	align 4
blt4to08:
	.while (ecx)
		xor eax, eax
		lodsb
		push eax
		shr al,4
		mov eax,[ebx+eax*4]
		stosb
		pop eax
		dec ecx
		jecxz @F
		and al,0Fh
		mov eax,[ebx+eax*4]
		stosb
		dec ecx
	.endw
@@:
	retn

	align 4
blt16to08:
	push -1
	xor eax, eax
	.while (ecx)
		lodsw
		cmp eax, [esp+0]
		jz nocolchange1608
		mov [esp+0], eax
		call _col16to8		;modifies EAX only
if 1
		mov edx, hdcDest
		cmp [edx].DCOBJ.bColMap,0
		jz @F
		mov edx, [edx].DCOBJ.pColMap
		movzx eax, byte ptr [edx+eax]
@@: 
endif
		mov edx, eax
nocolchange1608:
		mov eax, edx
		stosb
		dec ecx
	.endw
	add esp,4
	retn

	align 4
blt24to08:
	.while (ecx)
		mov al,[esi+2]
		shl eax,16
		mov ax,[esi+0]
		call _col24to8
		stosb
		add esi,3
		dec ecx
	.endw
	retn

	align 4
blt32to08:
	.while (ecx)
		lodsd
		call _col24to8
		stosb
		dec ecx
	.endw
	retn

	align 4
blt1to16:
	mov dl,80h
	.while (ecx)
		push ecx
		xor ecx,ecx
		test dl,[esi]
		setz cl
		mov eax,[ebx+ecx*4]
;		 call _col24to16
		stosw
		pop ecx
		shr dl,1
		jz nextbyte
nextbyte_ok:
		dec ecx
	.endw
	retn
nextbyte:
	inc esi
	mov dl,80h
	jmp nextbyte_ok

	align 4
blt4to16:
	.while (ecx)
		xor eax, eax
		lodsb
		push eax
		shr al,4
		mov eax,[ebx+eax*4]
		call _col24to16
		stosw
		pop eax
		dec ecx
		jecxz @F
		and al,0Fh
		mov eax,[ebx+eax*4]
		call _col24to16
		stosw
		dec ecx
	.endw
@@:
	retn

	align 4
blt8to16:
	.while (ecx)
		xor eax, eax
		lodsb
		mov eax, [ebx+eax*4]
		call _col24to16
		stosw
		dec ecx
	.endw
	retn

	align 4
blt24to16:
	.while (ecx)
		mov al,[esi+2]
		shl eax,16
		mov ax,[esi+0]
		add esi,3
		call _col24to16
		stosw
		dec ecx
	.endw
	retn

	align 4
blt32to16:
	.while (ecx)
		lodsd
		call _col24to16
		stosw
		dec ecx
	.endw
	retn

	align 4
blt1to24:
	mov ah,80h
	.while (ecx)
		push ecx
		xor ecx,ecx
		test ah,[esi]
		setz cl
		mov ecx,[ebx+ecx*4]
		mov [edi],cx
		inc edi
		inc edi
		shr ecx, 16
		mov [edi],cl
		inc edi
		pop ecx
		shr ah,1
		jnz @F
		inc esi
		mov ah,80h
@@:
		dec ecx
	.endw
	retn

	align 4
blt4to24:
	.while (ecx)
		xor eax, eax
		lodsb
		push eax
		shr al,4
		mov eax,[ebx+eax*4]
		stosw
		shr eax,16
		stosb
		pop eax
		dec ecx
		jecxz @F
		and al,0Fh
		mov eax,[ebx+eax*4]
		stosw
		shr eax,16
		stosb
		dec ecx
	.endw
@@:
	retn

	align 4
blt8to24:
	.while (ecx)
		xor eax, eax
		lodsb
		mov eax, [ebx+eax*4]
		stosw
		shr eax, 16
		stosb
		dec ecx
	.endw
	retn

	align 4
blt16to24:
	.while (ecx)
		lodsw
		call _col16to24
		stosw
		shr eax,16
		stosb
		dec ecx
	.endw
	retn

	align 4
blt32to24:
	.while (ecx)
		lodsd
		stosw
		shr eax, 16
		stosb
		dec ecx
	.endw
	retn

	align 4
blt1to32:
	mov ah,80h
	.while (ecx)
		push ecx
		xor ecx,ecx
		test ah,[esi]
		setz cl
		mov ecx,[ebx+ecx*4]
		mov [edi],ecx
		lea edi, [edi+4]
		pop ecx
		shr ah,1
		jnz @F
		inc esi
		mov ah,80h
@@:
		dec ecx
	.endw
	retn

	align 4
blt4to32:
	.while (ecx)
		xor eax, eax
		lodsb
		push eax
		shr al,4
		mov eax,[ebx+eax*4]
		stosd
		pop eax
		dec ecx
		jecxz @F
		and al,0Fh
		mov eax,[ebx+eax*4]
		stosd
		dec ecx
	.endw
@@:
	retn

	align 4
blt8to32:
	.while (ecx)
		xor eax, eax
		lodsb
		mov eax, [ebx+eax*4]
		stosd
		dec ecx
	.endw
	retn

	align 4
blt16to32:
	xor eax, eax
	.while (ecx)
		lodsw
		call _col16to24
		stosd
		dec ecx
	.endw
	retn

	align 4
blt24to32:
	.while (ecx)
		movsw
		movsb
		mov al,0
		stosb
		dec ecx
	.endw
	retn

BitBlt endp

	end
