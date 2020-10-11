
;--- implements IDirectSoundBuffer

		.386
if ?FLAT
		.MODEL FLAT, stdcall
else
		.MODEL SMALL, stdcall
endif
		option casemap:none
		option proc:private

		include windef.inc
		include winbase.inc
		include dsound.inc
		include ddsound.inc
		include mmsystem.inc
		include macros.inc

;--- normal cooperative level assumes
;--- 22 kHz sampling rate, stereo and 8 bit resolution

;--- the following caps will cause CreateSoundBuffer to fail

;?FAILREQ	equ DSBCAPS_LOCHARDWARE
?FAILREQ	equ DSBCAPS_CTRL3D or DSBCAPS_LOCHARDWARE
?DSNOTIFY	equ 1	;support DirectSoundNotify interface (not working yet)

DSBUFFER   struct
vft			dd ?
if ?DSNOTIFY
vft2		dd ?
endif
dwCnt		dd ?
lpDS		dd ?
dwDSFlags	dd ?	;flags from DSBUFFERDESC
if ?DSNOTIFY
cPositionNotifies dd ?
pNotifyPositions dd ?
endif
;dwFlags		dd ?	;private flags for DSBUFFER
;dwWriteCsr	dd ?	;
;dwPlayCsr	dd ?
wh			WAVEHDR <>
wfx			WAVEFORMATEX <>
			align 4
DSBUFFER   ends

QueryInterface proto pThis:ptr DSBUFFER,refiid:dword,pObj:dword
AddRef         proto pThis:ptr DSBUFFER
Release        proto pThis:ptr DSBUFFER
Stop           proto pThis:ptr DSBUFFER

_UnlinkBuffer	proto :ptr, :ptr

		.CONST
        
IID_IDirectSoundBuffer	GUID <279AFA85h ,  4981h , 11CEh , <0A5h , 21h , 00h , 20h , 0AFh , 0Bh , 0E5h , 60h>>
if ?DSNOTIFY
IID_IDirectSoundNotify	GUID <0b0210783h , 89cdh , 11d0h , <0afh ,  8h ,  0h ,0a0h , 0c9h , 25h , 0cdh , 16h>>
endif

dsbvf   label DSBUFFERVFT
		dd QueryInterface, AddRef, Release
		dd GetCaps
		dd GetCurrentPosition
		dd GetFormat
		dd GetVolume
		dd GetPan
		dd GetFrequency
		dd GetStatus
		dd Initialize
		dd Lock_
		dd Play
		dd SetCurrentPosition
		dd SetFormat
		dd SetVolume
		dd SetPan
		dd SetFrequency
		dd Stop
		dd Unlock
		dd Restore

if ?DSNOTIFY
dsnot   label DSNOTIFYVFT
		dd QueryInterface2, AddRef2, Release2
		dd SetNotificationPositions

DSBPOSITIONNOTIFY	struct 
dwOffset	DWORD	?
hEventNotify	HANDLE	?
DSBPOSITIONNOTIFY	ends

endif

@MakeStub macro name, suffix, offs, bNoJump
name&suffix:
		sub dword ptr [esp+4], offs
ifb <bNoJump>
		jmp name
		align 4
endif
		endm

		.DATA

protoSndGetDMABuffer typedef proto
LPFNSNDGETDMABUFFER typedef ptr protoSndGetDMABuffer

g_lpfnSndGetDMABuffer LPFNSNDGETDMABUFFER 0

protoSndGetCaps typedef proto
LPFNSNDGETCAPS typedef ptr protoSndGetCaps

g_lpfnSndGetCaps LPFNSNDGETCAPS 0

		.CODE

if ?DSNOTIFY
waveCallback proc uses ebx hWaveOut:HANDLE, uMsg:DWORD, dwInstance:Dword, dwParam1:Dword, dwParam2:Dword

		mov ebx, dwInstance
		.if (uMsg == WOM_DONE)
