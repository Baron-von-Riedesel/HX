
;--- emulation of \\.\PhysicalDriveX and \\.\X:
;--- proc physdrvhandler is called by DeviceIoControl()
;--- to make this code being inserted in dkrnl32, activate
;--- "extern _PHYSDRV" in DeviceIo.ASM


	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:none
	option proc:private
	option dotname

	include winbase.inc
	include winioctl.inc
	include macros.inc
	include vwin32.inc
	include dpmi.inc
	include dkrnl32.inc

	public _PHYSDRV
_PHYSDRV equ 12345678h        

.BASE$DA segment dword public 'DATA'
	VXDENTRY <offset physcompare>
.BASE$DA ends

ife ?FLAT
DGROUP	group .BASE$DA
endif

DAP struct
wSize	dw	?	;size
wSC		dw	?	;max 128 (or 127)
dwBuf	dd	?	;buffer SSSS:OOOO
qwLBA	dq	?	;starting block no
DAP ends

DIOP struct		;for int 21h, ax=7305h
dwSec	dd	?	;sector number
wSC		dw	?	;number of sectors to read/write
dwBuf	dd	?	;buffer address
DIOP ends

EDD struct
wSize	dw ?	;+0
wFlags	dw ?	;+2
dwCyl	dd ?	;+4
dwHeads	dd ?	;+8
dwSecs	dd ?	;+12
qwNumSecs dq ?	;+16
wSecSiz	dw ?	;+24
		dw ?	;+26
EDD ends

DISK_REMOVABLE	equ 4	;wFlags bit

	.code

;--- esi = filename
;--- return NC/C

physcompare proc uses esi edi ebx pszFile:dword

	mov esi,pszFile
	mov ax,[esi]
	cmp ah,':'
	jnz @F
	cmp byte ptr [esi+2],0
	jnz error
	or al,20h
	sub al,'a'-1
	jc error
	cmp al,20h
	jnc error
	mov bh,al
	mov ax,'\'
	shl eax,16
	mov ax,[esi]
	push eax
	invoke GetDriveTypeA, esp
	mov bl,FF_DRIVE
	cmp eax,DRIVE_CDROM
	jnz isdrive
	or bl,FF_CDROM
	dec bh		;int 2fh, ax=1508 starts count with 00
	jmp isdrive
@@:
	mov edi,CStr("physicaldrive")
	mov ecx,13
@@:
	lodsb
	or al,20h
	scasb
	loopz @B
	jnz error
	lodsw
	and ah,ah	;just drives 0-9 supperted!
	jnz error
	sub al,'0'
	mov bh,al
	mov bl,FF_DISK
	jnc isphysdisk
error:
	invoke SetLastError, ERROR_FILE_NOT_FOUND   ;added 01/2014
	or eax,-1
	ret
isphysdisk:
	or bh,80h	;FIXED disks only
	push ebx
	mov dl,bh
	mov bx,55AAh
	mov ah,41h
	int 13h
	mov ecx, ebx
	adc cl,0
	pop ebx
	cmp cx,0AA55h
	jz @F
	mov dl,bh   ;added 01/2014
	push ebx
	mov ah,08
	int 13h
	pop ebx
	jc error
	or bl,FF_CHS
@@:
isdrive:
	invoke KernelHeapAlloc, sizeof FILE
	and eax, eax
	jz error
	mov [eax].FILE.dwType, SYNCTYPE_FILE
	mov [eax].FILE.flags, bl
	mov [eax].FILE.bDrive, bh
	mov [eax].FILE.pHandler, offset physdrvhandler
	ret
	align 4
physcompare endp

;--- read/write physical disks and drives

physdrvhandler proc uses ebx esi edi handle:dword, dwCtrlCode:dword,pInBuf:dword,nInBuf:dword,pOutBuf:dword,nOutBuf:dword,pBytesReturned:ptr dword,pOverlapped:dword

local	dwDosMem:DWORD
local	dwOfs:DWORD
local	rmcs:RMCS

	@strace <"physdrive(", handle, ", ", dwCtrlCode, ", ", pInBuf, ", ", nInBuf, ", ", pOutBuf, ", ", nOutBuf, ",...) enter">
	mov dwDosMem,0
	mov ebx, handle
	mov eax, dwCtrlCode
	cmp eax, FILE_READ_ACCESS
	jz isread
	cmp eax, FILE_WRITE_ACCESS
	jz iswrite
	cmp eax, IOCTL_DISK_GET_DRIVE_GEOMETRY
	jz isdrvgeometry
	cmp eax, IOCTL_DISK_GET_DRIVE_GEOMETRY_EX
	jz isdrvgeometryex
	cmp eax, IOCTL_STORAGE_CHECK_VERIFY
	jz ischeckverify
	invoke SetLastError, ERROR_NOT_SUPPORTED
	xor eax, eax
	jmp exit
	align 4

