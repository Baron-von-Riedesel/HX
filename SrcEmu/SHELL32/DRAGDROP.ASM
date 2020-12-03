
        .386
if ?FLAT
        .MODEL FLAT, stdcall
else
        .MODEL SMALL, stdcall
endif
		option casemap:none
        option proc:private

        include winbase.inc
        include macros.inc

        .CODE

DragAcceptFiles proc public hWnd:DWORD, fAccept:DWORD

		xor eax, eax
		@strace <"DragAcceptFiles(", hWnd, ", ", fAccept, ")=", eax>                
		ret
        align 4
        
DragAcceptFiles endp

DragFinish proc public hDrop:DWORD

		xor eax, eax
		@strace <"DragFinish(", hDrop, ")=", eax>                
		ret
        align 4
        
DragFinish endp

DragQueryFileA proc public hDrop:DWORD, iFile:dword, lpszFile:ptr BYTE, cch:dword

		xor eax, eax
		@strace <"DragQueryFileA(", hDrop, ", ", iFile, ", ", lpszFile, ", ", cch, ")=", eax>                
		ret
        align 4
        
DragQueryFileA endp

DragQueryFileW proc public hDrop:DWORD, iFile:dword, lpszFile:ptr WORD, cch:dword

		xor eax, eax
		@strace <"DragQueryFileW(", hDrop, ", ", iFile, ", ", lpszFile, ", ", cch, ")=", eax>                
		ret
        align 4
        
DragQueryFileW endp

DragQueryPoint proc public hDrop:DWORD, lppt:ptr POINT

		xor eax, eax
		@strace <"DragQueryPoint(", hDrop, ", ", lppt, ")=", eax>                
		ret
        align 4
        
DragQueryPoint endp

		end