;			invoke waveOutUnprepareHeader, g_hwo, addr [ebx].DSBUFFER.wh, sizeof WAVEHDR
			.if ( [ebx].DSBUFFER.cPositionNotifies )
				mov ecx,[ebx].DSBUFFER.pNotifyPositions
				invoke SetEvent, [ecx].DSBPOSITIONNOTIFY.hEventNotify
			.endif
		.endif
		ret
		align 4
waveCallback endp
endif

GetSBProcs proc uses ebx
		invoke GetModuleHandle, CStr("SB16")
		.if (eax)
			mov ebx, eax
			invoke GetProcAddress, ebx, CStr("SndGetDMABuffer")
			mov g_lpfnSndGetDMABuffer, eax
			invoke GetProcAddress, ebx, CStr("SndGetCaps")
			mov g_lpfnSndGetCaps, eax
		.endif
		ret
GetSBProcs endp

;--- use the waveXXX functions for sound output

Create@DirectSoundBuffer  proc public uses ebx lpDS:ptr, lpDesc:ptr DSBUFFERDESC, 
		ppDSB: ptr dword, lpUnkOuter:ptr

		xor ebx, ebx
		mov ecx,ppDSB
		mov [ecx], ebx
		invoke waveOutGetNumDevs
		and eax, eax
		jz error3
		invoke LocalAlloc, LMEM_FIXED or LMEM_ZEROINIT, sizeof DSBUFFER
		and eax,eax
		jz error1
		mov ebx, eax
		mov [ebx].DSBUFFER.vft, offset dsbvf
if ?DSNOTIFY
		mov [ebx].DSBUFFER.vft2, offset dsnot
endif
		mov [ebx].DSBUFFER.dwCnt, 1
		mov eax, lpDS
		mov [ebx].DSBUFFER.lpDS, eax
		mov ecx, lpDesc
		mov edx, [ecx].DSBUFFERDESC.dwFlags
		mov [ebx].DSBUFFER.dwDSFlags, edx
		test edx, ?FAILREQ
		jnz error21
		mov eax, [ecx].DSBUFFERDESC.dwBufferBytes
		mov [ebx].DSBUFFER.wh.dwBufferLength, eax
		mov edx, [ecx].DSBUFFERDESC.lpwfxFormat
;--- no WAVEFORMATEX for primary buffers allowed
		.if (edx && ([ebx].DSBUFFER.dwDSFlags & DSBCAPS_PRIMARYBUFFER))
			@strace <"error: waveformatex supplied for primary buffer">
			jmp error4
		.endif
		.if (edx)
			invoke RtlMoveMemory, addr [ebx].DSBUFFER.wfx, edx, sizeof WAVEFORMATEX
		.endif
		.if ([ebx].DSBUFFER.dwDSFlags & DSBCAPS_PRIMARYBUFFER)
			@strace <"Create@DSBuffer: creating a PRIMARY sound buffer">
			.if ([ebx].DSBUFFER.wh.dwBufferLength)
				@strace <"Create@DSBuffer error: bufferlength supplied for primary buffer">
				jmp error4
			.endif
			.if (!g_lpfnSndGetDMABuffer)
				invoke GetSBProcs
				.if (!g_lpfnSndGetDMABuffer)
					@strace <"Create@DSBuffer error: proc SndGetDMABuffer not found">
					jmp error2
				.endif
			.endif
			invoke g_lpfnSndGetDMABuffer
			mov [ebx].DSBUFFER.wh.lpData, eax
			mov [ebx].DSBUFFER.wh.dwBufferLength, edx
			mov eax, 0
			mov [ebx].DSBUFFER.wh.reserved, eax
			mov [ebx].DSBUFFER.wh.dwFlags, WHDR_BEGINLOOP or WHDR_ENDLOOP or WHDR_PREPARED
			mov [ebx].DSBUFFER.wh.lpNext, -1
			mov [ebx].DSBUFFER.wh.dwLoops, -1
		.else
			invoke VirtualAlloc, 0, [ebx].DSBUFFER.wh.dwBufferLength, MEM_COMMIT, PAGE_READWRITE
			and eax, eax
			jz error1
			mov [ebx].DSBUFFER.wh.lpData, eax