isread:
	@strace <"physdrive.isread">
	mov eax, nOutBuf
	call getdosbuffer	;get DOS buffer in AX
	jc error
	test [ebx].FILE.flags, FF_DRIVE
	jnz isdrvread
	test [ebx].FILE.flags, FF_CHS
	jnz isread_chs
	@strace <"physdrive.isread, LBA access">
	mov dh,42h			;currently LBA only
	call fillrmcs		;in: DOS buffer segment in AX, out: buffer in ECX
	mov edi, nOutBuf
	call filldap
	mov al,13h
	call dormcall
	jc error
	movzx eax, [esi-10h].DAP.wSC
copyback:
	call setretvalues	;in: ax=sectors read, out: eax=bytes read
copyback2:
	push eax
	invoke RtlMoveMemory, pOutBuf, esi, eax
	pop eax
	call dosignal
	jmp exit
	align 4
isread_chs:
	@strace <"physdrive.isreadchs">
	mov dh,02h			;read CHS
	call fillrmcs		;in: DOS buffer segment in AX, out: buffer in ECX
	mov eax,nOutBuf
	call fillcxdh
	@strace <"physdrive.isreadchs: calling int 13h">
	mov al,13h
	call dormcall
	jc error
	@strace <"physdrive.isreadchs: ok, copy buffer">
	mov eax,nOutBuf
	shr eax,9		;/512
	sub esi,10h
	jmp copyback
	align 4
isdrvread:
	test [ebx].FILE.flags, FF_CDROM
	jnz iscdromread
	mov dx,7305h
	call fillrmcs
	or rmcs.rECX,-1	;CX must be FFFF
	mov edi, nOutBuf
	call filldiop
	@strace <"physdrive.isdrvwrite: calling int 21h, ax=7305h, read, drv=", rmcs.rEDX>
	mov al,21h
	call dormcall
	jc error
	movzx eax, [esi-10h].DIOP.wSC
	jmp copyback
	align 4
iscdromread:			;absolute cdrom read:
	mov dx,1508h	;int 2F, ax=1508h, es:bx=buffer, si:di=start sector
	call fillrmcs	;cx=drive, dx=numSecs
	mov edx, nOutBuf
	add edx, 2048-1
	shr edx, 11		;assume sector size of 2048
	mov rmcs.rEDX, edx
	movzx eax, [ebx].FILE.bDrive
	mov rmcs.rECX, eax
	add rmcs.rEBX,10h	;skip first 16 bytes of buffer
	call fillsidi	;fill SI:DI in rmcs
	mov al,2Fh
	call dormcall
	jc error
	mov eax, nOutBuf
	add esi, dwOfs
	call setretvalues2	;eax=bytes read
	jmp copyback2

iswrite:
	@strace <"physdrive.iswrite">
	mov eax, nInBuf
	call getdosbuffer
	jc error
	test [ebx].FILE.flags, FF_DISK
	jz isdrvwrite
	test [ebx].FILE.flags, FF_CHS
	jnz iswrite_chs
ifdef _DEBUG
	movzx ecx, [ebx].FILE.bDrive
	@strace <"physdrive.iswrite, LBA access, drv=", ecx>
endif
	mov dx,4300h		;LBA access, write without verify
	call fillrmcs
	mov edi, nInBuf
	call filldap
	add ecx, 10h
	invoke RtlMoveMemory, ecx, pInBuf, nInBuf
	mov al,13h
	call dormcall
	jc error
	movzx eax, [esi-10h].DAP.wSC
	call setretvalues
	call dosignal
	jmp exit
	align 4
iswrite_chs:
	@strace <"physdrive.iswritechs">
	mov dh,03h			;write CHS
	call fillrmcs		;in: DOS buffer segment in AX, out: buffer in ECX
	invoke RtlMoveMemory, ecx, pInBuf, nInBuf
	mov eax,nInBuf
	call fillcxdh
	@strace <"physdrive.iswritechs: calling int 13h">
	mov al,13h
	call dormcall
	jc error
	mov eax,nInBuf
	shr eax,9		;/512
	call setretvalues
	call dosignal
	jmp exit
	align 4
