
;--- APIX vxd emulation
;--- proc apixhandler is called by DeviceIoControl()
;--- with the first parameter (handle) skipped
;--- to make this code being inserted in dkrnl32, activate
;--- "extern _APIX" in DeviceIo.ASM

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
	include macros.inc
	include dpmi.inc
	include dkrnl32.inc
	include winaspi.inc
	include wnaspi32.inc

?SRBSIZE	equ 64

	public	_APIX
_APIX	equ 12345678h

.BASE$DA segment dword public 'DATA'
	VXDENTRY <offset apixcompare>
.BASE$DA ends

.BASE$XA SEGMENT dword public 'DATA'
	DD offset Deinstall
.BASE$XA ENDS

ife ?FLAT
DGROUP	group .BASE$DA
endif

SRBREQ struct		;size *must* be 12 (or adjust access in _SendASPICommand)
wDosSeg dw ?
		dw ?
pSRB	dd ?
hEvent	dd ?
SRBREQ ends

?MAXREQ	equ 8

@flatmove macro opcode, segreg       
ife ?FLAT
	push segreg
	push @flat
	pop segreg
endif
	rep opcode
ife ?FLAT
	pop segreg
endif
	endm

	.data

g_dwEntry	dd 0
g_dwRMCB	dd 0
g_rmcs		RMCS <>
			align 4
g_dwIndex	dd 0
g_Reqs		SRBREQ ?MAXREQ dup (<>)

	.code

apixcompare proc pszFile:DWORD
	invoke lstrcmpi, pszFile, CStr("apix")
	and eax, eax
	jnz error
	invoke KernelHeapAlloc, sizeof FILE
	and eax, eax
	jz error
	mov [eax].FILE.dwType, SYNCTYPE_FILE
	mov [eax].FILE.flags, FF_VXD
	mov [eax].FILE.pHandler, offset apixhandler
	ret
error:
	or eax,-1
	ret
	align 4
apixcompare endp


Deinstall proc
	@strace <"APIX destructor enter">
if 1
	.while (g_dwIndex)
		mov ecx, g_dwIndex
		mov edx, offset g_Reqs
		.while (ecx)
			movzx eax, [edx].SRBREQ.wDosSeg
			shl eax, 4
			.break .if (@flat:[eax].SRBHDR.SRB_Status == SS_PENDING)
			add edx, sizeof SRBREQ
			dec ecx
		.endw
	.endw
endif
	.if (g_dwRMCB)
		mov cx,word ptr g_dwRMCB+2
		mov dx,word ptr g_dwRMCB+0
		and g_dwRMCB,0
		mov ax,0304h
		int 31h
	.endif
	ret
	align 4
Deinstall endp

AllocRMCB proc uses esi edi
	mov edi, offset g_rmcs
	mov esi, offset rmcallback
	push ds
	push cs
	pop ds
	mov ax,0303h
	int 31h
	pop ds
	jc exit
	mov word ptr g_dwRMCB+0,dx
	mov word ptr g_dwRMCB+2,cx
exit:
	ret
	align 4
AllocRMCB endp        

;--- find real-mode srb from protected mode srb

FindSRB proc pSRB:DWORD
	mov ecx, g_dwIndex
	mov eax, pSRB
	mov edx, offset g_Reqs
	.while (ecx)
		.if (eax == [edx].SRBREQ.pSRB)
			mov ax, [edx].SRBREQ.wDosSeg
			shl eax,16
			ret
		.endif
		add edx, sizeof SRBREQ
		dec ecx
	.endw
	xor eax, eax
	ret
	align 4
FindSRB endp

;--- copy all return values to the win32 SRB
;--- esi=dos/win16 SRB
;--- edi=win32 SRB
;--- ebx=SRBREQ

