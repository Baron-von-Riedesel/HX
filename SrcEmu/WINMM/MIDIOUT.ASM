
;--- implements midiOutXXX()

        .386
if ?FLAT
        .MODEL FLAT, stdcall
else
        .MODEL SMALL, stdcall
endif
		option casemap:none
        option proc:private

        include winbase.inc
        include winuser.inc
        include mmsystem.inc
        include winmm.inc
        include macros.inc
        include sb16.inc

?MIDIACTIVE		equ 1
?MIDICHUNKSIZE	equ 64	;the SB can buffer up to 64 bytes for midi?
?DELAY			equ 20	;delay for long msgs in ms

?MPUDEVICE equ 0

;--- device 0 is SB MPU 401 (SB 16+ only)
;--- if ?SBMIDI is set then
;--- device 1 is SB Midi

MIDI_TYPE	equ "MIDI"

		.DATA

g_hmo		dd 0
g_hMOTimer  dd 0	;helper timer for midi long msg output
g_bInit		db 0	;bit 0: 1=MPU has been set to UART mode
					;bit 1: mm helper thread used
g_bCancel	db 0

			align 4

g_MidiProcs MIDIPROCS <>


FMO_UART  	equ 1
FMO_THREAD	equ 2

        .CODE

;--- ebx = MIDIOBJ
;--- if MOM_DONE: esi == MIDIHDR

_midiSendNotification proc dwFunc:dword, dwMsg:dword            
		.if ([ebx].MIDIOBJ.lpfnCallback)
			mov edx, [ebx].MIDIOBJ.dwFlags
			and edx, CALLBACK_TYPEMASK
			.if (dwFunc == MOM_DONE)
				mov ecx, esi
			.else
				xor ecx, ecx
			.endif
			.if (edx == CALLBACK_FUNCTION)
				invoke [ebx].MIDIOBJ.lpfnCallback, ebx, dwFunc, [ebx].MIDIOBJ.dwCallbackInstance, ecx, 0
			.elseif (edx == CALLBACK_WINDOW)
				invoke SendMessage, [ebx].MIDIOBJ.hwnd, dwMsg, ebx, ecx
			.elseif (edx == CALLBACK_THREAD)
				invoke PostThreadMessage, [ebx].MIDIOBJ.threadid, dwMsg, ebx, ecx
			.elseif (edx == CALLBACK_EVENT)
				invoke SetEvent, [ebx].MIDIOBJ.hEvent
			.endif
		.endif
		ret
		align 4
_midiSendNotification endp            

midiOutOpen proc public uses ebx phmo:ptr DWORD, uDeviceID:dword,
		dwCallback:dword, dwCallbackInstance:dword, dwFlags:dword

		@strace <"midiOutOpen(", phmo, ", ", uDeviceID, ", ", dwCallback, ", ", dwCallbackInstance, ", ", dwFlags, ") enter">
if ?MIDIACTIVE
		.if (g_hmo)
   	    	mov eax, MMSYSERR_ALLOCATED
       		jmp exit
        .endif
       	invoke SndInit
		@strace <"midiOutOpen: SndInit called">
        .if (!eax)
			@strace <"midiOutOpen: SndInit failed">
			mov eax, MIDIERR_NODEVICE
            jmp exit
        .endif
		invoke SndSetMidiDevice, uDeviceID, addr g_MidiProcs
		@strace <"midiOutOpen: SndSetMidiDevice called">
if ?SBMIDI
		.if (uDeviceID == 1)
        	jmp check_done
        .endif
endif
        invoke SndGetCaps
        .if (!edx)					;midi supported?
			@strace <"midiOutOpen: SndGetCaps failed">
			mov eax, MIDIERR_NODEVICE
            jmp exit
        .endif
        invoke SndGetMidiPort	;P3xx must be set in BLASTER variable
        .if (eax == -1)
			@strace <"midiOutOpen: SndGetMidiPort failed">
			mov eax, MIDIERR_NODEVICE
            jmp exit
        .endif
