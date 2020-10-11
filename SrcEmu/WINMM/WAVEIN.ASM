
;--- implementes waveInXXX()

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

		.DATA

        .CODE

waveInAddBuffer proc public hwi:dword, lpwh:LPWAVEHDR, dw1:DWORD
		mov eax, MMSYSERR_NODRIVER
		@strace <"waveInAddBuffer(", hwi, ", ", lpwh, ", ", dw1, ")=", eax, " *** unsupp ***">
		ret
        align 4
waveInAddBuffer endp

waveInOpen proc public phwi:ptr dword, dw1:dword, pwfx:ptr WAVEFORMATEX, dw2:dword, dw3:dword, dw4:dword
		mov eax, MMSYSERR_NODRIVER
		@strace <"waveInOpen(", phwi, ")=", eax, " *** unsupp ***">
		ret
        align 4
waveInOpen endp

waveInClose proc public hwi:dword
		mov eax, MMSYSERR_NODRIVER
		@strace <"waveInClose(", hwi, ")=", eax, " *** unsupp ***">
		ret
        align 4
waveInClose endp

waveInReset proc public hwi:dword
		mov eax, MMSYSERR_NODRIVER
		@strace <"waveInReset(", hwi, ")=", eax, " *** unsupp ***">
		ret
        align 4
waveInReset endp

waveInStart proc public hwi:dword
		mov eax, MMSYSERR_NODRIVER
		@strace <"waveInStart(", hwi, ")=", eax, " *** unsupp ***">
		ret
        align 4
waveInStart endp

waveInStop proc public hwi:dword
		mov eax, MMSYSERR_NODRIVER
		@strace <"waveInStop(", hwi, ")=", eax, " *** unsupp ***">
		ret
        align 4
waveInStop endp

waveInGetNumDevs proc public
		xor eax, eax
		@strace <"waveInGetNumDevs()=", eax>
		ret
        align 4
waveInGetNumDevs endp

waveInGetDevCapsA proc public uDeviceId:dword, lpWaveInCaps:ptr, cbWaveInCaps:dword
		mov eax, MMSYSERR_NODRIVER
		@strace <"waveInGetDevCapsA(", uDeviceId, ", ", lpWaveInCaps, ", ", cbWaveInCaps, ")=", eax, " *** unsupp ***">
		ret
        align 4
waveInGetDevCapsA endp

waveInPrepareHeader proc public hwi:DWORD, pwh:ptr WAVEHDR, cbwh:DWORD

		mov eax, MMSYSERR_NODRIVER
		@strace <"waveInPrepareHeader(", hwi, ", ", pwh, ", ", cbwh, ")=", eax>
		ret
        align 4
waveInPrepareHeader endp

waveInUnprepareHeader proc public hwi:DWORD, pwh:ptr WAVEHDR, cbwh:DWORD

		mov eax, MMSYSERR_NODRIVER
		@strace <"waveInUnprepareHeader(", hwi, ", ", pwh, ", ", cbwh, ")=", eax>
		ret
        align 4
waveInUnprepareHeader endp


		end
