
;--- VWIN32 vxd emulation
;--- proc vwin32handler is called by DeviceIoControl()
;--- to make this code being inserted in dkrnl32, activate
;--- "extern _VWIN32" in DeviceIo.ASM


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

	public	_VWIN32
_VWIN32	equ 12345678h

.BASE$DA segment dword public 'DATA'
	VXDENTRY <offset vwin32compare>
.BASE$DA ends

ife ?FLAT
DGROUP	group .BASE$DA
endif

	.code

;--- esi = filename
;--- return NC/C

vwin32compare proc pszFile:dword

	invoke lstrcmpi, pszFile, CStr("vwin32")
	and eax, eax
	jnz error
	invoke KernelHeapAlloc, sizeof FILE
	and eax, eax
	jz error
	mov [eax].FILE.dwType, SYNCTYPE_FILE
	mov [eax].FILE.flags, FF_VXD
	mov [eax].FILE.pHandler, offset vwin32handler
	ret
error:
	or eax,-1
	ret
	align 4
vwin32compare endp

vwin32handler proc uses esi edi ebx handle:dword, dwCtrlCode:dword,pInBuf:dword,nInBuf:dword,pOutBuf:dword,nOutBuf:dword,pBytesReturned:ptr dword,pOverlapped:dword

	@strace <"vwin32device(", handle, ", ", dwCtrlCode, ", ", pInBuf, ", ", nInBuf, ", ", pOutBuf, ", ", nOutBuf, ",...) enter">
	mov ecx, dwCtrlCode
	cmp ecx,VWIN32_DIOC_DOS_IOCTL		;meant for int 21h, ax=44xx
	jz do_int21_44
	cmp ecx,VWIN32_DIOC_DOS_INT25
	jz do_int25
	cmp ecx,VWIN32_DIOC_DOS_INT26
	jz do_int26
	cmp ecx,VWIN32_DIOC_DOS_INT13
	jz do_int13
	cmp ecx,VWIN32_DIOC_DOS_DRIVEINFO	;meant for int 21h, ax=73xx
	jz do_int21_73
	xor eax, eax
	jmp exit
do_int25:
	call GetRegs
	int 25h
	lea esp,[esp+4]
	jmp done
do_int26:
	call GetRegs
	int 26h
	lea esp,[esp+4]
	jmp done
do_int13:
	call GetRegs
	int 13h
	jmp done
do_int21_73:
do_int21_44:
	call GetRegs
	int 21h
done:
	call PutRegs
	mov eax,nOutBuf
	mov edx,pBytesReturned
	mov [edx],eax
	@mov eax,1
exit:
	@strace <"vwin32device()=", eax>
	ret
GetRegs:
	mov esi,pInBuf
	mov eax,[esi.DIOCRegs.reg_EAX]
	mov ebx,[esi.DIOCRegs.reg_EBX]
	mov ecx,[esi.DIOCRegs.reg_ECX]
	mov edx,[esi.DIOCRegs.reg_EDX]
	mov edi,[esi.DIOCRegs.reg_EDI]
	mov esi,[esi.DIOCRegs.reg_ESI]
	retn
PutRegs:
	push ebp
	mov ebp,pOutBuf
	mov [ebp.DIOCRegs.reg_EAX],eax
	mov [ebp.DIOCRegs.reg_EBX],ebx
	mov [ebp.DIOCRegs.reg_ECX],ecx
	mov [ebp.DIOCRegs.reg_EDX],edx
	mov [ebp.DIOCRegs.reg_EDI],edi
	mov [ebp.DIOCRegs.reg_ESI],esi
	pushfd
	pop [ebp.DIOCRegs.reg_Flags]
	pop ebp
	retn
vwin32handler endp

	end