copy16to32 proc                

	mov al, [edi].SRBHDR.SRB_Cmd
	.if (al == SC_HA_INQUIRY)
		mov eax,@flat:[esi].SRBHDR.SRB_Hdr_Rsvd
		mov [edi].SRBHDR.SRB_Hdr_Rsvd,eax
		push esi
		push edi
		lea esi, [esi].SRB_HAInquiry.HA_Count
		lea edi, [edi].SRB_HAInquiry.HA_Count
		mov ecx, (sizeof SRB_HAInquiry) - SRB_HAInquiry.HA_Count
		@flatmove movsb, ds
		pop edi
		pop esi
	.elseif (al == SC_GET_DEV_TYPE)
		mov al, @flat:[esi].SRB_GDEVBlock16.SRB_DeviceType
		mov [edi].SRB_GDEVBlock.SRB_DeviceType,al
	.elseif (al == SC_EXEC_SCSI_CMD)
		mov al, @flat:[esi].SRB_ExecSCSICmd16.SRB_HaStat
		mov [edi].SRB_ExecSCSICmd.SRB_HaStat,al
		mov al, @flat:[esi].SRB_ExecSCSICmd16.SRB_TargStat
		mov [edi].SRB_ExecSCSICmd.SRB_TargStat,al
		.if ([edi].SRBHDR.SRB_Flags & SRB_DIR_IN)
			push esi
			push edi
			movzx eax, word ptr @flat:[esi].SRB_ExecSCSICmd16.SRB_BufPointer+2
			shl eax, 4
			movzx esi, word ptr @flat:[esi].SRB_ExecSCSICmd16.SRB_BufPointer+0
			add esi, eax
			mov ecx, [edi].SRB_ExecSCSICmd.SRB_BufLen
			mov edi, [edi].SRB_ExecSCSICmd.SRB_BufPointer
ife ?FLAT
			push ds
			push @flat
			pop ds
endif
			mov dl,cl
			shr ecx, 2
			rep movsd
			mov cl,dl
			and cl,3
			rep movsb
ife ?FLAT
			pop ds
endif
			pop edi
			pop esi
		.endif
;--- the BufLen field may return a value (residual byte length) 		   
		mov eax, @flat:[esi].SRB_ExecSCSICmd16.SRB_BufLen
		mov [edi].SRB_ExecSCSICmd.SRB_BufLen, eax

		movzx ecx, @flat:[esi].SRB_ExecSCSICmd16.SRB_CDBLen
		mov dl, @flat:[esi].SRB_ExecSCSICmd16.SRB_SenseLen
		push esi
		push edi
		lea esi, [esi+?SRBSIZE]
		lea edi, [edi].SRB_ExecSCSICmd.CDBByte
		@flatmove movsb, ds
		mov edi, [esp]
		lea edi, [edi].SRB_ExecSCSICmd.SenseArea
;		 mov cl,dl
		mov cl,16
		@flatmove movsb, ds
		pop edi
		pop esi
	.elseif (al == SC_RESET_DEV)
		mov al, @flat:[esi].SRB_BusDeviceReset16.SRB_HaStat
		mov [edi].SRB_BusDeviceReset.SRB_HaStat,al
		mov al, @flat:[esi].SRB_BusDeviceReset16.SRB_TargStat
		mov [edi].SRB_BusDeviceReset.SRB_TargStat,al
;	.elseif (al == SC_SET_HA_PARMS)
	.elseif (al == SC_GET_DISK_INFO)
		mov eax, dword ptr @flat:[esi].SRB_GetDiskInfo16.SRB_DriveFlags
		mov dword ptr [edi].SRB_GetDiskInfo.SRB_DriveFlags,eax
;	.elseif (al == SC_RESCAN_SCSI_BUS)
	.elseif (al == SC_GETSET_TIMEOUTS)
		mov eax, @flat:[esi].SRB_GetSetTimeouts16.SRB_Timeout
		mov [edi].SRB_GetSetTimeouts.SRB_Timeout,eax
	.endif
