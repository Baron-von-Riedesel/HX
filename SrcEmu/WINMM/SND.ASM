
;--- implements sndPlaySoundA()

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

?BLKSIZE    equ 10000h

RIFFHDR struct
chkId   dd ?
chkSiz  dd ?
format  dd ?
RIFFHDR ends

RIFFCHKHDR struct
subchkId    dd ?
subchkSiz   dd ?
RIFFCHKHDR ends

WAVEFMT struct
    RIFFCHKHDR <>
wFormatTag      dw ?
nChannels       dw ?
nSamplesPerSec  dd ?
nAvgBytesPerSec dd ?
nBlockAlign     dw ?
wBitsPerSample  dw ?
WAVEFMT ends


		.DATA

hThread		dd 0        
dwFlags		dd 0
g_bCancel	db 0

        .CODE

LoadFile proc uses ebx esi pszFileName:ptr

local	dwRead:dword
local	dwSize:dword

        Invoke CreateFile, pszFileName, GENERIC_READ, FILE_SHARE_READ,NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL
        cmp eax,-1
        jz error
        mov ebx,eax
        invoke GetFileSize, eax, NULL
        mov dwSize, eax

        Invoke LocalAlloc, LMEM_FIXED or LMEM_ZEROINIT, dwSize
        mov esi, eax
        .if (!eax)
			invoke CloseHandle, ebx
            jmp error
        .endif
        Invoke ReadFile, ebx, esi, dwSize, addr dwRead, NULL
        mov eax,dwRead
        .if (eax != dwSize)
        	invoke LocalFree, esi
			invoke CloseHandle, ebx
            jmp error
        .endif
        invoke CloseHandle, ebx
        mov eax, esi
        mov edx, dwSize
        @strace <"file read, buffer=", eax, " size=", edx>
exit:        
        ret
error:
		xor eax,eax
        jmp exit
        
        align 4
LoadFile endp        

PlaySound proc uses ebx esi edi pImage:ptr

local	dwBuffSize:DWORD
local	pWavBuff:DWORD
local	pWavBuffEnd:DWORD
local	hWaveOut:DWORD
local	dwFlags1:dword
local	WavHdr1:WAVEHDR
local	WavFormat:WAVEFORMATEX
local	mmt:MMTIME

		@strace <"PlaySound, image=", pImage>
		mov esi, pImage
        
        .if ([esi].RIFFHDR.chkId != "FFIR")
        	@strace <"no RIFF header found">
            jmp exit
        .endif
        .if ([esi].RIFFHDR.format != "EVAW")
            @strace <"not a WAVE format">
            jmp exit
        .endif
        add esi, sizeof RIFFHDR
        
        .if ([esi].WAVEFMT.subchkId != " tmf")
            @strace <"no fmt chunk found">
            jmp exit
        .endif
        mov edi, esi
		add esi, sizeof WAVEFMT
        
        .if ([esi].RIFFCHKHDR.subchkId != "atad")
            @strace <"no data chunk found">
            jmp exit
        .endif
        mov eax, [esi].RIFFCHKHDR.subchkSiz
        mov dwBuffSize, eax
        @strace <"PlaySound: sound data size=", eax>
        
        lea eax, [esi+sizeof RIFFCHKHDR]
        mov pWavBuff, eax
        
        mov eax, pWavBuff        
        add eax, dwBuffSize
        mov pWavBuffEnd, eax
        
        lea ebx, WavFormat
        mov [ebx].WAVEFORMATEX.cbSize,sizeof WAVEFORMATEX   
        mov ax, [edi].WAVEFMT.wFormatTag
        mov [ebx].WAVEFORMATEX.wFormatTag, ax
        mov ax, [edi].WAVEFMT.nChannels
        mov [ebx].WAVEFORMATEX.nChannels,ax
        mov eax, [edi].WAVEFMT.nSamplesPerSec
        mov [ebx].WAVEFORMATEX.nSamplesPerSec, eax
        mov eax, [edi].WAVEFMT.nAvgBytesPerSec
        mov [ebx].WAVEFORMATEX.nAvgBytesPerSec, eax
        mov ax, [edi].WAVEFMT.nBlockAlign
        mov [ebx].WAVEFORMATEX.nBlockAlign, ax
        mov ax, [edi].WAVEFMT.wBitsPerSample
        mov [ebx].WAVEFORMATEX.wBitsPerSample, ax
                
        Invoke waveOutOpen, addr hWaveOut, WAVE_MAPPER, ebx, 0, NULL, CALLBACK_NULL
        .if (eax != MMSYSERR_NOERROR)
            @strace <"waveOutOpen() failed">
            jmp exit
        .endif

		.if (dwFlags & SND_LOOP)
        	mov dwFlags1, WHDR_BEGINLOOP or WHDR_ENDLOOP
        .else
        	mov dwFlags1, 0
        .endif

		lea ebx, WavHdr1
        mov ecx, dwFlags1
        mov [ebx].WAVEHDR.dwFlags, ecx
        .if (dwFlags & SND_LOOP)
	        mov [ebx].WAVEHDR.dwLoops, -1
        .else
	        mov [ebx].WAVEHDR.dwLoops, 0
        .endif
        mov eax, pWavBuff
        mov [ebx].WAVEHDR.lpData, eax
        mov eax, pWavBuffEnd
        sub eax, pWavBuff
        mov [ebx].WAVEHDR.dwBufferLength, eax
        invoke waveOutPrepareHeader, hWaveOut, ebx, sizeof WAVEHDR
        .if (eax == MMSYSERR_NOERROR)
	        Invoke waveOutWrite, hWaveOut, ebx, sizeof WAVEHDR
    	   	@strace <"waveOutWrite()=", eax>
			.if (eax == MMSYSERR_NOERROR)
	    	    .while (g_bCancel == 0)
    	    	    invoke Sleep,0
	    	        .break .if (WavHdr1.dwFlags & WHDR_DONE)
	    	    .endw
            .endif
	       	lea ebx, WavHdr1
			invoke waveOutUnprepareHeader, hWaveOut, ebx, sizeof WAVEHDR
        .endif
        invoke waveOutClose, hWaveOut
        mov hWaveOut, 0
exit:
		.if (!(dwFlags & SND_MEMORY))
        	invoke LocalFree, pImage
        .endif
        @strace <"PlaySound exit">
        ret
        align 4
PlaySound endp

sndPlaySoundA proc public uses ebx lpszSound:ptr byte, fuSound:dword

        invoke waveOutGetNumDevs
        and eax, eax
        jz exit
        mov eax, lpszSound
		.if (eax)
        	mov ebx, fuSound
            mov dwFlags, ebx
            .if (ebx & SND_MEMORY)
            .else
            	invoke LoadFile, eax
                and eax, eax
                jz exit
            .endif
            mov g_bCancel,0
            .if (ebx & SND_ASYNC)
	        	.if (hThread)
    	        	invoke WaitForSingleObject, hThread, INFINITE
                    invoke CloseHandle, hThread
            	.endif
            	push 0
            	invoke CreateThread, 0, 0, PlaySound, eax, 0, esp
                mov hThread, eax
                pop eax
            .else
	            invoke PlaySound, eax
            .endif
        .elseif (hThread)
        	mov g_bCancel, 1
            invoke WaitForSingleObject, hThread, INFINITE
            xor eax, eax
            xchg eax, hThread
           	invoke CloseHandle, eax
        .endif
exit:        
		@strace <"sndPlaySoundA(", lpszSound, ", ", fuSound, ")=", eax>
		ret
        align 4

sndPlaySoundA endp

		end
