
;--- implementes waveOutXXX()

	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:none
	option proc:private

	include winbase.inc
	include winuser.inc
	include mmsystem.inc
	include winmm.inc
	include macros.inc
	include sb16.inc

WAVE_TYPE	equ "WAVE"

	.DATA

g_dwHWO 	   dd 0	;current WAVEOBJ owning the WAVE device
g_hWOEvent	   dd 0	;used for communication between IRQ and wave thread
g_lpfnCopyProc dd 0
g_bInit		   db 0	;
g_bShiftLeft   db 0	;dma -> buffer shift left value (0 or 1)

;--- g_bInit flag values

FWO_THREAD	equ 2	;mm thread started

	.CODE

woDeinit proc public
	@strace <"woDeinit enter">
	mov ecx, g_dwHWO
	.if (ecx)
		mov [ecx].WAVEOBJ.lpfnCallback, 0	;do not call callbacks anymore
		invoke waveOutClose, ecx
	.endif
	@strace <"woDeinit exit">
	ret
	align 4
woDeinit endp

@repmovsb macro
	mov al,cl
	shr ecx, 2
	rep movsd
	mov cl,al
	and cl,3
	rep movsb
	endm

;--- esi->WAVEHDR
;--- ebx->WAVEOBJ
;--- ebp->DMABUFFER

;--- updates write cursors in WAVEOBJ (global) and WAVEHDR
;--- copy is restricted to write DMABUFFER.dwSize bytes!

;--- this code is ensured to be serialized

WriteToSndBuffer proc

	mov ecx, [esi].WAVEHDR.dwBufferLength
	mov eax, [esi].WAVEHDR.reserved
	mov edx, [edi].DMABUFFER.dwSize
	sub ecx, eax
	.if (ecx > edx)
		mov ecx, edx
	.endif
	add [esi].WAVEHDR.reserved, ecx
	add [ebx].WAVEOBJ.dwWriteCsr, ecx
	add [ebx].WAVEOBJ.dwBytesToPlay, ecx
	sub [edi].DMABUFFER.dwSize, ecx
	test [esi].WAVEHDR.dwFlags, WHDR_PRIMARY
	jnz dummycopy

	push esi
	push edi
	add eax, [esi].WAVEHDR.lpData
	mov esi, eax
ife ?FLAT
	push es
	push @flat
	pop es
endif
	mov edx, edi
	mov eax, [edi].DMABUFFER.pEnd
	mov edi, [edi].DMABUFFER.pCsr
	sub eax, edi
	.if (eax < ecx)
		sub ecx, eax
		push ecx
		mov ecx, eax
		@repmovsb
		pop ecx
		mov edi, [edx].DMABUFFER.pStart
	.endif
	@repmovsb
	mov [edx].DMABUFFER.pCsr, edi
ife ?FLAT
	pop es
endif
	pop edi
	pop esi
	ret
dummycopy:
	mov eax, [edi].DMABUFFER.pCsr
	add eax, ecx
	.if (eax >= [edi].DMABUFFER.pEnd)
		sub eax, [edi].DMABUFFER.pEnd
		add eax, [edi].DMABUFFER.pStart
	.endif
	mov [edi].DMABUFFER.pCsr, eax
	ret
	align 4

WriteToSndBuffer endp

;--- esi->WAVEHDR
;--- ebx->WAVEOBJ
;--- ebp->DMABUFFER

;--- convert 16bit signed to 8bit unsigned
;--- -32768 (8000h) -> 00h
;--- 0				-> 80h
;--- +32767 (7FFFh) -> FFh

@rep2movsb macro

local nextbyte, copydone, nolastbyte

	mov dl,cl
	shr ecx, 1
	jz copydone
nextbyte:
	mov eax,[esi+0]
	add eax,80008000h
	mov dh,ah
	shr eax,16
	add esi,4
	mov al,dh
	mov @flat:[edi+0],ax
	add edi,2
	dec ecx
	jnz nextbyte
copydone:
	test dl,1
	jz nolastbyte
	mov ax,[esi+0]
	add ah,80h
	add esi,2
	mov @flat:[edi+0],ah
	inc edi
nolastbyte:
	endm

;--- this code is ensured to be serialized

