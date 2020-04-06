
;--- LoadAccelerators

		.386
if ?FLAT
		.MODEL FLAT, stdcall
else
		.MODEL SMALL, stdcall
endif
		option casemap:none
ifndef __POASM__        
        option proc:private
endif

		include winbase.inc
		include winuser.inc
        include wingdi.inc
        include duser32.inc
        include macros.inc

		.CODE

LoadAcceleratorsA proc public uses ebx hInstance:HINSTANCE, lpName:ptr BYTE

        .if (!hInstance)
        	mov ecx, g_hInstance
            mov hInstance, ecx
        .endif
        invoke FindResource, hInstance, lpName, RT_ACCELERATOR
        .if (eax)
        	invoke LoadResource, hInstance, eax
        .endif
		@strace	<"LoadAcceleratorsA(", hInstance, ", ", lpName, ")=", eax>
		ret
        align 4
LoadAcceleratorsA endp

TranslateAcceleratorA proc public uses ebx hWnd:DWORD, hAccel:ptr, lpMsg:ptr MSG

		xor eax, eax
		@strace	<"TranslateAcceleratorA(", hWnd, ", ", hAccel, ", ", lpMsg, ")=", eax>
		ret
TranslateAcceleratorA endp

CopyAcceleratorTableA proc public hAccel:DWORD, lpAccelData:ptr, cEntries:DWORD

		xor eax, eax
		@strace	<"CopyAcceleratorTableA(", hAccel, ", ", lpAccelData, ", ", cEntries, ")=", eax>
		ret
CopyAcceleratorTableA endp


		end

