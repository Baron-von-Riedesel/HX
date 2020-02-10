
;--- communication API
;--- implements:
;--- BuildCommDCB 
;--- BuildCommDCBAndTimeouts
;--- ClearCommBreak
;--- ClearCommError
;--- CommConfigDialogA (NO!)
;--- EscapeCommFunction
;--- GetCommConfig
;--- GetCommMask
;--- GetCommModemStatus
;--- GetCommProperties
;--- GetCommState
;--- GetCommTimeouts
;--- GetDefaultCommConfigA
;--- PurgeComm
;--- SetCommBreak
;--- SetCommConfig
;--- SetCommMask
;--- SetCommState
;--- SetCommTimeouts
;--- SetDefaultCommConfigA
;--- SetupComm 
;--- TransmitCommChar
;--- WaitCommEvent

;--- besides the COMM API there are also exits implemented for
;--- CreateFile() [files "COMx"]
;--- CloseHandle()
;--- ReadFile()/WriteFile()

;--- devices supported are "COM1"-"COM4"!

?BUFFSIZE	equ 2048		;default buffer size for input/output
?MAXCOM		equ 4           ;there are max 4 BIOS serial ports
?INTSRC		equ 1+2+4		;bits to enable in IER
?SIMPLETO	equ 1			;do simple timeout checks based on timer ticks

?CHKDSR		equ 0 			;obsolete: check DSR before send

.BASE$IA SEGMENT dword public 'DATA'
		DD offset InstallComm
.BASE$IA      ENDS

externdef g_ComHandler:dword	;the CreateFile() exit for "COMx" files

ComOpen      proto stdcall :ptr COMMDESC
ComClose     proto stdcall :ptr COMMDESC
ComSetRate   proto stdcall :ptr COMMDESC
ComGetRate   proto stdcall :ptr COMMDESC
ComWriteBuf  proto stdcall :ptr COMMDESC, buffer:ptr BYTE, count:dword
ComReadBuf   proto stdcall :ptr COMMDESC, buffer:ptr BYTE, count:dword
ComWriteChar proto stdcall :ptr COMMDESC, char:dword

ComInitDCB        proto stdcall comno:dword, :ptr DCB
ComInitCommConfig proto stdcall comno:dword, :ptr COMMCONFIG

ComSetTimeouts proto stdcall comno:dword, :ptr COMMTIMEOUTS

;--- ComOpen: open a COM device (alloc buffers, enable IRQ)
;--- ComClose: close a COM device (dealloc buffers, disable IRQ)
;--- ComSetRate: set BaudRate
;--- ComGetRate: get BaudRate
;--- ComWriteBuf: write into buffer
;--- ComReadBuf: read from buffer
;--- ComWriteChar: write a byte directly to UART, bypassing buffer

;--- buffer descriptor
;--- 2 buffers for input and output are attached to each COM device
;--- they are created when ReadFile/WriteFile is called the first time
;--- and destroyed when the device is closed (CloseHandle)

BUFFERDESC struct
pCurr	dd ?	;next address for buffer clear 
pNext	dd ?	;next address for buffer fill
dwFree	dd ?	;free bytes in buffer
pEnd	dd ?	;end of buffer
pStart	dd ?	;start of buffer (=handle)
BUFFERDESC ends

;--- to store all information for a comm device
;--- the following internal structure is used

COMMDESC struct
newvec		DD ?		;new value for IRQ vector
oldvec		DF ?		;saved old IRQ vector
flags		DB ?		;flags, see below
irqint  	DB ?		;interrupt vector number for COM IRQ
port		DD ?		;port base, read from BIOS 400h+x
evntmask	DWORD ?		;event mask get/set with GetCommMask/SetCommMask
error		WORD ?		;error status (CE_xxx) (is just a word)
bLSRMST		BYTE ?		;LSRMST escape character
			BYTE ?
dcb 		DCB <>		;DCB set by SetCommState
ife ?SIMPLETO
readtimer	DWORD ?		;timer for read
writetimer	DWORD ?		;timer for write
endif
timeouts	COMMTIMEOUTS <>	;timeouts set by SetCommTimeouts
inbufsiz	DWORD ?		;recommended size input buffer (set by SetupComm)
outbufsiz	DWORD ?		;recommended size output buffer (set by SetupComm)
inbuf		BUFFERDESC <>	;input buffer
outbuf		BUFFERDESC <>	;output buffer
COMMDESC ends

;--- values for flags
CDF_XOFF 	equ 1	;XOFF received, transfer stops
CDF_ERROR	equ 2	;error flag (cleared by ClearCommError)
CDF_BREAK	equ 4	;break on
CDF_EVNTCHAR equ 8	;event character received
CDF_PURGETX	equ 16	;purge all async WriteFile
CDF_PURGERX	equ 32	;purge all async ReadFile

		.DATA

irqinit DB 4,3,4,3			;IRQ # for COM1 - COM4
vecinit	dd Com1Irq, Com2Irq, Com3Irq, Com4Irq

		.DATA?
        
commdescs label COMMDESC
        COMMDESC ?MAXCOM dup (<?>)

endif

		.CODE

;--- enable the COMM low-level API exit.
;--- if this is not done, trying to open "COMx" will
;--- just use plain DOS.

InstallComm proc 
		mov [g_ComHandler],offset HandleComOpen
		invoke ZeroMemory, offset commdescs, sizeof COMMDESC * ?MAXCOM
		ret
		align 4
InstallComm endp

;--- CreateFile stack frame structure

CREFILE struct
		dd ?	;old value of EBP, don't touch
		dd ?	;CreateFile caller, don't touch
fname	dd ?	;filename (also in ESI)
access	dd ?	;access (read,write, read+write)
share	dd ?	;share (COMx access must be exclusive)
secur	dd ?	;NULL
creation dd ?	;COMx is never "created", must be OPEN_EXISTING
attrib	dd ?
handle	dd ?	;NULL
CREFILE ends

;--- HandleComOpen: CreateFile() exit for COMx files.
;--- register values setup on entry:
;--- ebp=ptr CREFILE
;--- esi=filename ("COM1", ...)
;--- out: eax=handle (or -1)
;--- no need to preserve EBX, ESI or EDI here!

HandleComOpen proc
		@strace <"HandleComOpen called, name is ", &esi>
		mov al,0	 ;read only
		test [ebp].CREFILE.access, GENERIC_WRITE
		jz @F
		mov al,2	  ;read+write
		test [ebp].CREFILE.access, GENERIC_READ
		jnz @F
		mov al,1
@@:
		mov edx,esi
		xor ecx,ecx
		mov ah,3Dh	  ;use DOS to open the file and check if this COM is ok.
		int 21h
		jc failed
		movzx ebx,ax

;--- check if the handle is a device or a file!
;--- if it is a file, don't do anything special and exit.

		mov ax,4400h
		int 21h
		jc @F
		mov eax,ebx
		test dl,80h	;is it a file? then exit!
		jz exit
@@:

;--- create a kernel FILE object

		invoke KernelHeapAlloc, sizeof FILE
		and eax, eax
		jz failed2
		mov dword ptr [eax-4], offset destructor
		mov [eax].FILE.dwType, SYNCTYPE_FILE
		mov [eax].FILE.flags, FF_DEVICE
		mov [eax].FILE.pHandler, offset comrwhandler
		mov [eax].FILE.wDOSFH, bx
		mov cl,[esi+3]
		sub cl,'0'
		mov [eax].FILE.bDevice,cl	;1=COM1, 2=COM2, ...
		mov ebx, eax

;--- store a pointer to the COMDESC structure in the FILE's pParam

		dec ecx
		mov eax, sizeof COMMDESC
		mul ecx
		add eax, offset commdescs
		mov [ebx].FILE.pParams, eax

;--- initialize some fields in the COMMDESC structure

		mov edx,@flat:[ecx*2+400h]
		mov [eax].COMMDESC.port, edx

		mov dl,byte ptr [ecx*1+offset irqinit]
		add dl,8
		mov [eax].COMMDESC.irqint,dl

		mov edx,[ecx*4+offset vecinit]
		mov [eax].COMMDESC.newvec,edx

		mov [eax].COMMDESC.flags,0
		mov [eax].COMMDESC.error,0
		mov [eax].COMMDESC.evntmask,0

;--- init the DCB
        
		inc ecx
		add eax, COMMDESC.dcb

		invoke ComInitDCB, ecx, eax

		mov eax, ebx
exit:
		@strace <"HandleComOpen: handle=", eax>
		ret
failed:
		movzx eax,ax
		invoke SetLastError, eax
		jmp @F
failed2:
		mov ah,3Eh
		int 21h
