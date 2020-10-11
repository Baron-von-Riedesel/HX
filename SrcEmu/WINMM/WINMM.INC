
?USEMMTIMER		equ 1	;use multimedia timer for midi long msg output
?SBMIDI			equ 1	;support SB Midi


externdef g_hHeap:DWORD
externdef g_csalias:DWORD
externdef g_csMM:CRITICAL_SECTION
ife ?FLAT
externdef g_flatsel:dword
endif

externdef g_hWOEvent:DWORD
ife ?USEMMTIMER
externdef g_hMOTimer:DWORD
endif
externdef g_pTimer:DWORD
externdef g_dwHWO:DWORD

atexit	proto c :DWORD

;--- timeXXX objects

protoTimeProc typedef proto :DWORD, :DWORD, :DWORD, :DWORD, :DWORD
LPTIMEPROC typedef ptr protoTimeProc

TIMEOBJ	struct
pNext	dd ?	;must be first!
hTimer  dd ?
uDelay	dd ?
uResolution dd ?
lpProc	LPTIMEPROC ?
dwUser	dd ?
fuEvent dd ?
TIMEOBJ ends

;--- waveXXX objects

protowaveOutProc typedef proto :dword, :dword, :dword, :dword, :dword
LPWAVEOUTPROC typedef ptr protowaveOutProc

WAVEOBJ	struct
dwType				dd ?
pWaveHdr			dd ?
wf					WAVEFORMATEX <>
					align 4
dwWriteCsr			dd ?		;write position
dwPlayCsr			dd ?		;play position
dwBytesToPlay		dd ?		;bytes still to play
fdwOpen				dd ?
union 
lpfnCallback		LPWAVEOUTPROC ?
hwnd                DWORD ?
threadid            DWORD ?
hEvent              DWORD ?
ends
dwCallbackInstance 	dd ?
WAVEOBJ ends

;--- midiXXX objects

protomidiOutProc typedef proto :dword, :dword, :dword, :dword, :dword
LPMIDIOUTPROC typedef ptr protomidiOutProc

MIDIOBJ	struct
dwType				dd ?
pMidiHdr			dd ?
dwFlags				dd ?
uDeviceId			dd ?
union 
lpfnCallback		LPMIDIOUTPROC ?
hwnd                DWORD ?
threadid            DWORD ?
hEvent              DWORD ?
ends
dwCallbackInstance 	dd ?
MIDIOBJ ends


WHDR_PRIMARY	equ 80000000h

StartMMThread	proto
StopMMThread	proto

protoResetMidi typedef proto
LPFNRESETMIDI typedef ptr protoResetMidi
protoWriteMidiCmd typedef proto
LPFNWRITEMIDICMD typedef ptr protoWriteMidiCmd
protoWriteMidiData typedef proto
LPFNWRITEMIDIDATA typedef ptr protoWriteMidiData
protoWriteMidiShortMsg typedef proto
LPFNWRITEMIDISHORTMSG typedef ptr protoWriteMidiShortMsg

externdef g_dwResetMidi			:LPFNRESETMIDI
externdef g_dwWriteMidiCmd 		:LPFNWRITEMIDICMD
externdef g_dwWriteMidiData		:LPFNWRITEMIDIDATA
externdef g_dwWriteMidiShortMsg	:LPFNWRITEMIDISHORTMSG


