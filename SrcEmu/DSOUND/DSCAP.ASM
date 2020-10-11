
;--- implements DirectSoundEnumerateA()

        .386
if ?FLAT        
        .MODEL FLAT, stdcall
else
        .MODEL SMALL, stdcall
endif
        option casemap:none
        option proc:private

		include winbase.inc
        include dsound.inc
        include mmsystem.inc
        include macros.inc

        .CODE

DirectSoundCaptureCreate proc public lpcGUID:REFGUID, lplpDSC:ptr LPDIRECTSOUNDCAPTURE, lpUnkOuter:ptr

		mov eax, DSERR_ALLOCATED
		@strace	<"DirectSoundCaptureCreate(", lpcGUID, ", ", lplpDSC, ", ", lpUnkOuter, ")=", eax>
		ret
        align 4
        
DirectSoundCaptureCreate endp

        END

