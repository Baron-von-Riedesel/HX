
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
        include winuser.inc
        include ddraw.inc
        include macros.inc
        include dciddi.inc

		.DATA
        
g_lpDD	LPDIRECTDRAW 0        
g_lpDDS	LPDIRECTDRAWSURFACE 0        

        .CODE

DCIOpenProvider proc public

		.if (!g_lpDD)
	      	invoke DirectDrawCreate, 0, addr g_lpDD, 0
    	   .if (eax != DD_OK)
		      	mov eax, DCI_FAIL_GENERIC
                ret
	       .endif
        .endif
        invoke GetDC, 0
        @strace <"DCIOpenProvider()=", eax>
        ret
DCIOpenProvider endp

DCICloseProvider proc public hdc:DWORD
		xor eax, eax
        .if (g_lpDD)
        	invoke ReleaseDC, 0, hdc
        	invoke vf(g_lpDD, IUnknown, Release)
            mov g_lpDD, 0
	        @mov eax,1
        .endif
        @strace <"DCICloseProvider(", hdc, ")=", eax>
        ret
DCICloseProvider endp

DCICreatePrimary proc public uses ebx hdc:DWORD, pdci:ptr ptr DCISURFACEINFO

local	ddsd:DDSURFACEDESC		

        .if (!g_lpDD)
           	mov eax, DCI_FAIL_GENERIC
            jmp exit
        .endif
        invoke LocalAlloc, LMEM_FIXED or LMEM_ZEROINIT, sizeof DCISURFACEINFO
        .if (!eax)
        	mov eax, DCI_FAIL_GENERIC
            jmp exit
        .endif
        mov ebx, eax
        mov [ebx].DCISURFACEINFO.dwSize, sizeof DCISURFACEINFO
        .if (!g_lpDDS)
        	mov ddsd.dwFlags, DDSD_CAPS
            mov ddsd.ddsCaps.dwCaps, DDSCAPS_PRIMARYSURFACE
	        invoke vf(g_lpDD, IDirectDraw, CreateSurface), addr ddsd, addr g_lpDDS, 0
            .if (eax != DD_OK)
            	invoke LocalFree, ebx
            	mov eax, DCI_FAIL_GENERIC
	            jmp exit
            .endif
        .endif
		invoke vf(g_lpDDS, IDirectDrawSurface, GetSurfaceDesc), addr ddsd
		mov [ebx].DCISURFACEINFO.dwDCICaps, DCI_VISIBLE or DCI_PRIMARY
if 1
		mov ecx, ddsd.ddpfPixelFormat.dwRGBBitCount
		.if (ecx >= 24)
			mov eax, 0
        .elseif (ecx >= 15)
        	mov eax, 3
        .else
        	mov eax, 0
		.endif        
		mov [ebx].DCISURFACEINFO.dwCompression, eax

		mov eax, ddsd.ddpfPixelFormat.dwRBitMask
		mov ecx, ddsd.ddpfPixelFormat.dwGBitMask
		mov edx, ddsd.ddpfPixelFormat.dwBBitMask
		mov [ebx].DCISURFACEINFO.dwMask[0*4], eax
		mov [ebx].DCISURFACEINFO.dwMask[1*4], ecx
		mov [ebx].DCISURFACEINFO.dwMask[2*4], edx
endif        
		mov ecx, ddsd.dwWidth
		mov edx, ddsd.dwHeight
		mov eax, ddsd.lPitch
		mov [ebx].DCISURFACEINFO.dwWidth, ecx
		mov [ebx].DCISURFACEINFO.dwHeight, edx
		mov [ebx].DCISURFACEINFO.lStride, eax
        
		mov eax, ddsd.ddpfPixelFormat.dwRGBBitCount
       	mov ecx, ddsd.lpSurface
		mov [ebx].DCISURFACEINFO.dwBitCount, eax
		mov [ebx].DCISURFACEINFO.dwOffSurface, ecx
        mov eax, -1
		mov [ebx].DCISURFACEINFO.BeginAccess, eax
		mov [ebx].DCISURFACEINFO.EndAccess, eax
		mov [ebx].DCISURFACEINFO.DestroySurface, eax
        mov ecx, pdci
        mov [ecx], ebx
		mov eax, DCI_OK
exit:            
        @strace <"DCICreatePrimary(", hdc, ", ", pdci, ")=", eax>
        ret
DCICreatePrimary endp

DCIDestroy proc public pdci:ptr DCISURFACEINFO
		.if (g_lpDDS)
        	invoke vf(g_lpDDS, IUnknown, Release)
            mov g_lpDDS, 0
        .endif
		mov eax, DCI_OK
        @strace <"DCIDestroy(", pdci, ")=", eax>
        ret
DCIDestroy endp

DCIBeginAccess proc public pdci:ptr DCISURFACEINFO, x:dword, y:dword, dx_:dword, dy:dword

local	ddsd:DDSURFACEDESC		

		.if (g_lpDDS)
        	mov ddsd.dwSize, sizeof DDSURFACEDESC
        	invoke vf(g_lpDDS, IDirectDrawSurface, Lock_), 0, addr ddsd, 0, 0
            .if (eax == DD_OK)
                push ebx
				mov ebx, pdci
if 0
				mov eax, ddsd.ddpfPixelFormat.dwRBitMask
				mov ecx, ddsd.ddpfPixelFormat.dwGBitMask
				mov edx, ddsd.ddpfPixelFormat.dwBBitMask
				mov [ebx].DCISURFACEINFO.dwMask[0*4], eax
				mov [ebx].DCISURFACEINFO.dwMask[1*4], ecx
				mov [ebx].DCISURFACEINFO.dwMask[2*4], edx
				mov ecx, ddsd.ddpfPixelFormat.dwRGBBitCount
                mov [ebx].DCISURFACEINFO.dwBitCount, ecx
endif                
            	mov eax, ddsd.lpSurface
;                mov ecx, ddsd.lPitch

;                mov [ebx].DCISURFACEINFO.wSelSurface, ds
;                mov [ebx].DCISURFACEINFO.lStride, ecx
                cmp eax, [ebx].DCISURFACEINFO.dwOffSurface
                mov [ebx].DCISURFACEINFO.dwOffSurface, eax
                
;                mov [ebx].DCISURFACEINFO.dwCompression, xxx
				pop ebx
                
                mov eax, DCI_OK
                jz @F
            	mov eax, DCI_STATUS_POINTERCHANGED
            .else
				mov eax, DCI_FAIL_GENERIC
            .endif
        .else
			mov eax, DCI_FAIL_GENERIC
        .endif
@@:        
        @strace <"DCIBeginAccess(", pdci, ", ", x, ", ", y, ", ", dx_, ", ", dy, ")=", eax>
        ret
DCIBeginAccess endp

;--- no return value

DCIEndAccess proc public pdci:ptr DCISURFACEINFO
		.if (g_lpDDS)
        	invoke vf(g_lpDDS, IDirectDrawSurface, Unlock), 0
            .if (eax == DD_OK)
				mov eax, DCI_OK
            .else
				mov eax, DCI_FAIL_GENERIC
            .endif
        .else
			mov eax, DCI_FAIL_GENERIC
        .endif
        @strace <"DCIEndAccess(", pdci, ")=", eax>
        ret
DCIEndAccess endp

		end
