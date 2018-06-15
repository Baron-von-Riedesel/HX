

DMABUFFER struct
pStart	dd ?	;start
pEnd  	dd ?	;end
pCsr	dd ?	;write cursor
dwSize	dd ?	;size of DMA buffer half
DMABUFFER ends

SND_BUFFERPLAYED	equ 1
SND_FILLBUFFER		equ 2

protoMidiReset typedef proto
LPMIDIRESET typedef ptr protoMidiReset
protoMidiReadData typedef proto
LPMIDIREADDATA typedef ptr protoMidiReadData
protoMidiWriteData typedef proto
LPMIDIWRITEDATA typedef ptr protoMidiWriteData
protoMidiWriteCmd typedef proto
LPMIDIWRITECMD typedef ptr protoMidiWriteCmd
protoMidiWriteShortMsg typedef proto
LPMIDIWRITESHORTMSG typedef ptr protoMidiWriteShortMsg

MIDIPROCS struct
pReset			LPMIDIRESET ?
pReadData		LPMIDIREADDATA ?
pWriteData  	LPMIDIWRITEDATA ?
pWriteCmd   	LPMIDIWRITECMD ?
pWriteShortMsg	LPMIDIWRITESHORTMSG ?
MIDIPROCS ends


ifdef _SB16_
?INDCALL_ = 0
else
?INDCALL_ = 1
endif

if ?INDCALL_ eq 0
SndClearBuffer  proto :ptr, :dword
SndContinue  	proto
SndDeinit		proto
SndFillDMABuffer proto
SndGetPlayCsrPos proto :ptr DWORD
SndGetDMABuffer	proto
SndGetCaps		proto
SndGetMidiPort	proto
SndInit			proto
SndPause 		proto
SndReinit		proto
SndSetEventProc proto :ptr
SndSetMidiDevice proto :DWORD, :ptr MIDIPROCS
SndSetWaveFormat proto :ptr WAVEFORMATEX, :DWORD
else
externdef stdcall _imp__SndClearBuffer@8:pfunc@8
externdef stdcall _imp__SndContinue@0:pfunc@0
externdef stdcall _imp__SndDeinit@0:pfunc@0
externdef stdcall _imp__SndFillDMABuffer@0:pfunc@0
externdef stdcall _imp__SndGetPlayCsrPos@4:pfunc@4
externdef stdcall _imp__SndGetDMABuffer@0:pfunc@0
externdef stdcall _imp__SndGetCaps@0:pfunc@0
externdef stdcall _imp__SndGetMidiPort@0:pfunc@0
externdef stdcall _imp__SndInit@0:pfunc@0
externdef stdcall _imp__SndPause@0:pfunc@0
externdef stdcall _imp__SndReinit@0:pfunc@0
externdef stdcall _imp__SndSetEventProc@4:pfunc@4
externdef stdcall _imp__SndSetMidiDevice@8:pfunc@8
externdef stdcall _imp__SndSetWaveFormat@8:pfunc@8

SndClearBuffer  	equ <_imp__SndClearBuffer@8>
SndContinue 		equ <_imp__SndContinue@0>
SndDeinit			equ <_imp__SndDeinit@0>
SndFillDMABuffer    equ <_imp__SndFillDMABuffer@0>
SndGetPlayCsrPos    equ <_imp__SndGetPlayCsrPos@4>
SndGetDMABuffer     equ <_imp__SndGetDMABuffer@0>
SndGetCaps          equ <_imp__SndGetCaps@0>
SndGetMidiPort      equ <_imp__SndGetMidiPort@0>
SndInit             equ <_imp__SndInit@0>
SndPause            equ <_imp__SndPause@0>
SndReinit           equ <_imp__SndReinit@0>
SndSetEventProc     equ <_imp__SndSetEventProc@4>
SndSetMidiDevice    equ <_imp__SndSetMidiDevice@8>
SndSetWaveFormat    equ <_imp__SndSetWaveFormat@8>

endif

