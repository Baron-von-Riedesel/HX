
;--- SoundBlaster 16/Pro code

	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:none
	option proc:private

	include winbase.inc
;	include winuser.inc
	include mmsystem.inc
	include macros.inc
	include sb.inc
	include dma.inc
	include dpmi.inc
	include sb16int.inc
	include sb16.inc

?SBPRO		equ 1			;1=support SB Pro
?DMABUFSIZE equ 4000h		;size of DMA buffer in bytes
?SBPROONLY	equ 0			;1=always assume a SB Pro is installed
							;(to test SB Pro code)

if ?SBPRO
?MINDSPVER	equ 3
else
?MINDSPVER	equ 4
endif

AllocDmaMem	proto
FreeDmaMem	proto
InitDMA		proto

;_waveDequeueHdr proto


	.DATA

;--- sound blaster values (BLASTER environment variable)

g_dwSBBase	  dd -1			;Axxx variable
g_dwSBIrq	  label dword
g_bSBIrq	  db -1			;Ix variable
			  db 3 dup (-1)  
g_dwDMALow	  label dword
g_bDMALow	  db -1			;Dx variable
			  db 3 dup (-1)  
g_dwDMAHigh   label dword
g_bDMAHigh	  SBYTE -1		;Hx variable
			  db 3 dup (-1)  
g_dwSBMidi	  dd -1			;Pxxx variable
g_dwSBModel   dd 0			;Tx variable

g_dwBitsPerSample dd 0
g_dwChannels  dd 0
g_dwSamplesPerSec dd 0

protoSndEvent typedef proto :ptr DMABUFFER, :dword
LPSNDEVENT typedef ptr protoSndEvent

;--- dma buffer variable

;g_pDmaBuffer  dd 0		;dma buffer start linear address
g_dwDmaPhys   dd 0		;dma buffer physical address
g_dwDmaSize   dd 0		;dma buffer size
g_dwDmaPart   dd 0		;size of dma buffer part (size/2 | size/4 | size/8)
g_dwDmaPlay   dd 0		;offset in dma buffer for play cursor
g_dwDmaFree   dd 0		;free bytes in dma buffer
g_dwDosSel	  dd 0		;selector of dma buffer
g_dwClrValue  dd 0
g_pSndEvent   LPSNDEVENT 0		;sound event proc
g_DmaBuffer	  DMABUFFER <0,0,0,0>

;g_wDMALowPageReg  dw 0	;port to access page reg of low dma channel
;g_wDMAHighPageReg dw 0	;port to access page reg of high dma channel
g_dwIrqAck	  dd 0		;port to acknowledge int		

	align 4

g_dfOldIrq	  df 0		;old vector of SB interrupt
g_wPicPort    dw 0
g_bInit		  db 0		;
g_bDSPVer	  db 0		;4+ for SB16+, 3 for SB Pro
g_bOldBit	  db 0		;saved bit of PIC IRQ mask of SB interrupt
g_bPrepared   db 0		;SB device is prepared for playing
g_bPaused	  db 0		;SB device is paused
g_bPauseCmd   db 0		;DSP command to pause SB playing
g_bContCmd	  db 0		;DSP command to continue SB playing
g_bPicMask    db 0

SBINIT_ENVIRONMENT	equ 1
SBINIT_UART			equ 2

if ?SBMIDI
SBWriteMidiCmd proto
endif

	.CODE

SBResetDSP proc dwSBBase:dword

	@strace <"SBResetDSP(", dwSBBase, ") enter">
	mov g_bPrepared, FALSE
	mov g_bPaused, FALSE
	mov eax, g_dwDmaSize
	mov g_dwDmaFree, eax
;	mov g_dwDmaWrite, 0
	mov g_dwDmaPlay, 0

	.if (dwSBBase == -1)
		mov ecx, g_dwSBBase
		mov dwSBBase, ecx
	.endif

	@noints
	mov edx, dwSBBase
	add dl, SB_DSPRESET
	mov al,1
	out dx,al		; start DSP reset

	in al,dx
	in al,dx
	in al,dx
	in al,dx		; wait 3 æsec. this is valid for an ISA bus,
					; but newer cards/emulators should be happy with
					; this as well.

	xor al,al
	out dx,al		; end DSP Reset

	mov edx, dwSBBase
	add dl, SB_DSPSTATUS
	WAITREAD
	mov edx, dwSBBase
	add dl, SB_DSPREAD
	in al,dx
	mov edx, eax
	@restoreints
	mov eax, edx
if ?SBMIDI
	.if (g_bInit & SBINIT_UART)
		push eax
		mov al,3Fh
		invoke SBWriteMidiCmd
		pop eax
	.endif
endif
	@strace <"SBResetDSP(", dwSBBase, ")=", eax>
	ret
	align 4
SBResetDSP endp

SndClearBuffer proc public uses esi edi ebx pBuffer:ptr, dwSize:dword

	mov ebx, pBuffer
	mov esi, [ebx].DMABUFFER.pStart
	mov edx, [ebx].DMABUFFER.pEnd
	mov edi, [ebx].DMABUFFER.pCsr
	sub edx, edi
	mov eax, g_dwClrValue
	mov ecx, dwSize
ife ?FLAT
	push es
	push @flat
	pop es
