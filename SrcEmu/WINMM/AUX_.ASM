
;--- implements auxXXX()

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

auxGetNumDevs proc public
		@strace <"auxGetNumDevs *** unsupp ***">
		xor eax, eax
		ret
        align 4
auxGetNumDevs endp

auxGetDevCapsA proc public uAuxID:DWORD, pac:ptr AUXCAPS, cbac:DWORD
		mov eax, MMSYSERR_NODRIVER
		@strace <"auxGetDevCapsA(", uAuxID, ", ", pac, ", ", cbac, ")=", eax, " *** unsupp ***">
		ret
        align 4
auxGetDevCapsA endp

auxSetVolume proc public haux:DWORD, dwVolume:DWORD
		mov eax, MMSYSERR_INVALHANDLE
		@strace <"auxSetVolume(", haux, ", ", dwVolume, ")=", eax, " *** unsupp ***">
		ret
        align 4
auxSetVolume endp

auxGetVolume proc public haux:DWORD, pdwVolume:ptr DWORD
		mov eax, MMSYSERR_INVALHANDLE
		@strace <"auxGetVolume(", haux, ", ", pdwVolume, ")=", eax, " *** unsupp ***">
		ret
        align 4
auxGetVolume endp

		end