@@:
		@strace <"HandleComOpen: open failed">
		or eax,-1
		ret
		align 4
HandleComOpen endp

;--- CloseHandle() exit

destructor proc uses ebx edi pThis:DWORD
		@strace <"com destructor enter">
		mov ebx,pThis
		.if ([ebx].FILE.dwType == SYNCTYPE_FILE)
			.if ([ebx].FILE.flags & FF_DEVICE)
				mov edi,[ebx].FILE.pParams
ife ?SIMPLETO
				xor ecx, ecx
				xchg ecx, [edi].COMMDESC.readtimer
				.if (ecx)
					invoke CloseHandle, ecx
				.endif
				xor ecx, ecx
				xchg ecx, [edi].COMMDESC.writetimer
				.if (ecx)
					invoke CloseHandle, ecx
				.endif
endif                
				invoke ComClose, edi		;destroy buffer, reset IRQ proc
				mov bx,[ebx].FILE.wDOSFH	;close the DOS file handle
				mov ah,3Eh
				int 21h
			.endif
		.endif
		@mov eax,1		;tell CloseHandle to free memory
		ret
		align 4
destructor endp

if ?SIMPLETO

;--- calculate the number of ms for timeout
;--- eax=ctrlcode 
;--- ecx=bytes to transfer
;--- edi=COMMDESC

gettimeoutvalue proc uses esi
		xor esi, esi
		.if (eax == FILE_WRITE_ACCESS)
			.if ([edi].COMMDESC.timeouts.WriteTotalTimeoutMultiplier || [edi].COMMDESC.timeouts.WriteTotalTimeoutConstant)
				mov eax,[edi].COMMDESC.timeouts.WriteTotalTimeoutMultiplier
				mul ecx
				add eax,[edi].COMMDESC.timeouts.WriteTotalTimeoutConstant
			.endif
			mov esi, eax
		.else
			.if ([edi].COMMDESC.timeouts.ReadTotalTimeoutMultiplier || [edi].COMMDESC.timeouts.ReadTotalTimeoutConstant)
				mov eax,[edi].COMMDESC.timeouts.WriteTotalTimeoutMultiplier
				mul ecx
				add eax,[edi].COMMDESC.timeouts.WriteTotalTimeoutConstant
			.endif
			mov esi, eax
		.endif
		.if (esi)
			invoke GetTickCount
			add esi, eax
		.endif
		mov eax, esi
		ret
		align 4
gettimeoutvalue endp

endif

;--- async read/write for overlapped operation
;--- this runs in a separate thread

asyncrw proc uses ebx edi esi pVoid:ptr ASYNCFILE

local	flags:dword
local	count:dword
if ?SIMPLETO
local	dwTicks:dword
endif

		@strace <"asyncrw enter">
		mov esi, pVoid
		mov ebx, [esi].ASYNCFILE.handle
		mov edi, [ebx].FILE.pParams
		mov eax, [esi].ASYNCFILE.dwFlags
		mov ecx, [esi].ASYNCFILE.numBytes
		mov flags, eax
		mov count, ecx
		mov ebx, [esi].ASYNCFILE.lpOverlapped
		mov esi, [esi].ASYNCFILE.pBuffer
if ?SIMPLETO
		call gettimeoutvalue
		mov dwTicks, eax
endif
		.while (count)
			bt [edi].COMMDESC.dcb.r0, fAbortOnError 
			jnc @F
			.break .if ([edi].COMMDESC.flags & CDF_ERROR)
@@:
			.if (flags == FILE_WRITE_ACCESS)
				.break .if ([edi].COMMDESC.flags & CDF_PURGETX)
				invoke ComWriteBuf, edi, esi, count
			.else
				.break .if ([edi].COMMDESC.flags & CDF_PURGERX)
				invoke ComReadBuf, edi, esi, count
			.endif
			.if (!eax)		;nothing transfered?
				.if (flags == FILE_READ_ACCESS)
					.break .if ([edi].COMMDESC.timeouts.ReadIntervalTimeout == -1)
				.endif
				invoke Sleep, 0
				.continue
			.endif
			sub count, eax
			add esi, eax
			.if (dwTicks)
				invoke GetTickCount
				.break .if (eax > dwTicks)
			.endif
		.endw
done:
		mov edx, pVoid
		mov eax, esi
		sub eax, [edx].ASYNCFILE.pBuffer
		mov [ebx].OVERLAPPED.InternalHigh, eax
		invoke SetEvent, [ebx].OVERLAPPED.hEvent
		@strace <"asynccom exit">
		ret
		align 4

asyncrw endp

;--- ReadFile()/WriteFile()/DeviceIoControl() exit
;--- (same method as with physical disk access)
;--- a DeviceIoControl() stack frame is used.
;--- out: eax = 0 if error, then lasterror should have been set

comrwhandler proc uses ebx esi edi handle:dword, dwCtrlCode:dword,
			pInBuf:dword, nInBuf:dword,
			pOutBuf:dword,nOutBuf:dword,
			lpBytesReturned:ptr dword,lpOverlapped:dword

local	count:dword
if ?SIMPLETO
local	dwTicks:dword
endif

		mov ebx, handle
		mov edi,[ebx].FILE.pParams
		mov ecx, lpBytesReturned
		mov edx,dwCtrlCode
		jecxz @F
		mov dword ptr [ecx],0
@@:
		cmp edx, IOCTL_SERIAL_LSRMST_INSERT		;the only control code
		jz isdeviceio							;accepted from DeviceIoControl
		
		test [edi].COMMDESC.flags, CDF_ERROR	;did an error occur?
		jz @F
		bt [edi].COMMDESC.dcb.r0,fAbortOnError	;read/write abort on error?
		jc fail1
@@:
		mov ecx,nOutBuf
		mov esi,pOutBuf
		cmp edx, FILE_READ_ACCESS
		jz @F
		cmp edx, FILE_WRITE_ACCESS
		jnz fail2
		mov ecx,nInBuf
		mov esi,pInBuf
@@:
		and ecx, ecx	;nothing to do?
		jz done
		mov count,ecx
		cmp word ptr [edi].COMMDESC.oldvec+4,0	;device to be opened?
		jnz @F
		invoke ComOpen, edi
		jc fail1
@@:
		.if (lpOverlapped)
			invoke LocalAlloc, LMEM_FIXED, sizeof ASYNCFILE
			and eax, eax
			jz fail3
			mov [eax].ASYNCFILE.handle, ebx
			mov ebx, eax
			mov [ebx].ASYNCFILE.pBuffer, esi
			mov ecx,count
			mov [ebx].ASYNCFILE.numBytes, ecx
			mov edx, lpOverlapped
			mov [edx].OVERLAPPED.Internal, STATUS_PENDING
			mov [ebx].ASYNCFILE.lpOverlapped, edx
			mov [ebx].ASYNCFILE.lpCompletionRoutine, 0
			mov eax, dwCtrlCode
			mov [ebx].ASYNCFILE.dwFlags, eax
			; set the event object to "non-signaled"
			invoke ResetEvent, [edx].OVERLAPPED.hEvent
			push 0
			invoke CreateThread, 0, 1000h, offset asyncrw, ebx, 0, esp
			pop ecx
			and eax, eax
			jz fail3
			invoke SetLastError, ERROR_IO_PENDING
			xor eax, eax	;return FALSE!
			jmp exit
		.endif

if ?SIMPLETO
		mov eax, dwCtrlCode
		invoke gettimeoutvalue
		mov dwTicks, eax
endif
		;--- do read/write in a loop

		.while (count)
			bt [edi].COMMDESC.dcb.r0, fAbortOnError 
			jnc @F
			.break .if ([edi].COMMDESC.flags & CDF_ERROR)
@@:
			.if (dwCtrlCode == FILE_READ_ACCESS)
				invoke ComReadBuf, edi, esi, count
			.else
				invoke ComWriteBuf, edi, esi, count
			.endif
			.if (!eax)
				.if (dwCtrlCode == FILE_READ_ACCESS)
					.break .if ([edi].COMMDESC.timeouts.ReadIntervalTimeout == -1)
				.endif
				invoke Sleep, 0
				.continue
			.endif
			sub count, eax
			add esi, eax
			mov edx, lpBytesReturned
			and edx, edx
			jz @F
			add [edx],eax
@@:
			.if (dwTicks)
				invoke GetTickCount
				.break .if (eax > dwTicks)
			.endif
		.endw
done:
		@mov eax,1
exit:
		@strace <"comrwhandler(", handle, ", ", dwCtrlCode, ", ", pInBuf, ", ", nInBuf, ", ", pOutBuf, ", ", nOutBuf, ", ", lpBytesReturned, ", ", lpOverlapped, ")=", eax>
		ret
