
;*** implements
;--- FindFirstFileA()
;--- FindNextFileA()
;--- FindCloseA()

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
	include dkrnl32.inc

extern	__CHECKOS:abs	;check for NT/W2K/XP (LFN bug)

?VERBOSE	equ 1		;log more debug displays

DOSFIND struct				;11+13+4+3*1+4*2+1*4=43 Bytes
drive	  db ?
searchpat db 11 dup (?)
searchatt db ?				;0=r/o,1=hidden,2=sys,3=vol,4=dir
entrycnr  dw ?
cluster   dw ?
res 	  db 4 dup (?)
attr	  db ?
filetime  dw ?
filedate  dw ?
filesize  dd ?
filename  db 13 dup (?)
DOSFIND ends

	.CODE

;*** transform date/time into FILETIME
;--- used when LFN call was used

transdatetime:
	movzx ecx, word ptr [edi].WIN32_FIND_DATAA.ftLastWriteTime+2
	movzx edx, word ptr [edi].WIN32_FIND_DATAA.ftLastWriteTime+0
	invoke _DosDateTimeToFileTime, ecx, edx, addr [edi].WIN32_FIND_DATAA.ftLastWriteTime
	movzx ecx, word ptr [edi].WIN32_FIND_DATAA.ftLastAccessTime+2
	movzx edx, word ptr [edi].WIN32_FIND_DATAA.ftLastAccessTime+0
	invoke _DosDateTimeToFileTime, ecx, edx, addr [edi].WIN32_FIND_DATAA.ftLastAccessTime
	movzx ecx, word ptr [edi].WIN32_FIND_DATAA.ftCreationTime+2
	movzx edx, word ptr [edi].WIN32_FIND_DATAA.ftCreationTime+0
	invoke _DosDateTimeToFileTime, ecx, edx, addr [edi].WIN32_FIND_DATAA.ftCreationTime
	ret
	align 4

;*** copy from old dos findfile structure to win32 structure
;*** only needed if LFN functions not supported

copyfileattrs:
	movzx eax,[ebx].DOSFIND.attr
	and al, 37h
	jnz @F
	mov al,FILE_ATTRIBUTE_NORMAL 
@@:
	mov [edi].WIN32_FIND_DATAA.dwFileAttributes,eax

	movzx ecx, [ebx].DOSFIND.filedate
	movzx edx, [ebx].DOSFIND.filetime
	invoke _DosDateTimeToFileTime, ecx, edx, addr [edi].WIN32_FIND_DATAA.ftLastWriteTime
	mov eax, [edi].WIN32_FIND_DATAA.ftLastWriteTime.dwLowDateTime

;--- todo: use int21 , ax=5704 to get last file access date        
;--- todo: use int21 , ax=5706 to get file creation date/time        
;--- OTOH: these functions are only available if LFN is installed
;--- so most likely they will fail anyway
        
	mov [edi].WIN32_FIND_DATAA.ftLastAccessTime.dwLowDateTime,eax
	mov [edi].WIN32_FIND_DATAA.ftCreationTime.dwLowDateTime,eax
	mov eax, [edi].WIN32_FIND_DATAA.ftLastWriteTime.dwHighDateTime
	mov [edi].WIN32_FIND_DATAA.ftLastAccessTime.dwHighDateTime,eax
	mov [edi].WIN32_FIND_DATAA.ftCreationTime.dwHighDateTime,eax
	mov eax, [ebx].DOSFIND.filesize
	mov [edi.WIN32_FIND_DATAA.nFileSizeLow],eax
	mov [edi.WIN32_FIND_DATAA.nFileSizeHigh],0
	mov edx, edi
	lea edi,[edx.WIN32_FIND_DATAA.cFileName]
	lea esi,[ebx.DOSFIND.filename]
	push esi
	mov ecx,13
	rep movsb
	pop esi
	lea edi,[edx.WIN32_FIND_DATAA.cAlternateFileName]
	mov cl,13
	rep movsb
	mov edi, edx
	ret
	align 4

;--- get the volume name by using dos findfirst function call
;--- dont preserve ebx, edi, esi here, should have been done by caller

_GetVolumeName proc public lpRootPathName:ptr byte, lpVolumeNameBuffer:ptr byte, nVolumeNameSize:dword

local	szFind[8]:byte
local	finddata:WIN32_FIND_DATAA
local	dosfnd:DOSFIND

	lea edx,szFind
	mov ecx,lpRootPathName
	mov eax, [ecx]
	mov [edx],eax
	.if (byte ptr [edx+3] == 0)
		mov byte ptr [edx+3],'*'
	.endif
	mov byte ptr [edx+4],0
	lea edi,finddata
	mov si,1		;use dos time/date format
	mov cx,0808h	;get volume label
	mov ax,714Eh
	stc
	int 21h
	.if (!CARRY?)
		mov ebx, eax
		mov ax,71A1h
		int 21h
		lea esi, [edi].WIN32_FIND_DATAA.cFileName
		mov ecx, nVolumeNameSize
		mov edi, lpVolumeNameBuffer
