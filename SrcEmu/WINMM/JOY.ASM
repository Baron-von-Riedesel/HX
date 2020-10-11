
;--- implements joyXXX()

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

joyGetNumDevs proc public
		xor eax, eax
		@strace <"joyGetNumDevs()=", eax>
		ret
        align 4
joyGetNumDevs endp

joyGetDevCapsA proc public uJoyID:DWORD, pjc:ptr JOYCAPS, cbjc:DWORD
		mov eax, MMSYSERR_NODRIVER
		@strace <"joyGetDevCapsA(", uJoyID, ", ", pjc, ", ", cbjc, ")=", eax, " *** unsupp ***">
		ret
        align 4
joyGetDevCapsA endp

joyGetPos proc public uJoyID:DWORD, pji:ptr JOYINFO
		mov eax, MMSYSERR_NODRIVER
		@strace <"joyGetPos(", uJoyID, ", ", pji, ")=", eax, " *** unsupp ***">
		ret
        align 4
joyGetPos endp

joyGetPosEx proc public uJoyID:DWORD, pji:ptr JOYINFOEX
		mov eax, MMSYSERR_NODRIVER
		@strace <"joyGetPosEx(", uJoyID, ", ", pji, ")=", eax, " *** unsupp ***">
		ret
        align 4
joyGetPosEx endp

joySetCapture proc public hwnd:DWORD, uJoyID:DWORD, uPeriod:DWORD, fChanged:DWORD
		mov eax, MMSYSERR_NODRIVER
		@strace <"joySetCapture(", hwnd, ", ", uJoyID, ", ", uPeriod, ", ", fChanged, ")=", eax, " *** unsupp ***">
		ret
        align 4
joySetCapture endp

joyReleaseCapture proc public uJoyID:DWORD
		mov eax, MMSYSERR_NODRIVER
		@strace <"joyReleaseCapture(", uJoyID, ")=", eax, " *** unsupp ***">
		ret
        align 4
joyReleaseCapture endp

		end