endif
	.if (edx < ecx)
		sub ecx, edx
		push ecx
		mov ecx, edx
		shr ecx, 2
		rep stosd
		pop ecx
		mov edi, esi
	.endif
	shr ecx, 2
	rep stosd
ife ?FLAT
	pop es
endif
if 0
	mov [ebx].DMABUFFER.pCsr, edi
endif
	ret
	align 4
SndClearBuffer endp

SndFillDMABuffer proc public

	@strace <"SndFillDMABuffer() enter, dwDmaFree=", g_dwDmaFree, " pSndEvent=", g_pSndEvent>
	invoke AllocDmaMem	;ensure DMA buffer is valid
	jc done
	.if (g_dwDmaFree)
		.if (g_pSndEvent)
			@noints
			mov eax, g_dwDmaPart
			mov g_DmaBuffer.dwSize, eax
			invoke [g_pSndEvent], addr g_DmaBuffer, SND_FILLBUFFER
			mov eax, [g_dwDmaPart]
			sub eax, g_DmaBuffer.dwSize
			sub [g_dwDmaFree], eax
			@restoreints
		.endif
	.endif
	.if (!g_bPrepared)
		@strace <"prepare SoundBlaster">
		call InitIrq
		call SBPrepareDSP
		call SBWritePlayCmd
	.elseif (g_bPaused)
		invoke SndContinue
	.endif
done:
	@strace <"SndFillDMABuffer()=", eax>
	ret
	align 4
SndFillDMABuffer endp

;--- sound blaster IRQ proc
;--- the wave sound is double-buffered
;--- that is DMA size is - at least - double the size of SB buffer size
;--- so this irq is called whenever half of the data is played
;--- for the std size of 16 kB, it is called:
;--- 44200, stereo, 16bit = 176.800 samples/sec = 21.5 times/sec
;--- 22100, mono, 16bit = 44.200 samples/sec = 5.4 times/sec
;--- 11050, mono, 8bit = 11.050 sampes/sec = 1.33 times/sec

SBIrqProc proc
	pushad
	push ds
	push es
	mov ds,cs:[g_csalias]
ife ?FLAT
	push @flat
	mov @flat, [g_flatsel]
endif
	mov eax, ds
	mov es, eax

	@strace <"SBIrqProc*****">

	cmp [g_bPaused],0
	jnz is_paused

;--- update the dma play cursor

	mov eax, g_dwDmaPart
	mov edx, g_dwDmaPlay
	add edx, eax
	.if (edx >= g_dwDmaSize)
		mov edx, 0
	.endif
	mov g_dwDmaPlay, edx

;--- update the dma free mem value

	add eax, g_dwDmaFree
	.if (eax > g_dwDmaSize)
		mov eax, g_dwDmaSize
	.endif
	mov g_dwDmaFree, eax
if 0
	.if (eax == g_dwDmaSize)
;		mov g_dwDmaWrite, edx
		invoke SndPause
	.endif
endif

;--- fill the dma buffer while interrupts are disabled
;--- this has high priority!

	cld
	mov eax, g_dwDmaPart
	mov g_DmaBuffer.dwSize, eax
	invoke [g_pSndEvent], addr g_DmaBuffer, SND_FILLBUFFER+SND_BUFFERPLAYED
	mov eax, [g_dwDmaPart]
	mov ecx, g_DmaBuffer.dwSize
	sub eax, ecx
	sub [g_dwDmaFree], eax
	.if (ecx)
		invoke SndClearBuffer, addr g_DmaBuffer, ecx
	.endif
is_paused:

;--- now acknowledge the interrupt

	mov edx, g_dwIrqAck
	in al,dx

;--- and send an EOI to PIC

	mov al,20h
	cmp [g_bSBIrq], 8
	jb @F
	out 0A0h,al
@@:
	out 20h,al

ife ?FLAT
	pop @flat
endif
	pop es
	pop ds
	popad
	sti
	iretd
;defaultirq:
;	jmp cs:[g_dfOldIrq]
	align 4

SBIrqProc endp

getnum proc uses ebx

	mov ebx, edx
	xor edx, edx
	.while (ecx && (byte ptr [esi]))
		lodsb
		dec ecx
		.break .if (al == ' ')
		sub al,'0'
		jc error
		cmp al,9
		ja error
		movzx eax,al
		add edx, edx	;*2
		push ecx
		mov ecx, edx
		lea edx, [edx*4+ecx]
		add edx, eax
		pop ecx
	.endw
	mov [ebx],edx
	ret
error:
	xor eax,eax
	mov [ebx],eax
	ret
	align 4
getnum endp

gethex proc uses ebx

	mov ebx, edx
	xor edx, edx
	.while (ecx && (byte ptr [esi]))
		lodsb
		dec ecx
		.break .if (al == ' ')
		cmp al,'0'
		jc error
		cmp al,'9'
		jbe @F
		or al,20h
		cmp al,'a'
		jb error
		cmp al,'f'
		ja error
		sub al,27h
@@:
		sub al,'0'
		movzx eax,al
		shl edx, 4
		add edx, eax
	.endw
	mov [ebx],edx
	ret
error:
	xor eax,eax
	mov [ebx],eax
	ret
	align 4
gethex endp

;--- return SB version in AL, minor in AH

