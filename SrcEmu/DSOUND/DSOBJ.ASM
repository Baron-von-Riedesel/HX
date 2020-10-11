
;--- implements IDirectSound

        .386
if ?FLAT        
        .MODEL FLAT, stdcall
else
        .MODEL SMALL, stdcall
endif
        option casemap:none
        option proc:private

        include winbase.inc
        include wincon.inc
        include dsound.inc
        include ddsound.inc
        include mmsystem.inc
        include macros.inc

?MINSAMPLERATE	equ 100        
?MAXSAMPLERATE	equ 44100        
?PRIMARYBUFFERS	equ 1
?HWBUFFERSIZE	equ 4000h

?MAXBUFFERS		equ 64	;max number of buffers a ds object can handle
?DELETEALL		equ 0	;delete all buffers belonging to this ds object

DSOBJ   struct
vft			dd ?
dwCnt		dd ?
hwnd		dd ?
dwFlags		dd ?
dwCoopFlags	dd ?
pBuffers	dd ?
DSOBJ   ends

DSOBJF_INITIALIZED	equ 1

QueryInterface proto pThis:ptr DSOBJ,refiid:dword,pObj:dword
AddRef         proto pThis:ptr DSOBJ
Release        proto pThis:ptr DSOBJ

		.DATA

g_hwo		DWORD 0
g_hwoFlags  DWORD 0	;flags for waveOut device
        
		.CONST
        
IID_IDirectSound	GUID <279AFA83h , 4981h  , 11CEh , <0A5h ,  21h , 00h ,  20h , 0AFh , 0Bh , 0E5h , 60h>>

dsvf    label DSOBJVFT
		dd QueryInterface, AddRef, Release
		dd CreateSoundBuffer
		dd GetCaps
		dd DuplicateSoundBuffer
		dd SetCooperativeLevel
		dd Compact
		dd GetSpeakerConfig
		dd SetSpeakerConfig
		dd Initialize

        .CODE

Initialize proto :ptr DSOBJ, :DWORD

DirectSoundCreate proc public uses ebx pGUID:ptr, pDS:ptr dword, pIUnknown:ptr

		invoke	waveOutGetNumDevs
        and		eax, eax
        jz		error1
        cmp		g_hwo, 0
        jnz		error2
        invoke	LocalAlloc, LMEM_FIXED or LMEM_ZEROINIT, sizeof DSOBJ
        and     eax,eax
        jz      error3
        mov		ebx, eax
        mov     [ebx].DSOBJ.vft, offset dsvf
        mov		[ebx].DSOBJ.dwCnt, 1
;        invoke	Initialize, ebx, 0
        mov     ecx,pDS
        mov     [ecx], ebx
        mov     eax,DS_OK
        jmp		exit
error1:
        mov     eax,DSERR_NODRIVER
        jmp		exit
error2:
        mov     eax,DSERR_ALLOCATED
        jmp		exit
error3:
        mov     eax,DSERR_OUTOFMEMORY
exit:  
		@strace	<"DirectSoundCreate(", pGUID, ", ", pDS, ", ", pIUnknown, ")=", eax>
        ret
        align 4
DirectSoundCreate endp

QueryInterface proc uses esi edi ebx pThis:ptr DSOBJ, pIID:dword, pObj:dword

		mov		edx, pThis
        mov     edi,offset IID_IDirectSound
        mov     esi,pIID
        mov     ecx,4
        repz    cmpsd
        jz      found
        mov     ecx,pObj
        mov		dword ptr [ecx],0
        mov     eax,DSERR_NOINTERFACE
        jmp		exit
found:
        mov     ecx, pObj
        mov     [ecx], edx
        invoke	AddRef, edx
        mov     eax,DS_OK
exit:        
		@strace	<"DirectSound::QueryInterface(", pThis, ")=", eax>
        ret
        align 4
QueryInterface endp

AddRef proc pThis:ptr DSOBJ
		mov ecx, pThis
        mov eax, [ecx].DSOBJ.dwCnt
        inc [ecx].DSOBJ.dwCnt
		@strace	<"DirectSound::AddRef(", pThis, ")=", eax>
        ret
        align 4
AddRef endp

Release proc uses ebx pThis:ptr DSOBJ
		mov ebx, pThis
        mov eax, [ebx].DSOBJ.dwCnt
        dec [ebx].DSOBJ.dwCnt
        .if (ZERO?)
        	.if (g_hwo)
            	invoke waveOutClose, g_hwo
                mov g_hwo, 0
            .endif
if ?DELETEALL            
            .if ([ebx].DSOBJ.pBuffers)
            	push esi
                mov esi, [ebx].DSOBJ.pBuffers
            	mov ecx, ?MAXBUFFERS
                .while (ecx)
                	push ecx
                	lodsd
                    .if (eax)
                    	invoke vf(eax, IUnknown, Release)
                    .endif
                    pop ecx
                    dec ecx
                .endw
                pop esi
            .endif
endif            
        	invoke LocalFree, ebx
            xor eax, eax
        .endif
		@strace	<"DirectSound::Release(", pThis, ")=", eax>
        ret
        align 4
Release endp

CreateSoundBuffer proc pThis:ptr DSOBJ, lpDesc:ptr DSBUFFERDESC, lplpDSBuffer:ptr dword, lpUnkOuter:LPUNKNOWN

		invoke Create@DirectSoundBuffer, pThis, lpDesc, lplpDSBuffer, lpUnkOuter