;--- VirtualAlloc zeros the region, which is good for signed data (16-bit),
;--- but 8-bit data is unsigned and needs a 80h value for silence!
			.if ([ebx].DSBUFFER.wfx.wBitsPerSample == 8)
				invoke RtlFillMemory, [ebx].DSBUFFER.wh.lpData, [ebx].DSBUFFER.wh.dwBufferLength, 80h
			.endif
		.endif
		
		mov ecx,ppDSB
		mov [ecx], ebx
		mov eax,DS_OK
		jmp exit
error4:
		mov eax,DSERR_INVALIDPARAM
		jmp errorx
error3:
		@strace <"Create@DSBuffer: no sound hardware installed">
		mov eax,DSERR_NODRIVER
		jmp errorx
error21:
		@strace <"Create@DSBuffer: flags invalid : ", edx>
error2:
		mov eax,DSERR_UNSUPPORTED
		jmp errorx
error1:
		@strace <"Create@DSBuffer: VirtualAlloc failed">
		mov eax,DSERR_OUTOFMEMORY
errorx:
		.if (ebx)
			push eax
			.if ([ebx].DSBUFFER.wh.lpData)
				invoke VirtualFree, [ebx].DSBUFFER.wh.lpData, 0, MEM_RELEASE
			.endif
			invoke LocalFree, ebx
			pop eax
		.endif
exit:
ifdef _DEBUG
		xor ecx, ecx
		xor edx, edx
		.if (eax == DS_OK)
			mov ecx, [ebx].DSBUFFER.wh.dwBufferLength
			mov edx, [ebx].DSBUFFER.wh.lpData
		.endif
endif
		@strace <"Create@DSBuffer(", lpDS, ", ", lpDesc, ", ", ppDSB, ", ", lpUnkOuter, ")=", eax, " [", ebx, ", ", edx, ":", ecx, "]">
		ret
		align 4
Create@DirectSoundBuffer  endp

if ?DSNOTIFY
		@MakeStub QueryInterface, 2, DSBUFFER.vft2, 1
endif

QueryInterface proc uses esi edi pThis:ptr DSBUFFER, pIID:dword, pObj:dword

		mov edx, pThis
		mov edi,offset IID_IDirectSoundBuffer
		mov esi,pIID
		mov ecx,4
		repz cmpsd
		jz found
if ?DSNOTIFY
		test [edx].DSBUFFER.dwDSFlags, DSBCAPS_CTRLPOSITIONNOTIFY
		jz @F
		mov edi,offset IID_IDirectSoundNotify
		mov esi,pIID
		mov ecx,4
		repz cmpsd
		jz found2
@@:
endif
		mov ecx,pObj
		mov dword ptr [ecx],0
		mov eax, DSERR_NOINTERFACE
		jmp exit
if ?DSNOTIFY
found2:
		mov ecx, pObj
		add edx, DSBUFFER.vft2
		mov [ecx], edx
		sub edx, DSBUFFER.vft2
		invoke AddRef, edx
		mov eax, DS_OK
		jmp exit
endif
found:
		mov ecx, pObj
		mov [ecx], edx
		invoke AddRef, edx
		mov eax, DS_OK
exit:
ifdef _DEBUG
		mov edx, pIID
endif
		@strace <"DirectSoundBuffer::QueryInterface(", pThis, ", ", pIID, " [", [edx+0], " ", [edx+4], " ", [edx+8], " ", [edx+12], "])=", eax>
		ret
		align 4
QueryInterface endp

if ?DSNOTIFY
		@MakeStub AddRef, 2, DSBUFFER.vft2, 1
endif

AddRef proc pThis:ptr DSBUFFER
		mov ecx, pThis
		mov eax, [ecx].DSBUFFER.dwCnt
		inc [ecx].DSBUFFER.dwCnt
		@strace	<"DirectSoundBuffer::AddRef(", pThis, ")=", eax>
		ret
		align 4