;--- copy the status at last (in case the client is polling!)
	mov al,@flat:[esi].SRBHDR.SRB_Status
	mov [edi].SRBHDR.SRB_Status,al
	ret
	align 4

copy16to32 endp                

;--- copy input values to the dos/win16 SRB
;--- esi=win32 SRB
;--- edi=dos/win16 SRB
;--- ebx=SRBREQ

copy32to16 proc dwExtraBytes:DWORD

local	dwBuffer:dword

	push edi
	mov eax, [esi+0]
ife ?FLAT
	push es
	push @flat
	pop es
endif
	stosd
	mov eax, [esi+4]
	stosd
	xor eax, eax
	mov ecx, (?SRBSIZE-8)/4
	rep stosd
ife ?FLAT
	pop es
endif
	pop edi
	mov al, [esi].SRBHDR.SRB_Cmd
	.if (al == SC_HA_INQUIRY)
	.elseif (al == SC_GET_DEV_TYPE)
		mov ax, word ptr [esi].SRB_GDEVBlock.SRB_Target
		mov word ptr @flat:[edi].SRB_GDEVBlock16.SRB_Target,ax
	.elseif (al == SC_EXEC_SCSI_CMD)
		mov eax, dwExtraBytes
		lea eax, [eax + edi + ?SRBSIZE]
		mov dwBuffer, eax
ifdef _DEBUG
		movzx eax, [esi].SRB_ExecSCSICmd.SRB_CDBLen
		movzx ecx, [esi].SRB_ExecSCSICmd.SRB_SenseLen
		@strace <"SendASPICommand, EXEC SCSI, buffer=", [esi].SRB_ExecSCSICmd.SRB_BufPointer, ",", [esi].SRB_ExecSCSICmd.SRB_BufLen, " CDBlen=", eax, " SenseLen=", ecx>
endif
		mov ax, word ptr [esi].SRB_ExecSCSICmd.SRB_Target
		mov word ptr @flat:[edi].SRB_ExecSCSICmd16.SRB_Target,ax
		.if ([esi].SRBHDR.SRB_Flags & SRB_DIR_OUT)
			push edi
			push esi
			mov edi, dwBuffer
			mov ecx, [esi].SRB_ExecSCSICmd.SRB_BufLen
			mov esi, [esi].SRB_ExecSCSICmd.SRB_BufPointer
ife ?FLAT
			push es
			push @flat
			pop es
endif
			mov dl,cl
			shr ecx, 2
			rep movsd
			mov cl,dl
			and cl,3
			rep movsb
ife ?FLAT
			pop es