fail1:
		invoke SetLastError, ERROR_ACCESS_DENIED
		xor eax, eax
		jmp exit
fail2:
		invoke SetLastError, ERROR_INVALID_PARAMETER
		xor eax, eax
		jmp exit
fail3:
		invoke SetLastError, ERROR_NOT_ENOUGH_MEMORY
		xor eax, eax
		jmp exit

		align 4

;--- the deviceiocontrol support is rather simple
;--- if the byte in input buffer is != 0, the LSRMST_INSERT
;--- mode is turned on, else it is turned off.

isdeviceio:
		mov esi, pInBuf
		mov al,[esi]
		mov [ebx].COMMDESC.bLSRMST, al
		@mov eax,1
		jmp exit

		align 4

comrwhandler endp

;--- check if file handle is for a valid COM device
;--- return with Carry if handle is invalid

chkhdl proc
		cmp [ebx].FILE.dwType, SYNCTYPE_FILE
		jnz fail
		test [ebx].FILE.flags, FF_DEVICE
		jz fail
		ret
fail:
		invoke SetLastError, ERROR_INVALID_HANDLE
		xor eax,eax
		stc
		ret
		align 4
chkhdl endp

;--- COMM IRQ proc
;--- usually either IRQ 4 (COM1/3) or IRQ 3 (COM2/4)

IRQprocs proc

Com1Irq::
		sub esp,4
		push offset commdescs + sizeof COMMDESC*0
		jmp @F
Com2Irq::
		sub esp,4
		push offset commdescs + sizeof COMMDESC*1
		jmp @F
Com3Irq::
		sub esp,4
		push offset commdescs + sizeof COMMDESC*2
		jmp @F
Com4Irq::
		sub esp,4
		push offset commdescs + sizeof COMMDESC*3
@@:
		push	ds
		pushad
		mov		ds, cs:[g_csalias]
		mov		ebx,[esp+32+4]
		mov 	edx,[ebx].COMMDESC.port
		add 	edx,2
		in		al,dx
		test	al,1		   ;interrupt occured (then bit is 0!)?
		jz		@F
		mov 	eax,dword ptr [ebx].COMMDESC.oldvec+0
		mov 	cx,word ptr [ebx].COMMDESC.oldvec+4
		mov		[esp+32+4],eax
		mov		[esp+32+8],ecx
		popad
		pop 	ds
		retf
@@:
		and		al,0Fh
		movzx	eax,al
		jmp		[intv+eax*2]
		align 4

intv	label dword
		dd offset v0	;000	modem status changed
		dd offset v1	;001	transmitter register empty
		dd offset v2	;010	received data available
		dd offset v3	;011	receiver line status changed
		dd offset v4	;100    transmit machine (82510)
		dd offset v5	;101    timer interrupt (82510)
		dd offset v6	;110	timeout interrupt pending
		dd offset v7	;111    cannot happen?

;--- modem status changed (DSR, CTS, RI, DCD)
;--- this interrupt is not enabled in IER!
;--- bit 0: dCTS
;--- bit 1: dDSR
;--- bit 2: dRI
;--- bit 3: dDCD
;--- the problem is that the delta lines are cleared by the read.
;--- therefore MSR is read inside WaitCommEvent only.

v0:
;		add edx,4
;		 in al,dx	;get new MSR
		jmp doeoi
		align 4

;--- fill transmitter with new bytes from output buffer

v1:
		test [ebx].COMMDESC.flags, CDF_BREAK
		jnz doeoi
		mov esi, [ebx].COMMDESC.outbuf.pCurr
		add edx, 3			;position to LSR
next_out:        
		cmp [ebx].COMMDESC.outbuf.dwFree,?BUFFSIZE
		jz out_done 		;output buffer is empty
		in al,dx
		test al,20h
		jz out_done
		mov al,[esi]
		inc esi
		cmp esi, [ebx].COMMDESC.outbuf.pEnd
		jb @F
		mov esi, [ebx].COMMDESC.outbuf.pStart
@@:
		sub edx,5
		out dx,al
		add edx,5
		inc [ebx].COMMDESC.outbuf.dwFree
		jmp next_out
out_done:
		mov [ebx].COMMDESC.outbuf.pCurr,esi
		jmp doeoi
		align 4

;--- byte received. store it in the input buffer

v2:
		sub edx,2
		in al,dx
		cmp al,0
		jnz @F
		bt [ebx].COMMDESC.dcb.r0, fNull	;NUL bytes to be discarded?
		jnz doeoi
@@:
		mov esi, [ebx].COMMDESC.inbuf.pNext
		cmp [ebx].COMMDESC.inbuf.dwFree,0
		jz	v2_buffer_full
		mov [esi],al
		inc esi
		cmp esi, [ebx].COMMDESC.inbuf.pEnd
		jb @F
		mov esi, [ebx].COMMDESC.inbuf.pStart
@@:
		mov [ebx].COMMDESC.inbuf.pNext, esi
		dec [ebx].COMMDESC.inbuf.dwFree
		jmp doeoi
v2_buffer_full:
		or [ebx].COMMDESC.error, CE_RXOVER
		or [ebx].COMMDESC.flags, CDF_ERROR
		jmp doeoi
		align 4

;--- receiver line status? LSR changed?
;--- bit 4: BREAK interrupt (CE_BREAK is 10h)
;--- bit 3: frame error   (CE_FRAME is 8)
;--- bit 2: parity error  (CE_PARITY is 4)
;--- bit 1: overrun error (CE_OVERRUN is 2)

v3:
		add edx,3
		in al,dx	;get new LSR
		and al,2+4+8+10h
		jz doeoi
;--- check what changed, set flag in COMMDESC
		or byte ptr [ebx].COMMDESC.error,al
		or [ebx].COMMDESC.flags, CDF_ERROR
		jmp doeoi
		align 4

;--- transmit machine ???

v4:
		int 3
		jmp doeoi
		db 4
		align 4

;--- timer interrupt ???

v5:
		int 3
		jmp doeoi
		db 5
		align 4

;--- timeout interrupt ???

v6:
		int 3
		jmp doeoi
		db 6
		align 4

;--- cannot happen ???

v7:
		int 3
		jmp doeoi
		db 7
		align 4
doeoi:
		mov al,20h
		out 20h,al
		popad
		pop ds
		add esp,4*2
		sti
		iretd
		align 4
IRQprocs endp

;--- restore character transmission
;--- clear BREAK (bit 6) in LCR

ClearCommBreak proc public uses ebx hFile:dword

		mov ebx,hFile
		call chkhdl
		jc exit
		mov ebx,[ebx].FILE.pParams
		and [ebx].COMMDESC.flags, not CDF_BREAK
;		 @noints
		mov edx,[ebx].COMMDESC.port
		add edx,3	;position to LCR
		in al,dx
		and al,not 40h
		out dx,al
;		 @restoreints
		invoke ComWriteBuf, ebx, 0, 0	;reinitiate transfer, just in case
		@mov eax,1
exit:
		@strace <"ClearCommBreak(", hFile, ")=", eax>
		ret
		align 4

ClearCommBreak endp

;--- stop character transmission
;--- set BREAK (bit 6) in LCR

SetCommBreak proc public uses ebx hFile:dword

		mov ebx,hFile
		call chkhdl
		jc exit
		@noints
		mov ebx,[ebx].FILE.pParams
		or [ebx].COMMDESC.flags, CDF_BREAK
		mov edx,[ebx].COMMDESC.port
if 0
		add edx,5
		mov ecx,1000
@@:
		in al,dx
		test al,20h
		loopz @B
		sub edx,5
endif
		add edx, 3	;position to LCR
		in al, dx
		or al, 40h
		out dx, al
		@restoreints
		@mov eax,1
exit:
		@strace <"SetCommBreak(", hFile, ")=", eax>
		ret
		align 4

SetCommBreak endp

;--- report reason why transmission stops
;--- lpStat may be NULL

if 0
COMSTAT:
fCtsHold:1,	;CTS is 0
fDsrHold:1,	;DSR is 0
fRlsdHold:1,;???
fXoffHold:1,;XOFF received
fXoffSent:1,;XOFF transmitted
fEof:1		;EOF character has been received
fTxim:1		;immediate transmission by TransmitCommChar

CE_BREAK	;?
CE_FRAME	;?
CE_IOE		;io error
CE_MODE		;?
CE_OVERRUN	;
CE_RXOVER	;input buffer overflow
CE_RXPARITY	;parity error
CE_TXFULL	;output buffer full
endif

