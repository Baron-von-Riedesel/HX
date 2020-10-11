
;--- global init/deinit of WinMM

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

		.data

g_pAtExit	dd 0
g_hHeap		dd 0
g_csalias	dd 0
if 0;?DOSEMUCHECK
g_bIsDosEmu	db 0
endif

g_csMM	CRITICAL_SECTION <>

        .CODE

woDeinit proto

atexit	proc c public dwProc:DWORD

		invoke HeapAlloc, g_hHeap, 0, 2*4
        .if (eax)
        	mov edx, eax
        	mov ecx, dwProc
            mov [edx+4], ecx
            @noints
            lea ecx, g_pAtExit
            mov eax,[ecx+0]
            mov [edx+0], eax
            mov [ecx+0], edx
            @restoreints
		.endif
		ret
        align 4
atexit  endp

InitMM	proc public                

		mov g_csalias, ds
		invoke GetProcessHeap
		mov g_hHeap, eax
        invoke InitializeCriticalSection, addr g_csMM
if 0;?DOSEMUCHECK
		push edi
		sub esp,128
		mov edi, esp
		mov ax,401h
		int 31h
		jc @F
		cmp dword ptr [edi+2],"ESOD"
		jnz @F
		cmp word ptr [edi+6],"UM"
		jnz @F
		mov g_bIsDosEmu, 1
@@: 			   
		add esp,128
		pop edi
				
endif
		ret
        align 4

InitMM	endp

DeinitMM proc public

		invoke woDeinit
		mov edx, g_pAtExit
		.while (edx)
			push dword ptr [edx+0]
			push dword ptr [edx+4]
			invoke HeapFree, g_hHeap, 0, edx
			pop eax
			call eax
			pop edx
		.endw
        invoke DeleteCriticalSection, addr g_csMM
		ret
        align 4

DeinitMM endp

		end

