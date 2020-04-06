
;--- LoadImage

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

		.CODE

ReadBitmap proc uses ebx lpszName:ptr BYTE

local	dwRead:DWORD
local	pBM:ptr BITMAPINFOHEADER
local	bfh:BITMAPFILEHEADER

		invoke CreateFile, lpszName, GENERIC_READ, 0, 0, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0
		cmp eax, HFILE_ERROR
		jz error
    	mov ebx, eax
		invoke ReadFile, ebx, addr bfh, sizeof bfh, addr dwRead, 0
		and eax, eax
		jz error2
        mov eax, dwRead
        cmp eax, sizeof bfh
        jnz error2
        cmp bfh.bfType, "MB"
        jnz error2
        mov eax, bfh.bfSize
        invoke malloc, eax
        and eax, eax
        jz error2
        mov pBM, eax
        invoke ReadFile, ebx, pBM, bfh.bfSize, addr dwRead, 0
        and eax, eax
        jz error3
	    invoke CloseHandle, ebx
        mov eax, pBM
exit:
		ret
error3:    
		invoke free, pBM
error2:    
		invoke CloseHandle, ebx
error:
		xor eax, eax
        jmp exit
        align 4
ReadBitmap endp        


LoadImageA proc public hInstance:HINSTANCE, lpszName:ptr BYTE, uType:DWORD, 
			cxDesired:DWORD, cyDesired:DWORD, fuLoad:DWORD
		xor eax, eax
		mov ecx, fuLoad
        mov edx, uType
        .if (ecx & LR_LOADFROMFILE)
        	.if (edx == IMAGE_BITMAP)
            	invoke ReadBitmap, lpszName
                .if (eax)
                	push eax
                	invoke _CreateBitmapFromMemory, eax
                    pop ecx
                    push eax
                    invoke free, ecx
                    pop eax
                .endif
            .elseif (edx == IMAGE_CURSOR)
            .elseif (edx == IMAGE_ICON)
            .endif
        .else
        	.if (edx == IMAGE_BITMAP)
	        	invoke LoadBitmapA, hInstance, lpszName
            .elseif (edx == IMAGE_CURSOR)
	        	invoke LoadCursorA, hInstance, lpszName
            .elseif (edx == IMAGE_ICON)
;	        	invoke LoadIconA, hInstance, lpszName
            .endif
        .endif
		@strace	<"LoadImage(", hInstance, ", ", lpszName, ", ", uType, ", ", cxDesired, ", ", cyDesired, ", ", fuLoad, ")=", eax>
        ret
        align 4
LoadImageA endp

CopyImage proc public hImage:DWORD, uType:DWORD, cxDesired:DWORD, cyDesired:DWORD, fuFlags:DWORD
		xor eax, eax
		@strace	<"CopyImage(", hImage, ", ", uType, ", ", cxDesired, ", ", cyDesired, ", ", fuFlags, ")=", eax>
        ret
        align 4
CopyImage endp

		end

