
;--- implements mixerXXX()

        .386
if ?FLAT
        .MODEL FLAT, stdcall
else
        .MODEL SMALL, stdcall
endif
		option casemap:none
        option proc:private

        include winbase.inc
        include mmsystem.inc
        include macros.inc

        .CODE

mixerOpen proc public lphMixer:ptr DWORD, puDeviceId:ptr DWORD,
		dwCallback:DWORD, dwInstance:DWORD, fdwOpen:DWORD
        
		mov eax, MMSYSERR_NODRIVER
		@strace <"mixerOpen(", lphMixer, ", ", puDeviceId, ", ", dwCallback, ", ", dwInstance, ", ", fdwOpen, ")=", eax, " *** unsupp ***">
		ret
        align 4
mixerOpen endp

mixerClose proc public hMixer: DWORD
        
		mov eax, MMSYSERR_NODRIVER
		@strace <"mixerClose(", hMixer, ")=", eax, " *** unsupp ***">
		ret
        align 4
        
mixerClose endp

mixerGetNumDevs proc public
		xor eax, eax
		@strace <"mixerGetNumDevs()=", eax>
		ret
        align 4
mixerGetNumDevs endp

mixerSetControlDetails proc public hMixer:dword, lpmcd:ptr MIXERCONTROLDETAILS, dw1:DWORD
		xor eax, eax
		@strace <"mixerSetControlDetails(", hMixer, ", ", lpmcd, ", ", dw1, ")=", eax>
		ret
        align 4
mixerSetControlDetails endp

mixerGetControlDetailsA proc public hMixer:dword, lpmcd:ptr MIXERCONTROLDETAILS, dw1:DWORD
		xor eax, eax
		@strace <"mixerGetControlDetailsA(", hMixer, ", ", lpmcd, ", ", dw1, ")=", eax>
		ret
        align 4
mixerGetControlDetailsA endp

mixerGetLineInfoA proc public hMixer:dword, lpml:ptr MIXERLINEA, dw1:DWORD
		xor eax, eax
		@strace <"mixerGetLineInfoA(", hMixer, ", ", lpml, ", ", dw1, ")=", eax>
		ret
        align 4
mixerGetLineInfoA endp

mixerGetLineControlsA proc public hMixer:dword, lpmlc:ptr MIXERLINECONTROLSA, dw1:DWORD
		xor eax, eax
		@strace <"mixerGetLineControlsA(", hMixer, ", ", lpmlc, ", ", dw1, ")=", eax>
		ret
        align 4
mixerGetLineControlsA endp

mixerGetDevCapsA proc public uDeviceId:dword, lpMixerCaps:ptr, cbMixerCaps:dword
		mov eax, MMSYSERR_NODRIVER
		@strace <"mixerGetDevCapsA(", uDeviceId, ", ", lpMixerCaps, ", ", cbMixerCaps, ")=", eax, " *** unsupp ***">
		ret
        align 4
mixerGetDevCapsA endp

		end