SBGetVersion proc dwBase:dword

	WRITEDSP dwBase, DSP_VERSION
	mov edx, dwBase
	add edx, SB_DSPSTATUS
	WAITREAD
	mov edx, dwBase
	add edx, SB_DSPREAD
	in al,dx
	mov ah,al
	mov edx, dwBase
	add edx, SB_DSPSTATUS
	WAITREAD
	mov edx, dwBase
	add edx, SB_DSPREAD
	in al,dx
	xchg al,ah
	ret
	align 4
SBGetVersion endp

;--- initialize sound card
;--- out: eax==0 if no sound card
;--- else: eax != 0

SndInit proc public uses esi

local	dwBase:dword
local	dwIrq:dword
local	dwDMALow:dword
local	dwDMAHigh:dword
local	dwMidi:dword
local	dwModel:dword
local	dwTmp:dword
local	szVar[128]:byte

	test g_bInit, SBINIT_ENVIRONMENT
	jnz done
	or g_bInit, SBINIT_ENVIRONMENT
	invoke GetEnvironmentVariable, CStr("BLASTER"), addr szVar, sizeof szVar
	.if (eax)
		mov ecx, eax
		mov eax, -1
		mov dwBase, eax
		mov dwIrq, eax
		mov dwDMALow, eax
		mov dwDMAHigh, eax
		mov dwMidi, 330h
		lea esi, szVar
		.while (ecx && (byte ptr [esi]))
			lodsb
			or al,20h
			.if (al == 'a')
				lea edx, dwBase
				invoke gethex
				jmp skipbyte
			.elseif (al == 'i')
				lea edx, dwIrq
			.elseif (al == 'd')
				lea edx, dwDMALow
			.elseif (al == 'h')
				lea edx, dwDMAHigh
			.elseif (al == 'p')
				lea edx, dwMidi
				invoke gethex
				jmp skipbyte
			.elseif (al == 't')
				lea edx, dwModel
			.elseif ((al >= 'a') && (al <= 'z'))
				lea edx, dwTmp
			.elseif (al == ' ')
				jmp skipbyte
			.endif
			invoke getnum
skipbyte:
			dec ecx
		.endw
		@strace <"SndInit: Base=", dwBase, " Irq=", dwIrq, " DMALow=", dwDMALow, " DMAHigh=", dwDMAHigh>
		.if ((dwBase != -1) && (dwIrq != -1) && (dwDMALow != -1))
			invoke SBResetDSP, dwBase
			@strace <"SBResetDSP=", eax>
			cmp al,0AAh
			jnz done
			invoke SBGetVersion, dwBase
			cmp al,?MINDSPVER	;is it a SB16/AWE32 + SB Pro?
			jb done
			mov g_bDSPVer, al
if ?SBPROONLY
			mov g_bDSPVer, 3	;SB Pro fix	
endif
			invoke AllocDmaMem
			jc done

			mov eax, dwBase
			mov ecx, dwIrq
			mov edx, dwDMALow
			mov g_dwSBBase, eax
			mov g_dwSBIrq, ecx
			mov g_dwDMALow, edx
			mov ah,1
			.if (cl < 8)
				shl ah,cl
				mov al,21h
			.else
				sub cl,8
				shl ah,cl
				mov al,0A1h
			.endif
			mov byte ptr g_wPicPort, al
			mov g_bPicMask, ah
			mov eax, dwDMAHigh
if ?SBPRO
			.if (g_bDSPVer < 4)	;no high DMA for SB Pro
				mov eax, -1
			.endif
endif
			mov ecx, dwMidi
			mov edx, dwModel
			mov g_dwDMAHigh, eax
			mov g_dwSBMidi, ecx
			mov g_dwSBModel, edx
			WRITEDSP g_dwSBBase, DSP_ENABLESPEAKER
		.endif
	.endif
done:
	mov eax, g_dwSBBase
	inc eax
	@strace <"SndInit()=", eax, " base=", g_dwSBBase, " irq=", g_dwSBIrq, " DMALow=", g_dwDMALow, " DMAHigh=", g_dwDMAHigh, " midi=", g_dwSBMidi>
	ret
	align 4
SndInit endp

SndDeinit proc public

	invoke SBResetDSP, -1
if 0
	mov g_pSndEvent,7FFF0000h
endif
	invoke FreeDmaMem
	@strace <"SndDeinit()">
	ret
	align 4

SndDeinit endp

;--- set sound event proc
;--- out: old event proc

SndSetEventProc proc public pEventProc:ptr
	mov eax, pEventProc
	xchg eax, g_pSndEvent
	@strace <"SndSetEventProc(", pEventProc, ")=", eax>
	ret
	align 4
SndSetEventProc endp

;--- check if format is supported
;--- out: 0=no, 1=yes, 2=must be reduced to 8-bit

SndSetWaveFormat proc public uses ebx pwfx:ptr WAVEFORMATEX, fdwOpen:dword

local	nAlign:dword

	mov ebx, pwfx
	xor eax, eax
	movzx ecx, [ebx].WAVEFORMATEX.wFormatTag
	cmp ecx, WAVE_FORMAT_UNKNOWN
	jz @F
	cmp ecx, WAVE_FORMAT_PCM
	jz @F
	cmp ecx, WAVE_FORMAT_ADPCM
	jnz error1