WriteToSndBuffer2 proc

	mov ecx, [esi].WAVEHDR.dwBufferLength
	mov eax, [esi].WAVEHDR.reserved
	sub ecx, eax
	shr ecx, 1					;we only use the upper half of each word!
	mov edx, [edi].DMABUFFER.dwSize
	sub ecx, eax
	.if (ecx > edx)
		mov ecx, edx
	.endif
	lea edx, [ecx*2]
	add [esi].WAVEHDR.reserved, edx
	add [ebx].WAVEOBJ.dwWriteCsr, edx
	add [ebx].WAVEOBJ.dwBytesToPlay, edx
	sub [edi].DMABUFFER.dwSize, ecx
	test [esi].WAVEHDR.dwFlags, WHDR_PRIMARY
	jnz dummycopy

	push esi
	push edi
	push ebx
	add eax, [esi].WAVEHDR.lpData
	mov esi, eax
ife ?FLAT
	push es
	push @flat
	pop es
endif
	mov ebx, edi
	mov eax, [edi].DMABUFFER.pEnd
	mov edi, [edi].DMABUFFER.pCsr
	sub eax, edi			;eax = bytes free until end of buffer
	.if (eax < ecx)
		sub ecx, eax
		push ecx
		mov ecx, eax
		@rep2movsb
		pop ecx
		mov edi, [ebx].DMABUFFER.pStart
	.endif
	@rep2movsb
	mov [ebx].DMABUFFER.pCsr, edi
ife ?FLAT
	pop es
endif
	pop ebx
	pop edi
	pop esi
	ret
dummycopy:
	mov eax, [edi].DMABUFFER.pCsr
	add eax, ecx
	.if (eax >= [edi].DMABUFFER.pEnd)
		sub eax, [edi].DMABUFFER.pEnd
		add eax, [edi].DMABUFFER.pStart
	.endif
	mov [edi].DMABUFFER.pCsr, eax
	ret
	align 4

WriteToSndBuffer2 endp

;--- this is called during interrupt time
;--- SS most likely is not flat!

woEventProc proc uses ebx esi edi

	mov edi, [esp+4*4+0]
	mov ecx, [esp+4*4+4]

	@strace <"woEventProc, edi=", edi, " ecx=", ecx>

	mov ebx, g_dwHWO
	and ebx, ebx
	jz nowave
	mov esi, [ebx].WAVEOBJ.pWaveHdr

	.if (ecx & SND_BUFFERPLAYED)

;--- update the global play cursor in WAVEOBJ

		mov eax, [ebx].WAVEOBJ.dwBytesToPlay
		mov ecx, [edi].DMABUFFER.dwSize
		.if (g_bShiftLeft)
			shl ecx, 1
		.endif
		.if (eax > ecx)
			mov eax, ecx
		.endif
		add [ebx].WAVEOBJ.dwPlayCsr, eax
		sub [ebx].WAVEOBJ.dwBytesToPlay, eax

;--- if current WAVEHDR is looping, adjust global play cursor

		.if (esi && ([esi].WAVEHDR.dwFlags & WHDR_BEGINLOOP) && ([esi].WAVEHDR.dwLoops))
			mov edx, [esi].WAVEHDR.dwBufferLength
			.if ([ebx].WAVEOBJ.dwPlayCsr >= edx)
				sub [ebx].WAVEOBJ.dwPlayCsr, edx
			.endif
		.endif

	.endif

;--- copy new audio data to the dma buffer or, if the dma buffer
;--- is accessed directly, adjust the variables at least

	.while (esi)
		.if ([esi].WAVEHDR.dwFlags & WHDR_BEGINLOOP)
			mov eax, [esi].WAVEHDR.reserved
			.if ((eax == [esi].WAVEHDR.dwBufferLength) && ([esi].WAVEHDR.dwLoops))
				dec [esi].WAVEHDR.dwLoops
				mov eax, [esi].WAVEHDR.dwBufferLength
				sub [ebx].WAVEOBJ.dwWriteCsr, eax
				mov [esi].WAVEHDR.reserved, 0
			.endif
		.endif
		@strace <"woEventProc a, DMABuffer.dwSize=", [edi].DMABUFFER.dwSize>
		call g_lpfnCopyProc
		@strace <"woEventProc b, DMABuffer.dwSize=", [edi].DMABUFFER.dwSize>
		.break .if [edi].DMABUFFER.dwSize == 0
		mov esi, [esi].WAVEHDR.lpNext
	.endw
nowave:
	.if (g_hWOEvent)
		invoke SetEvent, g_hWOEvent	;notify wave thread that IRQ happened
	.else
		call _waveDequeueHdr
	.endif

	ret 8
	align 4