endif
			pop esi
			pop edi
		.endif
		.if ([esi].SRB_ExecSCSICmd.SRB_BufLen)
			mov eax, dwBuffer
			mov ecx, edi
			sub eax, ecx
			mov word ptr @flat:[edi].SRB_ExecSCSICmd16.SRB_BufPointer+0, ax
			shr ecx, 4
			mov word ptr @flat:[edi].SRB_ExecSCSICmd16.SRB_BufPointer+2, cx
		.else
			mov @flat:[edi].SRB_ExecSCSICmd16.SRB_BufPointer, 0
		.endif
		mov eax, [esi].SRB_ExecSCSICmd.SRB_BufLen
		mov @flat:[edi].SRB_ExecSCSICmd16.SRB_BufLen, eax
		mov eax, g_dwRMCB
		mov @flat:[edi].SRB_ExecSCSICmd16.SRB_PostProc, eax
		.if (@flat:[edi].SRBHDR.SRB_Flags & SRB_EVENT_NOTIFY)
			or	@flat:[edi].SRBHDR.SRB_Flags, SRB_POSTING			;enable posting
			and @flat:[edi].SRBHDR.SRB_Flags, not SRB_EVENT_NOTIFY	;disable events
		.endif
		mov al, [esi].SRB_ExecSCSICmd.SRB_CDBLen
		mov ah, [esi].SRB_ExecSCSICmd.SRB_SenseLen
		mov @flat:[edi].SRB_ExecSCSICmd16.SRB_CDBLen,al
		mov @flat:[edi].SRB_ExecSCSICmd16.SRB_SenseLen,ah
		movzx ecx, al
		push edi
		push esi
		lea edi, [edi+?SRBSIZE]
		lea esi, [esi].SRB_ExecSCSICmd.CDBByte
		@flatmove movsb, es
		mov cl,ah
		mov al,0
		@flatmove stosb, es 		   
		pop esi
		pop edi
	.elseif (al == SC_ABORT_SRB)
		invoke FindSRB, [esi].SRB_Abort.SRB_ToAbort
		mov @flat:[edi].SRB_Abort16.SRB_ToAbort, eax
	.elseif (al == SC_RESET_DEV)
		mov ax, word ptr [esi].SRB_BusDeviceReset.SRB_Target
		mov word ptr @flat:[edi].SRB_BusDeviceReset16.SRB_Target,ax
		mov eax, g_dwRMCB
		mov @flat:[edi].SRB_BusDeviceReset16.SRB_PostProc, eax
		.if (@flat:[edi].SRBHDR.SRB_Flags & SRB_EVENT_NOTIFY)
			or	@flat:[edi].SRBHDR.SRB_Flags, SRB_POSTING			;enable posting
			and @flat:[edi].SRBHDR.SRB_Flags, not SRB_EVENT_NOTIFY	;disable events
		.endif
	.elseif (al == SC_SET_HA_PARMS)
		push esi
		push edi
		lea esi, [esi+sizeof SRBHDR]
		lea edi, [edi+sizeof SRBHDR]
ife ?FLAT
		push es
		push @flat
		pop es
endif
		movsd
		movsd
		movsd
		movsd
ife ?FLAT	
		pop es
endif
		pop edi
		pop esi
	.elseif (al == SC_GET_DISK_INFO)
		mov ax, word ptr [esi].SRB_GetDiskInfo.SRB_Target
		mov word ptr @flat:[edi].SRB_GetDiskInfo16.SRB_Target,ax
;	 .elseif (al == SC_RESCAN_SCSI_BUS)
	.elseif (al == SC_GETSET_TIMEOUTS)
		mov ax, word ptr [esi].SRB_GetSetTimeouts.SRB_Target
		mov word ptr @flat:[edi].SRB_GetSetTimeouts16.SRB_Target,ax
		mov eax, [esi].SRB_GetSetTimeouts.SRB_Timeout
		mov @flat:[edi].SRB_GetSetTimeouts16.SRB_Timeout,eax
	.endif
	ret
	align 4

copy32to16 endp

;--- request completed
;--- dwReq: linear address of real mode SRB
;--- this proc may be called from an ISR, interrupts disabled and SS==LPMS!

FreeSrb16 proc uses ebx edi esi dwReq:DWORD

	mov ecx, g_dwIndex
	mov ebx, offset g_Reqs
	mov eax, dwReq
	shr eax, 4
	.while (ecx)
		.if (ax == [ebx].SRBREQ.wDosSeg)
			push ecx
			mov esi, dwReq
			mov edi, [ebx].SRBREQ.pSRB
			invoke copy16to32
			mov ax, [ebx].SRBREQ.wDosSeg
			invoke _freedosmem
ifdef _DEBUG                
			movzx eax, [edi].SRBHDR.SRB_Status
endif
			@strace <"FreeSrb16: SRB ", edi, " status=", eax>
			.if ([ebx].SRBREQ.hEvent)
				invoke SetEvent, [ebx].SRBREQ.hEvent
			.endif
			pop ecx
			lea esi, [ebx+sizeof SRBREQ]
			push edi
			mov edi, ebx
			dec ecx
			.while (ecx)
				movsd
				movsd