ClearCommError proc public uses ebx hFile:dword, lpErrors:ptr DWORD, lpStat:ptr COMSTAT

		mov ebx,hFile
		call chkhdl
		jc exit
		mov ebx,[ebx].FILE.pParams
		movzx eax, [ebx].COMMDESC.error
		mov edx,lpErrors
		mov [edx],eax
		mov edx, lpStat
		.if (edx)
			mov dword ptr [edx].COMSTAT.r0, 0
			mov eax,?BUFFSIZE
			sub eax,[ebx].COMMDESC.inbuf.dwFree
			mov dword ptr [edx].COMSTAT.cbInQue, eax
			mov eax,?BUFFSIZE
			sub eax,[ebx].COMMDESC.outbuf.dwFree
			mov dword ptr [edx].COMSTAT.cbOutQue, eax
		.endif
		mov [ebx].COMMDESC.error, 0
		and [ebx].COMMDESC.flags, not CDF_ERROR	;clear error flag
		@mov eax,1
exit:
		@strace <"ClearCommError(", hFile, ", ", lpErrors, ", ", lpStat, ")=", eax>
		ret
		align 4

ClearCommError endp

;--- 

GetCommModemStatus proc public uses ebx hFile:dword, lpModemStat:ptr DWORD

		mov ebx,hFile
		call chkhdl
		jc exit
		mov ebx,[ebx].FILE.pParams
		mov edx,[ebx].COMMDESC.port
		add edx,6		;position to MSR
		in al,dx
		and al,0F0h		;the modem bits are bits 4-7 of MSR
		movzx eax,al
		mov ecx,lpModemStat
		mov [ecx],eax
		@mov eax,1
exit:
		@strace <"GetCommModemStatus(", hFile, ", ", lpModemStat, ")=", eax>
		ret
		align 4

GetCommModemStatus endp

;--- get current status of COM port

GetCommState proc public uses ebx esi hFile:dword, lpDCB:ptr DCB

		mov ebx,[hFile]
		call chkhdl
		jc exit
		mov esi, lpDCB
		mov eax, [ebx].FILE.pParams
		invoke RtlMoveMemory, esi, addr [eax].COMMDESC.dcb, sizeof DCB
		mov [esi].DCB.DCBlength, sizeof DCB

		invoke ComGetRate, [ebx].FILE.pParams
		and eax, eax
		jz exit
		mov [esi].DCB.BaudRate, eax
		mov eax, edx		 ;LCR
		and eax, 1+2		 ;bit 0+1 are data size (5,6,7,8)
		add eax, 5
		mov [esi].DCB.ByteSize, al
		mov cl,al
		mov eax, edx
		and eax, 4			 ;bit 2 is stopbits (0=1,1=2 [1.5 if size is 5])
		shr eax, 2			 ;ONESTOPBIT=0, ONE5STOPBITS=1, TWOSTOPBITS=2
		test al,1
		jz @F
		cmp cl,6
		cmc
		adc al,0
@@:
		mov [esi].DCB.StopBits, al
		mov eax, edx
		and eax, 18h		 ;bit 3+4 is parity (0=no parity, 11=even/01=odd)
		mov cl,NOPARITY
		test al,8
		jz @F
		mov cl,ODDPARITY
		test al,10h
		jz @F
		mov cl,EVENPARITY
@@:
		mov [esi].DCB.Parity, cl

;		mov [esi].DCB.XonLim, 0
;		mov [esi].DCB.XoffLim, 0
;		mov [esi].DCB.XonChar, 0
;		mov [esi].DCB.XoffChar, 0
;		mov [esi].DCB.ErrorChar, 0
;		mov [esi].DCB.EofChar, 0
;		mov [esi].DCB.EvtChar, 0

		@mov eax,1
exit:
		@strace <"GetCommState(", hFile, ", ", lpDCB, ")=", eax>
		ret

		align 4

GetCommState endp

;--- set current status (DCB) of COM port

SetCommState proc public uses ebx hFile:dword, lpDCB:ptr DCB

		mov ebx,[hFile]
		call chkhdl
		jc exit

		mov ebx,[ebx].FILE.pParams
		invoke RtlMoveMemory, addr [ebx].COMMDESC.dcb, lpDCB, sizeof DCB

		invoke ComSetRate, ebx
		and eax, eax
		jz exit

		mov edx,[ebx].COMMDESC.port
		add edx,3	;point to LCR port

		in	al,dx
		and al,60h	;preserve bits 5+6
		mov cl,[ebx].COMMDESC.dcb.ByteSize
		sub cl,5
		and cl,3
		or al,cl
		mov ah,[ebx].COMMDESC.dcb.StopBits
		test ah,3
		setnz ah	;transform 1 and 2 to 1, 0 to 0
		shl ah,2
		or al,ah
		mov ch,[ebx].COMMDESC.dcb.Parity
		cmp ch,NOPARITY
		jz @F		;nothing to do
		or al,8 	;enable parity, default is ODD
		cmp ch,ODDPARITY
		jz @F
		or al,10h
@@:
		out dx,al
		@mov eax,1
exit:
		@strace <"SetCommState(", hFile, ", ", lpDCB, ")=", eax>
		ret
		align 4

SetCommState endp

;--- get current configuration (includes DCB)

GetCommConfig proc public uses ebx esi hCommDev:DWORD, lpCC:ptr COMMCONFIG, lpdwSize: ptr DWORD
		
		mov ebx,[hCommDev]
        call chkhdl
        jc exit
        mov esi, lpCC
        mov ecx, lpdwSize
        mov eax, [ecx]
        mov edx,sizeof COMMCONFIG
        mov [ecx], edx
        
;        cmp eax, edx 	;it seems NOT to fail if buffer too small
;        jc failed
	        
        movzx ecx, [ebx].FILE.bDevice
        invoke ComInitCommConfig, ecx, esi
        invoke GetCommState, ebx, addr [esi].COMMCONFIG.dcb
exit:
        @strace <"GetCommConfig(", hCommDev, ", ", lpCC, ", ", lpdwSize, ")=", eax>
        ret
failed:
		xor eax, eax
        jmp exit
        align 4

GetCommConfig endp

;--- set the configuration

SetCommConfig proc public uses ebx esi hCommDev:DWORD, lpCC:ptr COMMCONFIG, dwSize: DWORD

		mov ebx,[hCommDev]
        call chkhdl
        jc exit
        mov esi, lpCC
        mov edx, dwSize
        cmp edx, sizeof COMMCONFIG
        jc fail
        invoke SetCommState, ebx, addr [esi].COMMCONFIG.dcb
exit:
        @strace <"SetCommConfig(", hCommDev, ", ", lpCC, ", ", dwSize, ")=", eax>
        ret
fail:
		invoke SetLastError, ERROR_INSUFFICIENT_BUFFER
		xor eax, eax
        jmp exit
        align 4
SetCommConfig endp

;--- check if a name is a valid device
;--- if ok, return COM number in EAX

checkname proc lpszName:dword

		mov edx, lpszName
        mov ax, [edx+0]
        mov cx, [edx+2]
        or ax,2020h
        cmp ax,"oc"          ;just "COM1"-"COM4" supported
        jnz fail
        or cl,20h
        cmp cl,'m'
        jnz fail
        cmp ch,'1'
        jb fail
        cmp ch,'4'
        ja fail
        cmp byte ptr [edx+4],0
        jnz fail
        sub ch,'0'
        movzx eax,ch
        ret
fail:
		xor eax,eax
		stc
        ret
checkname endp

;--- the "default" functions don't have an open device
;--- and therefore have to provide the device name as first param

GetDefaultCommConfigA proc public lpszName:ptr BYTE, lpCC:ptr, lpdwSize:ptr DWORD

		invoke checkname, lpszName
        jc exit
		invoke ComInitCommConfig, eax, lpCC
        @mov eax,1
exit:
        @strace <"GetDefaultCommConfigA(", lpszName, ", ", lpCC, ", ", lpdwSize, ")=", eax>
        ret
fail:
		invoke SetLastError, ERROR_INVALID_HANDLE
		xor eax, eax
        jmp exit
        align 4
GetDefaultCommConfigA endp

;--- where to store the default configuration?
;--- in the registry?

SetDefaultCommConfigA proc public lpszName:ptr BYTE, lpCC:ptr, dwSize:DWORD

		mov esi, lpszName
        mov ax, [esi+0]
        mov cx, [esi+2]
        or ax,2020h
        cmp ax,"oc"          ;just "COM1"-"COM4" supported
        jnz fail
        or cl,20h
        cmp cl,'m'
        jnz fail
        cmp ch,'1'
        jb fail
        cmp ch,'4'
        ja fail
        
;--- store it somewhere

        @mov eax, 1
