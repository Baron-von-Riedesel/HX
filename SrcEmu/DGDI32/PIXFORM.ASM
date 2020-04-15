
        .386
if ?FLAT
        .MODEL FLAT, stdcall
else
        .MODEL SMALL, stdcall
endif
		option casemap:none
        option proc:private

        include winbase.inc
        include wingdi.inc
        include dgdi32.inc
        include macros.inc

		.DATA
        
g_lpfnSwapBuffers dd 0

        .CODE
        
szOpenGL32					db "OpenGL32", 0        
szwglChoosePixelFormat		db "wglChoosePixelFormat",0
szwglDescribePixelFormat	db "wglDescribePixelFormat",0
szwglGetPixelFormat			db "wglGetPixelFormat",0
szwglSetPixelFormat			db "wglSetPixelFormat",0
szwglSwapBuffers		  	db "wglSwapBuffers",0

		align 4

;--- returns a 1-based index

ChoosePixelFormat proc public hdc:DWORD, ppfd:ptr PIXELFORMATDESCRIPTOR

ifdef _DEBUG
        mov edx, ppfd
        assume edx:ptr PIXELFORMATDESCRIPTOR
		movzx ecx, [edx].cColorBits
endif
		@strace <"ChoosePixelFormat(", hdc, ", ", ppfd, " [ flags=", [edx].dwFlags, " bpp=", ecx, "]) enter">
if 0
		@mov eax, 1
else
		invoke GetModuleHandle, addr szOpenGL32
        .if (eax)
        	invoke GetProcAddress, eax, addr szwglChoosePixelFormat
            .if (eax)
            	push ppfd
                push hdc
                call eax
            .endif
        .endif
endif
ifdef _DEBUG
        mov edx, ppfd
        assume edx:ptr PIXELFORMATDESCRIPTOR
		movzx ecx, [edx].cColorBits
endif
		@strace <"ChoosePixelFormat(", hdc, ", ", ppfd, " [ flags=", [edx].dwFlags, " bpp=", ecx, "])=", eax>
        ret
        assume edx:nothing
        align 4

ChoosePixelFormat endp

GetPixelFormat proc public hdc:DWORD

		@strace <"GetPixelFormat(", hdc, ") enter">
if 0
		mov ecx, hdc
        xor eax, eax
        .if ([ecx].DCOBJ.pPF)
        	inc eax
        .endif
else        
		invoke GetModuleHandle, addr szOpenGL32
        .if (eax)
        	invoke GetProcAddress, eax, addr szwglGetPixelFormat
            .if (eax)
                push hdc
                call eax
            .endif
        .endif
endif        
		@strace <"GetPixelFormat(", hdc, ")=", eax>
        ret
        align 4

GetPixelFormat endp

GdiSetPixelFormat proc public
GdiSetPixelFormat endp

SetPixelFormat proc public uses ebx hdc:DWORD, iPixelFormat:DWORD, ppfd:ptr PIXELFORMATDESCRIPTOR

		@strace <"SetPixelFormat(", hdc, ", ", iPixelFormat, ", ", ppfd, ") enter">
if 0
        mov ebx, hdc
		mov ecx, iPixelFormat
        xor eax, eax
        .if (ecx == 1)
        	.if (![ebx].DCOBJ.pPF)
            	invoke malloc, sizeof PIXELFORMATDESCRIPTOR
               	mov [ebx].DCOBJ.pPF, eax
            .endif
            mov eax, [ebx].DCOBJ.pPF
            .if (eax)
            	pushad
                mov edi, eax
                mov esi, ppfd
                mov ecx, sizeof PIXELFORMATDESCRIPTOR
                rep movsb
                popad
            	@mov eax, 1
            .endif
        .endif
else
		invoke GetModuleHandle, addr szOpenGL32
        .if (eax)
        	invoke GetProcAddress, eax, addr szwglSetPixelFormat
            .if (eax)
            	push ppfd
                push iPixelFormat
                push hdc
                call eax
            .endif
        .endif
endif
		@strace <"SetPixelFormat(", hdc, ", ", iPixelFormat, ", ", ppfd, ")=", eax>
        ret
        align 4

SetPixelFormat endp

;--- returns number of available pixel formats