AddRef endp

if ?DSNOTIFY
		@MakeStub Release, 2, DSBUFFER.vft2, 1
endif

Release proc uses ebx pThis:ptr DSBUFFER
		mov ebx, pThis
		mov eax, [ebx].DSBUFFER.dwCnt
		dec [ebx].DSBUFFER.dwCnt
		.if (ZERO?)
			invoke Stop, ebx
			.if ([ebx].DSBUFFER.wh.dwFlags & WHDR_INQUEUE)
				invoke waveOutReset, g_hwo
			.endif
			.if ([ebx].DSBUFFER.wh.dwFlags & WHDR_PREPARED)
				invoke waveOutUnprepareHeader, g_hwo, addr [ebx].DSBUFFER.wh, sizeof WAVEHDR
			.endif
			.if ((!([ebx].DSBUFFER.dwDSFlags & DSBCAPS_PRIMARYBUFFER)) && ([ebx].DSBUFFER.wh.lpData))
				invoke VirtualFree, [ebx].DSBUFFER.wh.lpData, 0, MEM_RELEASE
			.endif
			invoke _UnlinkBuffer, [ebx].DSBUFFER.lpDS, ebx
			invoke LocalFree, ebx
			xor eax, eax
		.endif
		@strace <"DirectSoundBuffer::Release(", pThis, ")=", eax>
		ret
		align 4
Release endp

GetCaps proc uses ebx pThis:ptr DSBUFFER, lpDSBCaps:LPDSBCAPS
		mov ebx, pThis
		mov ecx, lpDSBCaps
		mov edx, [ebx].DSBUFFER.wh.dwBufferLength
		mov [ecx].DSBCAPS.dwBufferBytes, edx
		mov eax, [ebx].DSBUFFER.dwDSFlags
		mov [ecx].DSBCAPS.dwFlags, eax
		.if ([ebx].DSBUFFER.dwDSFlags & DSBCAPS_PRIMARYBUFFER)
			mov [ecx].DSBCAPS.dwPlayCpuOverhead, 0
			mov [ecx].DSBCAPS.dwUnlockTransferRate, 100000
		.else
			mov [ecx].DSBCAPS.dwPlayCpuOverhead, 1
			mov [ecx].DSBCAPS.dwUnlockTransferRate, 100000
		.endif
		mov eax, DS_OK
		@strace <"DirectSoundBuffer::GetCaps(", pThis, ", ", lpDSBCaps, ")=", eax>
		ret
		align 4
GetCaps endp

GetCurrentPosition proc uses ebx pThis:ptr DSBUFFER, lpdwCurrentPlayCursor:LPDWORD, lpdwCurrentWriteCursor:LPDWORD

local	mmtime:MMTIME

		mov ebx, pThis
		mov mmtime.wType, -1
		mov mmtime.u.cb, 0
		.if (lpdwCurrentPlayCursor)
			call getcurrent
			.while (eax > [ebx].DSBUFFER.wh.dwBufferLength)
				sub eax, [ebx].DSBUFFER.wh.dwBufferLength
			.endw
			mov ecx, lpdwCurrentPlayCursor
			mov [ecx],eax
		.endif
		mov ecx, lpdwCurrentWriteCursor
		jecxz @F
;		 .if ([ebx].DSBUFFER.dwDSFlags & DSBCAPS_PRIMARYBUFFER)
			call getcurrent
			mov edx, [ebx].DSBUFFER.wfx.nAvgBytesPerSec
			shr edx, 6	;1000/64 = 15.62 ms
			add eax, edx
			.while (eax > [ebx].DSBUFFER.wh.dwBufferLength)
				sub eax, [ebx].DSBUFFER.wh.dwBufferLength
			.endw
			mov ecx, lpdwCurrentWriteCursor
;		 .else
;			mov eax, [ebx].DSBUFFER.wh.reserved
;		 .endif
		mov [ecx],eax
@@:
		mov eax, DS_OK