if ?DELETEALL        
        .if (eax == DS_OK)
        	pushad
            mov ebx, pThis
            .if (![ebx].DSOBJ.pBuffers)
            	invoke LocalAlloc, LMEM_FIXED or LMEM_ZEROINIT, ?MAXBUFFERS*4
                mov [ebx].DSOBJ.pBuffers, eax
            .endif
            .if ([ebx].DSOBJ.pBuffers)
            	mov edi, [ebx].DSOBJ.pBuffers
                xor eax, eax
                mov ecx, ?MAXBUFFERS
                repnz scasd
                .if (ZERO?)
                	mov ecx, lplpDSBuffer
                    mov edx, [ecx]
                    mov [edi-4],edx
                .endif
            .endif
            popad
        .endif
endif        
		@strace	<"DirectSound::CreateSoundBuffer(", pThis, ", ",  lpDesc, ", ", lplpDSBuffer, ", ", lpUnkOuter, ")=", eax>
		ret
        align 4
CreateSoundBuffer endp

;--- since destroying a DS object should also destroy all
;--- buffers, a linked list of buffers is required

_UnlinkBuffer proc public uses edi pThis:ptr DSOBJ, pBuffer:ptr
if ?DELETEALL
        mov ecx, pThis
        mov edi, [ecx].DSOBJ.pBuffers
        .if (edi)
        	mov eax, pBuffer
            mov ecx, ?MAXBUFFERS
            repnz scasd
            .if (ZERO?)
            	mov dword ptr [edi-4], 0
            .endif
        .endif
endif        
		ret
        align 4
_UnlinkBuffer endp

GetCaps proc uses edi pThis:ptr DSOBJ, lpCaps:LPDSCAPS

local	woc:WAVEOUTCAPSA

		invoke waveOutGetDevCapsA, 0, addr woc, sizeof woc
        
		mov edx, lpCaps
        mov ecx, [edx].DSCAPS.dwSize
        .if (ecx < sizeof DSCAPS)
        	mov eax, DSERR_INVALIDPARAM
            jmp exit
        .endif
        shr ecx, 2
        dec ecx
        lea edi, [edx].DSCAPS.dwFlags
        xor eax, eax
        rep stosd
;;        mov [edx].DSCAPS.dwFlags, DSCAPS_EMULDRIVER or DSCAPS_PRIMARY16BIT or DSCAPS_PRIMARY8BIT or DSCAPS_PRIMARYMONO or DSCAPS_PRIMARYSTEREO
        mov [edx].DSCAPS.dwFlags,\
        	DSCAPS_PRIMARY16BIT or DSCAPS_PRIMARY8BIT or DSCAPS_PRIMARYMONO or DSCAPS_PRIMARYSTEREO
        mov [edx].DSCAPS.dwMinSecondarySampleRate, ?MINSAMPLERATE
        mov [edx].DSCAPS.dwMaxSecondarySampleRate, ?MAXSAMPLERATE
        mov [edx].DSCAPS.dwPrimaryBuffers, ?PRIMARYBUFFERS
        mov [edx].DSCAPS.dwTotalHwMemBytes, ?HWBUFFERSIZE
        mov [edx].DSCAPS.dwFreeHwMemBytes, ?HWBUFFERSIZE
        mov [edx].DSCAPS.dwMaxContigFreeHwMemBytes, ?HWBUFFERSIZE
		mov eax, DS_OK
exit:        
		@strace	<"DirectSound::GetCaps(", pThis, ", ",  lpCaps, ")=", eax>
		ret
        align 4
GetCaps endp

DuplicateSoundBuffer proc pThis:ptr DSOBJ, lpDSBuffer:ptr, lplpDSBuffer:ptr dword

		mov eax, DSERR_UNINITIALIZED
		@strace	<"DirectSound::DuplicateSoundBuffer(", pThis, ", ",  lpDSBuffer, ", ", lplpDSBuffer, ")=", eax>
		ret
        align 4
DuplicateSoundBuffer endp

SetCooperativeLevel proc uses ebx pThis:ptr DSOBJ, hwnd:dword, dwFlags:dword

		mov ebx, pThis
        mov ecx, hwnd
        mov edx, dwFlags
        mov [ebx].DSOBJ.hwnd, ecx
        mov [ebx].DSOBJ.dwCoopFlags, edx
		mov eax, DS_OK
		@strace	<"DirectSound::SetCooperativeLevel(", pThis, ", ",  hwnd, ", ", dwFlags, ")=", eax>
		ret
        align 4
SetCooperativeLevel endp

Compact proc pThis:ptr DSOBJ

		mov eax, DSERR_UNINITIALIZED
		@strace	<"DirectSound::Compact(", pThis, ")=", eax>
		ret
        align 4
Compact endp

GetSpeakerConfig proc pThis:ptr DSOBJ, lpdw1:ptr dword

		mov eax, DSERR_UNINITIALIZED
		@strace	<"DirectSound::GetSpeakerConfig(", pThis, ", ",  lpdw1, ")=", eax>
		ret
        align 4
GetSpeakerConfig endp

SetSpeakerConfig proc pThis:ptr DSOBJ, dw1:dword

		mov eax, DSERR_UNINITIALIZED
		@strace	<"DirectSound::SetSpeakerConfig(", pThis, ", ",  dw1, ")=", eax>
		ret
        align 4
SetSpeakerConfig endp

Initialize proc pThis:ptr DSOBJ, refguid:dword

		mov ecx, pThis
        .if ([ecx].DSOBJ.dwFlags & DSOBJF_INITIALIZED)
			mov eax, DSERR_ALREADYINITIALIZED
        .else
	        or [ecx].DSOBJ.dwFlags, DSOBJF_INITIALIZED
			mov eax, DS_OK
        .endif
		@strace	<"DirectSound::Initialize(", pThis, ", ",  refguid, ")=", eax>
		ret
        align 4
Initialize endp

        END

