
		.386
if ?FLAT
		.MODEL FLAT, stdcall
else
		.MODEL SMALL, stdcall
endif
		option casemap:none
		option proc:private

		include function.inc
		include vesa32.inc
		include dpmi.inc
		include equates.inc
		include macros.inc

?WAITINPM	equ 1	;std 1: 0=wait in VESA function
?CLI		equ 0	;std 0: disable interrupts before call
?NOVESA30	equ 0	;std 0: 1=dont use VESA 3.0
?NEVERCLI	equ 0	;std 0: 1=dont disable ints during vsync in PM
?FLIPSTATUS equ 1	;std 1: 1=support query flip status (VESA 3.0

;--- the dwFlags fields is a the same as dwFlags in IDirectDrawSurface::Flip

DDFLIP_NOVSYNC equ 8

		.DATA

g_lpfnSetDisplayStart	dd 0	;protected mode VESA set display start addr
g_dwDisplayStart		dd offset vbe2int
if ?FLIPSTATUS
g_dwFlipStatus  		dd offset flipstatusdefault
endif

		.CODE

SetVesaDisplayStart proc public uses ebx dwOffset:dword, dwPitch:dword, dwFlags:dword

if ?CLI
		@noints
endif
		xor ebx, ebx
ife ?WAITINPM
		cmp g_Vesa32Options.bNoVSyncWait,0	;ignore DDFLIP_NOVSYNC flag?
		jnz @F
		test byte ptr dwFlags,DDFLIP_NOVSYNC
		setz bl
		shl bl,7				;80h=wait for vertical retrace
@@:
endif
		jmp g_dwDisplayStart
		align 4
vbe2int::
		mov eax, dwOffset
		cdq
		mov ecx, dwPitch
		div ecx
		mov edx, eax
		xor ecx, ecx
		mov ax,4F07h 
		int 10h
		jmp done
		align 4
vbe2direct::
		mov edx, dwOffset
		shr edx, 2
		mov ecx, edx
		shr edx, 16
		call g_lpfnSetDisplayStart
		jmp done
		align 4
vbe3int::
		or bl, 2			   ;schedule display start at next retrace
		mov ecx, dwOffset
		mov ax,4F07h 
		int 10h
		jmp done
		align 4

vbe3direct::
		or bl, 2
		mov edx, dwOffset
		shr edx, 2
		mov ecx, edx
		shr edx, 16
		call g_lpfnSetDisplayStart
done:
if ?WAITINPM
		test byte ptr dwFlags,DDFLIP_NOVSYNC
		jnz novsync
		cmp g_Vesa32Options.bNoVSyncWait,0	;ignore DDFLIP_NOVSYNC flag?
		jnz novsync
 ife ?CLI
 ife ?NEVERCLI
		@noints
 endif
 endif
		mov  dx,3dah
  if 1
@@:
		in al,dx
		test al,8
		jnz @B
  endif
@@:
		in al,dx
		test al,8
		jz @B
 ife ?CLI
 ife ?NEVERCLI
		@restoreints
 endif
 endif
novsync:
endif
		mov eax,dwOffset
		call MouseSetDisplayStart
exit:
if ?CLI
		@restoreints
endif
		ret
error:
		xor eax,eax
		jmp exit
		align 4

SetVesaDisplayStart endp

GetVesaDisplayStart proc public uses ebx

		mov ax,4f07h
		mov bx,1
		int 10h
		cmp ax,004Fh
		jnz error
		movzx eax,dx
		ret
error:
		mov eax,-1 
		ret
		align 4

GetVesaDisplayStart endp


GetVesaFlipStatus proc public
if ?FLIPSTATUS
		jmp g_dwFlipStatus
endif        
flipstatusdefault::
		mov eax,1
		ret

if ?FLIPSTATUS
flipstatusint::
		push ebx
		mov bx,0004		;get flip status
		mov ax,4F07h
		int 10h
		movzx eax,cx
		pop ebx
		ret
  if 0
flipstatusdirect::
		push ebx
		mov bx,0004		;get flip status
		call g_lpfnSetDisplayStart
		movzx eax,cx
		pop ebx
		ret
  endif
endif
GetVesaFlipStatus endp

;--- this is called in any case to init display start proc

_SetDisplayStartProc proc public lpfnProc:dword

		mov eax, lpfnProc
		mov g_lpfnSetDisplayStart, eax
		mov ecx, offset flipstatusdefault
		.if (eax)
if ?NOVESA30
			mov edx, offset vbe2direct
else
			.if (byte ptr g_vesainfo.VESAVersion+1 >= 3)
				mov edx, offset vbe3direct
if ?FLIPSTATUS
				mov ecx, offset flipstatusint
;;				mov ecx, offset flipstatusdirect	;doesnt work
endif
			.else
				mov edx, offset vbe2direct
			.endif
endif
		.else
if ?NOVESA30
			mov edx, offset vbe2int
else
			.if (byte ptr g_vesainfo.VESAVersion+1 >= 3)
				mov edx, offset vbe3int
if ?FLIPSTATUS
				mov ecx, offset flipstatusint
endif
			.else
				mov edx, offset vbe2int
			.endif
endif
		.endif
		mov g_dwDisplayStart, edx
if ?FLIPSTATUS
		.if (!g_Vesa32Options.bFlipStatus)
			mov ecx, offset flipstatusdefault
		.endif
		mov g_dwFlipStatus, ecx
endif
		ret
		align 4
_SetDisplayStartProc endp

		end