ifdef _DEBUG
		mov ecx, lpdwCurrentWriteCursor
		mov edx, lpdwCurrentPlayCursor
		.if (ecx)
			mov ecx, [ecx]
		.endif
		.if (edx)
			mov edx, [edx]
		.endif
endif
		@strace <"DirectSoundBuffer::GetCurrentPosition(", pThis, ", ", lpdwCurrentPlayCursor, " [", edx, "], ", lpdwCurrentWriteCursor, " [", ecx,"])=", eax>
		ret
getcurrent:
		.if (g_hwo && (mmtime.wType == -1))
			mov mmtime.wType, TIME_BYTES
			invoke waveOutGetPosition, g_hwo, addr mmtime, sizeof mmtime
		.endif
		mov eax, mmtime.u.cb
		retn
		align 4
GetCurrentPosition endp

GetFormat proc pThis:ptr DSBUFFER, lpwfx:LPWAVEFORMATEX, dwSizeAllocated:DWORD, lpdwSizeWritten:LPDWORD
		.if (lpwfx)
			pushad
			mov edi, lpwfx
			mov esi, pThis
			lea esi, [esi].DSBUFFER.wfx
			mov ecx, dwSizeAllocated
			.if (ecx > sizeof WAVEFORMATEX)
				mov ecx, sizeof WAVEFORMATEX
			.endif
			rep movsb
			popad
		.endif
		mov edx,lpdwSizeWritten 
		.if (edx)
			mov dword ptr [edx],sizeof WAVEFORMATEX
		.endif
		mov eax, DS_OK
		@strace <"DirectSoundBuffer::GetFormat(", pThis, ", ", lpwfx, ", ", dwSizeAllocated, ", ", lpdwSizeWritten, ")=", eax>
		ret
		align 4
GetFormat endp

GetVolume proc pThis:ptr DSBUFFER, lpl:LPLONG
		mov eax, DSERR_CONTROLUNAVAIL
		@strace <"DirectSoundBuffer::GetVolume(", pThis, ")=", eax>
		ret
		align 4
GetVolume endp

GetPan proc pThis:ptr DSBUFFER, lpl:LPLONG
		mov eax, DSERR_CONTROLUNAVAIL
		@strace <"DirectSoundBuffer::GetPan(", pThis, ")=", eax>
		ret
		align 4
GetPan endp

GetFrequency proc pThis:ptr DSBUFFER, lpdwFrequency:LPDWORD
		mov ecx, pThis
		mov edx, lpdwFrequency
		mov eax, [ecx].DSBUFFER.wfx.nSamplesPerSec
		mov [edx], eax
		mov eax, DS_OK
		@strace <"DirectSoundBuffer::GetFrequency(", pThis, ")=", eax>
		ret
		align 4
GetFrequency endp

GetStatus proc uses ebx pThis:ptr DSBUFFER, lpdwStatus:LPDWORD
		mov ebx, pThis
		mov ecx, lpdwStatus
		mov edx, [ebx].DSBUFFER.wh.dwFlags
		xor eax, eax
		.if (edx & WHDR_DONE)
		.elseif (edx & WHDR_INQUEUE)
			or eax, DSBSTATUS_PLAYING
		.endif
		.if (edx & WHDR_BEGINLOOP)
			or eax, DSBSTATUS_LOOPING
		.endif
		mov [ecx], eax
		mov eax, DS_OK
ifdef _DEBUG
		mov ecx, [ecx]
endif
		@strace <"DirectSoundBuffer::GetStatus(", pThis, ")=", eax, " [", ecx, "]">
		ret
		align 4
GetStatus endp

Initialize proc pThis:ptr DSBUFFER, lpDS:LPDIRECTSOUND, lpDSBD:LPDSBUFFERDESC
		mov eax, DSERR_ALREADYINITIALIZED
		@strace <"DirectSoundBuffer::Initialize(", pThis, ")=", eax>
		ret
		align 4
Initialize endp

;--- if a region is to be locked which starts between current play cursor
;--- and waveOut write cursor, then syncronize!