@@:
	movzx eax, [ebx].WAVEFORMATEX.nChannels
	cmp eax, 2
	ja error2
	mov g_dwChannels, eax
	movzx eax, [ebx].WAVEFORMATEX.wBitsPerSample
	cmp eax, 16
	ja error3
	mov g_dwBitsPerSample, eax
	test fdwOpen, WAVE_FORMAT_QUERY
	jnz done
	mov ecx,80808080h
	cmp al,8
	jbe @F
	cmp g_bDSPVer,4	;is it a SB Pro?
	jb @F
	xor ecx, ecx
@@:
	mov g_dwClrValue, ecx
	movzx eax, [ebx].WAVEFORMATEX.nChannels
	movzx ecx, [ebx].WAVEFORMATEX.wBitsPerSample
	mul ecx
	shr eax, 3
	mov nAlign, eax	;16*2->32->4 ;	8*2->16->2
	mov ecx, [ebx].WAVEFORMATEX.nSamplesPerSec
	mov g_dwSamplesPerSec, ecx
	mul ecx

;--- divide DMA buffer in parts:
;--- each part can hold about 46 ms sound data
;--- which gives a latency of 46 - 92 ms

;--- for 16 kB buffer:

;--- 16 bit stereo at 44100 -> 176.400	-> 2 parts, 2000h

;--- 16 bit stereo at 22050 ->	88.200	-> 4 parts, 1000h
;--- 16 bit   mono at 44100 ->	88.200
;---  8 bit stereo at 44100 ->	88.200

;--- 16 bit stereo at 11025 ->	44.100	-> 8 parts, 800h
;--- 16 bit   mono at 22050 ->	44.100
;---  8 bit stereo at 22050 ->	44.100
;---  8 bit   mono at 44100 ->	44.100

;--- 16 bit   mono at 11025 ->	22.050	-> 16 parts, 400h
;---  8 bit stereo at 11025 ->	22.050
;---  8 bit   mono at 22050 ->	22.050

;---  8 bit   mono at 11025 ->	11.025	-> 16 parts (latency doubled)

	mov edx, g_dwDmaSize
	.while (edx > 4000h)
		shr edx, 1
	.endw
	.if (eax > 88200)
		shr edx, 1
	.elseif (eax >	44100)
		shr edx, 2
	.elseif (eax >	22050)
		shr edx, 3
	.else
		shr edx, 4
	.endif
	mov g_dwDmaPart, edx
	@strace <"SBSetWaveFormat: g_dwDmaPart=", edx>
done:
	mov eax,1
	.if ((g_bDSPVer < 4) && (g_dwBitsPerSample > 8))
		inc eax
	.endif
ifndef _DEBUG
error1:
error2:
error3:
endif
exit:
	@strace <"SBSetWaveFormat()=", eax>
	ret
ifdef _DEBUG
error1:
	@strace <"SndSetWaveFormat: error 1, format=", ecx>
	jmp exit
error2:
	movzx ecx, [ebx].WAVEFORMATEX.nChannels
	@strace <"SndSetWaveFormat: error 2, channels=", ecx>
	jmp exit
error3:
	movzx ecx, [ebx].WAVEFORMATEX.wBitsPerSample
	@strace <"SndSetWaveFormat: error 3, bits/sample=", ecx>
	jmp exit
endif
	align 4
SndSetWaveFormat endp

;--- get INT for SB IRQ
;--- no need to save ebx

GetInterrupt proc
if 1
	mov ax,0400h	;modifies ebx
	int 31h
else
	mov dx,0870h
endif
	mov al, g_bSBIrq
	.if (al < 8)
		add al,dh
	.else
		sub al,8
		add al,dl
	.endif
	ret
	align 4
GetInterrupt endp

FreeDmaMem proc
	.if (g_dwDosSel)
		mov g_DmaBuffer.pStart,0F0000h	;to be safe set to ROM Bios
		xor edx, edx
		xchg edx, g_dwDosSel
		mov ax,0101h
		int 31h
	.endif
	ret
	align 4
FreeDmaMem endp

DeinitIrq proc public
	.if (word ptr g_dfOldIrq+4)
		push ebx
		mov dx,g_wPicPort
		in al,dx
		or al, g_bOldBit
		out dx,al
		invoke GetInterrupt
		mov bl, al
		xor ecx, ecx
		xchg cx, word ptr g_dfOldIrq+4
		mov edx, dword ptr g_dfOldIrq+0
		mov ax,0205h
		int 31h
		pop ebx
	.endif
	ret
	align 4
DeinitIrq endp

InitIrq proc uses ebx

	cmp g_dwSBBase,-1
	jz exit
	.if (!(word ptr g_dfOldIrq+4))
		invoke GetInterrupt
		mov bl, al
ifdef _DEBUG
		movzx eax,al
		@strace <"installing sound IRQ proc at INT ", eax>
endif            
		mov ax, 0204h
		int 31h
		mov dword ptr g_dfOldIrq+0, edx
		mov word ptr g_dfOldIrq+4, cx
		mov ecx, cs
		mov edx, offset SBIrqProc
		mov ax, 0205h
		int 31h
		mov dx,g_wPicPort
		mov ah, g_bPicMask
		in al,dx
		push eax
		and al,ah
		mov g_bOldBit, al
		pop eax
		not ah
		and al,ah
		out dx,al
