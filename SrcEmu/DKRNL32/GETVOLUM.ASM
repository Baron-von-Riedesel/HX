
	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:none

	include winbase.inc
	include dkrnl32.inc
	include macros.inc

extern __CHECKOS:abs	;avoid NT LFN bug

VOLINFO	struct
		dw ?
serno	dd ?
label_	db 11 dup (?)	;the volume label may NOT be returned by 440d,66
system	db 8 dup (?)
VOLINFO	ends

_GetVolumeName proto :ptr byte, :ptr byte, :dword

	.CODE

;--- lpRootPathName may be NULL
;--- lpVolumeNameBuffer may be NULL
;--- lpVolumeSerialNumber may be NULL
;--- lpFileSystemNameBuffer may be NULL

GetVolumeInformationA proc public uses ebx esi edi lpRootPathName:ptr BYTE,
		lpVolumeNameBuffer:ptr BYTE, nVolumeNameSize:DWORD,
		lpVolumeSerialNumber:ptr DWORD,lpMaximumComponentLength:ptr DWORD,
		lpFileSystemFlags:ptr DWORD,
		lpFileSystemNameBuffer:ptr BYTE, nFileSystemNameSize:DWORD

local	volinfo:VOLINFO
local	bLFN:BYTE
local	szDrv[4]:byte
local	szFileSystemName[32]:byte
 
	mov bLFN, TRUE
	mov edx, lpRootPathName				;edx==0 is supported!
	and edx, edx
	jnz @F
	mov ah,19h
	int 21h
	movzx eax,al
	add eax,'\:A'
	mov dword ptr szDrv,eax
	lea edx,szDrv
	mov lpRootPathName, edx
@@:
	mov edi, lpFileSystemNameBuffer
	mov ecx, nFileSystemNameSize
	and edi,edi
	jnz @F
	lea edi, szFileSystemName
	mov ecx, sizeof szFileSystemName
@@:
	mov ax,71A0h
	stc
	int 21h
	jnc @F
	cmp ax,7100h
	jnz error1
	invoke GetDriveTypeA, lpRootPathName
	cmp eax, DRIVE_NO_ROOT_DIR
	jz error2
	mov cx, 11
	mov bx, 0
	mov bLFN, FALSE
@@:
	mov eax, lpMaximumComponentLength
	.if (eax)
		movzx ecx, cx			;cx=max file name length
		mov [eax], ecx
	.endif
	mov eax, lpFileSystemFlags
	.if (eax)
		movzx ebx,bx
		mov [eax], ebx
	.endif
	.if ((lpVolumeNameBuffer) && (nVolumeNameSize))
		invoke _GetVolumeName, lpRootPathName, lpVolumeNameBuffer, nVolumeNameSize
	.endif
	@mov eax, 1
	.if ((bLFN == FALSE) || lpVolumeSerialNumber)
		mov ecx,lpRootPathName
		.if (ecx && (byte ptr [ecx+1] == ':'))
			mov bl,[ecx]
			or bl,20h
			sub bl,'a'-1
		.else
			mov bl,0
		.endif
		mov ch,48h			;FAT32
		mov cl,66h			;get volume serial number
		lea edx, volinfo
		mov word ptr [edx],0
		mov [edx].VOLINFO.system,0
		mov [edx].VOLINFO.serno,0
		mov [edx].VOLINFO.label_,0
		mov ax,440Dh
		int 21h
if 0
		jc done
endif
		mov edi, lpFileSystemNameBuffer
		.if ((bLFN == FALSE) && edi)
			mov ecx, nFileSystemNameSize
			.if (ecx > sizeof VOLINFO.system)
				mov ecx, sizeof VOLINFO.system
				mov byte ptr [edi+sizeof VOLINFO.system],0
			.endif
			lea esi, volinfo.system
			rep movsb
		.endif
		mov ecx,lpVolumeSerialNumber
		.if (ecx)
			mov eax, volinfo.serno
			mov [ecx],eax
		.endif
done:
		@mov eax,1
	.endif
exit@: 
ifdef _DEBUG
	mov ecx,lpRootPathName
	.if (!ecx)
		mov ecx,CStr("NULL")
	.endif
	mov edx, lpVolumeNameBuffer
	.if (!edx)
		mov edx,CStr(<"NULL">)
	.endif
	mov ebx,lpFileSystemNameBuffer
	.if (!ebx)
		mov ebx, CStr(<"NULL">)
	.endif
	@strace <"GetVolumeInformationA(", &ecx, ", ", &edx, ", ", nVolumeNameSize, ", ", lpVolumeSerialNumber, ", ", lpMaximumComponentLength, ", ", lpFileSystemFlags, ", ", &ebx, ", ", nFileSystemNameSize, ")=", eax>
endif
	ret
error1:
	@strace <"int 21h, ax=71A0h failed, eax=", eax>
error2:
	xor eax,eax 		;0 = failure
	jmp exit@
	align 4
GetVolumeInformationA endp

GetVolumeInformationW proc public lpRootPathName:ptr WORD,
		lpVolumeNameBuffer:ptr WORD, nVolumeNameSize:DWORD,
		lpVolumeSerialNumber:ptr DWORD,lpMaximumComponentLength:ptr DWORD,
		lpFileSystemFlags:ptr DWORD,
		lpFileSystemNameBuffer:ptr WORD, nFileSystemNameSize:DWORD

local	pszAStr:dword
local	pszAStr2:dword

	mov eax, lpRootPathName
	.if (eax)
		call ConvertWStr
	.endif
	mov ecx, nVolumeNameSize
	sub esp, ecx
	mov pszAStr, esp
	mov ecx, nFileSystemNameSize
	sub esp, ecx
	mov pszAStr2, esp
	invoke GetVolumeInformationA, eax, pszAStr, nVolumeNameSize,\
		lpVolumeSerialNumber,lpMaximumComponentLength, lpFileSystemFlags,\
		pszAStr2, nFileSystemNameSize
	.if (eax)
		invoke ConvertAStrN, pszAStr, lpVolumeNameBuffer, nVolumeNameSize
		invoke ConvertAStrN, pszAStr2, lpFileSystemNameBuffer, nFileSystemNameSize
	.endif
	@strace <"GetVolumeInformationW()=", eax>
	ret
	align 4

GetVolumeInformationW endp

	end

