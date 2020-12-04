
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
        include mmsystem.inc
        include msacm.inc
        include macros.inc

        .CODE

acmStreamOpen proc public phas:LPHACMSTREAM, had:HACMDRIVER,
		pwfxSrc:ptr WAVEFORMATEX, pwfxDst:ptr WAVEFORMATEX,
        pwfltr:ptr WAVEFILTER, dwCallback:DWORD, dwInstance:dword, fdwOpen:DWORD
        
		mov eax, ACMERR_NOTPOSSIBLE         
		@strace <"acmStreamOpen(", phas, ", ", had, ", ", pwfxSrc, ", ", pwfxDst, ", ", pwfltr, ", ", dwCallback, ", ", dwInstance, ", ", fdwOpen, ")=", eax>
		ret
acmStreamOpen endp

acmStreamClose proc public has:dword, fdwClose:dword
		mov eax, MMSYSERR_INVALHANDLE
		@strace <"acmStreamClose(", has, ", ", fdwClose, ")=", eax>
		ret
acmStreamClose endp

acmStreamConvert proc public has:dword, dw1:LPACMSTREAMHEADER, dw2:dword
		mov eax, MMSYSERR_INVALHANDLE
		@strace <"acmStreamConvert(", has, ", ", dw1, ", ", dw2, ")=", eax>
		ret
acmStreamConvert endp

acmStreamPrepareHeader proc public has:dword, dw1:LPACMSTREAMHEADER, dw2:dword
		mov eax, MMSYSERR_INVALHANDLE
		@strace <"acmStreamPrepareHeader(", has, ", ", dw1, ", ", dw2, ")=", eax>
		ret
acmStreamPrepareHeader endp

acmStreamUnprepareHeader proc public has:dword, dw1:LPACMSTREAMHEADER, dw2:dword
		mov eax, MMSYSERR_INVALHANDLE
		@strace <"acmStreamUnprepareHeader(", has, ", ", dw1, ", ", dw2, ")=", eax>
		ret
acmStreamUnprepareHeader endp

acmStreamSize proc public has:dword, dw1:DWORD, pdw:ptr dword, dw2:DWORD
		mov eax, MMSYSERR_INVALHANDLE
		@strace <"acmStreamSize(", has, ", ", dw1, ", ", pdw, ", ", dw2, ")=", eax>
		ret
acmStreamSize endp

acmFormatSuggest proc public has:dword, pwfx:ptr WAVEFORMATEX, pwfx2:ptr WAVEFORMATEX,
		dw1:DWORD, dw2:DWORD

		mov eax, MMSYSERR_INVALHANDLE
		@strace <"acmFormatSuggest(", has, ", ", pwfx, ", ", pwfx2, ", ", dw1, ", ", dw2, ")=", eax>
		ret
acmFormatSuggest endp


		end