check_done:        
        invoke g_MidiProcs.pReset
        mov g_bInit, 0
        .if (!eax)
			@strace <"midiOutOpen: reset Midi failed">
			mov eax, MIDIERR_NODEVICE
            jmp exit
        .endif

       	invoke LocalAlloc, LMEM_FIXED or LMEM_ZEROINIT, sizeof MIDIOBJ
        .if (eax)
           	mov ebx, eax
            mov g_hmo, eax
            mov [ebx].MIDIOBJ.dwType, MIDI_TYPE
            mov ecx, uDeviceID 
            mov eax, dwCallback
            mov edx, dwCallbackInstance
            mov [ebx].MIDIOBJ.uDeviceId, ecx
            mov [ebx].MIDIOBJ.lpfnCallback, eax
            mov [ebx].MIDIOBJ.dwCallbackInstance, edx
            mov eax, dwFlags
            mov ecx, phmo
            mov [ebx].MIDIOBJ.dwFlags, eax
            mov [ecx], ebx
            invoke _midiSendNotification, MOM_OPEN, MM_MOM_OPEN
	        mov eax, MMSYSERR_NOERROR
        .else
           	mov eax, MMSYSERR_NOMEM
        .endif
else
		mov eax, MIDIERR_NODEVICE
endif
exit:        
		@strace <"midiOutOpen(", phmo, ", ", uDeviceID, ", ", dwCallback, ", ", dwCallbackInstance, ", ", dwFlags, ")=", eax, " [hmo=", ebx, "]">
		ret
        align 4
midiOutOpen endp

midiOutClose proc public uses ebx hmo:dword
		mov ebx, hmo
        .if (ebx && (ebx == g_hmo))
        	invoke midiOutReset, ebx
			.if (g_bInit & FMO_THREAD)
                and g_bInit, not FMO_THREAD
            	invoke StopMMThread
            .endif
            invoke _midiSendNotification, MOM_CLOSE, MM_MOM_CLOSE
			invoke LocalFree, ebx
            mov g_hmo, 0
	        mov eax, MMSYSERR_NOERROR
        .else
			mov eax, MMSYSERR_INVALHANDLE
        .endif
		@strace <"midiOutClose(", hmo, ")=", eax>
		ret
        align 4
midiOutClose endp

midiOutPrepareHeader proc public hmo:DWORD, lpMidiOutHdr:DWORD, cbMidiOutHdr:DWORD
		mov ecx, hmo
        .if (ecx && (ecx == g_hmo))
        	mov edx, lpMidiOutHdr
	  	    .if (!([edx].MIDIHDR.dwFlags & MHDR_PREPARED))
    	   		or  [edx].MIDIHDR.dwFlags, MHDR_PREPARED
	        .endif
	        mov eax, MMSYSERR_NOERROR
        .else
			mov eax, MMSYSERR_INVALHANDLE
        .endif
		@strace <"midiOutPrepareHeader(", hmo, ", ", lpMidiOutHdr, ", ", cbMidiOutHdr, ")=", eax>
		ret
        align 4
midiOutPrepareHeader endp

midiOutUnprepareHeader proc public hmo:DWORD, lpMidiOutHdr:DWORD, cbMidiOutHdr:DWORD
		mov ecx, hmo
        .if (ecx && (ecx == g_hmo))
        	mov edx, lpMidiOutHdr
            .if (!([edx].MIDIHDR.dwFlags & MHDR_INQUEUE))
		      	and [edx].MIDIHDR.dwFlags, not MHDR_PREPARED
		        mov eax, MMSYSERR_NOERROR                       	
            .else
				mov eax, MIDIERR_STILLPLAYING
            .endif
        .else
			mov eax, MMSYSERR_INVALHANDLE
        .endif
		@strace <"midiOutUnprepareHeader(", hmo, ", ", lpMidiOutHdr, ", ", cbMidiOutHdr, ")=", eax>
		ret
        align 4
midiOutUnprepareHeader endp

