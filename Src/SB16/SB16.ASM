
		.386
if ?FLAT		
		.MODEL FLAT, stdcall
else
		.MODEL SMALL, stdcall
endif

		option casemap:none
		option proc:private

		include winbase.inc
		include macros.inc
		include sb16int.inc


		.DATA

;g_pAtExit	dd 0
;g_hHeap	dd 0
g_dwCnt		dd 0
g_csalias	dd 0
if ?DOSEMUCHECK
g_bIsDosEmu	db 0
endif

		.CODE

DeinitIrq	proto

if 0
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
atexit	endp
endif

DllMain proc public handle:dword,reason:dword,reserved:dword

		.if (reason == DLL_PROCESS_ATTACH)
			.if (!g_dwCnt)
				invoke DisableThreadLibraryCalls, handle
				mov g_csalias, ds
if ?DOSEMUCHECK
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
			.endif
			inc g_dwCnt
		.elseif (reason == DLL_PROCESS_DETACH)
			dec g_dwCnt
			jnz @F
if 0
			mov edx, g_pAtExit
			.while (edx)
				push dword ptr [edx+0]
				push dword ptr [edx+4]
				invoke HeapFree, g_hHeap, 0, edx
				pop eax
				call eax
				pop edx
			.endw
else
			invoke DeinitIrq
endif
@@:
		.endif
		@mov eax,1
		ret
DllMain endp

		END DllMain