Lock_ proc uses ebx esi edi pThis:ptr DSBUFFER, dwWriteCursor:DWORD, dwWriteBytes:DWORD,
		lplpvAudioPtr1:ptr LPVOID, lpdwAudioBytes1:LPDWORD,
		lplpvAudioPtr2:ptr LPVOID, lpdwAudioBytes2:LPDWORD, dwFlags:DWORD

;local	dwPlayCsr:dword
;local	dwWriteCsr:dword

		mov ebx, pThis
		.if (dwFlags & DSBLOCK_FROMWRITECURSOR)
			invoke GetCurrentPosition, ebx, NULL, addr dwWriteCursor
if 0
		.else
			invoke GetCurrentPosition, ebx, addr dwPlayCsr, addr dwWriteCsr
			mov eax, dwPlayCsr
			mov edx, dwWriteCsr
			mov ecx, dwWriteCursor
			.if (eax >= edx)
				.if ((ecx < edx) || (ecx > eax))
					;gotcha
					mov [ebx].DSBUFFER.wh.reserved, ecx
				.endif
			.else
				.if ((ecx < edx) && (ecx > eax))
					;gotcha
					mov [ebx].DSBUFFER.wh.reserved, ecx
				.endif
			.endif
endif
		.endif
		mov ecx, dwWriteCursor
		mov esi, [ebx].DSBUFFER.wh.dwBufferLength
		.if (dwFlags & DSBLOCK_ENTIREBUFFER)
			mov edx, esi
		.else
			mov edx, dwWriteBytes
			.if (edx > esi)
				mov eax, DSERR_INVALIDPARAM
				jmp exit
			.endif
		.endif
		mov eax, [ebx].DSBUFFER.wh.lpData
		add esi, eax	;esi = end of buffer
		add eax, ecx	;eax = current write pos
		sub esi, eax
		jc error1
		jnz @F
;--- the write cursor is at the end of the buffer
		mov esi,[ebx].DSBUFFER.wh.dwBufferLength
		mov eax, [ebx].DSBUFFER.wh.lpData
@@:
		mov edi, lplpvAudioPtr1
		mov [edi], eax
		mov edi, lpdwAudioBytes1
		.if (esi >= edx)
			mov [edi], edx
			xor edx, edx
		.else
			mov [edi], esi
			sub edx, esi
		.endif
		mov edi, lplpvAudioPtr2
		.if (edi)
			.if (edx)
				mov ecx, [ebx].DSBUFFER.wh.lpData
			.else
				xor ecx, ecx
			.endif
			mov [edi], ecx
			mov edi, lpdwAudioBytes2
			mov [edi], edx
		.endif
		mov eax, DS_OK
exit:
		@strace <"DirectSoundBuffer::Lock(", pThis, ", ", dwWriteCursor, ", ", dwWriteBytes, " ...,", dwFlags, ")=", eax>
		ret
error1:
		mov eax, DSERR_INVALIDPARAM
		jmp exit
		align 4

Lock_ endp

Play proc uses ebx pThis:ptr DSBUFFER, dwReserved:DWORD, dwPriority:DWORD, dwFlags:DWORD

		mov ebx, pThis
		.if (!g_hwo)
if ?DSNOTIFY
			.if ( [ebx].DSBUFFER.cPositionNotifies )
				invoke waveOutOpen, addr g_hwo, WAVE_MAPPER, addr [ebx].DSBUFFER.wfx,
					offset waveCallback, ebx, CALLBACK_FUNCTION
			.else
				invoke waveOutOpen, addr g_hwo, WAVE_MAPPER, addr [ebx].DSBUFFER.wfx,
					0, ebx, CALLBACK_NULL
			.endif
else
			invoke waveOutOpen, addr g_hwo, WAVE_MAPPER, addr [ebx].DSBUFFER.wfx,
				0, ebx, CALLBACK_NULL