exit:
        @strace <"SetDefaultCommConfigA(", lpszName, ", ", lpCC, ", ", dwSize, ")=", eax>
        ret
fail:
		invoke SetLastError, ERROR_INVALID_HANDLE
		xor eax, eax
        jmp exit
        align 4
SetDefaultCommConfigA endp


;--- the timeouts are stored in the FILE enhancement

GetCommTimeouts proc public uses ebx hFile:dword, lpCommTimeouts:ptr COMMTIMEOUTS

		mov ebx,[hFile]
        call chkhdl
        jc exit
        mov eax, [ebx].FILE.pParams
        lea eax, [eax].COMMDESC.timeouts
        invoke CopyMemory, lpCommTimeouts, eax, sizeof COMMTIMEOUTS
		@mov eax,1
exit:
        @strace <"GetCommTimeouts(", hFile, ", ", lpCommTimeouts, ")=", eax>
        ret
        align 4
        
GetCommTimeouts endp

;--- the timeouts are stored in the FILE enhancement (pParams)

SetCommTimeouts proc public uses ebx hFile:dword, lpTimeouts:ptr COMMTIMEOUTS

		mov ebx,[hFile]
        call chkhdl
        jc exit
        mov eax, [ebx].FILE.pParams
        lea eax, [eax].COMMDESC.timeouts
		invoke CopyMemory, eax, lpTimeouts, sizeof COMMTIMEOUTS
        @mov eax,1
exit:
        @strace <"SetCommTimeouts(", hFile, ", ", lpTimeouts, ")=", eax>
        ret
        align 4
        
SetCommTimeouts endp

;--- get the current event mask for WaitCommEvent

GetCommMask proc public uses ebx hFile:dword, lpEvtMask:ptr DWORD

		mov ebx,[hFile]
        call chkhdl
        jc exit
        mov edx,[ebx].FILE.pParams
        mov ecx,lpEvtMask
        mov eax,[edx].COMMDESC.evntmask
        mov [ecx],eax
        @mov eax,1
exit:
        @strace <"GetCommMask(", hFile, ", ", lpEvtMask, ")=", eax>
        ret
        align 4
        
GetCommMask endp

;--- set the current event mask for WaitCommEvent

SetCommMask proc public uses ebx hFile:dword, dwEvtMask:DWORD

		mov ebx,[hFile]
        call chkhdl
        jc exit
        mov eax,[ebx].FILE.pParams
        mov ecx,dwEvtMask
        mov [eax].COMMDESC.evntmask,ecx
        @mov eax,1
exit:
        @strace <"SetCommMask(", hFile, ", ", dwEvtMask, ")=", eax>
        ret
        align 4
        
SetCommMask endp

;--- watch status of COM device. If it changes,
;--- set event in *pEvent and return

testcomstat proc uses ebx esi hCom:dword, pEvent:ptr DWORD

		mov ebx,hCom
		mov ebx,[ebx].FILE.pParams
        mov esi,[ebx].COMMDESC.evntmask
        .while (1)
        	xor ecx,ecx
	        .if (esi & EV_RXCHAR)
            	mov cx, EV_RXCHAR
            	cmp [ebx].COMMDESC.inbuf.dwFree, ?BUFFSIZE
                jnz exit
    	    .endif
	        .if (esi & EV_TXEMPTY)
            	mov cx, EV_TXEMPTY
            	cmp [ebx].COMMDESC.outbuf.dwFree, ?BUFFSIZE
                jz exit
        	.endif
	        .if (esi & EV_BREAK)
	            mov cx, EV_BREAK
            	test [ebx].COMMDESC.flags, CDF_BREAK
                jnz exit
    	    .endif
    	    .if (esi & EV_ERR)
	            mov cx, EV_ERR
            	test [ebx].COMMDESC.flags, CDF_ERROR
                jnz exit
        	.endif
            ;--- the "event" character was received?
    	    .if (esi & EV_RXFLAG)
	            mov cx, EV_RXFLAG
            	test [ebx].COMMDESC.flags, CDF_EVNTCHAR
                jnz exit
        	.endif
            
;--- for the rest check the UART status
;--- the MSR lower 4 bits are "deltas"
;--- which are cleared when this register is read
            
	        mov edx,[ebx].COMMDESC.port
            add edx,6	;get MSR
            in al,dx
            
        	.if (esi & EV_CTS)
	          	mov cx,EV_CTS
            	test al,01h
                jz exit
	        .endif
	        .if (esi & EV_DSR)
	          	mov cx,EV_DSR
            	test al,02h
                jz exit
    	    .endif
        	.if (esi & EV_RING)
	          	mov cx,EV_RING
            	test al,04h
                jnz exit
	        .endif
	        .if (esi & EV_RLSD)
	          	mov cx,EV_RLSD
;           	test al,??
;               jnz exit
    	    .endif
	        invoke Sleep, 0
		.endw
exit:
        mov edx,pEvent
        mov [edx],ecx
		ret
        align 4
testcomstat endp

;--- structure for WaitCommEvent with lpOverlapped != NULL

WECOMM struct
handle  dd ?
pevnt	dd ?
pov		dd ?
WECOMM	ends

asyncwcp proc uses ebx pVoid:ptr WECOMM
		mov ebx, pVoid
		invoke testcomstat, [ebx].WECOMM.handle, [ebx].WECOMM.pevnt
        mov edx,[ebx].WECOMM.pov
        mov [edx].OVERLAPPED.InternalHigh, 4
		invoke SetEvent, [edx].OVERLAPPED.hEvent
		invoke LocalFree, ebx
		ret
        align 4
asyncwcp endp

;--- this function waits for an event to occur if lpOverlapped is NULL
;--- if lpOverlapped is != NULL, the function will return with either
;--- 1 or 0 and lasterror set to ERROR_IO_PENDING

;--- the event to watch must have been set with SetCommMask() before
;--- WaitCommEvent()

WaitCommEvent proc public uses ebx hFile:dword, lpEvtMask:ptr DWORD, lpOverlapped:ptr OVERLAPPED

		mov ebx, hFile
		call chkhdl
        jc exit
        mov ebx,[ebx].FILE.pParams
        mov ecx, lpEvtMask
        mov dword ptr [ecx],0
        cmp [ebx].COMMDESC.evntmask,0
        jz fail1
        .if (lpOverlapped)
            invoke LocalAlloc, LMEM_FIXED, sizeof WECOMM
            and eax, eax
            jz fail2
			mov ebx, eax
            mov eax, hFile
            mov ecx, lpOverlapped
            mov edx, lpEvtMask
			mov [ecx].OVERLAPPED.Internal, STATUS_PENDING
			mov [ebx].WECOMM.handle, eax
			mov [ebx].WECOMM.pevnt, edx
			mov [ebx].WECOMM.pov, ecx
	        invoke ResetEvent, [ecx].OVERLAPPED.hEvent
			push 0
			invoke CreateThread, 0, 1000h, offset asyncwcp, ebx, 0, esp
			pop ecx
			and eax, eax
			jz fail2
			invoke SetLastError, ERROR_IO_PENDING
			xor eax, eax	;return FALSE!
        .else
        	invoke testcomstat, hFile, lpEvtMask
        .endif
exit:
        @strace <"WaitCommEvent(", hFile, ", ", lpEvtMask, ", ", lpOverlapped, ")=", eax>
        ret
fail1:
		invoke SetLastError, ERROR_INVALID_PARAMETER
        xor eax,eax
        jmp exit
fail2:
		invoke SetLastError, ERROR_NOT_ENOUGH_MEMORY
        xor eax,eax
        jmp exit
        align 4
        
WaitCommEvent endp

;--- clear input/output buffers of the device

PurgeComm proc public uses ebx hFile:dword, dwFlags:DWORD

		mov ebx, hFile
		call chkhdl
        jc exit
        mov ebx,[ebx].FILE.pParams
        .if (dwFlags & PURGE_TXABORT)	;clear overlapping WriteFile()s
        	or [ebx].COMMDESC.flags, CDF_PURGETX
		.endif
        .if (dwFlags & PURGE_RXABORT)	;clear overlapping ReadFile()s
        	or [ebx].COMMDESC.flags, CDF_PURGERX
		.endif
        ;-- now run the async threads
        .if (dwFlags & (PURGE_RXABORT or PURGE_TXABORT))
        	invoke SwitchToThread
        .endif
        @noints
        .if (dwFlags & PURGE_TXCLEAR)	;clear output buffer
	        mov [ebx].COMMDESC.outbuf.dwFree, ?BUFFSIZE
    	    mov ecx, [ebx].COMMDESC.outbuf.pNext
        	mov [ebx].COMMDESC.outbuf.pCurr, ecx
		.endif
        .if (dwFlags & PURGE_RXCLEAR)	;clear input buffer
	        mov [ebx].COMMDESC.inbuf.dwFree, ?BUFFSIZE
    	    mov ecx, [ebx].COMMDESC.inbuf.pNext
        	mov [ebx].COMMDESC.inbuf.pCurr, ecx
		.endif
        @restoreints
        @mov eax,1