ifdef _DEBUG
		movzx edx,dx
		movzx eax,ax
		@strace <"PIC port ", edx, " mask ", eax>
endif            
;		invoke atexit, offset DeinitIrq
	.endif
	clc
exit:
	ret
	align 4
InitIrq endp

;--- PCM data format is either 8-bit unsigned or 16-bit signed		  

SBWritePlayCmd proc

if ?SBPRO
	.if (g_bDSPVer < 4)
		WRITEDSP g_dwSBBase, 90h ;8 bit DMA autoinit highspeed (>23 kHz)
		jmp done
	.endif
endif

	.if (g_dwBitsPerSample == 8)
		@strace <"SBWritePlayCmd 8 bit, channels=", g_dwChannels>
		mov cl,0C6h
		mov ah, DSP_MODE_UNSIGNED
	.else
		@strace <"SBWritePlayCmd 16 bit, channels=", g_dwChannels>
		mov cl,0B6h
		mov ah, DSP_MODE_SIGNED
	.endif
	WRITEDSP g_dwSBBase, cl
	WAITWRITE
	mov ecx, g_dwDmaPart
	.if ((g_dwBitsPerSample == 16) && (g_bDMAHigh != -1))
;;  .if (([ebx].WAVEOBJ.wf.wBitsPerSample == 16) && (g_bDMAHigh >= 4))
		shr ecx, 1
	.endif
	.if (g_dwChannels == 2)
		mov al, DSP_MODE_STEREO
	.else
		mov al, DSP_MODE_MONO
	.endif
	or al,ah
	out dx,al
	dec ecx
	WAITWRITE
	mov al,cl		;first LOWER PART
	out dx,al
	WAITWRITE
	mov al,ch		;then HIGHER PART
	out dx,al
done:
	ret
	align 4
SBWritePlayCmd endp

;--- a new WAVEOBJ has been created, prepare SB for it

;--- SB Pro: 
;--- 1. set mono/stereo output in mixer
;--- 2. set time constant (40h)
;--- 3. set DMA block size (48h)
;--- 4. Init DMA controller

;--- SB16: 
;--- 1. Init DMA controller
;--- 2. set sample rate (41h)

SBPrepareDSP proc

	mov eax, g_dwDMAHigh
;;	.if (([ebx].WAVEOBJ.wf.wBitsPerSample == 8) || (al == -1))
;;	.if (al == -1)
	.if ((al == -1) || (g_dwBitsPerSample == 8))
		mov eax, g_dwDMALow
	.endif
	invoke InitDMA

;;	.if (([ebx].WAVEOBJ.wf.wBitsPerSample == 8) || (g_bDMAHigh < 4))
	.if (g_dwBitsPerSample == 8)
		mov al, DSP_PAUSE8BIT	
		mov ah, DSP_CONTINUE8BIT	
		mov edx, g_dwSBBase
		add dl, SB_DSPINTACK
	.else
		mov al, DSP_PAUSE16BIT	
		mov ah, DSP_CONTINUE16BIT	
		mov edx, g_dwSBBase
		add dl, SB16_DSPINTACK
	.endif
	mov g_bPauseCmd, al 
	mov g_bContCmd, ah
	mov g_dwIrqAck, edx

if ?SBPRO
	.if (g_bDSPVer < 4)

;--- set mixer mono/stereo

		.if (g_dwChannels == 2)
			mov cl, 11h+2
		.else
			mov cl, 11h+0
		.endif

		mov edx, g_dwSBBase
		add dl, 4			;Mixer
		mov al, 0Eh			;this mixer register is for SB Pro only
		out dx, al
		inc dx
		mov al, cl			;set mono/stereo output
		out dx, al

;--- set DSP time constant

		mov ecx, g_dwSamplesPerSec
		mov edx, g_dwChannels
		.if (dl > 1)
			shl ecx, 1
		.endif
		mov eax, 1000000
		cdq
		div ecx
		neg al
		mov cl,al
		WRITEDSP g_dwSBBase, DSP_SETTIMECONST
		WAITWRITE
		mov al,cl
		out dx,al

;--- set DSP DMA blocksize

		WRITEDSP g_dwSBBase, DSP_SETDMABLOCKSIZE
		WAITWRITE
		mov ecx, g_dwDmaPart
		dec ecx
		mov al,cl		;first LOWER PART
		out dx,al
		WAITWRITE
		mov al,ch		;then HIGHER PART
		out dx,al
;		WRITEDSP g_dwSBBase, DSP_ENABLESPEAKER
	.endif
endif
	.if (g_bDSPVer >= 4)
		WRITEDSP g_dwSBBase, DSP_SETOUTSAMPLERATE
		mov ecx, g_dwSamplesPerSec
		WAITWRITE
		mov al,ch
		out dx,al
		WAITWRITE
		mov al,cl
		out dx,al
	.endif
	mov g_bPrepared, 1
	ret
	align 4
SBPrepareDSP endp

PageXLat DB 87H,83H,81H,82H,8Fh,8BH,89H,8AH

; Setup DMA-controller
; inp: eax=channel

;--- DMA low mode : 00 + 000A