woEventProc endp

;--- ebx=WAVEOBJ
;--- esi=WAVEHDR (for WOM_DONE only)

_waveSendNotification proc dwFunc:dword, dwMsg:dword

	.if ([ebx].WAVEOBJ.lpfnCallback)
		mov edx, [ebx].WAVEOBJ.fdwOpen
		and edx, CALLBACK_TYPEMASK
		.if (dwFunc == WOM_DONE)
			mov ecx, esi
		.else
			xor ecx, ecx
		.endif
		.if (edx == CALLBACK_FUNCTION)
			invoke [ebx].WAVEOBJ.lpfnCallback, ebx, dwFunc, [ebx].WAVEOBJ.dwCallbackInstance, ecx, 0
		.elseif (edx == CALLBACK_WINDOW)
			invoke SendMessage, [ebx].WAVEOBJ.hwnd, dwMsg, ebx, ecx
		.elseif (edx == CALLBACK_THREAD)
			invoke PostThreadMessage, [ebx].WAVEOBJ.threadid, dwMsg, ebx, ecx
		.elseif (edx == CALLBACK_EVENT)
			invoke SetEvent, [ebx].WAVEOBJ.hEvent
		.endif
	.endif
	ret
	align 4

_waveSendNotification endp


waveOutOpen proc public uses ebx phwo:ptr DWORD, uDeviceID:dword, pwfx:ptr WAVEFORMATEX,
			dwCallback:dword, dwCallbackInstance:dword, fdwOpen:dword


	.if (!(fdwOpen & WAVE_FORMAT_QUERY))
		.if (g_dwHWO)
			mov eax, MMSYSERR_ALLOCATED
			jmp @exit
		.endif
	.endif
	invoke SndInit
	.if (!eax)
		mov eax, MMSYSERR_NODRIVER
		jmp @exit
	.endif
	invoke SndSetWaveFormat, pwfx, fdwOpen
	.if (!eax)
		mov eax, WAVERR_BADFORMAT
		jmp @exit
	.endif
	.if (fdwOpen & WAVE_FORMAT_QUERY)
		mov eax, MMSYSERR_NOERROR
		jmp @exit
	.endif
	.if (eax == 1)
		mov edx, pwfx
		mov g_lpfnCopyProc, offset WriteToSndBuffer
		mov g_bShiftLeft, 0
	.else
		mov g_lpfnCopyProc, offset WriteToSndBuffer2
		mov g_bShiftLeft, 1
	.endif

	invoke LocalAlloc, LMEM_FIXED or LMEM_ZEROINIT, sizeof WAVEOBJ
	.if (eax)
		mov ebx, eax
		mov g_dwHWO, eax
		invoke SndSetEventProc, offset woEventProc
		mov [ebx].WAVEOBJ.dwType, WAVE_TYPE
		invoke RtlMoveMemory, addr [ebx].WAVEOBJ.wf, pwfx, sizeof WAVEFORMATEX
		mov eax, dwCallback
		mov ecx, dwCallbackInstance
		mov edx, fdwOpen
		mov [ebx].WAVEOBJ.lpfnCallback, eax
		mov [ebx].WAVEOBJ.dwCallbackInstance, ecx
		mov [ebx].WAVEOBJ.fdwOpen, edx
		mov ecx, phwo
		mov [ecx], ebx
		@strace <"waveOutOpen: sending WOM_OPEN ", ebx>
		invoke _waveSendNotification, WOM_OPEN, MM_WOM_OPEN
		mov eax, MMSYSERR_NOERROR
	.else
		mov eax, MMSYSERR_NOMEM
	.endif
@exit:
	@strace <"waveOutOpen(", phwo, ", ", uDeviceID, ", ", pwfx, ", callback=", dwCallback, ", ", dwCallbackInstance, ", ", fdwOpen, ")=", eax>
	ret
	align 4

waveOutOpen endp

