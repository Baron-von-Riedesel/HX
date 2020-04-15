
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

?RESETFLAGS	equ 1

		.DATA

		public g_DefaultBM
        
g_DefaultBM dd 0        

        .CODE

;--- a memory DC has hBitmap != NULL
;--- the palette is not copied! the compatible DC gets the default palette

CreateCompatibleDC proc public uses ebx hdc:DWORD

       	invoke _GDImalloc2, sizeof DCOBJ
        .if (eax)
        	mov ebx, eax
        	mov eax, hdc
            .if (!eax)
            	invoke getdisplaydc
            .endif
            invoke RtlMoveMemory, ebx, eax, sizeof DCOBJ
            xor ecx, ecx
if ?RESETFLAGS            
            mov [ebx].DCOBJ.dwFlags, ecx
endif            
if 1            
            mov [ebx].DCOBJ.ptViewportOrg.x, ecx
            mov [ebx].DCOBJ.ptViewportOrg.y, ecx
            mov [ebx].DCOBJ.ptWindowOrg.x, ecx
            mov [ebx].DCOBJ.ptWindowOrg.y, ecx
            mov [ebx].DCOBJ.pColMap, ecx
            mov [ebx].DCOBJ.bColMap, cl
endif            
            mov eax, g_DefaultBM
            .if (!eax)
	            invoke CreateCompatibleBitmap, ebx, 0, 0
                mov g_DefaultBM, eax
            .endif
            mov [ebx].DCOBJ.hBitmap, eax
            
            invoke GetStockObject, DEFAULT_PALETTE
            invoke SelectPalette, ebx, eax, 0
            
            mov eax, ebx
        .endif
		@strace	<"CreateCompatibleDC(", hdc, ")=", eax>
        ret
		align 4
        
CreateCompatibleDC endp

		end