isdrvwrite:
ifdef _DEBUG
	movzx ecx, [ebx].FILE.bDrive
	@strace <"physdrive.isdrvwrite: calling int 21h, ax=7305h, write, drv=", ecx>
endif
	mov dx,7305h
	call fillrmcs
	or rmcs.rECX,-1
	or rmcs.rESI, 1	;for write, set bit 0 of SI 
	mov edi, nInBuf
	call filldiop
	add ecx, 10h
	invoke RtlMoveMemory, ecx, pInBuf, nInBuf
	mov al,21h
	call dormcall
	jc error
	movzx eax, [esi-10h].DIOP.wSC
	call setretvalues
	call dosignal
	jmp exit
	align 4

isdrvgeometry:
	call getdrvgeometry
	jc error
	mov eax, sizeof DISK_GEOMETRY
	call dosignal
	jmp exit

isdrvgeometryex:
	call getdrvgeometry
	jc error
	mov edx, eax
	mov eax, sizeof DISK_GEOMETRY
	mov ecx, nOutBuf
	cmp ecx, DISK_GEOMETRY_EX.Data
	jb isg_1

	push edx
	.if edx == DetectExInt13
		invoke _mul64, [esi].EDD.qwNumSecs, [edi].DISK_GEOMETRY.BytesPerSector 
	.else
		mov eax, [edi].DISK_GEOMETRY.TracksPerCylinder
		mul [edi].DISK_GEOMETRY.SectorsPerTrack
		mul dword ptr [edi].DISK_GEOMETRY.Cylinders
		mul [edi].DISK_GEOMETRY.BytesPerSector
	.endif
	mov dword ptr [edi].DISK_GEOMETRY_EX.DiskSize+0, eax
	mov dword ptr [edi].DISK_GEOMETRY_EX.DiskSize+4, edx

	pop edx
	mov esi, edi
	lea edi, [edi+DISK_GEOMETRY_EX.Data]
	mov eax, DISK_GEOMETRY_EX.Data
	cmp ecx, DISK_GEOMETRY_EX.Data + sizeof DISK_PARTITION_INFO
	jb isg_1
	mov [edi].DISK_PARTITION_INFO.SizeOfPartitionInfo, sizeof DISK_PARTITION_INFO
	mov [edi].DISK_PARTITION_INFO.PartitionStyle, PARTITION_STYLE_MBR
;	mov [edi].DISK_PARTITION_INFO.Mbr.Signature, 	;fill with dword at MBR.1B8h
	mov eax, DISK_GEOMETRY_EX.Data + sizeof DISK_PARTITION_INFO
	cmp ecx, DISK_GEOMETRY_EX.Data + sizeof DISK_PARTITION_INFO + sizeof DISK_DETECTION_INFO
	jb isg_1
	lea edi, [edi+sizeof DISK_PARTITION_INFO]
	mov [edi].DISK_DETECTION_INFO.SizeOfDetectInfo, sizeof DISK_DETECTION_INFO
	mov [edi].DISK_DETECTION_INFO.DetectionType, edx
	; todo: fill the Int13 struct
	mov eax, dword ptr [esi].DISK_GEOMETRY.Cylinders
	.if (eax >= 1024)
		mov eax,1023
	.endif
	mov [edi].DISK_DETECTION_INFO.Int13.MaxCylinders, eax
	mov eax, [esi].DISK_GEOMETRY.SectorsPerTrack
	mov [edi].DISK_DETECTION_INFO.Int13.SectorsPerTrack, ax
	mov eax, [esi].DISK_GEOMETRY.TracksPerCylinder
	dec eax
	mov [edi].DISK_DETECTION_INFO.Int13.MaxHeads, ax
	movzx eax,byte ptr @flat:[475h]
	mov [edi].DISK_DETECTION_INFO.Int13.NumberDrives, ax

	mov eax, DISK_GEOMETRY_EX.Data + sizeof DISK_PARTITION_INFO + sizeof DISK_DETECTION_INFO
isg_1:
	call dosignal
	jmp exit

ischeckverify:
	test [ebx].FILE.flags, FF_DRIVE
	jz error
	mov bl,[ebx].FILE.bDrive
	mov ax,4408h
	int 21h
	jc error
	mov eax, 1
	jmp exit
error:
	@strace <"physdrive.error, rmcs.eax=", rmcs.rEAX>
	xor eax, eax
