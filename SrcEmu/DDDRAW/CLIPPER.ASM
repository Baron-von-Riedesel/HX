
;--- implements IDirectDrawClipper
 
        .386
if ?FLAT        
        .MODEL FLAT, stdcall
else
        .MODEL SMALL, stdcall
endif
        option casemap:none
        option proc:private

        include winbase.inc
        include ddraw.inc
        include vesa32.inc
        include dddraw.inc
        include macros.inc

QueryInterface proto stdcall pThis:dword,refiid:dword,pObj:dword
AddRef         proto stdcall pThis:dword
Release        proto stdcall pThis:dword

DDCLIPPERVFT struct
pQueryInterface         dd ?
pAddRef                 dd ?
pRelease                dd ?
pGetClipList			dd ? ; :LPRECT, :LPRGNDATA, :LPDWORD
pGetHWnd				dd ? ; :ptr HWND
pInitialize				dd ? ; :LPDIRECTDRAW, :DWORD
pIsClipListChanged		dd ? ; :ptr BOOL
pSetClipList			dd ? ; :LPRGNDATA, :DWORD
pSetHWnd				dd ? ; :DWORD, :HWND
DDCLIPPERVFT ends


DDCLIPPER struct
vft      	dd ?
dwCnt    	dd ?
hwnd		dd ?
DDCLIPPER ends

		.CONST
        
IID_IDirectDrawClipper	GUID <6C14DB85h,0A733h,11CEh,<0A5h,21h,00h,20h,0AFh,0Bh,0E5h,60h>>

vtable   label DDCLIPPERVFT
        dd QueryInterface,AddRef,Release
		dd GetClipList
		dd GetHWnd
		dd Initialize
		dd IsClipListChanged
		dd SetClipList
		dd SetHWnd

        .CODE

QueryInterface proc uses esi edi pThis:dword,pIID:dword,pObj:dword

        mov     edi,offset IID_IDirectDrawClipper
        mov     esi,pIID
        mov     ecx,4
        repz    cmpsd
        jz      found
        mov     ecx,pObj
        mov		dword ptr [ecx],0
        mov     eax,DDERR_INVALIDOBJECT
        jmp		exit
found:
		mov		eax, pThis
        mov     ecx, pObj
        mov     [ecx],eax
        invoke	AddRef, eax
        mov     eax,DD_OK
exit:   
		@strace	<"DirectDrawClipper::QueryInterface(", pThis, ")=", eax>
        ret
        align 4
QueryInterface endp

AddRef proc pThis:dword
		mov ecx, pThis
        mov eax, [ecx].DDCLIPPER.dwCnt
        inc [ecx].DDCLIPPER.dwCnt
		@strace	<"DirectDrawClipper::AddRef(", pThis, ")=", eax>
        ret
        align 4
AddRef endp

Release proc pThis:dword
		mov ecx, pThis
        mov eax, [ecx].DDCLIPPER.dwCnt
        dec [ecx].DDCLIPPER.dwCnt
        .if (ZERO?)
        	invoke LocalFree, ecx
            xor eax, eax
        .endif
		@strace	<"DirectDrawClipper::Release(", pThis, ")=", eax>
        ret
        align 4
Release endp

GetClipList proc pThis:dword, pRect:ptr RECT, pRgn:ptr RGNDATA, pdw:ptr DWORD
		mov eax, DDERR_UNSUPPORTED
		@strace	<"DirectDrawClipper::GetClipList(", pThis, ")=", eax>
        ret
        align 4
GetClipList endp

GetHWnd proc pThis:dword, phwnd:ptr HWND
		mov ecx, pThis
        mov edx, phwnd
        mov eax, [ecx].DDCLIPPER.hwnd
        mov [edx], eax
		mov eax, DD_OK
		@strace	<"DirectDrawClipper::GetHWnd(", pThis, ", ", phwnd, ")=", eax>
        ret
        align 4
GetHWnd endp

Initialize proc pThis:dword, lpDD:LPDIRECTDRAW, dw1:DWORD
		mov eax, DDERR_UNSUPPORTED
		@strace	<"DirectDrawClipper::Initialize(", pThis, ")=", eax>
        ret
        align 4
Initialize endp

IsClipListChanged proc pThis:dword, pBool:ptr BOOL
		mov eax, DDERR_UNSUPPORTED
		@strace	<"DirectDrawClipper::IsClipListChanged(", pThis, ")=", eax>
        ret
        align 4
IsClipListChanged endp

SetClipList proc pThis:dword, lpRgnData:ptr RGNDATA, dw1:DWORD
		mov eax, DDERR_UNSUPPORTED
		@strace	<"DirectDrawClipper::SetClipList(", pThis, ")=", eax>
        ret
        align 4
SetClipList endp

SetHWnd proc pThis:dword, dwFlags:DWORD, hwnd:DWORD
		mov ecx, pThis
        mov edx, hwnd
        mov [ecx].DDCLIPPER.hwnd, edx
		mov eax, DD_OK
		@strace	<"DirectDrawClipper::SetHWnd(", pThis, ", ", dwFlags, ", ", hwnd, ")=", eax>
        ret
        align 4
SetHWnd endp

Create@DDClipper proc public uses ebx lpDD:LPDIRECTDRAW

		@strace	<"Create@DirectDrawClipper()">
        invoke	LocalAlloc, LMEM_FIXED or LMEM_ZEROINIT, sizeof DDCLIPPER
        and     eax,eax
        jz      error
        mov     ebx,eax
        mov     [ebx].DDCLIPPER.vft, offset vtable
        mov     [ebx].DDCLIPPER.dwCnt, 1
        mov		eax, ebx
        ret
error:
		ret
        align 4

Create@DDClipper endp

        END

