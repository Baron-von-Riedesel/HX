
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
		include wincon.inc
        include macros.inc
        include duser32.inc

		.data
        
g_pTimer	dd 0        

		.code

SetTimer proc public uses ebx hwnd:DWORD, nIDEvent:DWORD, uElapse:DWORD, lpTimerProc:DWORD

		mov eax, hwnd
        .if (eax)
        	mov edx, nIDEvent
            mov ebx, g_pTimer
            .while (ebx)
                .if ((edx == [ebx].UTIMER.dwID) && (eax == [ebx].UTIMER.hwnd))
                	jmp timerfound
                .endif
	            mov ebx, [ebx].UTIMER.pNext
            .endw
        .endif
        invoke malloc2, sizeof UTIMER
        and eax, eax
       	jz exit
        mov ecx, eax
        @serialize_enter
        lea ebx, g_pTimer
        .while ([ebx].UTIMER.pNext)
            mov ebx, [ebx].UTIMER.pNext
        .endw
        mov [ebx].UTIMER.pNext, ecx
        mov ebx, ecx
        @serialize_exit
        mov ecx, nIDEvent
        mov [ebx].UTIMER.dwID, ecx
        mov ecx, hwnd
        mov [ebx].UTIMER.hwnd, ecx
timerfound:        
        mov ecx, lpTimerProc
        mov [ebx].UTIMER.pProc, ecx
        .if (![ebx].UTIMER.hTimer)
            invoke CreateWaitableTimer, 0, TRUE, 0
            mov [ebx].UTIMER.hTimer, eax
        .endif
        .if ([ebx].UTIMER.hTimer)
            mov eax, uElapse
 		   	mov ecx, 1000*10
			mul ecx
			not eax
			not edx
            add eax,1
            adc edx,0
			mov [ebx].UTIMER.time.dwLowDateTime, eax
			mov [ebx].UTIMER.time.dwHighDateTime, edx
            invoke SetWaitableTimer, [ebx].UTIMER.hTimer, addr [ebx].UTIMER.time, 0, NULL, 0, 0
            mov eax, ebx
        .else
            invoke KillTimer, ebx, [ebx].UTIMER.dwID
            xor eax, eax
        .endif
exit:
		@strace	<"SetTimer(", hwnd, ", ", nIDEvent, ", ", uElapse, ", ", lpTimerProc, ")=", eax>
		ret
        align 4
SetTimer endp

KillTimer proc public uses ebx hwnd:DWORD, nIDEvent:DWORD

		mov eax, hwnd
;		.if (eax)		;hwnd==NULL is valid
			@serialize_enter
        	mov edx, nIDEvent
            lea ecx, g_pTimer
            mov ebx, [ecx].UTIMER.pNext
            .while (ebx)
                .if ((edx == [ebx].UTIMER.dwID) && (eax == [ebx].UTIMER.hwnd))
	            	mov edx, [ebx].UTIMER.pNext
    	            mov [ecx].UTIMER.pNext, edx
                	.break
                .endif
                mov ecx, ebx
	            mov ebx, [ebx].UTIMER.pNext
            .endw
			@serialize_exit
            .if (ebx)
                .if ([ebx].UTIMER.hTimer)
                	invoke CancelWaitableTimer, [ebx].UTIMER.hTimer
                	invoke CloseHandle, [ebx].UTIMER.hTimer
                .endif
                invoke free, ebx
            .else
            	xor eax,eax
            .endif
;        .endif
		@strace	<"KillTimer(", hwnd, ", ", nIDEvent, ")=", eax>
		ret
        align 4
KillTimer endp

		end
