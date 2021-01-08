

;--- this is a simple GetModuleHandleA() emulation
;--- intended to be used if the Win32 emulation code
;--- is linked statically to the binary and LOADPE.BIN
;--- stub is used. Then there is no true support for modules
;--- available, but some C runtimes need at least access to
;--- KERNEL32 - the most important one is MS VC V7+.

        .386
        .MODEL FLAT, stdcall
		option casemap:none
        option proc:private

		.DATA

		public _imp__GetModuleHandleA@4
_imp__GetModuleHandleA@4 dd _GetModuleHandleA

		public _imp__GetProcAddressA@8
_imp__GetProcAddressA@8 dd _GetProcAddressA

        .CODE

GetModuleHandleA proto stdcall :ptr BYTE
lstrcmpA proto stdcall :ptr BYTE, :ptr BYTE
ifdef _DEBUG
OutputDebugStringA proto stdcall :ptr BYTE
endif

ifdef _DEBUG
szFound db "kernel32 found",13,10,0
szGMH1  db "GetModuleHandleA(",0
szGMH2  db ")",13,10,0
szGPA1  db "GetProcAddressA(",0
szGPA2  db ")",13,10,0
endif

		align 4

;--- to add functions returned by GetProcAddress        
;--- enter a pair of DWORD, first is name, second is address

kernel32funcs label dword
;		dd 0,0	
endkernel32funcs label byte

_GetModuleHandleA proc public pName:ptr byte

        mov     edx,pName
        and		edx, edx
        jnz		@F
        invoke  GetModuleHandleA, edx
        jmp 	exit
@@:
ifdef _DEBUG
		pushad
        mov esi,edx
        invoke OutputDebugStringA, offset szGMH1
        invoke OutputDebugStringA, esi
        invoke OutputDebugStringA, offset szGMH2
        popad
endif
		mov		eax,[edx+0]
		mov		ecx,[edx+4]
        or		eax,20202020h
        or		ecx,2020h
        .if ((eax == "nrek") && (ecx == "23le"))	;is KERNEL32 searched?
        	mov eax,[edx+8]
            .if (al)
            	or eax,20202020h
            .endif
            .if (al == 0) || (eax == "lld.")		;the ".dll" suffix is opt.
ifdef _DEBUG            
            	invoke OutputDebugStringA, offset szFound
endif                
            	mov eax,offset kernel32funcs
                jmp exit
            .endif
        .endif
        xor eax,eax
exit:        
        ret
        align 4
_GetModuleHandleA endp

;--- this is dummy, there is no function "exported" currently,
;--- but is must be avoided that the original GetProcAddress is used
;--- since it calls DPMILD32.EXE.

_GetProcAddressA proc public uses esi hModule:DWORD, pszName:ptr BYTE

		mov esi, hModule
		.if (esi == offset kernel32funcs)
ifdef _DEBUG
	        invoke OutputDebugStringA, offset szGPA1
    	    invoke OutputDebugStringA, pszName
        	invoke OutputDebugStringA, offset szGPA2
endif
        	.while (esi < offset endkernel32funcs)
				lodsd
            	invoke lstrcmpA, eax, pszName
                and eax,eax
               	lodsd
                jz exit
            .endw
        .endif
        xor eax,eax
exit:        
        ret
        align 4
_GetProcAddressA endp

        end