midiOutShortMsg proc public hmo:DWORD, dwMsg:dword
		mov ecx, hmo
		.if (ecx && (ecx == g_hmo))
			.if (!(g_bInit & FMO_UART))
				or g_bInit, FMO_UART
                mov al,3Fh
				invoke g_MidiProcs.pWriteCmd
			.endif
			mov eax, dwMsg
			invoke g_MidiProcs.pWriteShortMsg
			mov eax, MMSYSERR_NOERROR
		.else
			mov eax, MMSYSERR_INVALHANDLE
		.endif
		@strace <"midiOutShortMsg(", hmo, ", ", dwMsg, ")=", eax>
		ret
		align 4
midiOutShortMsg endp

;--- inp: ebx=MIDIOBJ
;--- ESI=MIDIHDR
;--- code is serialized by g_csMM

UnlinkMidiHdr proc

        mov ecx, [ebx].MIDIOBJ.pMidiHdr
        xor edx, edx
       	.while (ecx)
			.if (esi == ecx)
            	xor eax, eax
				xchg eax, [esi].MIDIHDR.lpNext
				.if (edx)
					mov [edx].MIDIHDR.lpNext, eax
				.else
					mov [ebx].MIDIOBJ.pMidiHdr, eax
				.endif
                and [esi].MIDIHDR.dwFlags, not MHDR_INQUEUE
				.break  
			.endif
			mov edx, ecx
			mov ecx, [ecx].MIDIHDR.lpNext
		.endw
        ret
        align 4

UnlinkMidiHdr endp

;--- this code is serialized by g_csMM

_midiDequeueHdr proc uses ebx esi

		mov ebx, g_hmo
        mov esi, [ebx].MIDIOBJ.pMidiHdr
		.while (esi)
			mov eax, [esi].MIDIHDR.reserved
            .break .if (eax != [esi].MIDIHDR.dwBufferLength)
            push [esi].MIDIHDR.lpNext
			invoke UnlinkMidiHdr
			or [esi].MIDIHDR.dwFlags, MHDR_DONE
            invoke _midiSendNotification, MOM_DONE, MM_MOM_DONE
            pop esi
        .endw
        ret
        align 4
_midiDequeueHdr endp

;--- this proc is called from inside the multimedia thread
;--- feed the MPU port from the MIDIHDR data
;--- the code runs in the MM critical section!

if ?USEMMTIMER
_midithreadproc proc public uses ebx esi uID:dword, dw1:dword, dwUser:dword, lParam1:dword, lParam2:dword
else
_midithreadproc proc public uses ebx esi
endif

		@strace <"midicallbackA(", uID, ", ", dw1, ", ", dwUser, ")=", eax>
       	mov ebx, g_hmo
        mov esi, [ebx].MIDIOBJ.pMidiHdr
        .if (esi)
			mov eax, [esi].MIDIHDR.reserved
   	        .if (eax < [esi].MIDIHDR.dwBufferLength)
       	    	mov edx, [esi].MIDIHDR.lpData
                mov ecx, [esi].MIDIHDR.dwBufferLength
           	    add edx, eax
   	            sub ecx, eax
       	        .if (ecx > ?MIDICHUNKSIZE)
           	    	mov ecx, ?MIDICHUNKSIZE
                .endif
   	            add [esi].MIDIHDR.reserved, ecx
       	        mov esi, edx
           	    .while (ecx)
                	push ecx
   	            	lodsb
    	            invoke g_MidiProcs.pWriteData
           	        pop ecx
                    dec ecx
                .endw
            .endif
        	invoke _midiDequeueHdr
        .else
           	xor ecx, ecx
            xchg ecx, g_hMOTimer
ife ?USEMMTIMER            
            push ecx
          	invoke CancelWaitableTimer, ecx
            pop eax
           	invoke CloseHandle, eax
else
           	invoke timeKillEvent, ecx
endif
        .endif
		ret
        align 4
_midithreadproc endp

;--- ebx -> MIDIOBJ

