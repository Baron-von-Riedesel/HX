
		.386
		.MODEL FLAT, stdcall
		option proc:private

		option casemap:none

		include winnt.inc
		include isvbop.inc
		include macros.inc
		include vesa32.inc
		include equates.inc

VesaMouseExit proto
_GetVesaInfo  proto

		.DATA

if ?VESAVDD
		public g_hVesaVDD
g_hVesaVDD	dd 0
g_dwSelector dd 0
endif

		.CODE

if ?VESAVDD
;--- on NT platforms load VESAVDD.DLL

InstallVDD proc handle:dword

		pushad
		mov	ax,3306h
		int	21h
		cmp	bx,3205h		;NT, 2k, XP?
		jnz	exit
		mov cx,1
		mov ax,0
		int 31h
		jc exit
		mov g_dwSelector, eax
		mov ebx, eax
		mov eax, handle
		push eax
		pop dx
		pop cx
		mov ax,0007h
		int 31h
		jc error
		mov cx,0
		mov dx,-1
		mov ax,0008h
		int 31h
		jc error
		mov eax, handle
		mov esi, CStr("VESAVDD.DLL")
		sub esi, eax
		mov edi, CStr("Init")			
		sub edi, eax
		mov ebx, CStr("Dispatch")			
		sub ebx, eax
		push ds
		push es
		mov es,g_dwSelector
		mov ds,g_dwSelector
		RegisterModule
		pop es
		pop ds
		jc error
		mov	g_hVesaVDD, eax
		jmp exit
error:
		mov edx, CStr(<"RegisterModule('VESAVDD.DLL') failed",13,10,'$'>)
		mov ah,9
		int 21h
exit:
		popad
		ret
InstallVDD endp

DeinstallVDD proc uses ebx
		mov eax, g_hVesaVDD
		and eax, eax
		jz @F
		UnRegisterModule

@@:
		mov ebx, g_dwSelector
		and ebx, ebx
		jz @F
		mov ax,1
		int 31h
@@:
		ret
DeinstallVDD endp
endif

VesaInit proc public

if ?VESAVDD
		invoke InstallVDD, hModule
endif
		invoke _GetVesaInfo
		invoke _SetDisplayStartProc, 0
		ret
		align 4
VesaInit endp

VesaExit proc public
		invoke VesaMouseExit
if ?VESAVDD
		invoke DeinstallVDD
endif
		ret
		align 4
VesaExit endp

		END

