
;--- implements DeviceIoControl()

	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option proc:private
	option casemap:none

extern	_VWIN32:abs	;inserts VWIN32 device 
extern	_APIX:abs	;inserts APIX device
extern	_PHYSDRV:abs;inserts PhysicalDriveX device

	include winbase.inc
	include winerror.inc
	include dkrnl32.inc
	include macros.inc

	.CODE

DeviceIoControl proc public handle:dword, dwCtrlCode:dword, 
		pInBuf:ptr, nInBuf:dword, pOutBuf:ptr, nOutBuf:dword, 
		pBytesReturned:ptr dword, pOverlapped:dword

	mov eax,handle
	.if ([eax].FILE.dwType == SYNCTYPE_FILE)
		.if ([eax].FILE.flags & (FF_VXD or FF_DISK or FF_DRIVE or FF_DEVICE))
			invoke [eax].FILE.pVxdHandler, handle, dwCtrlCode, pInBuf, nInBuf, pOutBuf, nOutBuf, pBytesReturned, pOverlapped
			jmp exit
		.endif
	.endif
	invoke SetLastError, ERROR_NOT_SUPPORTED
	xor eax,eax
exit:
	@strace <"DeviceIoControl(", handle, ", ", dwCtrlCode, ", ", pInBuf, ", ", nInBuf, ", ", pOutBuf, ", ", nOutBuf, ", ", pBytesReturned, ", ", pOverlapped, ")=", eax>
ifdef _DEBUG
	mov edx, pOverlapped
	.if (edx)
		@strace <" *pOverlapped ", [edx].OVERLAPPED.Internal, " ", [edx].OVERLAPPED.InternalHigh, " ", [edx].OVERLAPPED.Offset_, " ", [edx].OVERLAPPED.OffsetHigh, " ", [edx].OVERLAPPED.hEvent>
	.endif
endif
	ret
	align 4
DeviceIoControl endp

	end