exit:
        @strace <"PurgeComm(", hFile, ", ", dwFlags, ")=", eax>
        ret
        align 4
        
PurgeComm endp

;--- send a character immediately to the COMM device,
;--- bypassing buffers

TransmitCommChar proc public uses ebx hFile:dword, cChar:dword

		mov ebx, hFile
		call chkhdl
        jc exit
        invoke ComWriteChar, [ebx].FILE.pParams, cChar
        @mov eax,0
        jc exit
        inc eax
exit:
        @strace <"TransmitCommChar(", hFile, ", ", cChar, ")=", eax>
        ret
        align 4
        
TransmitCommChar endp

if 0
SETXOFF		EQU	1
SETXON		EQU	2
SETRTS		EQU	3
CLRRTS		EQU	4
SETDTR		EQU	5
CLRDTR		EQU	6
RESETDEV	EQU	7
SETBREAK	EQU	8
CLRBREAK	EQU	9
endif

EscapeCommFunction proc public uses ebx hFile:dword, dwFunc:dword

		mov ebx, hFile
		call chkhdl
        jc exit
        mov ebx, [ebx].FILE.pParams
        mov edx, [ebx].COMMDESC.port
        mov eax, dwFunc
       	@mov ecx, 1
        .if (eax == SETXOFF)
        	or [ebx].COMMDESC.flags, CDF_XOFF
        .elseif (eax == SETXON)
        	and [ebx].COMMDESC.flags, not CDF_XOFF
        .elseif (eax == SETRTS)
        	add edx,4
            in al, dx
            or al,2
            out dx,al
        .elseif (eax == CLRRTS)
        	add edx,4
            in al, dx
            and al,not 2
            out dx,al
        .elseif (eax == SETDTR)
        	add edx,4
            in al, dx
            or al,1
            out dx,al
        .elseif (eax == CLRDTR)
        	add edx,4
            in al, dx
            and al,not 1
            out dx,al
        .elseif (eax == RESETDEV)
        	dec ecx
        .elseif (eax == SETBREAK)
        	push ecx
        	invoke SetCommBreak, hFile
            pop ecx
        .elseif (eax == CLRBREAK)
        	push ecx
        	invoke ClearCommBreak, hFile
            pop ecx
        .else
        	dec ecx
        .endif
        mov eax,ecx
exit:
        @strace <"EscapeCommFunction(", hFile, ", ", dwFunc, ")=", eax>
        ret
        align 4
        
EscapeCommFunction endp

GetCommProperties proc public uses ebx edi hFile:dword, lpCommProp

		mov ebx, hFile
		call chkhdl
        jc exit
        mov edi,[ebx].FILE.pParams
        invoke ZeroMemory, lpCommProp, sizeof COMMPROP
        mov edx,lpCommProp
        mov [edx].COMMPROP.wPacketLength, sizeof COMMPROP
        mov [edx].COMMPROP.wPacketVersion, 2
        mov [edx].COMMPROP.dwServiceMask, SP_SERIALCOMM
        mov [edx].COMMPROP.dwMaxTxQueue, ?BUFFSIZE
        mov [edx].COMMPROP.dwMaxRxQueue, ?BUFFSIZE
        mov [edx].COMMPROP.dwMaxBaud, BAUD_115200
        mov [edx].COMMPROP.dwProvSubType, PST_RS232
        mov [edx].COMMPROP.dwProvCapabilities, PCF_RTSCTS or PCF_XONXOFF or PCF_DTRDSR or PCF_TOTALTIMEOUTS
        mov [edx].COMMPROP.dwSettableParams, SP_BAUD or SP_DATABITS or SP_HANDSHAKING or SP_PARITY or SP_STOPBITS
        mov [edx].COMMPROP.wSettableStopParity, STOPBITS_10 or STOPBITS_20 or PARITY_NONE or PARITY_ODD or PARITY_EVEN
        mov [edx].COMMPROP.dwCurrentTxQueue, ?BUFFSIZE
        mov [edx].COMMPROP.dwCurrentRxQueue, ?BUFFSIZE
        @mov eax,1
exit:
        @strace <"GetCommProperties(", hFile, ", ", lpCommProp, ")=", eax>
        ret
        align 4
GetCommProperties endp

;--- now the exotic functions

;--- fill a DCB from a "mode" style init string.
;--- "COMx: BAUD=X PARITY=X DATA=X STOP=X XON=on/off ..."

BuildCommDCBAndTimeoutsA proc public uses ebx esi edi lpDef:ptr BYTE, lpDCB:ptr DCB, lpCommTimeouts:ptr COMMTIMEOUTS

local	comno:dword
local	szWord[32]:byte

		mov comno,0
		mov esi, lpDef
        call getword
        .if (al == ':')
        	invoke checkname, addr szWord
            jc failed
            mov comno, eax
            inc esi
            call getword
		.endif
        mov ebx, lpDCB
        .while (szWord && (al == '='))
        	inc esi	;go behind '='
            mov ecx, offset words
            .while (dword ptr [ecx])
            	mov eax,[ecx+0]
                mov edi,[ecx+4]
                push ecx
                invoke lstrcmpi, addr szWord, eax
                pop ecx
                add ecx,2*4
                .break .if (eax == 0)
                xor edi,edi
            .endw
            .if (edi)
				mov al,[esi]
            	call edi
                jc failed
            .endif
        	call getword
        .endw
        @mov eax,1
exit:
        @strace <"BuildCommDCBAndTimeoutsA(", lpDef, ", ", lpDCB, ", ", lpCommTimeouts, ")=", eax>
		ret
failed:
		invoke SetLastError, ERROR_INVALID_PARAMETER
		xor eax,eax
        jmp exit
        align 4

words label dword
		dd CStr("baud"), offset setbaud	;decimal number
		dd CStr("parity"), offset setpar;"N|O|E"
		dd CStr("data"), offset setdata	;"5|6|7|8"
		dd CStr("stop"), offset setstop	;"1|2"
		dd CStr("xon"), offset setxon   ;"on|off"
		dd CStr("dtr"), offset setdtr	;"on|off|hs"
		dd CStr("rts"), offset setrts 	;"on|off|hs|tg"
		dd CStr("to"), offset setto		;"on|off"
        dd 0

testonoffhstg label dword
		dd CStr("tg"), 3
testonoffhs label dword
		dd CStr("hs"), 2
testonoff label dword
		dd CStr("on"), 1
		dd CStr("off"), 0
        dd 0

setbaud:
		call getdecnumber
        cmp eax,50
        jc @F
        mov [ebx].DCB.BaudRate, eax
@@:
		retn
setpar:
        or al,20h
        inc esi
        .if (al == 'n')
        	mov [ebx].DCB.Parity, NOPARITY
        .elseif (al == 'e')
        	mov [ebx].DCB.Parity, EVENPARITY
        .elseif (al == 'o')
        	mov [ebx].DCB.Parity, ODDPARITY
        .else
        	dec esi
        	stc
        .endif
		retn
setdata:
        .if ((al >= '5') && (al <= '8'))
        	sub al,'0'
            mov [ebx].DCB.ByteSize,al
            inc esi
        .else
        	stc
        .endif
		retn
setstop:
        .if (al == '1')
        	mov [ebx].DCB.StopBits, ONESTOPBIT
            inc esi
        .elseif (al == '2')
        	mov [ebx].DCB.StopBits, TWOSTOPBITS
            inc esi
        .else
        	stc
        .endif
		retn
setxon:
		call getonoff
        jc @F
        .if (eax)
		   	bts [ebx].DCB.r0, fOutX
		   	bts [ebx].DCB.r0, fInX
        .else
		   	btr [ebx].DCB.r0, fOutX
		   	btr [ebx].DCB.r0, fInX
        .endif
        clc
@@:     
		retn
        align 4
setdtr:
		mov edi, offset testonoffhs
		call getonoffex
        jc setdtr_failed
	   	btr [ebx].DCB.r0, fDtrControl
	   	btr [ebx].DCB.r0, fDtrControl+1
        .if (eax == 1)
		   	bts [ebx].DCB.r0, fDtrControl
        .elseif (eax == 2)
		   	bts [ebx].DCB.r0, fDtrControl+1
        .endif
        clc