exit:
	cmp dwDosMem,0
	jz @F
	push eax
	mov ax,0101h
	mov edx,dwDosMem
	int 31h
	pop eax
@@:
	ret
	align 4
getdosbuffer:
	cmp eax, 10000h+1	;64 kB is maximum
	cmc
	jc buferr
	push ebx
	mov edx,512-1		;1FF
	test [ebx].FILE.flags, FF_CDROM
	jz @F
	mov edx,2048-1		;7FF
@@:
	test eax,edx
	jz @F
	inc edx
	add eax, edx
@@:
	add eax,sizeof DAP + 16-1
	shr eax,4
	mov ebx,eax
	mov ax,0100h
	int 31h
	pop ebx
	jc buferr
	mov dwDosMem,edx
	retn
buferr:
	invoke SetLastError, ERROR_OUTOFMEMORY
	stc
	@strace <"physdrv.getdosbuffer failed">
	retn
	align 4

;--- fill real-mode call struct
;--- AX=segment value for DS,ES
;--- EDX=value for EAX

fillrmcs:  
	movzx ecx,ax
	shl ecx,4			;ECX=linear address DAP/DIOC
	mov rmcs.rDS, ax
	mov rmcs.rES, ax
	mov esi, eax
	inc esi
	shl esi, 16			;ESI=buffer address in SSSS:OOOO format
	mov rmcs.rEAX, edx
	xor edx, edx
	mov rmcs.rESI, edx	;for int 13h 
	mov rmcs.rEBX, edx	;for int 21h, ax=7305h and int 2Fh, ax=1508h
	mov rmcs.rSSSP, edx
	inc edx
	mov rmcs.rFlags, dx	;set Carry flag (for int 21h, ax=7305h!)
	mov dl,[ebx].FILE.bDrive
	mov byte ptr rmcs.rDX, dl
	retn
	align 4
filldap:
	mov [ecx].DAP.wSize, sizeof DAP
	shr edi, 9		;/512
	mov [ecx].DAP.wSC, di
	mov [ecx].DAP.dwBuf, esi
	call getfpos
	shrd eax, edx, 9
	mov dword ptr [ecx].DAP.qwLBA+0, eax
	shr edx, 9
	mov dword ptr [ecx].DAP.qwLBA+4, edx
	retn
	align 4
fillcxdh: ; fill values for AL/CX/DH for CHS access
	shr eax, 9		;/512
	mov byte ptr rmcs.rAX, al
	call getfpos
	shrd eax, edx, 9
	inc eax			;chs is one-based
	call lba2chs
	mov rmcs.rCX, cx
	mov byte ptr rmcs.rDX+1, dh
	retn
	align 4
lba2chs: ;in: LBA sector in EAX, out: cx=cyl+sec, dh=head
	push ebx
	push eax
	mov ah,08
	mov dl,[ebx].FILE.bDrive
	push es
	int 13h
	pop es
	movzx eax,dh	;get max head
	inc eax
	mov ebx,ecx
	and ebx,3Fh
	mov edi,ebx
	mul ebx
	mov ebx, eax
	pop eax
	div ebx 	   ;gives cyl in eax
	mov ch,al
	mov cl,ah
	shl cl,6
	mov eax,edx
	xor edx,edx
	div edi 	   ;gives head in al
	or cl,dl
	mov dh,al
	pop ebx
	retn
	align 4
filldiop:
	shr edi, 9		;/512
	mov [ecx].DIOP.wSC, di
	mov [ecx].DIOP.dwBuf, esi
	call getfpos
	shrd eax, edx, 9
	mov dword ptr [ecx].DIOP.dwSec, eax
	retn
	align 4
fillsidi:
	call getfpos		;get fpos in EDX:EAX
	mov ecx, eax
	and ecx, 7FFh
	mov dwOfs, ecx
	shrd eax, edx, 11
	mov rmcs.rEDI,eax
	shr eax,16
	mov rmcs.rESI,eax
	retn
	align 4
getfpos:
	mov eax, dword ptr [ebx].FILE.dqPos+0
	mov edx, dword ptr [ebx].FILE.dqPos+4
	mov edi, pOverlapped
	and edi, edi
	jz @F
	mov eax, dword ptr [edi].OVERLAPPED.Offset_+0
	mov edx, dword ptr [edi].OVERLAPPED.Offset_+4
@@:
	retn
	align 4
