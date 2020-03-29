
;--- implements icon functions:
;--- CopyIcon
;--- CreateIcon
;--- CreateIconFromResource
;--- CreateIconFromResourceEx
;--- CreateIconIndirect
;--- DestroyIcon
;--- DrawIconEx
;--- GetIconInfo
;--- LoadIcon

		.386
if ?FLAT
		.MODEL FLAT, stdcall
else
		.MODEL SMALL, stdcall
endif
		option casemap:none
        option proc:private

		include winbase.inc
		include winuser.inc
        include wingdi.inc
        include duser32.inc
        include macros.inc

?FORMVER	equ 030000h

		.CODE

CreateIconIndirect proc public pIconInfo:ptr ICONINFO
		xor eax,eax
		@strace	<"CreateIconIndirect(", pIconInfo, ")=", eax, " *** unsupp ***">
		ret
        align 4
CreateIconIndirect endp

CreateIcon proc public hInstance:DWORD, nWidth:DWORD, nHeight:DWORD,
			cPlanes:DWORD, cBitsPixel:DWORD, lpbANDbits:ptr, lpbXORbits:ptr
		xor eax,eax
		@strace	<"CreateIcon(", hInstance, ", ", nWidth, ", ", nHeight, ", ", cPlanes, ", ", cBitsPixel, ", ...)=", eax, " *** unsupp ***">
		ret
        align 4
CreateIcon endp

DestroyIcon proc public hIcon:DWORD
		xor eax,eax
		@strace	<"DestroyIcon(", hIcon, ")=", eax, " *** unsupp ***">
		ret
        align 4
DestroyIcon endp

CreateIconFromResource proc public pResBits:ptr, dwSize:DWORD, bIcon:DWORD, dwVer:DWORD
		xor eax, eax
		@strace	<"CreateIconFromResource(", pResBits, ", ", dwSize, ", ", bIcon, ", ", dwVer, ")=", eax, " *** unsupp ***">
		ret
        align 4
CreateIconFromResource endp

CreateIconFromResourceEx proc public pbIconBits:ptr, cbIconBits:DWORD, fIcon:DWORD,
			dwVersion:DWORD, cxDesired:DWORD, cyDesired:DWORD, uFlags:DWORD
		xor eax,eax
		@strace	<"CreateIconFromResourceEx(", pbIconBits, ", ", cbIconBits, ", ", fIcon, ", ", dwVersion, ", ", cxDesired, ", ", cyDesired, ", ", uFlags, ")=", eax, " *** unsupp ***">
		ret
        align 4
CreateIconFromResourceEx endp

LoadIconA proc public uses ebx hInstance:HINSTANCE, lpIconName:ptr BYTE

        .if (!hInstance)
        	mov ecx, g_hInstance
            mov hInstance, ecx
            mov edx, lpIconName
            test edx, 0FFFF0000h
            .if (ZERO?)
            	sub lpIconName, 32512 - 52
            .endif
        .endif
if 1        
        invoke FindResource, hInstance, lpIconName, RT_GROUP_ICON
        .if (eax)
        	invoke LoadResource, hInstance, eax
            .if (eax)
				mov ebx, eax
                add ebx, sizeof NEWHEADER
                movzx eax, [ebx].RESDIR.IconCursorId
	            invoke FindResource, hInstance, eax, RT_ICON
        	.endif
        .endif
else
        invoke FindResource, hInstance, lpIconName, RT_ICON
endif       
        .if (eax)
        	invoke LoadResource, hInstance, eax
            .if (eax)
            	push eax
                invoke SizeofResource, hInstance, eax
                mov ecx, eax
                pop eax
            	invoke CreateIconFromResource, eax, ecx, TRUE, ?FORMVER
            .endif
        .endif
		@strace	<"LoadIconA(", hInstance, ", ", lpIconName, ")=", eax>
		ret
        align 4
LoadIconA endp

CopyIcon proc public hIcon:DWORD
		xor eax, eax
		@strace	<"CopyIcon(", hIcon, ")=", eax, " *** unsupp ***">
		ret
        align 4
CopyIcon endp

GetIconInfo proc public hIcon:HICON, pIconInfo:ptr ICONINFO
		xor eax, eax
		@strace	<"GetIconInfo(", hIcon, ", ", pIconInfo, ")=", eax, " *** unsupp ***">
		ret
        align 4
GetIconInfo endp

		end