endif
			.if (eax != MMSYSERR_NOERROR)
				mov eax, DSERR_UNINITIALIZED
				jmp exit
			.endif
		.endif
		.if (g_hwoFlags & HWOF_PAUSED)
			and g_hwoFlags, not HWOF_PAUSED
			invoke waveOutRestart, g_hwo
		.endif
		.if (!([ebx].DSBUFFER.wh.dwFlags & WHDR_PREPARED))
			.if (dwFlags & DSBPLAY_LOOPING)
if 0
				invoke waveOutReset, g_hwo
endif
				mov [ebx].DSBUFFER.wh.dwFlags, WHDR_BEGINLOOP or WHDR_ENDLOOP
				mov [ebx].DSBUFFER.wh.dwLoops, -1
			.else
				mov [ebx].DSBUFFER.wh.dwFlags, 0
			.endif
			invoke waveOutPrepareHeader, g_hwo, addr [ebx].DSBUFFER.wh, sizeof WAVEHDR
			.if (eax != MMSYSERR_NOERROR)
				mov eax, DSERR_INVALIDCALL
				jmp exit
			.endif
		.endif
		.if (!([ebx].DSBUFFER.wh.dwFlags & WHDR_INQUEUE))
			invoke waveOutWrite, g_hwo, addr [ebx].DSBUFFER.wh, sizeof WAVEHDR
			.if (eax != MMSYSERR_NOERROR)
				mov eax, DSERR_INVALIDCALL
				jmp exit
			.endif
		.endif
		mov eax, DS_OK
exit:
		@strace <"DirectSoundBuffer::Play(", pThis, ", ", dwReserved, ", ", dwPriority, ", ", dwFlags, ")=", eax>
		ret
		align 4
Play endp

SetCurrentPosition proc pThis:ptr DSBUFFER, dwNewPosition:DWORD
		mov ecx, pThis
		.if ([ecx].DSBUFFER.dwDSFlags & DSBCAPS_PRIMARYBUFFER)
			mov eax, DSERR_INVALIDCALL
		.else
			mov edx, dwNewPosition
			.if (edx > [ecx].DSBUFFER.wh.dwBufferLength)
				mov eax, DSERR_INVALIDPARAM
			.else
				mov [ecx].DSBUFFER.wh.reserved, edx
				mov eax, DS_OK
			.endif
		.endif
		@strace <"DirectSoundBuffer::SetCurrentPosition(", pThis, ", ", dwNewPosition, ")=", eax>
		ret
		align 4
SetCurrentPosition endp

SetFormat proc uses ebx pThis:ptr DSBUFFER, lpwfx:LPWAVEFORMATEX
		mov ebx, pThis
		.if (!([ebx].DSBUFFER.dwDSFlags & DSBCAPS_PRIMARYBUFFER))
			mov eax, DSERR_INVALIDCALL
			jmp exit
		.endif
;--- for a SB Pro a primary sound buffer cannot handle 16-bit samples!
		mov ecx, lpwfx
		.if ([ecx].WAVEFORMATEX.wBitsPerSample > 8)
			.if (g_lpfnSndGetCaps)
				invoke g_lpfnSndGetCaps
				.if (!(eax & 0CCCh))	;any 16bit supported?
					mov eax, DSERR_BADFORMAT
					jmp exit
				.endif
			.endif
		.endif
		invoke RtlMoveMemory, addr [ebx].DSBUFFER.wfx, lpwfx, sizeof WAVEFORMATEX
		mov eax, DS_OK
exit:
		@strace <"DirectSoundBuffer::SetFormat(", pThis, ")=", eax>
		ret
		align 4
SetFormat endp

SetVolume proc pThis:ptr DSBUFFER, lVolume:SDWORD
		mov eax, DSERR_CONTROLUNAVAIL
		@strace <"DirectSoundBuffer::SetVolume(", pThis, ", ", lVolume, ")=", eax>
		ret
		align 4
SetVolume endp

SetPan proc pThis:ptr DSBUFFER, lPan:SDWORD
		mov eax, DSERR_CONTROLUNAVAIL
		@strace <"DirectSoundBuffer::SetPan(", pThis, ", ", lPan, ")=", eax>
		ret
		align 4