setdtr_failed:
		retn
        align 4
setrts:
		mov edi, offset testonoffhstg
		call getonoffex
        jc setrts_failed
	   	btr [ebx].DCB.r0, fRtsControl
	   	btr [ebx].DCB.r0, fRtsControl+1
        .if (eax == 1)
		   	bts [ebx].DCB.r0, fRtsControl
        .elseif (eax == 2)
		   	bts [ebx].DCB.r0, fRtsControl+1
        .elseif (eax == 3)
		   	bts [ebx].DCB.r0, fRtsControl
		   	bts [ebx].DCB.r0, fRtsControl+1
        .endif
setrts_failed:
		retn

        align 4

;--- set timeouts
        
setto:
        cmp lpCommTimeouts,0
        jz to_exit
		call getonoff
        jc to_failed
        cmp comno,0		;was there a "COMx:" in the string?
        stc
        jz to_failed
        .if (eax)
        	invoke ComSetTimeouts, comno, lpCommTimeouts
        .else
        	invoke ComSetTimeouts, comno, 0
        .endif
to_failed:
to_exit:
		retn

        align 4

getonoff:
		mov edi, offset testonoff
getonoffex:
		push edi
		call getword2
        pop edi
cmp_next:
        mov eax,[edi]
        invoke lstrcmpi, addr szWord, eax
        and eax, eax
        jz cmp_found
		add edi,2*4
        cmp dword ptr [edi],0
        jnz cmp_next
        stc
        retn
cmp_found:
		mov eax,[edi+4]
        retn
        align 4
getword:
		.while (1)
        	mov al,[esi]
            cmp al,9
            jz @F
            cmp al,' '
            jz @F
            .break
@@:
			inc esi
        .endw
getword2:
        lea edi, szWord
        and al,al
        jz stop
        mov ecx, sizeof szWord - 1
        .repeat
           mov al,[esi]
           .break .if (al <= ' ')
           .break .if (al == '=')
           .break .if (al == ':')
           stosb
           inc esi
           dec ecx
        .until (ecx == 0)
stop:
		mov byte ptr [edi],0
        retn
getdecnumber:			;get a decimal number
		xor edx,edx
gn_next:        
		mov al,[esi]
        cmp al,'0'
        jb gn_done
        cmp al,'9'
        ja gn_done
        inc esi
        sub al,'0'
        movzx eax,al
        shl edx,1		;edx*2
        mov ecx,edx
        shl edx,2		;edx*4
        add edx,ecx
        add edx,eax
        jmp gn_next
gn_done:
		mov eax,edx
		retn
        align 4

BuildCommDCBAndTimeoutsA endp

;--- just call BuildCommDCBAndTimeouts with a NULL
;--- as timeout parameter.

BuildCommDCBA proc public lpDef:ptr BYTE, lpDCB:ptr DCB

		invoke BuildCommDCBAndTimeoutsA, lpDef, lpDCB, NULL
        @strace <"BuildCommDCBAA(", lpDef, ", ", lpDCB, ")=", eax>
		ret
        align 4

BuildCommDCBA endp

;--- set a device's input and output buffer size
;--- these values are just recommendations (and ignored)

SetupComm proc public uses ebx hFile:DWORD, dwInQueue:DWORD, dwOutQueue:DWORD

		mov ebx, hFile
        call chkhdl
        jc exit
        mov edx, [ebx].FILE.pParams
        mov eax, dwInQueue
        mov ecx, dwOutQueue
        mov [edx].COMMDESC.inbufsiz, eax
        mov [edx].COMMDESC.outbufsiz, ecx
        @mov eax,1
exit:
        @strace <"SetupComm(", hFile, ", ", dwInQueue, ", ", dwOutQueue, ")=", eax>
        ret
        align 4
SetupComm endp

;--- this export is still unsupported!

CommConfigDialogA proc public lpszName:ptr BYTE, hWnd:DWORD, lpCC:ptr
		xor eax, eax
        @strace <"CommConfigDialogA(", lpszName, ", ", hWnd, ", ", lpCC, ")=", eax>
        ret
        align 4
CommConfigDialogA endp

;--- COM helper functions
;--- these functions don't know anything about FILE
;--- they just know the COM ports

;--- init all fields in a DCB which cannot be set by reading
;--- the COM port

ComOpen proc uses ebx esi pcd:ptr COMMDESC

		mov ebx, pcd
        
        invoke LocalAlloc, LMEM_FIXED, ?BUFFSIZE*2
        and eax, eax
        jz error
        mov esi, eax

;--- save old IRQ vector

        push ebx
        mov bl,[ebx].COMMDESC.irqint
        mov ax,0204h
        int 31h
        pop ebx
        mov dword ptr [ebx].COMMDESC.oldvec+0,edx
        mov word ptr [ebx].COMMDESC.oldvec+4,cx

;--- set new IRQ vector

		mov ecx,cs
        mov edx,[ebx].COMMDESC.newvec
        push ebx
        mov bl,[ebx].COMMDESC.irqint
        mov ax,0205h
        int 31h
        pop ebx

        mov ecx, ?BUFFSIZE
        mov [ebx].COMMDESC.inbuf.pStart, esi
        mov [ebx].COMMDESC.inbuf.pCurr, esi
        mov [ebx].COMMDESC.inbuf.pNext, esi
        mov [ebx].COMMDESC.inbuf.dwFree, ecx
        add esi, ecx
        mov [ebx].COMMDESC.inbuf.pEnd, esi
        mov [ebx].COMMDESC.outbuf.pStart, esi
        mov [ebx].COMMDESC.outbuf.pCurr, esi
        mov [ebx].COMMDESC.outbuf.pNext, esi
        mov [ebx].COMMDESC.outbuf.dwFree, ecx
        add esi, ecx
        mov [ebx].COMMDESC.outbuf.pEnd, esi
        
;--- enable IRQs in UART IER

		mov		edx,[ebx].COMMDESC.port
		add		edx, 3
		in		al, dx
		and		al, 7Fh	;select IER for 3F9
		out		dx, al
		sub 	edx,2
        in 		al,dx
        or 		al,?INTSRC	;set allowed IRQs sources
        out 	dx,al

;--- should MCR be written?

		mov		edx,[ebx].COMMDESC.port
		add		edx, 4
        in		al,dx
        and		al,0F0h
        or		al,1+2+8	;DTR=1, RTS=1, OUT1=0, OUT2=1
        out		dx,al

;--- clear "delta" bits in MSR by reading it

		add		edx, 2		;position to MSR
        in		al,dx

;--- clear IRQ mask in PIC
        
        movzx ecx,[ebx].COMMDESC.irqint
        cmp ecx,10h
        jnc @F
        sub ecx,8
        in  al,21h
        btr eax,ecx
		out 21h,al
        jmp maskdone
@@:
        sub ecx,70h
        in  al,0A1h
        btr eax,ecx
		out 0A1h,al
maskdone:
        clc
        ret
error:
		stc
        ret
        align 4
ComOpen endp

ComClose proc uses ebx pcd:ptr COMMDESC

		mov ebx, pcd
		@strace <"ComClose enter, pcd=", ebx, " free=", [ebx].COMMDESC.outbuf.dwFree, " esp=", esp>
        cmp word ptr [ebx].COMMDESC.oldvec+4,0	;IRQ set?
        jz exit
;--- wait until output buffer is emptied
        .while ([ebx].COMMDESC.outbuf.dwFree != ?BUFFSIZE)
	        .break .if ([ebx].COMMDESC.flags & (CDF_BREAK or CDF_XOFF or CDF_ERROR))
            invoke ComWriteBuf, ebx, 0, 0
        	invoke SwitchToThread
        .endw

        @noints

        mov edx,[ebx].COMMDESC.port
        inc edx
        mov al,0
        out dx,al	;disable all interrupts
		
        mov edx,dword ptr [ebx].COMMDESC.oldvec+0
        xor ecx,ecx
        xchg cx,word ptr [ebx].COMMDESC.oldvec+4
		push ebx
        mov bl,[ebx].COMMDESC.irqint
        mov ax,0205h
        int 31h
        pop ebx

        @restoreints
        
		;release the 2 buffers
		xor ecx, ecx
        xchg ecx, [ebx].COMMDESC.inbuf.pStart
        invoke LocalFree, ecx

exit:
		@strace <"ComClose exit">
        ret
        align 4
ComClose endp

ComInitDCB proc comno:dword, pdcb:ptr DCB 
		mov edx, pdcb
        mov [edx].DCB.XonChar,17 	;Ctrl-Q
        mov [edx].DCB.XoffChar,19 	;Ctrl-S
        mov [edx].DCB.XonLim,2048
        mov [edx].DCB.XoffLim,512
        bts [edx].DCB.r0, fBinary	;the field's name is the bit position
		ret
        align 4