if sizeof SRBREQ gt 8                    
				movsd                    
endif                    
				dec ecx
			.endw
			dec g_dwIndex
			pop edi
			.if ([edi].SRBHDR.SRB_Flags & SRB_POSTING)
				@strace <"FreeSrb16: SRB posting enabled!!!">
				.if ([edi].SRBHDR.SRB_Cmd == SC_EXEC_SCSI_CMD)
					push edi
					call [edi].SRB_ExecSCSICmd.SRB_PostProc
					add esp,4
				.endif
			.endif
			.break
		.endif
		add ebx, sizeof SRBREQ
		dec ecx
	.endw
	ret
	align 4

FreeSrb16 endp

;--- ASPI post proc (asynchronous command)
;--- the SRB is on the real-mode stack (DS:ESI)

rmcallback proc

	push es
	push ds
ife ?FLAT
	push @flat
	mov @flat,cs:[g_flatsel]
endif
	cld
	lodsd							;get the return address
	mov es:[edi].RMCS.rCSIP, eax
	mov es:[edi].RMCS.rSP, si
if 0;def _DEBUG 
	or byte ptr es:[edi].RMCS.rFlags+1,1	;set trace flag to stop in rm
endif
	lodsd							;get the real-mode SRB address
	mov ds, cs:[g_csalias]
	push ds
	pop es
	shr eax,12						;offset is always 0000
	invoke FreeSrb16, eax
ife ?FLAT
	pop @flat
endif
	pop ds
	pop es
	@iret
	align 4

rmcallback endp

;--- a SRB (SCSI Request Block) is 64 bytes long

_SendASPICommand proc uses ebx esi edi pSRB:DWORD, pOverlapped:DWORD

local	dwDosAddr:dword
local	dwExtraBytes:dword
local	rmcs:RMCS

	mov esi, pSRB
ifdef _DEBUG        
	movzx eax,[esi].SRBHDR.SRB_Cmd
	movzx ecx,[esi].SRBHDR.SRB_Status
	movzx ebx,[esi].SRBHDR.SRB_HaId
	movzx edx,[esi].SRBHDR.SRB_Flags
	@strace <"SendASPICommand(header=", eax, " ", ecx, " ", ebx, " ", edx , " ", dword ptr [esi+4], ")">
endif        
	.if (!g_dwRMCB)
		invoke AllocRMCB
		cmp g_dwRMCB,0
		jz error2
	.endif
	mov bx, ?SRBSIZE / 16
	mov dwExtraBytes, 0
	.if ([esi].SRBHDR.SRB_Cmd == SC_EXEC_SCSI_CMD)
		movzx eax, [esi].SRB_ExecSCSICmd.SRB_CDBLen
		movzx ecx, [esi].SRB_ExecSCSICmd.SRB_SenseLen
		add eax, ecx
		add eax, 4
		and al,0FCh
		mov dwExtraBytes, eax
		add eax, [esi].SRB_ExecSCSICmd.SRB_BufLen
		shr eax, 4
		inc eax
		cmp eax, 0FFF8h
		jnc error5
		add bx, ax
	.endif
	invoke _allocdosmem
	jc error3
	mov ecx, g_dwIndex
	cmp ecx, ?MAXREQ
	jnc error1
	inc g_dwIndex
	shl ecx,2								;*4
	lea ebx, [ecx*2 + ecx + offset g_Reqs]	;*3 = *12
	mov [ebx].SRBREQ.wDosSeg,ax
	shl eax, 16
	push eax			;push the SRB address SSSS:OOOO onto the stack
	shr eax, 12
	mov dwDosAddr,eax
	mov edi, eax
	mov [ebx].SRBREQ.pSRB, esi
	mov eax, pOverlapped
	.if (eax)
		mov eax, [eax].OVERLAPPED.hEvent
	.endif
	mov [ebx].SRBREQ.hEvent,eax
	invoke copy32to16, dwExtraBytes
	mov rmcs.rSSSP, 0
	mov eax, g_dwEntry
	mov rmcs.rCSIP, eax
	mov rmcs.rFlags,0