SetPan endp

SetFrequency proc pThis:ptr DSBUFFER, dwFrequency:DWORD
		mov ecx, pThis
		.if ([ecx].DSBUFFER.dwDSFlags & DSBCAPS_PRIMARYBUFFER)
			mov eax, DSERR_INVALIDCALL
			jmp exit
		.endif
		mov eax, DSERR_CONTROLUNAVAIL
exit:
		@strace <"DirectSoundBuffer::SetFrequency(", pThis, ", ", dwFrequency, ")=", eax>
		ret
		align 4
SetFrequency endp

Stop proc uses ebx pThis:ptr DSBUFFER
		test g_hwoFlags, HWOF_PAUSED
		jnz @F
		or g_hwoFlags, HWOF_PAUSED
		invoke waveOutPause, g_hwo
@@:
		mov eax, DS_OK
		@strace <"DirectSoundBuffer::Stop(", pThis, ")=", eax>
		ret
		align 4
Stop endp

Unlock proc uses ebx pThis:ptr DSBUFFER, lpBuffer1:LPVOID, dwSize1:DWORD, lpBuffer2:LPVOID, dwSize2:DWORD

		mov eax, DS_OK
		@strace <"DirectSoundBuffer::Unlock(", pThis, ", ", lpBuffer1, ", ", dwSize1, ", ", lpBuffer2, ", ", dwSize2, ")=", eax>
		ret
		align 4
Unlock endp

Restore proc pThis:ptr DSBUFFER
		mov eax, DS_OK
		@strace <"DirectSoundBuffer::Restore(", pThis, ")=", eax>
		ret
		align 4
Restore endp

if ?DSNOTIFY

;--- IDirectSoundNotify methods

SetNotificationPositions:
		sub dword ptr [esp+4], DSBUFFER.vft2

_SetNotificationPositions proc uses ebx pThis:ptr DSBUFFER, cPositionNotifies:DWORD, lpcPositionNotification:ptr

;--- function cannot be called while the buffer is "playing"

		mov ecx, pThis
		test [ecx].DSBUFFER.wh.dwFlags, WHDR_INQUEUE
		mov eax, DSERR_INVALIDCALL
		jnz exit

;--- reset the event objects.

		mov ecx, cPositionNotifies
		mov ebx, lpcPositionNotification
		@strace <"DirectSoundNotify::SetNotificationPositions:">
		.while ( ecx )
			@strace <" offs=", [ebx].DSBPOSITIONNOTIFY.dwOffset, " hEvent=", [ebx].DSBPOSITIONNOTIFY.hEventNotify>
			push ecx
			invoke ResetEvent, [ebx].DSBPOSITIONNOTIFY.hEventNotify
			pop ecx
			and eax, eax
			mov eax, DSERR_INVALIDPARAM
			jz exit
			add ebx, sizeof DSBPOSITIONNOTIFY
			dec ecx
		.endw
		mov eax, cPositionNotifies
		shl eax, 3
		invoke LocalAlloc, LMEM_FIXED, eax
		.if (!eax)
			mov eax, DSERR_OUTOFMEMORY
			jmp exit
		.endif
		mov ebx, pThis
		push eax
		.if ( [ebx].DSBUFFER.pNotifyPositions )
			invoke LocalFree, [ebx].DSBUFFER.pNotifyPositions
		.endif
		pop [ebx].DSBUFFER.pNotifyPositions
		mov eax, cPositionNotifies
		mov [ebx].DSBUFFER.cPositionNotifies, eax
		shl eax, 3
		invoke RtlMoveMemory, [ebx].DSBUFFER.pNotifyPositions, lpcPositionNotification, eax
		mov eax, DS_OK
exit:
		@strace <"DirectSoundNotify::SetNotificationPositions(", pThis, ", ", cPositionNotifies, ", ", lpcPositionNotification, ")=", eax>
		ret
		align 4
_SetNotificationPositions endp

endif

		END
