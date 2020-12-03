
        .386
if ?FLAT
        .MODEL FLAT, stdcall
else
        .MODEL SMALL, stdcall
endif
		option casemap:none
        option proc:private

        include wtypes.inc
        include winbase.inc
        include winuser.inc
        include shellapi.inc
        include macros.inc

        .CODE

SHFileOperationA proc public uses esi edi ebx lpFileOp:ptr SHFILEOPSTRUCTA

local	bCreateDir:DWORD
local	bIsDir:DWORD
local	dwOp:DWORD
local	hFF:DWORD
local	wff:WIN32_FIND_DATAA
local	szFile[MAX_PATH]:byte

		mov ebx, lpFileOp
		mov ecx, [ebx].SHFILEOPSTRUCTA.wFunc
		mov esi, [ebx].SHFILEOPSTRUCTA.pFrom
		xor eax, eax
		.if (ecx == FO_COPY)
			inc eax
		    mov edx, copy
		.elseif (ecx == FO_DELETE)
		   mov edx, delete
		   cmp [ebx].SHFILEOPSTRUCTA.pTo, 0
		   jnz error
		.elseif (ecx == FO_MOVE)
		   inc eax
		   mov edx, move
		.elseif (ecx == FO_RENAME)
		   inc eax
		   mov edx, rename
		.else
		   jmp error
		.endif
		mov dwOp, edx
       	mov bCreateDir, FALSE
       	mov bIsDir, FALSE
        .if (eax)
			movzx eax, [ebx].SHFILEOPSTRUCTA.fFlags
			.if (eax & FOF_MULTIDESTFILES)
                .if (dwOp == rename)
                	jmp error
                .endif
            .else
		  		invoke GetFileAttributes, [ebx].SHFILEOPSTRUCTA.pTo
	            .if (eax == -1)
     		       	invoke GetLastError
	                .if (eax == ERROR_FILE_NOT_FOUND)
    	            	.if (dwOp != rename)
	        	        	mov bCreateDir, TRUE
                        .endif
    	            .endif
	            .else
	            	.if (eax & FILE_ATTRIBUTE_DIRECTORY)
    	            	.if (dwOp == rename)
        	            	jmp error
            	        .endif
	                    mov bIsDir, TRUE
	                .endif
				.endif
            .endif
        .endif
		.while (byte ptr [esi])
			invoke FindFirstFile, esi, addr wff
			.if (eax != -1)
				mov hFF, eax
                mov edi, [ebx].SHFILEOPSTRUCTA.pTo
				.while (eax)
					.if (bCreateDir)
        				invoke CreateDirectory, edi, NULL
                        .if (!eax)
                        	jmp error
                        .endif
                        mov bCreateDir, FALSE
                        mov bIsDir, TRUE
			        .endif
					call dwOp
					invoke FindNextFile, hFF, addr wff
				.endw
				invoke FindClose, hFF
			.endif
			mov edi, esi
			mov al,0
			or ecx,-1
			repnz scasb
			mov esi, edi
		.endw
		xor eax, eax
exit:		 
		@strace <"SHFileOperationA(", lpFileOp, ")=", eax>				  
		ret
error:
		mov eax, E_FAIL
		jmp exit
copy:
move:
		.if (byte ptr [edi])
			invoke lstrcpy, addr szFile, [ebx].SHFILEOPSTRUCTA.pTo
        	.if (bIsDir)
    		    invoke lstrcat, addr szFile, "\"
                lea edx, wff.cFileName
                mov ecx, edx
                .while (byte ptr [edx])
                	mov al,[edx]
                	inc edx
                	.if ((al == '\') || (al == '/'))
                    	mov ecx, edx
                    .endif
                .endw
        		invoke lstrcat, addr szFile, ecx
            .endif
            .if (dwOp == move)
				invoke MoveFile, addr wff.cFileName, addr szFile
            .else
				invoke CopyFile, addr wff.cFileName, addr szFile, 1
            .endif
            .if (!bIsDir)
	    	    mov al,0
		        or ecx,-1
    		    repnz scasb
            .endif
        .endif
		retn
delete:
		invoke DeleteFile, addr wff.cFileName
		retn
rename:
		invoke MoveFile, addr wff.cFileName, edi
		retn
		align 4
SHFileOperationA endp

SHGetFileInfoA proc public pszFile:dword, pFI:ptr, dw1:dword, dw2:dword
		mov eax, E_FAIL
		@strace <"SHGetFileInfoA()=", eax>				  
		ret
		align 4
SHGetFileInfoA endp

SHGetFileInfoW proc public pszFile:dword, pFI:ptr, dw1:dword, dw2:dword
		mov eax, E_FAIL
		@strace <"SHGetFileInfoW()=", eax>				  
		ret
		align 4
SHGetFileInfoW endp

		end