_midiQueueHdr proc pMidiHdr:LPMIDIHDR, cbMidiOutHdr:dword
			mov edx, pMidiHdr
   	        mov [edx].MIDIHDR.lpNext, 0
       	    mov [edx].MIDIHDR.reserved, 0
            or [edx].MIDIHDR.dwFlags, MHDR_INQUEUE
        	and [edx].MIDIHDR.dwFlags, not MHDR_DONE
            invoke EnterCriticalSection, addr g_csMM
       	    mov ecx, [ebx].MIDIOBJ.pMidiHdr
            .if (ecx)
   	        	.while ([ecx].MIDIHDR.lpNext)
       	        	mov ecx, [ecx].MIDIHDR.lpNext
                .endw
   	            mov [ecx].MIDIHDR.lpNext, edx
            .else
   	        	mov [ebx].MIDIOBJ.pMidiHdr, edx
            .endif
            invoke LeaveCriticalSection, addr g_csMM
			ret
_midiQueueHdr endp

midiOutLongMsg proc public uses ebx hmo:DWORD, pMidiHdr:LPMIDIHDR, cbMidiOutHdr:dword

local	filetime:FILETIME

		mov ebx, hmo
        .if (ebx && (ebx == g_hmo))
        	.if (!(g_bInit & FMO_UART))
            	or g_bInit, FMO_UART
                mov al,3Fh
            	invoke g_MidiProcs.pWriteCmd
            .endif
            invoke _midiQueueHdr, pMidiHdr, cbMidiOutHdr
            mov eax, 1
            .if (!g_hMOTimer)
	            invoke EnterCriticalSection, addr g_csMM
				.if (!g_hMOTimer)
if ?USEMMTIMER
	            	invoke timeSetEvent, ?DELAY, 0, offset _midithreadproc, ebx, TIME_PERIODIC or TIME_CALLBACK_FUNCTION
    	            mov g_hMOTimer, eax
else                
	               	invoke CreateWaitableTimer, 0, 0, 0
    	            .if (eax)
						mov g_hMOTimer, eax
						mov eax, ?DELAY*1000*10
						neg eax
						cdq
						mov filetime.dwLowDateTime, eax
						mov filetime.dwHighDateTime, edx
						mov ecx, ?DELAY
						invoke SetWaitableTimer, g_hMOTimer, addr filetime, \
							ecx, 0, 0, 0
	                .endif
endif                
                .endif
    	        invoke LeaveCriticalSection, addr g_csMM
                .if (!g_hMOTimer)
	   	            mov eax, MMSYSERR_NOMEM
    	            jmp exit
        	    .endif
			.endif
            
           	.if (!(g_bInit & FMO_THREAD))
                or g_bInit, FMO_THREAD
               	invoke StartMMThread
                .if (!eax)
	   	            mov eax, MMSYSERR_NOMEM
                    jmp exit
                .endif
            .endif
if 1            
			invoke _midithreadproc, g_hMOTimer, 0, ebx, 0, 0
;            invoke Sleep,0
endif            
	        mov eax, MMSYSERR_NOERROR
        .else
			mov eax, MMSYSERR_INVALHANDLE
        .endif
exit:   
		@strace <"midiOutLongMsg(", hmo, ", ", pMidiHdr, ", ", cbMidiOutHdr, ")=", eax>
		ret
        align 4
midiOutLongMsg endp

midiOutReset proc public uses ebx esi hmo:DWORD
		mov ebx, hmo
        .if (ebx && (ebx == g_hmo))
        	invoke g_MidiProcs.pReset
            and g_bInit, not FMO_UART
            .if (eax)
            	invoke EnterCriticalSection, addr g_csMM
        	    mov esi, [ebx].MIDIOBJ.pMidiHdr
		       	.while (esi)
    	            push [esi].MIDIHDR.lpNext
        	        invoke UnlinkMidiHdr
			  		or [esi].MIDIHDR.dwFlags, MHDR_DONE
    	            pop esi
				.endw
            	invoke LeaveCriticalSection, addr g_csMM
		        mov eax, MMSYSERR_NOERROR
            .else
			  	mov eax, MMSYSERR_NODRIVER
            .endif
        .else
		  	mov eax, MMSYSERR_INVALHANDLE
        .endif
		@strace <"midiOutReset(", hmo, ")=", eax>
		ret
        align 4