;--- DMA high mode : C0 + 000A * 2 == D4
;--- DMA write	   : C0 + 000B * 2 == D6
;--- DMA flipflop  : C0 + 000C * 2 == D8


InitDMA proc

	@strace <"InitDMA enter, channel=", eax>
	pushad
	mov ebx, eax
	and ebx, 7

	.if (al < 4)

		mov al, bl						; 1. MASK DMA CHANNEL
		or al, DMA_MASK_DISABLE_CHN
		out 000Ah, al
;
		out 000Ch,al					; 2. CLEAR FLIPFLOP
;
		mov al, DMA_MODE_SINGLE + DMA_MODE_AUTOINIT + DMA_MODE_READ
		or al, bl
		out 000Bh,al					; 3. WRITE TRANSFER MODE
;
		movzx edx, [PageXLat+ebx]
		mov al, byte ptr g_dwDmaPhys+2
		out dx, al						; 4. WRITE PAGE NUMBER
;
		mov edx, ebx					; low base dma is 0000!
		shl edx,1
		mov eax, g_dwDmaPhys
		out dx, al						; 5. WRITE BASEADDRESS
		mov al, ah
		out dx, al
;
		inc edx
		mov eax, g_dwDmaSize
		dec eax
		out dx, al						; 6. WRITE SAMPLELENGTH-1
		mov al, ah
		out dx, al
;
		mov al, bl
		out 000Ah,al					; 7. DEMASK CHANNEL
;

	.else

		mov al, bl				; 1.  MASK DMA CHANNEL
		sub al,4
		or al,DMA_MASK_DISABLE_CHN
		out 00D4h,al
;
		out 00D8h,al			; 2.  CLEAR FLIPFLOP
;
		mov al, bl
		sub al, 4
		or al, DMA_MODE_SINGLE + DMA_MODE_AUTOINIT + DMA_MODE_READ
		out 00D6h,al			; 3.  WRITE TRANSFER MODE
;
		movzx edx, [PageXLat+ebx]
		mov eax, g_dwDmaPhys
		shr eax, 16
		and al, 0FEh			;reset bit 0 for 16bit dma
		out dx, al				; 4.  WRITE PAGE NUMBER
;
		mov edx, ebx
		sub dl, 4
		shl edx, 2				;4 ports for each channel
		or	dl, 0C0h			;high dma io base is 00C0h
		mov eax, g_dwDmaPhys
		shr eax, 1
		out dx, al				; 5. WRITE BASEADDRESS (low + high)
		mov al, ah
		out dx, al
;
		add edx, 2
		mov eax, g_dwDmaSize
		shr eax, 1				;count is in WORDs!
		dec eax
		out dx, al				; 6. WRITE SAMPLELENGTH-1 (low + high)
		mov al, ah
		out dx, al
;
		mov al, bl
		sub al, 4
		out 00D4h,al			; 7. DEMASK CHANNEL
;
	.endif

	popad
	ret
	align 4
InitDMA endp

;--- alloc dos memory for DMA buffer
;--- out: C on error

DDS struct
dwSize	dd ?	;size of region
dwOfs	dd ?	;offset virtual start address
wSeg	dw ?	;segment/selector virtual start address (or 0000)
wID		dw ?	;buffer ID
dwPhys	dd ?	;physical address
DDS ends

AllocDmaMem proc uses ebx esi edi

local	pStart:dword
local	rmcs:RMCS

	@strace <"AllocDmaMem() enter">
	cmp g_dwDosSel,0
	jnz done
	mov bx,2*?DMABUFSIZE/16		;alloc double the size
	mov ax,0100h
	int 31h
	jc error
	movzx eax,ax
	shl eax, 4
	mov pStart, eax
	mov g_dwDosSel, edx

if 0
	test @flat:[47Bh],20h	;VDS implemented?
	jz novds
	mov bl,4Bh
	mov ax,0200h
	int 31h
	mov eax,ecx
	or ax,dx
	jz novds				;int 4Bh is 0000:0000
	xor edx,edx
	mov ax,8102h
	stc
	int 4Bh
	jc novds
	cmp ax,8102h
	jz novds

	mov ebx, pStart
	mov @flat:[ebx].DDS.dwSize, ?DMABUFSIZE
	mov @flat:[ebx].DDS.dwOfs, 0
	mov eax, ebx
	shr eax, 4
	mov [edi].RMCS.rES, ax
	mov @flat:[ebx].DDS.wSeg, ax
	.while (1)
		mov rmcs.rAX, 8103h
		mov rmcs.rDX, 001Ch	;dont alloc buffer, dont remap, no 64k crossing
		xor eax,eax
		mov rmcs.rSSSP, eax
		mov rmcs.rDI, ax
		lea edi, rmcs
		mov bx,004Bh
		mov cx,0000h
		mov ax,0300h
		int 31h
		.break .if (!(byte ptr rmcs.rFlags & 1))
		mov ebx, pStart
		mov eax, @flat:[ebx].DDS.dwOfs
		add eax, 1000h
		mov @flat:[ebx].DDS.dwOfs,eax
		cmp eax,?DMABUFSIZE
		jnc novds
	.endw
	mov ebx, pStart
	mov eax, [ebx].DDS.dwPhys
	jmp xxx
novds:        
	mov eax, pStart
endif

	mov ecx, eax
	lea ebx, [eax+?DMABUFSIZE-1]
	shr ecx, 16
	shr ebx, 16