waveOutClose proc public uses ebx hwo:DWORD

	@strace <"waveOutClose(", hwo, ") enter">
	mov ebx, hwo
	.if (ebx && (ebx == g_dwHWO))
		invoke waveOutReset, ebx
		.if (g_bInit & FWO_THREAD)
			@strace <"waveOutClose: cancel mm thread">
			and g_bInit, not FWO_THREAD
			invoke StopMMThread
		.endif
		@strace <"waveOutClose: sending WOM_CLOSE ", ebx>
		invoke _waveSendNotification, WOM_CLOSE, MM_WOM_CLOSE
		mov g_dwHWO, 0
		@strace <"waveOutClose: calling SndDeinit ", ebx>
		invoke SndDeinit
		@strace <"waveOutClose: freeing ", ebx>
		invoke LocalFree, ebx
		mov eax, MMSYSERR_NOERROR
	.else
		mov eax, MMSYSERR_INVALHANDLE
	.endif
	@strace <"waveOutClose(", hwo, ")=", eax>
	ret
	align 4

waveOutClose endp

waveOutGetNumDevs proc public

	invoke SndInit
	and eax, eax
	jz @exit
	mov eax, 1
@exit:
	@strace <"waveOutGetNumDevs()=", eax>
	ret
	align 4

waveOutGetNumDevs endp

waveOutPrepareHeader proc public uses ebx hwo:DWORD, pwh:ptr WAVEHDR, cbwh:DWORD

	mov ebx, hwo
	.if (ebx && (ebx == g_dwHWO))
		mov edx, pwh
		.if (!([edx].WAVEHDR.dwFlags & WHDR_PREPARED))
			or [edx].WAVEHDR.dwFlags, WHDR_PREPARED
		.endif
		mov eax, MMSYSERR_NOERROR
	.else
		mov eax, MMSYSERR_INVALHANDLE
	.endif
	@strace <"waveOutPrepareHeader(", hwo, ", ", pwh, ", ", cbwh, ")=", eax>
	ret
	align 4

waveOutPrepareHeader endp

waveOutUnprepareHeader proc public uses ebx hwo:DWORD, pwh:ptr WAVEHDR, cbwh:DWORD

	mov ebx, hwo
	.if (ebx && (ebx == g_dwHWO))
		mov ecx, pwh
		.if (!([ecx].WAVEHDR.dwFlags & WHDR_PREPARED))
			mov eax, MMSYSERR_NOERROR
			jmp @exit
		.endif
		.if ([ecx].WAVEHDR.dwFlags & WHDR_INQUEUE)
			mov eax, WAVERR_STILLPLAYING
			jmp @exit
		.endif
		and [ecx].WAVEHDR.dwFlags, not WHDR_PREPARED
		mov eax, MMSYSERR_NOERROR
	.else
		mov eax, MMSYSERR_INVALHANDLE
	.endif
@exit:
	@strace <"waveOutUnprepareHeader(", hwo, ", ", pwh, ", ", cbwh, ")=", eax>
	ret
	align 4

waveOutUnprepareHeader endp

;--- unlink wavehdr in ESI
;--- ebx = hwo
;--- clear fields lpNext, dwFlags.WHDR_INQUEUE
;--- this code might be called during interrupt time!!!

UnlinkWaveHdr proc

	mov ecx, [ebx].WAVEOBJ.pWaveHdr
	xor edx, edx
	.while (ecx)
		.if (esi == ecx)
			xor eax, eax
			xchg eax, [esi].WAVEHDR.lpNext
			.if (edx)
				mov [edx].WAVEHDR.lpNext, eax
			.else
				mov [ebx].WAVEOBJ.pWaveHdr, eax
			.endif
			and [esi].WAVEHDR.dwFlags, not WHDR_INQUEUE
			.break
		.endif
		mov edx, ecx
		mov ecx, [ecx].WAVEHDR.lpNext
	.endw
	ret
	align 4

UnlinkWaveHdr endp

;--- dequeue the buffers which are played (or at least copied to dma buffer)
;--- notify callbacks, windows, events, (threads?)

;--- this proc is called directly by the event proc if g_hWOEvent == 0
;--- (then _waveSendNotification does nothing)
;--- or it is called by waveout helper thread
;--- in both cases the code is serialized, either by disabled interrupts
;--- or by g_csMM critical section

;--- window callback: wParam=hWO
;--- WOM_DONE: lParam=WAVEHDR