midiOutReset endp

midiOutGetDevCapsA proc public uDeviceId:dword, lpMidiOutCaps:ptr, cbMidiOutCaps:dword
		
        mov ecx, uDeviceId
if ?SBMIDI        
        .if ((ecx == 0) || (ecx == 1) || (ecx == MIDI_MAPPER))
else        
        .if ((ecx == 0) || (ecx == MIDI_MAPPER))
endif        
	       	invoke SndInit
	        .if (eax)
            	.if (uDeviceId != 1)
		  	        invoke SndGetCaps
    		        .if (edx)
		    	        invoke SndGetMidiPort
                	    .if (eax != -1)
                       		jmp error
                        .endif
                    .endif
                .endif
               	mov edx, lpMidiOutCaps
				mov ecx, cbMidiOutCaps
				mov [edx].MIDIOUTCAPSA.wMid, 0
				mov [edx].MIDIOUTCAPSA.wPid, 0
				mov [edx].MIDIOUTCAPSA.vDriverVersion, 100h
if ?SBMIDI                  
                .if ((uDeviceId == 0) || (uDeviceId == MIDI_MAPPER))
                   	mov ecx, CStr("HX SB MPU-401")
                .else
                  	mov ecx, CStr("HX SB MIDI")
                .endif
else                    
               	mov ecx, CStr("HX SB MPU-401")
endif                       
				invoke lstrcpy, addr [edx].MIDIOUTCAPSA.szPname, ecx
				mov edx, lpMidiOutCaps
				mov [edx].MIDIOUTCAPSA.wTechnology, MOD_SYNTH
				mov [edx].MIDIOUTCAPSA.wVoices, 128
				mov [edx].MIDIOUTCAPSA.wNotes, 128
				mov [edx].MIDIOUTCAPSA.wChannelMask, -1
				mov [edx].MIDIOUTCAPSA.dwSupport, 0
				mov eax, MMSYSERR_NOERROR
				jmp exit
            .endif
        .endif
error:        
		mov eax, MMSYSERR_NODRIVER
exit:        
		@strace <"midiOutGetDevCapsA(", uDeviceId, ")=", eax>
		ret
        align 4
midiOutGetDevCapsA endp

;--- 1 or 2 devices, first is SB Midi

midiOutGetNumDevs proc public uses ebx

if ?MIDIACTIVE		
		xor ebx, ebx
       	invoke SndInit
        .if (eax)
	        invoke SndGetCaps
    	    .if (edx)				;midi supported?
		        invoke SndGetMidiPort
		        .if (eax != -1)
                	inc ebx
if ?SBMIDI        
		        	inc ebx
endif            
                .endif
            .endif
        .endif
endif        
       	mov eax, ebx
		@strace <"midiOutGetNumDevs()=", eax>
		ret
        align 4
midiOutGetNumDevs endp

midiOutSetVolume proc public hmo:DWORD, dwVolume:DWORD
		mov eax, MMSYSERR_INVALHANDLE
		@strace <"midiOutSetVolume(", hmo, ", ", dwVolume, ")=", eax, " *** unsupp ***">
		ret
        align 4
midiOutSetVolume endp

midiOutGetVolume proc public hmo:dword, pVol:ptr DWORD
		mov eax, MMSYSERR_INVALHANDLE
		@strace <"midiOutGetVolume(", hmo, ", ", pVol, ")=", eax, " *** unsupp ">
		ret
        align 4
midiOutGetVolume endp

midiOutGetErrorTextA proc public mmrError:dword, pszText:ptr BYTE, cchText:DWORD
		mov eax, MMSYSERR_NODRIVER
		@strace <"midiOutGetErrorTextA(", mmrError, ", ", pszText, ", ", cchText, ")=", eax>
		ret
        align 4
midiOutGetErrorTextA endp

		end