;--- examples for 32 kb dma size:
;--- eax = 0000FA00h -> edx = 00017A00h, ecx = 00010000h -> uses 2 segs
;--- eax = 00010000h -> edx = 00018000h, ecx = 00020000h -> fits in 1 seg
;--- examples for 16 kb dma size:
;--- eax = 0000FA00h -> edx = 00013A00h, ecx = 00010000h -> uses 2 segs
;--- eax = 00012000h -> edx = 00016000h, ecx = 00020000h -> fits in 1 seg
;--- eax = 0001C000h -> edx = 00020000h, ecx = 00020000h -> fits in 1 seg

	.if (ecx != ebx)		;does the first half cross a 64 kb boundary?
		shl ebx, 16
	.else
		mov ebx, eax
	.endif
	mov g_DmaBuffer.pStart, ebx
	mov g_DmaBuffer.pCsr, ebx
	mov g_dwDmaPhys, ebx
	add ebx, ?DMABUFSIZE
	mov g_DmaBuffer.pEnd, ebx
	sub ebx, eax
	shr ebx, 4
	mov edx, g_dwDosSel
	mov ax,0102h			;resize dos memory
	int 31h
	mov ecx, ?DMABUFSIZE
	mov g_dwDmaSize, ecx
	mov g_dwDmaFree, ecx
	clc
error:
done:
	@strace <"AllocDmaMem() exit">
	ret
	align 4
AllocDmaMem endp

;--- out: in eax bytes played since last IRQ

SndGetPlayCsrPos proc public pPlayCsr:ptr DWORD

;--- disable the sound irq

if 0
	mov dx,g_wPicPort
	in al,dx
	or al,g_bPicMask
	out dx,al
else
	pushfd
	cli
endif

;--- now get the current DMA position

	xor eax, eax
	mov ecx, g_dwDmaPhys
	.if ((g_dwBitsPerSample == 8) || (g_bDMAHigh < 4))
		out 000Ch,al			; CLEAR FLIPFLOP
		mov edx, g_dwDMALow
		shl edx,1
		in al,dx
		movzx ecx, cx
		mov ah, al
		in al, dx
		xchg al,ah
	.else
		out 00D8h,al		; CLEAR FLIPFLOP
		mov edx, g_dwDMAHigh
		sub dl, 4
		shl edx, 2			; 4 ports for each channel
		or dl, 0C0h			; high dma io base is 00C0h
		in al,dx
		and ecx, 1FFFFh
		mov ah, al
		in al, dx
		xchg al,ah
		shl eax, 1
	.endif
	mov edx,pPlayCsr
	mov edx,[edx]

	sub eax, ecx
	sub eax, g_dwDmaPlay

;--- reenable the sound IRQ

if 0
	push edx
	push eax
	mov dx,g_wPicPort
	in al,dx
	mov ah,g_bPicMask
	not ah
	and al,ah
	out dx,al
	pop eax
	pop edx
else
	test byte ptr [esp+1],2
	jz @F
	sti
@@:
	popfd
endif

	@strace <"SndGetPlayCsrPos()=", eax, " ecx=", ecx, " dwDmaPlay=", g_dwDmaPlay>
	ret
	align 4
SndGetPlayCsrPos endp

SndPause proc public
	@strace <"SndPause">
	xor eax, eax
	.if (!g_bPaused)
		WRITEDSP g_dwSBBase, g_bPauseCmd
		mov g_bPaused, TRUE
		@mov eax, 1
	.endif
	@strace <"SndPause()=", eax>
	ret
	align 4
SndPause endp

SndContinue proc public
	@strace <"SndContinue">
	.if (g_bPaused)
		mov g_bPaused, FALSE
		WRITEDSP g_dwSBBase, g_bContCmd
	.endif
done:
	@strace <"SndContinue()=", eax>
	ret
	align 4
SndContinue endp

SndReinit proc public uses ebx

	.if (g_bInit)
		invoke SBResetDSP, g_dwSBBase
		call SBPrepareDSP
		call SBWritePlayCmd
	.endif
	@strace <"SndReinit()=", eax>
	ret
	align 4

SndReinit endp

;--- return DMA buffer linear address in EAX
;--- and size in EDX

SndGetDMABuffer proc public

	invoke SndInit
	and eax, eax
	jz error
	mov eax, g_DmaBuffer.pStart
	mov edx, g_dwDmaSize
	ret
error:
	@strace <"SndGetDMABuffer()=", eax>
	ret
	align 4
SndGetDMABuffer endp

;--- returns:
;--- eax=wave caps
;--- edx=midi caps

SndGetCaps proc public

	invoke SndInit
	and eax, eax
	jz error
	movzx eax, g_bDSPVer
	.if (eax >= 4)
		mov eax, ?SB16_WAVE_FORMATS
		mov edx, 1		;midi supported
	.else
		mov eax, ?SBPRO_WAVE_FORMATS
		xor edx, edx
	.endif
error:
	ret
	align 4
SndGetCaps endp

;-------------------------------------------------
;--- MPU-401 part
;-------------------------------------------------
;--- the midi interface is very simple:
;--- there are 2 ports, usually 330h/331h (or 300h/301h]
;--- 330h is used to send and receive data
;--- 331h is used to read status and write commands