_waveDequeueHdr proc public uses ebx esi

	mov ebx, g_dwHWO
	and ebx, ebx
	jz nowave
	mov esi, [ebx].WAVEOBJ.pWaveHdr
	.while (esi)
		mov eax, [esi].WAVEHDR.reserved
		.break .if (eax != [esi].WAVEHDR.dwBufferLength)
		.break .if (([esi].WAVEHDR.dwFlags & WHDR_BEGINLOOP) && ([esi].WAVEHDR.dwLoops))
		.break .if (([ebx].WAVEOBJ.dwBytesToPlay) && (![esi].WAVEHDR.lpNext))
		push [esi].WAVEHDR.lpNext
		invoke UnlinkWaveHdr
		or [esi].WAVEHDR.dwFlags, WHDR_DONE
		invoke _waveSendNotification, WOM_DONE, MM_WOM_DONE
		pop esi
	.endw
nowave:
	ret
	align 4

_waveDequeueHdr endp

;--- put a WAVEHDR structure to the end of the snd output queue

waveOutWrite proc public uses ebx hwo:DWORD, pwh:ptr WAVEHDR, cbwh:DWORD

	mov ebx, hwo
	.if (ebx && (ebx == g_dwHWO))
		mov edx, pwh
		.if (!([edx].WAVEHDR.dwFlags & WHDR_PREPARED))
			mov eax, WAVERR_UNPREPARED
			jmp @exit
		.endif

		mov edx, pwh
		mov [edx].WAVEHDR.lpNext, 0
		mov [edx].WAVEHDR.reserved, 0
		or [edx].WAVEHDR.dwFlags, WHDR_INQUEUE
		and [edx].WAVEHDR.dwFlags, not WHDR_DONE
		invoke EnterCriticalSection, addr g_csMM
		mov ecx, [ebx].WAVEOBJ.pWaveHdr
		.if (ecx)
			.while ([ecx].WAVEHDR.lpNext)
				mov ecx, [ecx].WAVEHDR.lpNext
			.endw
			mov [ecx].WAVEHDR.lpNext, edx
		.else
			mov [ebx].WAVEOBJ.pWaveHdr, edx
		.endif
		invoke LeaveCriticalSection, addr g_csMM
		.if ([ebx].WAVEOBJ.lpfnCallback)
			.if (!g_hWOEvent)
				invoke CreateEvent, 0, 0, 0, 0
				mov g_hWOEvent, eax
				and eax, eax
				mov eax, MMSYSERR_NOMEM
				jz @exit
				@strace <"waveOutWrite(): event object=", g_hWOEvent>
			.endif
			invoke StartMMThread
			and eax, eax
			mov eax, MMSYSERR_NOMEM
			jz @exit
			or g_bInit, FWO_THREAD
			@strace <"waveOutWrite(): mmthread started">
		.endif
ifdef _DEBUG
		mov ecx, pwh
		@strace <"waveOutWrite(): WAVEHDR.length=", [ecx].WAVEHDR.dwBufferLength, " flags=", [ecx].WAVEHDR.dwFlags, " loops=", [ecx].WAVEHDR.dwLoops>
endif

		.if (![ebx].WAVEOBJ.dwBytesToPlay)
			@strace <"waveOutWrite(): initial fill of DMA buffer">
			invoke SndFillDMABuffer
		.endif
		invoke SndFillDMABuffer

		mov eax, MMSYSERR_NOERROR
	.else
		mov eax, MMSYSERR_INVALHANDLE
	.endif
@exit:
	@strace <"waveOutWrite(", hwo, ", ", pwh, ", ", cbwh, ")=", eax>
	ret
	align 4

waveOutWrite endp

waveOutReset proc public uses ebx esi hwo:DWORD

	mov ebx, hwo
	.if (ebx && (ebx == g_dwHWO))
		xor ecx, ecx
		mov [ebx].WAVEOBJ.dwWriteCsr,ecx
		mov [ebx].WAVEOBJ.dwPlayCsr,ecx
		invoke waveOutPause, ebx
		invoke EnterCriticalSection, addr g_csMM
		mov esi, [ebx].WAVEOBJ.pWaveHdr
		.while (esi)
			push [esi].WAVEHDR.lpNext
			invoke UnlinkWaveHdr
			or [esi].WAVEHDR.dwFlags, WHDR_DONE
			pop esi
		.endw
		invoke LeaveCriticalSection, addr g_csMM
		mov eax, MMSYSERR_NOERROR
	.else
		mov eax, MMSYSERR_INVALHANDLE
	.endif
@exit:
	@strace <"waveOutReset(", hwo, ")=", eax>
	ret
error:
	mov eax, MMSYSERR_INVALHANDLE
	jmp @exit
	align 4

waveOutReset endp