dormcall:           ;call real-mode interrupt (in AL), registers in rmcs variable
	shr esi, 12		;convert SSSS:0000 to linear address of buffer
	push ebx
	movzx ebx,al
	xor ecx,ecx
	lea edi, rmcs
	mov ax,0300h
	int 31h
	pop ebx
	mov ah,byte ptr rmcs.rFlags
	sahf			;the interesting flag is the Carry flag
	retn
	align 4
setretvalues:
	shl eax, 9
setretvalues2:
	cmp pOverlapped, 0
	jnz @F
	add dword ptr [ebx].FILE.dqPos+0, eax
	adc dword ptr [ebx].FILE.dqPos+4, 0
@@:
	retn
	align 4
dosignal:
	mov ecx, pBytesReturned
	jecxz @F
	mov [ecx], eax
@@:
	mov esi, pOverlapped
	.if (esi)
		mov [esi].OVERLAPPED.InternalHigh, eax
		invoke SetEvent, [esi].OVERLAPPED.hEvent
	.endif
	mov eax,1
	retn

getdrvgeometry:
	mov eax, nOutBuf
	cmp eax, sizeof DISK_GEOMETRY
	jb gdg_error
	test [ebx].FILE.flags, FF_DISK
	jz gdg_error
	test [ebx].FILE.flags, FF_CHS
	jnz noedd

;	mov eax,42h		;size 42h, get a EDD
	mov eax,4Ah		;01/2020: size 4Ah, get a EDD30
	call getdosbuffer
	jc gdg_error

	mov dh,48h      ;value for AH in rmcs
	call fillrmcs	;in: DOS buffer in AX, out: buffer in ECX
;	mov dword ptr [ecx], 42h
	mov dword ptr [ecx], 4Ah	;01/2020: size of EDD30=4Ah
	mov al,13h
	call dormcall
	jc gdg_error
	movzx esi,rmcs.rDS
	shl esi,4
	mov edi, pOutBuf

	mov eax,FixedMedia
	test [esi].EDD.wFlags, DISK_REMOVABLE
	jz @F
	mov eax, RemovableMedia
@@:
	mov [edi].DISK_GEOMETRY.MediaType, eax

	mov eax,dword ptr [esi].EDD.qwNumSecs+0
	mov edx,dword ptr [esi].EDD.qwNumSecs+4

	;--- 01/2014: checking wFlags instead of cylinder value
;	cmp eax, 63*16*16383	;below the 8 GB limit?
;	jbe @F
	test [esi].EDD.wFlags, 2	;CHS values valid?
	jnz @F
	;--- calculate cylinder value
	div [esi].EDD.dwSecs
	xor edx, edx	;just to be sure
	mov ecx, 255	;assume 255 heads
	div ecx
	jmp setgeovals 
@@:
	mov eax,[esi].EDD.dwCyl
	mov ecx,[esi].EDD.dwHeads
setgeovals:
	mov dword ptr [edi].DISK_GEOMETRY.Cylinders+0, eax
	mov dword ptr [edi].DISK_GEOMETRY.Cylinders+4, 0
	mov [edi].DISK_GEOMETRY.TracksPerCylinder, ecx

	mov eax,[esi].EDD.dwSecs
	mov [edi].DISK_GEOMETRY.SectorsPerTrack, eax
	movzx eax,[esi].EDD.wSecSiz
	mov [edi].DISK_GEOMETRY.BytesPerSector, eax
	mov eax,DetectExInt13
	clc
	retn
gdg_error:
	stc
	retn
noedd:
	mov ah,08
	mov dl,[ebx].FILE.bDrive
	push es
	push ebx
	int 13h
	pop ebx
	pop es
	jc gdg_error
	mov edi, pOutBuf
	mov [edi].DISK_GEOMETRY.MediaType, FixedMedia
	mov eax, ecx
	and eax, 03Fh
	mov [edi].DISK_GEOMETRY.SectorsPerTrack, eax
	movzx eax, dh
	inc eax
	mov [edi].DISK_GEOMETRY.TracksPerCylinder, eax
	movzx eax, cl
	shl eax, 2
	mov al, ch
	inc eax
	mov dword ptr [edi].DISK_GEOMETRY.Cylinders+0, eax
	mov dword ptr [edi].DISK_GEOMETRY.Cylinders+4, 0
	mov [edi].DISK_GEOMETRY.BytesPerSector, 200h
	mov eax,DetectInt13
	clc
	retn
	align 4
physdrvhandler endp

	end

