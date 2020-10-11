
;--- helper thread for multimedia (timer, waveout, midiout)

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

_waveDequeueHdr proto
_midithreadproc proto
_timethreadproc proto :DWORD

externdef g_hWOEvent:DWORD
externdef g_hMOTimer:DWORD

		.data

g_hMMThread		dd 0
g_hEvent        dd 0
g_bRefCnt		dd 0
g_bCancel		db 0

        .CODE

;--- the mm thread is created if there is a notification
;--- to be done (which can't be made from the sound IRQ procedure)
;--- or if midi sound has to be feeded

mmthreadproc proc lParam:DWORD

       	@strace <"mm helper thread starting">
        .while (!g_bCancel)
ifdef _DEBUG
			invoke GetCurrentThread
endif
	       	@strace <"mmthreadproc: still alive, [thread=", eax, ",", dword ptr [eax+4], "]">
        	invoke EnterCriticalSection, addr g_csMM
        	xor esi, esi
            mov eax, g_pTimer
            .while (eax)
               	push [eax].TIMEOBJ.hTimer
               	inc esi
                mov eax, [eax].TIMEOBJ.pNext
            .endw
            mov edi, esi		;number of timers in edi
        	.if (g_hWOEvent)
		       	@strace <"mmthreadproc: calling _waveDequeueHdr">
	        	invoke _waveDequeueHdr
                push g_hWOEvent
                inc esi
            .endif
ife ?USEMMTIMER            
        	.if (g_hMOTimer)
		       	@strace <"mmthreadproc: calling _midithreadproc">
	        	invoke _midithreadproc
                .if (g_hMOTimer)
	                push g_hMOTimer
    	            inc esi
                .endif
            .endif
endif
        	invoke LeaveCriticalSection, addr g_csMM
			push g_hEvent
            inc esi
           	.if (esi == 1)
            	mov edx, [esp+0]
		     	invoke WaitForSingleObject, edx, INFINITE
       	    .else 
           		mov edx, esp
		     	invoke WaitForMultipleObjects, esi, edx, 0, INFINITE
   	        .endif
ifdef _DEBUG
			.if (eax == WAIT_FAILED)
		       	@strace <"mmthreadproc: wait function failed!!!">
            .endif
endif
            mov ecx, esi			;total objects -> ecx
            sub ecx, edi			;non-timer objects -> ecx
           	sub eax, WAIT_OBJECT_0
       	    .if ((eax >= ecx) && (eax < esi))
                mov eax, [esp+eax*4]
		       	@strace <"mmthreadproc: calling _timethreadproc, eax=", eax, " esi=", esi, " edi=", edi, " ecx=", ecx>
        	  	invoke _timethreadproc, eax
ifdef _DEBUG
			.else
		       	@strace <"mmthreadproc: wait returned, eax=", eax, " esi=", esi>
;				invoke ResetEvent, g_hEvent	;not needed
endif
            .endif
   	        lea esp, [esp+esi*4]
        .endw
if 0        
        xor eax, eax
        xchg eax, g_hWOEvent
        .if (eax)
	        invoke CloseHandle, eax
        .endif
  ife ?USEMMTIMER        
        xor eax, eax
        xchg eax, g_hMOTimer
        .if (eax)
        	push eax
        	invoke CancelWaitableTimer, eax
            pop eax
	        invoke CloseHandle, eax
        .endif
  endif
endif
       	@strace <"mm helper thread exiting">
		ret
        align 4
mmthreadproc endp

;--- termination.
;--- since dll termination code is serialized,
;--- it's not possible to run the mm thread here!

stopthread proc
       	@strace <"stop mm thread: enter">
        .if (g_hMMThread)
;--- cant wait in dll termination code
if 0
        	mov g_bCancel, 1
            invoke SetEvent, g_hEvent
			invoke WaitForSingleObject, g_hMMThread, 200
else
			invoke TerminateThread, g_hMMThread, 0	;this suspends the thread
endif
       	    xor ecx, ecx
            xchg ecx, g_hMMThread
   	        invoke CloseHandle, ecx
       	    xor ecx, ecx
            xchg ecx, g_hEvent
   	        invoke CloseHandle, ecx
        .endif
        xor ecx, ecx
        xchg ecx, g_hWOEvent
        jecxz @F
        invoke CloseHandle, ecx
@@:     
ife ?USEMMTIMER        
        xor ecx, ecx
        xchg ecx, g_hMOTimer
        jecxz @F
       	push ecx
       	invoke CancelWaitableTimer, ecx
		pop eax
        invoke CloseHandle, eax
@@:        
endif
       	@strace <"stop mm thread: exit">
		ret
        align 4
stopthread endp

StartMMThread proc public

		invoke EnterCriticalSection, addr g_csMM
        .if (!g_hMMThread)
        	invoke CreateEvent, 0, FALSE, 0, 0
            and eax, eax
            jz exit
           	mov g_hEvent, eax
	        push 0
   		    invoke CreateThread, 0, 0, offset mmthreadproc, 0, CREATE_SUSPENDED, esp
	        pop edx
            .if (eax)
    		    mov g_hMMThread, eax
                invoke SetThreadPriority, eax, THREAD_PRIORITY_TIME_CRITICAL
                invoke atexit, offset stopthread
            .else
               	invoke CloseHandle, g_hEvent
                mov g_hEvent, 0
                jmp exit
            .endif
        .endif
       	inc g_bRefCnt
        .if (g_bRefCnt == 1)
	       	@strace <"StartMMThread: calling ResumeThread(", g_hMMThread, ")">
        	invoke ResumeThread, g_hMMThread
        .endif
       	@strace <"StartMMThread: calling SetEvent">
       	invoke SetEvent, g_hEvent
exit:        
        invoke LeaveCriticalSection, addr g_csMM
		mov eax, g_hMMThread
       	@strace <"StartMMThread()=", eax, " cnt=", g_bRefCnt>
		ret
        align 4
StartMMThread endp

StopMMThread proc public

       	@strace <"StopMMThread() enter, cnt=", g_bRefCnt>
        .if (g_hMMThread)
	        invoke GetCurrentThread
			dec g_bRefCnt
            .if (ZERO?)
	       		cmp eax,g_hMMThread
                jz done
		       	@strace <"StopMMThread: calling SuspendThread(", g_hMMThread, ")">
            	invoke SuspendThread, g_hMMThread
            .else
	       		cmp eax,g_hMMThread
   	        	jz done
		       	@strace <"StopMMThread: calling SetEvent()">
    	    	invoke SetEvent, g_hEvent
ifdef _DEBUG
				invoke GetCurrentThread
		       	@strace <"StopMMThread: calling SwitchToThread() [thread=", eax, "]">
endif
				invoke SwitchToThread	;give the helper thread a time slice
            .endif
        .endif
done:        
       	@strace <"StopMMThread() exit, cnt=", g_bRefCnt>
		ret
        align 4
StopMMThread endp

		end