ifdef _DEBUG            
	mov al, [esi].SRBHDR.SRB_Cmd
	.if (al == SC_EXEC_SCSI_CMD)
		movzx ecx, [esi].SRB_ExecSCSICmd.SRB_Target
		movzx eax, [esi].SRB_ExecSCSICmd.SRB_Lun
		movzx edx, [esi].SRB_ExecSCSICmd.CDBByte
		@strace <"Exec SCSI IO Target=", ecx, " Lun=", eax, " CCB-Command=", edx, " rm-srb=", edi>
	.elseif (al == SC_ABORT_SRB)
		@strace <"Abort SRB srb=", [esi].SRB_Abort.SRB_ToAbort, " rm-srb=", @flat:[edi].SRB_Abort16.SRB_ToAbort>
	.endif
endif
	lea edi, rmcs
	mov bx,0000h
	mov cx,2			;copy 2 words to real-mode stack
	mov ax,0301h
	int 31h
	lea esp, [esp+4]
	mov eax, dwDosAddr
	.if (@flat:[eax].SRBHDR.SRB_Status != SS_PENDING)
		invoke FreeSrb16, eax
	.endif
if 0
	test rmcs.rFlags,1
	jnz error4
endif
	@mov eax,1
	jmp exit
error1:
	invoke _freedosmem		;segment in AX
	mov [esi].SRBHDR.SRB_Status, SS_ASPI_IS_BUSY
	@strace <"SendASPICommand: too many open SRBs error">
	jmp errorX
error2:
	mov [esi].SRBHDR.SRB_Status, SS_INSUFFICIENT_RESOURCES
	@strace <"SendASPICommand: no realmode callback error">
	jmp errorX
error3:
	mov [esi].SRBHDR.SRB_Status, SS_ASPI_IS_BUSY
	@strace <"SendASPICommand: dos alloc memory error">
	jmp errorX
if 0        
error4:
	@strace <"SendASPICommand: realmode ASPI returned with Carry">
	jmp errorX
endif
error5:
	mov [esi].SRBHDR.SRB_Status, SS_BUFFER_TO_BIG
	@strace <"SendASPICommand: buffer too big">
	jmp errorX
errorX:
;	xor eax, eax
	@mov eax, 1
exit:
	ret
	align 4

_SendASPICommand endp

apixhandler proc uses esi edi ebx handle:dword, dwCtrlCode:dword, pInBuf:ptr, nInBuf:dword,
		pOutBuf:ptr, nOutBuf:dword, pBytesReturned:ptr dword, pOverlapped:dword

	@strace <"apixdevice(", handle, ", ", dwCtrlCode, ") enter">
	mov esi,pInBuf
	.if (dwCtrlCode == 1)		;get version
		invoke _lopen, CStr("SCSIMGR$"), OF_READ
		.if (eax != -1)
			mov ebx, eax
			mov ax,4402h
			mov cx,4
			mov edx, offset g_dwEntry
			int 21h
			invoke CloseHandle, ebx
			mov eax, g_dwEntry
			.if (eax)
				mov ecx, pOutBuf
				mov edx, pBytesReturned
				mov dword ptr [ecx],1
				mov dword ptr [edx],4
				mov eax,1
			.endif
		.else
			xor eax, eax
		.endif
	.elseif (dwCtrlCode == 3)	;SendASPI32Command
		mov eax, g_dwEntry
		.if (eax)
			invoke _SendASPICommand, esi, pOverlapped
		.endif
	.else
		@strace <"apixdevice: control code ", dwCtrlCode, " not implemented">
		xor eax, eax
	.endif
	@strace <"apixdevice()=", eax>
	ret
	align 4

apixhandler endp

	end

