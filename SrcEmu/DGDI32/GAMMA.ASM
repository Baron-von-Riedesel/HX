
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

?GAMMASUPP	equ 1

        .CODE

GetDeviceGammaRamp proc public hdc:DWORD, lpRamp:ptr

if ?GAMMASUPP
		xor ecx, ecx
        push ebx
        mov ebx, lpRamp
        xor edx, edx
        .repeat
        	mov [ebx+ecx*2+256*0],dx
        	mov [ebx+ecx*2+256*2],dx
        	mov [ebx+ecx*2+256*4],dx
            inc dh
            inc ecx
        .until (ecx==100h)
        pop ebx
        mov eax,1
		@strace <"GetDeviceGammaRamp(", hdc, ", ", lpRamp, ")=", eax>
else        
        xor eax, eax
		@strace <"GetDeviceGammaRamp(", hdc, ", ", lpRamp, ")=", eax, " *** unsupp">
endif        
        ret
		align 4
GetDeviceGammaRamp endp

SetDeviceGammaRamp proc public hdc:DWORD, lpRamp:ptr

        xor eax, eax
		@strace <"SetDeviceGammaRamp(", hdc, ", ", lpRamp, ")=", eax, " *** unsupp">
        ret
		align 4

SetDeviceGammaRamp endp


		end