waveOutGetErrorTextA proc public mmrError:dword, pszText:ptr BYTE, cchText:DWORD
	mov eax, MMSYSERR_NODRIVER
	@strace <"waveOutGetErrorTextA(", mmrError, ", ", pszText, ", ", cchText, ")=", eax>
	ret
	align 4
waveOutGetErrorTextA endp

waveOutSetVolume proc public hwo:DWORD, dwVolume:DWORD
	mov eax, MMSYSERR_NODRIVER
	@strace <"waveOutSetVolume(", hwo, ", ", dwVolume, ")=", eax>
	ret
	align 4
waveOutSetVolume endp

waveOutGetID proc public hwo:DWORD, pDeviceID:ptr DWORD
	mov eax, MMSYSERR_NODRIVER
	@strace <"waveOutGetID(", hwo, ", ", pDeviceID, ")=", eax>
	ret
	align 4
waveOutGetID endp

waveOutGetDevCapsA proc public uses ebx uDeviceId:dword, lpWaveOutCaps:ptr WAVEOUTCAPSA, cbWaveOutCaps:dword

	.if ((uDeviceId == 0) || (uDeviceId == WAVE_MAPPER))
		invoke SndInit
		mov ebx, lpWaveOutCaps
		mov [ebx].WAVEOUTCAPSA.wMid,0
		mov [ebx].WAVEOUTCAPSA.wPid,0
		mov [ebx].WAVEOUTCAPSA.vDriverVersion,100h
		invoke lstrcpy, addr [ebx].WAVEOUTCAPSA.szPname, CStr("HX wave emulation")
		invoke SndGetCaps
		mov [ebx].WAVEOUTCAPSA.dwFormats, eax
		mov [ebx].WAVEOUTCAPSA.wChannels,2
		mov [ebx].WAVEOUTCAPSA.wReserved1,0
		mov [ebx].WAVEOUTCAPSA.dwSupport,0
		mov eax, MMSYSERR_NOERROR
	.else
		mov eax, MMSYSERR_NODRIVER
	.endif
	@strace <"waveOutGetDevCapsA(", uDeviceId, ", ", lpWaveOutCaps, ", ", cbWaveOutCaps, ")=", eax>
	ret
	align 4

waveOutGetDevCapsA endp

;--- get current position
;--- type TIME_BYTES returns position from beginning

waveOutGetPosition proc public uses ebx hwo:dword, pmmt:ptr MMTIME, cbmmt:DWORD

	mov ebx, hwo
	.if (ebx)
		invoke SndGetPlayCsrPos, addr [ebx].WAVEOBJ.dwPlayCsr
		.if (eax > [ebx].WAVEOBJ.dwBytesToPlay)
			mov eax, [ebx].WAVEOBJ.dwBytesToPlay
		.endif
		add edx, eax
		mov ecx, pmmt
		mov [ecx].MMTIME.wType, TIME_BYTES	;just "bytes" supported
		mov [ecx].MMTIME.u.cb, edx
		mov eax, MMSYSERR_NOERROR
	.else
		mov eax, MMSYSERR_NODRIVER
	.endif
	@strace <"waveOutGetPosition(", hwo, ", ", pmmt, ", ", cbmmt, ")=", eax, " pos=", [ecx].MMTIME.u.cb, " playcsr=", [ebx].WAVEOBJ.dwPlayCsr, " still to play=", [ebx].WAVEOBJ.dwBytesToPlay>
	ret
	align 4

waveOutGetPosition endp

waveOutGetVolume proc public hwo:dword, pVol:ptr DWORD

	mov eax, MMSYSERR_INVALHANDLE
	@strace <"waveOutGetVolume()=", eax>
	ret
	align 4

waveOutGetVolume endp

waveOutPause proc public hwo:dword

	.if (g_dwHWO)
		invoke SndPause		;returns 1 if sound has been paused
		mov edx, eax		;0 if sound is already paused
		mov eax, MMSYSERR_NOERROR
	.else
		mov eax, MMSYSERR_INVALHANDLE
	.endif
	@strace <"waveOutPause(", hwo, ")=", eax>
	ret
	align 4

waveOutPause endp

waveOutRestart proc public hwo:dword

	.if (g_dwHWO)
		invoke SndContinue
		mov eax, MMSYSERR_NOERROR
	.else
		mov eax, MMSYSERR_INVALHANDLE
	.endif
	@strace <"waveOutRestart(", hwo, ")=", eax>
	ret
	align 4

waveOutRestart endp

	end