ComInitDCB endp

;--- init all fields in a COMMCONFIG which cannot be set by reading

ComInitCommConfig proc comno:dword, lpCC:ptr COMMCONFIG        

        invoke ZeroMemory, lpCC, sizeof COMMCONFIG
        mov ecx, lpCC
        mov [ecx].COMMCONFIG.dwSize, sizeof COMMCONFIG
        mov [ecx].COMMCONFIG.wVersion, 1
        mov [ecx].COMMCONFIG.dwProviderSubType, PST_RS232
        invoke ComInitDCB, comno, addr [ecx].COMMCONFIG.dcb
        ret
        align 4
ComInitCommConfig endp

;*** write char to COM port
;--- buffer is NOT used
;--- used by TransmitComChar

ComWriteChar proc stdcall uses ebx pcd:ptr COMMDESC, char:dword

		mov		ebx,pcd
        mov     edx,[ebx].COMMDESC.port
if ?CHKDSR
        mov     ecx,edx
		add 	edx,6
		in		al,dx			;DSR - modem ready?
		and 	al,20h
		jz		error2
        mov     edx,ecx
endif
		add 	edx,5           ;point to LSR
		@noints					;disable interrupts
		mov 	ecx,8000h
@@:
		in		al,dx
;;		and 	al,40h			;transmitter empty?
		and 	al,20h			;transmitter empty?
		loopz	@B
		mov 	eax,char
        sub		edx,5
		out 	dx,al
        @restoreints
        clc
		ret
error1:        ;timeout
error2:        ;device not ready
error3:
		stc
		ret
        align 4
ComWriteChar endp

;--- set COM speed

ComSetRate proc stdcall uses ebx pcd:ptr COMMDESC

		mov		ebx,pcd
        xor     eax,eax     ;default to error
        mov     ecx,[ebx].COMMDESC.dcb.BaudRate
        jecxz   exit        ;0 is impossible
        xor		edx,edx
        mov     eax,115200
        div     ecx
        and     edx,edx     ;something left?
        jnz     exit
        @noints
        mov     ecx,eax     ;divisor -> ecx
        mov     edx,[ebx].COMMDESC.port
        add     edx,3
        in      al,dx
        push    eax
        or      al,80h     ;select baudrate register
        out     dx,al
        sub		edx,3
        mov     al,cl
        out     dx,al
        inc     edx
        mov     al,ch
        out     dx,al
        add     edx,2
        pop     eax
        out     dx,al
        @restoreints
        mov     al,1
exit:
        ret
        align 4
        
ComSetRate endp

;--- get COM speed, returns value of LCR in DL

ComGetRate proc stdcall uses ebx pcd:ptr COMMDESC

        xor     eax,eax
        mov     ebx,pcd
        mov     edx,[ebx].COMMDESC.port
        add     edx,3
        @noints
        in      al,dx       ;read LCR
        push    eax
	    or      al,80h      ;bit7 of x+2: select baudrate register
        out     dx,al
        sub		edx,3
        in      al,dx       ;X+0
        inc     edx
        mov     ah,al
        in      al,dx       ;X+1
        add     edx,2
        xchg    ah,al
        movzx   ecx,ax
        pop     eax
        out     dx,al       ;restore value of LCR
        @restoreints
        push	eax
        mov     eax,115200
        xor     edx,edx
        cmp     ecx,1
        jb      @F
        div     ecx
@@:
		pop		edx			;return value of LCR in DL
getcomspeed_err:
        ret
        align 4
ComGetRate endp

;--- set timeouts in COMMDESC for special comno

ComSetTimeouts proc comno:dword, pct:ptr COMMTIMEOUTS
		mov ecx,pct
        .if (ecx)
        	mov eax, comno
            dec eax
            mov edx, sizeof COMMDESC
            mul edx
            add eax, offset commdescs
            add eax, COMMDESC.timeouts
            invoke CopyMemory, eax, ecx, sizeof COMMTIMEOUTS
        .endif
		ret
        align 4
        
ComSetTimeouts endp

;--- write bytes in output buffer
;--- returns bytes actually stored in buffer in EAX

ComWriteBuf proc uses ebx esi pcd:ptr COMMDESC, buffer:ptr BYTE, count:DWORD

		mov ebx,pcd
		@noints
		mov ecx,count
		cmp ecx, [ebx].COMMDESC.outbuf.dwFree
		jb @F
		mov ecx, [ebx].COMMDESC.outbuf.dwFree
@@:
		mov esi, ecx
		jecxz nocopy
		mov edx,[ebx].COMMDESC.outbuf.pNext
		mov eax,[ebx].COMMDESC.outbuf.pEnd
		sub eax, edx	  ;eax = space till buffer end
		.if (eax < ecx)
			sub ecx, eax
			push ecx
			mov ecx, buffer
			add buffer, eax
			invoke CopyMemory, edx, ecx, eax
			pop ecx
			mov edx, [ebx].COMMDESC.outbuf.pStart
		.endif
		lea eax, [edx+ecx]
		mov [ebx].COMMDESC.outbuf.pNext, eax
		sub [ebx].COMMDESC.outbuf.dwFree, esi
		invoke CopyMemory, edx, buffer, ecx
nocopy:

;--- initiate transfer in case buffer is not empty and transmitter is free

		mov ah,32	;restrict bytes to send. In emulated environments
					;it might be very well true that transmitter is always
					;"empty". Some programs might not expect this.

		.while (ah && ([ebx].COMMDESC.outbuf.dwFree != ?BUFFSIZE))
			.break .if ([ebx].COMMDESC.flags & CDF_BREAK)
			mov edx,[ebx].COMMDESC.port
			add edx,5
			in al,dx
			and al,20h			;transmitter empty?
			jz write_done
			mov ecx,[ebx].COMMDESC.outbuf.pCurr
			mov al,[ecx]
			sub edx,5
			out dx,al
			inc ecx
			cmp ecx, [ebx].COMMDESC.outbuf.pEnd
			jb @F
			mov ecx, [ebx].COMMDESC.outbuf.pStart
@@:
			mov [ebx].COMMDESC.outbuf.pCurr, ecx
			inc [ebx].COMMDESC.outbuf.dwFree
			dec ah
		.endw
write_done:
		
		@restoreints
done:
		mov eax, esi
		ret
		align 4

ComWriteBuf endp

;--- read bytes in input buffer
;--- returns bytes actually found in buffer in EAX


ComReadBuf proc uses ebx esi pcd:ptr COMMDESC, buffer:ptr BYTE, count:DWORD

local	bReadChar:BYTE

		mov ebx,pcd
		xor esi,esi
		cmp [ebx].COMMDESC.inbuf.dwFree, ?BUFFSIZE	;is buffer empty
		jz done
		@noints
		cmp [ebx].COMMDESC.inbuf.dwFree, 0	;is buffer full?
		setz bReadChar
		.while (count)
			mov ecx, count
			mov eax, ?BUFFSIZE
			sub eax, [ebx].COMMDESC.inbuf.dwFree ;eax = bytes in buffer
			.break .if (ZERO?) ;nothing in buffer?
			cmp ecx, eax
			jb @F
			mov ecx, eax
@@:
			mov edx,[ebx].COMMDESC.inbuf.pCurr
			mov eax,[ebx].COMMDESC.inbuf.pEnd
			sub eax, edx	  ;eax = space till buffer end
			.if (eax < ecx)
				mov ecx, eax
			.endif
			sub count, ecx
			lea eax, [edx+ecx]
			.if (eax == [ebx].COMMDESC.inbuf.pEnd)
				mov eax,[ebx].COMMDESC.inbuf.pStart
			.endif
			mov [ebx].COMMDESC.inbuf.pCurr, eax
			add [ebx].COMMDESC.inbuf.dwFree, ecx
			mov eax, buffer
			add buffer, ecx
			add esi, ecx
			invoke CopyMemory, eax, edx, ecx
		.endw

;--- was transmit stopped (and therefore a transfer to be initiated?)
if 0
		.if (bReadChar)
			mov edx,[ebx].COMMDESC.outbuf.pCurr
			mov al,[edx]
			inc edx
			mov [ebx].COMMDESC.inbuf.pCurr, edx
			inc [ebx].COMMDESC.inbuf.dwFree
			.if (1)
				mov edx,[ebx].COMMDESC.port
				mov al,17	;XON
				out dx,al
			.endif
		.endif
endif
		@restoreints
done:
		mov eax, esi
		ret
		align 4

ComReadBuf endp

