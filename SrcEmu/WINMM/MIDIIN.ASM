
;--- implements midiInXXX()

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

midiInOpen proc public phmi:ptr DWORD, dw1:dword, dw2:dword, dw3:dword, dw4:dword
		mov eax, MMSYSERR_INVALHANDLE
		@strace <"midiInOpen(", phmi, ")=", eax, " *** unsupp ***">
		ret
        align 4
midiInOpen endp

midiInClose proc public hmi:dword
		mov eax, MMSYSERR_INVALHANDLE
		@strace <"midiInClose(", hmi, ")=", eax, " *** unsupp ***">
		ret
        align 4
midiInClose endp

midiInStart proc public hmi:dword
		mov eax, MMSYSERR_INVALHANDLE
		@strace <"midiInStart(", hmi, ")=", eax, " *** unsupp ***">
		ret
        align 4
midiInStart endp

midiInStop proc public hmi:dword
		mov eax, MMSYSERR_INVALHANDLE
		@strace <"midiInStop(", hmi, ")=", eax, " *** unsupp ***">
		ret
        align 4
midiInStop endp

midiInReset proc public hmi:dword
		mov eax, MMSYSERR_INVALHANDLE
		@strace <"midiInReset(", hmi, ")=", eax, " *** unsupp ***">
		ret
        align 4
midiInReset endp

midiInGetNumDevs proc public
		xor eax, eax
		@strace <"midiInGetNumDevs()=", eax>
		ret
        align 4
midiInGetNumDevs endp

midiInPrepareHeader proc public hmi:DWORD, lpMidiInHdr:DWORD, cbMidiInHdr:DWORD
		mov eax, MMSYSERR_INVALHANDLE
		@strace <"midiInPrepareHeader(", hmi, ", ", lpMidiInHdr, ", ", cbMidiInHdr, ")=", eax>
		ret
        align 4
midiInPrepareHeader endp

midiInUnprepareHeader proc public hmi:DWORD, lpMidiInHdr:DWORD, cbMidiInHdr:DWORD
		mov eax, MMSYSERR_INVALHANDLE
		@strace <"midiInUnprepareHeader(", hmi, ", ", lpMidiInHdr, ", ", cbMidiInHdr, ")=", eax>
		ret
        align 4
midiInUnprepareHeader endp

midiInGetDevCapsA proc public uDeviceId:dword, lpMidiInCaps:ptr, cbMidiInCaps:dword
		mov eax, MMSYSERR_NODRIVER
		@strace <"midiInGetDevCapsA(", uDeviceId, ")=", eax, " *** unsupp ***">
		ret
        align 4
midiInGetDevCapsA endp

midiInGetErrorTextA proc public mmrError:dword, pszText:ptr BYTE, cchText:DWORD
		mov eax, MMSYSERR_NODRIVER
		@strace <"midiInGetErrorTextA(", mmrError, ", ", pszText, ", ", cchText, ")=", eax>
		ret
        align 4
midiInGetErrorTextA endp

midiInAddBuffer proc public hmi:dword, lpmh:ptr MIDIHDR, dw1:DWORD
		mov eax, MMSYSERR_NODRIVER
		@strace <"midiInAddBuffer(", hmi, ", ", lpmh, ", ", dw1, ")=", eax, " *** unsupp ***">
		ret
        align 4
midiInAddBuffer endp


		end
