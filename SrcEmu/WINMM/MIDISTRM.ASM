
;--- implements midiStreamXXX()

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

midiStreamOpen proc public lphStream:ptr DWORD, puDeviceId:ptr DWORD, cMidi:DWORD,
		dwCallback:DWORD, dwInstance:DWORD, fdwOpen:DWORD
        
		mov eax, MMSYSERR_NODRIVER
		@strace <"midiStreamOpen(", lphStream, ", ", puDeviceId, ", ", cMidi, ", ", dwCallback, ", ", dwInstance, ", ", fdwOpen, ")=", eax, " *** unsupp ***">
		ret
        align 4
        
midiStreamOpen endp

midiStreamClose proc public hStream:DWORD
		mov eax, MMSYSERR_INVALHANDLE
		@strace <"midiStreamClose(", hStream, ")=", eax, " *** unsupp ***">
		ret
        align 4
midiStreamClose endp

midiStreamOut proc public hStream:DWORD, lpMidiHdr:LPMIDIHDR, cbMidiHdr:DWORD
		mov eax, MMSYSERR_INVALHANDLE
		@strace <"midiStreamOut(", hStream, ", ", lpMidiHdr, ", ", cbMidiHdr, ")=", eax, " *** unsupp ***">
		ret
        align 4
midiStreamOut endp

midiStreamStop proc public hStream:DWORD
		mov eax, MMSYSERR_INVALHANDLE
		@strace <"midiStreamStop(", hStream, ")=", eax, " *** unsupp ***">
		ret
        align 4
midiStreamStop endp

midiStreamRestart proc public hStream:DWORD
		mov eax, MMSYSERR_INVALHANDLE
		@strace <"midiStreamRestart(", hStream, ")=", eax, " *** unsupp ***">
		ret
        align 4
midiStreamRestart endp

midiStreamPause proc public hStream:DWORD
		mov eax, MMSYSERR_INVALHANDLE
		@strace <"midiStreamPause(", hStream, ")=", eax, " *** unsupp ***">
		ret
        align 4
midiStreamPause endp

midiStreamProperty proc public hStream:DWORD, lpPropData:DWORD, dwProperty:DWORD
		mov eax, MMSYSERR_INVALHANDLE
		@strace <"midiStreamProperty(", hStream, ", ", lpPropData, ", ", dwProperty, ")=", eax, " *** unsupp ***">
		ret
        align 4
midiStreamProperty endp

		end