GdiDescribePixelFormat proc public
GdiDescribePixelFormat endp

DescribePixelFormat proc public uses ebx hdc:DWORD, iPixelFormat:DWORD,
		nBytes:DWORD, ppfd:ptr PIXELFORMATDESCRIPTOR

		@strace <"DescribePixelFormat(", hdc, ", ", iPixelFormat, ", ", nBytes, ", ", ppfd, ") enter">
if 0
        xor eax, eax
        mov ecx, hdc
        .if (([ecx].DCOBJ.pPF) && (iPixelFormat == 1))
        	mov ebx, ppfd
            assume ebx:ptr PIXELFORMATDESCRIPTOR
            .if (ebx)
            	invoke GetDeviceCaps, hdc, BITSPIXEL
                mov ecx, hdc
                mov ecx, [ecx].DCOBJ.pPF
            	mov [ebx].nVersion, 1
            	mov [ebx].cColorBits, al
                
                
                .if (al >= 24)
		          	mov [ebx].cRedBits, 8
		          	mov [ebx].cRedShift, 0
		          	mov [ebx].cGreenBits, 8
		          	mov [ebx].cGreenShift, 8
		          	mov [ebx].cBlueBits, 8
		          	mov [ebx].cBlueShift, 8+8
                .elseif (al == 16)
		          	mov [ebx].cRedBits, 5
		          	mov [ebx].cRedShift, 0
		          	mov [ebx].cGreenBits, 6
		          	mov [ebx].cGreenShift, 5
		          	mov [ebx].cBlueBits, 5
		          	mov [ebx].cBlueShift, 5+6
                .elseif (al == 15)
		          	mov [ebx].cRedBits, 5
		          	mov [ebx].cRedShift, 0
		          	mov [ebx].cGreenBits, 5
		          	mov [ebx].cGreenShift, 5
		          	mov [ebx].cBlueBits, 5
		          	mov [ebx].cBlueShift, 5+5
                .else
		          	mov [ebx].cRedBits, 0
		          	mov [ebx].cRedShift, 0
		          	mov [ebx].cGreenBits, 0
		          	mov [ebx].cGreenShift, 0
		          	mov [ebx].cBlueBits, 0
		          	mov [ebx].cBlueShift, 0
                .endif
                mov eax, [ecx].PIXELFORMATDESCRIPTOR.dwFlags
                or eax, PFD_GENERIC_ACCELERATED or PFD_GENERIC_FORMAT
            	mov [ebx].dwFlags, eax
                mov al, [ecx].PIXELFORMATDESCRIPTOR.iPixelType
            	mov [ebx].iPixelType, al
                
	          	mov [ebx].cAlphaBits, 0
	          	mov [ebx].cAlphaShift, 0
                mov al, [ecx].PIXELFORMATDESCRIPTOR.cDepthBits
                and al,al
                jnz @F
                mov al,16
@@:                
                mov [ebx].cDepthBits, al
                mov [ebx].iLayerType, PFD_MAIN_PLANE
			.endif            
        	@mov eax,1
        .endif
else    
		invoke GetModuleHandle, addr szOpenGL32
        .if (eax)
        	invoke GetProcAddress, eax, addr szwglDescribePixelFormat
            .if (eax)
            	push ppfd
            	push nBytes
                push iPixelFormat
                push hdc
                call eax
            .endif
        .endif
endif   
		@strace <"DescribePixelFormat(", hdc, ", ", iPixelFormat, ", ", nBytes, ", ", ppfd, ")=", eax>
        ret
        assume ebx:nothing
        align 4

DescribePixelFormat endp

GdiSwapBuffers proc public
GdiSwapBuffers endp

SwapBuffers proc public hdc:DWORD

		@strace <"SwapBuffers(", hdc, ") enter">
		mov eax, g_lpfnSwapBuffers
		.if (!eax)
	   		invoke GetModuleHandle, addr szOpenGL32
	        .if (eax)
     	   		invoke GetProcAddress, eax, addr szwglSwapBuffers
                mov g_lpfnSwapBuffers, eax
            .endif
        .endif
        .if (eax)
            push hdc
            call eax
        .endif
		@strace <"SwapBuffers(", hdc, ")=", eax>
        ret
        align 4

SwapBuffers endp

		end