@@:
		lodsb
		and al,al
		stosb
		loopnz @B
		@mov eax, 1
	.elseif (ax == 7100h)
		lea edx,dosfnd
		mov ah,1Ah					   ;set DTA
		int 21h
		lea edx, szFind
		mov dword ptr [edx+3],'*.*'
		mov cx,0808h
		mov ax,4E00h				   ;get first
		int 21h
		.if (!CARRY?)
			lea esi, dosfnd.filename
			mov edi, lpVolumeNameBuffer
			mov ecx, 13
@@:
			lodsb
			stosb
			and al,al
			loopnz @B
			@mov eax, 1
		.else
			xor eax, eax
		.endif
	.else
		xor eax, eax
	.endif
	ret
	align 4
_GetVolumeName endp  

FINDATTR equ 1 + 2 + 4 + 10h	;r/o,hidden,system,dir

FindFirstFileA proc public uses esi edi ebx pFileSpec:ptr BYTE,fbuf:ptr WIN32_FIND_DATAA

local	fspec[80]:byte
local	dosfnd:DOSFIND

	mov edi,fbuf
	mov cl,FINDATTR
	mov ch,0
	mov edx,pFileSpec
if ?CLEARHIGHEBP
	test edx,0FFFF0000h
	jnz error
endif
	mov si,1			;use dos timedate format
	mov ax,714Eh
	stc
	int 21h
	jc @F
if ?VERBOSE        
	@trace <"using LFN version int 21h, ax=714Eh",13,10>
endif        
	push eax
	call transdatetime
	pop eax
	movzx eax,ax
	jmp exit
@@:
	cmp ax,7100h				   ;unsupported function?
	jnz error
	lea edx,dosfnd
	mov ah,1Ah					   ;set DTA
	int 21h
	mov esi, pFileSpec
	lea edi, fspec
	mov ebx, edi
	mov edx, edi
	mov ecx, sizeof fspec-4
	.while (ecx)
		lodsb
		stosb
		.break .if (!al)
		.if ((al == '\') || (al == '/'))
			mov ebx, edi
		.endif
		dec ecx
	.endw
	.if (word ptr [ebx] == '*')
		mov dword ptr [ebx],"*.*"
	.endif
	mov cl,FINDATTR
	mov ch,0
	mov ax,4E00h				   ;get first
	int 21h
	jc error2
	mov edi,fbuf
	lea ebx,dosfnd
	call copyfileattrs
	invoke KernelHeapAlloc, sizeof DOSFIND
	and eax,eax
	jz error
	mov edi,eax
	invoke RtlMoveMemory, edi, ebx, sizeof DOSFIND
	mov eax,edi
exit:
	@trace <"FindFirstFileA(">
	@trace pFileSpec
	@trace <")=">
	@tracedw eax
ifdef _DEBUG
	.if (eax != -1)
		@trace <" [">
		mov ecx, fbuf
		lea ecx, [ecx].WIN32_FIND_DATAA.cFileName
		@trace ecx
		@trace <"]">
	.endif
endif
	@trace <13,10>
	ret
error2:
	cmp ax,12h		;invalid access?
	jnz @F
	mov ax,2		;file not found!
@@:        
if 0
	push eax
	invoke KernelHeapFree, fhandle
	pop eax
endif   
error:
	movzx eax,ax
	invoke SetLastError, eax
	mov eax,INVALID_HANDLE_VALUE  ;error if eax == -1
	jmp exit
	align 4

FindFirstFileA endp

FindNextFileA proc public uses ebx esi edi fhandle:dword,fbuf:ptr WIN32_FIND_DATAA

	mov edi,fbuf
	mov ebx,fhandle
	mov si,1
	mov ax,714Fh
	stc
	int 21h
	jc @F
if ?VERBOSE        
	@trace <"using LFN version int 21h, ax=714Fh",13,10>
endif
	call transdatetime
	jmp success
@@:
	cmp ax,7100h
	jnz error
	mov edx,fhandle
	mov ah,1Ah					   ;set DTA
	int 21h
	mov ah,4Fh					   ;get next
	int 21h
	jc error
	mov edi,fbuf
	mov ebx,fhandle
	call copyfileattrs
success:
	@mov eax,1
	jmp exit
error:
	movzx eax,ax
	invoke SetLastError, eax
	xor eax,eax 				   ;here eax == 0 indicates an error
exit:
	@trace <"FindNextFileA()=">
	@tracedw eax
ifdef _DEBUG
	.if (eax)
		@trace	<" [">
		mov ecx, fbuf
		lea ecx, [ecx].WIN32_FIND_DATAA.cFileName
		@trace ecx
		@trace <"]">
	.endif
endif
	@trace <13,10>
	ret
	align 4

FindNextFileA endp

;*** return: TRUE if ok, else FALSE ***

FindClose proc public uses ebx fhandle:dword

	mov ebx,fhandle
	mov ax,71A1h
	stc
	int 21h
	jnc done
	cmp ax,7100h
	jnz error
	.if (ebx != INVALID_HANDLE_VALUE)
		invoke KernelHeapFree, ebx
	.endif
done:
	@mov eax, 1
exit: 
	@strace <"FindClose(", fhandle, ")=", eax>
	ret
error:
	xor eax,eax
	jmp exit
	align 4

FindClose endp

	END
