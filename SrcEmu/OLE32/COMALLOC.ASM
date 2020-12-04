
;--- implements CoTaskMemXXX

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
        include winreg.inc
        include winuser.inc
        include objbase.inc
        include macros.inc

        .CODE

IMalloc label near
pVtbl	dd offset IMallocVtbl
IMallocVtbl dd QueryInterface, AddRef, Release
		dd Alloc, Realloc, Free, GetSize, DidAlloc, HeapMinimize

IID_IMalloc	GUID <00000002H, 0H, 0H, <0C0H, 0H, 0H, 0H, 0H, 0H, 0H, 046H>>
IID_IUnknown GUID <00000000H, 0H, 0H, <0C0H, 0H, 0H, 0H, 0H, 0H, 0H, 046H>>

CoTaskMemAlloc	proc public cb:dword
		invoke LocalAlloc, LMEM_FIXED, cb
        @strace <"CoTaskMemAlloc(", cb, ")=", eax>
        ret
        align 4
CoTaskMemAlloc endp        

CoTaskMemFree	proc public pv:ptr
		mov eax, pv
		.if (eax)
		  	invoke LocalFree, eax
        .endif
        @strace <"CoTaskMemFree(", pv, ")=", eax>
        ret
        align 4
CoTaskMemFree endp        

CoTaskMemRealloc	proc public pv:ptr, dwNewSize:dword
		mov eax, pv
		.if (eax)
		  	invoke LocalReAlloc, eax, dwNewSize, LMEM_FIXED
        .endif
        @strace <"CoTaskMemRealloc(", pv, ", ", dwNewSize, ")=", eax>
        ret
        align 4
        
CoTaskMemRealloc endp        

CoGetMalloc proc public dwRes:dword, pMalloc:ptr DWORD
		mov ecx, pMalloc
        mov [ecx],offset IMalloc
        xor eax, eax
        @strace <"CoGetMalloc(", dwRes, ", ", pMalloc, ")=", eax>
        ret
        align 4
CoGetMalloc endp

QueryInterface proc uses esi edi pThis:ptr, piid:ptr, ppObj:ptr DWORD
		mov edx, pThis
        cmp edx, offset IMalloc
        jnz error
        mov esi, piid
        mov edi, offset IID_IMalloc
        mov ecx, 4
        repe cmpsd
        jz found
        mov esi, piid
        mov edi, offset IID_IUnknown
        mov ecx, 4
        repe cmpsd
        jz found
error:        
        mov     ecx,ppObj
        mov		dword ptr [ecx],0
        mov     eax,E_NOINTERFACE
        jmp		exit
found:
        mov     ecx,ppObj
        mov     [ecx],edx
        xor     eax, eax
exit:
		@strace <"IMalloc::QueryInterface(", pThis, ", ", piid, ", ", ppObj, ")=", eax>
        ret
        align 4

QueryInterface endp

AddRef	proc pThis:ptr
		mov eax,1
		@strace <"IMalloc::AddRef(", pThis, ")=", eax>
        ret
        align 4
AddRef	endp

Release proc pThis:ptr
		xor eax, eax
		@strace <"IMalloc::Release(", pThis, ")=", eax>
        ret
        align 4
Release endp

Alloc	proc pThis:ptr, dwSize:dword
		invoke CoTaskMemAlloc, dwSize
        @strace <"IMalloc::Alloc(", pThis, ", ", dwSize, ")=", eax>
        ret
        align 4
Alloc	endp

Realloc	proc pThis:ptr, pv:ptr, dwNewSize:dword
		invoke CoTaskMemRealloc, pv, dwNewSize
        @strace <"IMalloc::Realloc(", pThis, ", ", pv, ", ", dwNewSize, ")=", eax>
        ret
        align 4
Realloc	endp

Free	proc pThis:ptr, pv:ptr
		invoke CoTaskMemFree, pv
        @strace <"IMalloc::Free(", pThis, ", ", pv, ")=", eax>
        ret
        align 4
Free	endp

GetSize proc pThis:ptr, pv:ptr
		invoke LocalSize, pv
        @strace <"IMalloc::GetSize(", pThis, ", ", pv, ")=", eax>
        ret
        align 4
GetSize endp

DidAlloc proc pThis:ptr, pv:ptr

		mov ecx, pv
        .if (ecx)
			invoke LocalHandle, ecx
            and eax, eax
            setnz al
            movzx eax,al
        .else
        	mov eax, 1
        .endif
        @strace <"IMalloc::DidAlloc(", pThis, ", ", pv, ")=", eax>
        ret
        align 4
DidAlloc endp

HeapMinimize proc pThis:ptr
		xor eax, eax
        @strace <"IMalloc::HeapMinimize(", pThis, ")=", eax>
        ret
        align 4
HeapMinimize endp

		end