;--- 331h, bit 7 (80h): 0=data is available at 330h
;--- 331h, bit 6 (40h): 0=data can be written to 330h or 331h

SBWriteMPUCmd proc
	mov edx, g_dwSBMidi
	inc edx
	mov ah,al
	mov ecx, 10000h
@@:
	in al,dx
	test al,40h
	loopnz @B
	mov al, ah
	out dx, al
	ret
	align 4
SBWriteMPUCmd endp

;--- write data in AL

SBWriteMPUData proc
	mov edx, g_dwSBMidi
	inc edx
	mov ah,al
	mov ecx, 10000h
@@:
	in al,dx
	test al,40h
	loopnz @B
	dec edx
	mov al, ah
	out dx, al
	ret
	align 4
SBWriteMPUData endp

;--- write data in EAX (24 bits)

SBWriteMPUShortMsg proc
	push eax
	call SBWriteMPUData
	mov eax, [esp]
	mov al,ah
	call SBWriteMPUData
	mov eax, [esp]
	test al,80h			;is first byte a status byte?
	jz @F
	shr eax, 16
	call SBWriteMPUData
@@:
	pop eax
	ret
	align 4
SBWriteMPUShortMsg endp

SBReadMPUData proc
	mov edx, g_dwSBMidi
	inc edx
	mov ecx, 10000h
@@:
	in al,dx
	test al,80h
	loopnz @B
	dec edx
	in al,dx
	ret
	align 4
SBReadMPUData endp

SndGetMidiPort proc public
	mov eax, g_dwSBMidi
	ret
	align 4
SndGetMidiPort endp

;--- reset is done by writing FF to command port,
;--- then get an ACK (FE) from the data port

SBResetMPU proc
	mov ecx, g_dwSBMidi
	.if (ecx != -1)
if 1    ;stop playing
		mov al,04h
		invoke SBWriteMPUCmd
		invoke SBReadMPUData
endif
		mov al,0FFh
		invoke SBWriteMPUCmd
		invoke SBReadMPUData
		.if (al == 0FEh)
			@strace <"SBResetMPU: reset ok, got ACK(FEh) as response to FF">
			mov eax, 1
			jmp exit
		.endif
ifdef _DEBUG
		movzx eax,al
		@strace <"SBResetMPU: reset failed, got ", eax," as response to FF"> 
endif
	.endif
	xor eax, eax
exit:
	ret
	align 4
SBResetMPU endp

;--- SB Midi part (not used)

if ?SBMIDI

SBWriteMidiCmd proc
	.if (al == 3Fh)
		or g_bInit, SBINIT_UART
	.elseif (al == 0FFh)
;		WRITEDSP g_dwSBBase, DSP_MIDIREADPOLLWRITEPOLL
		and g_bInit, not SBINIT_UART
	.endif
	ret
	align 4
SBWriteMidiCmd endp

;--- write data in AL

SBWriteMidiData proc
	push eax
	WRITEDSP g_dwSBBase, DSP_MIDIWRITEPOLL
	WAITWRITE
	pop eax
	out dx, al
	ret
	align 4
SBWriteMidiData endp

;--- write data in EAX (24 bits)

SBWriteMidiShortMsg proc
	push eax
	call SBWriteMidiData
	mov eax, [esp]
	mov al,ah 
	call SBWriteMidiData
	mov eax, [esp]
	test al,80h			;is first byte a status byte?
	jz @F
	shr eax, 16
	call SBWriteMidiData
@@:
	pop eax
	ret
	align 4
SBWriteMidiShortMsg endp

SBReadMidiData proc
	WRITEDSP g_dwSBBase, DSP_MIDIREADPOLL
	WAITREAD
	in al,dx
	ret
	align 4
SBReadMidiData endp

SBResetMidi proc
	mov al,0FFh
	invoke SBWriteMidiCmd
	mov eax, 1
	ret
	align 4
SBResetMidi endp
endif

SndSetMidiDevice proc public uDevice:dword, pProcs:ptr MIDIPROCS

	mov edx, pProcs
if ?SBMIDI
	.if ((uDevice == 0) || (uDevice == -1))
endif        
		mov [edx].MIDIPROCS.pReset,     offset SBResetMPU
		mov [edx].MIDIPROCS.pReadData,  offset SBReadMPUData
		mov [edx].MIDIPROCS.pWriteData, offset SBWriteMPUData
		mov [edx].MIDIPROCS.pWriteCmd,  offset SBWriteMPUCmd
		mov [edx].MIDIPROCS.pWriteShortMsg, offset SBWriteMPUShortMsg
if ?SBMIDI            
	.else
		mov [edx].MIDIPROCS.pReset,         offset SBResetMidi
		mov [edx].MIDIPROCS.pReadData,      offset SBReadMidiData
		mov [edx].MIDIPROCS.pWriteData,     offset SBWriteMidiData
		mov [edx].MIDIPROCS.pWriteCmd,      offset SBWriteMidiCmd
		mov [edx].MIDIPROCS.pWriteShortMsg, offset SBWriteMidiShortMsg
	.endif
endif        
	@strace <"SndSetMidiDevice(", uDevice, ", ", pProcs, ")=", eax>
	ret
	align 4
SndSetMidiDevice endp

	end
