
;*** load VDD HXVDD.DLL when running on WinNT

	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option proc:private
	option casemap:none

	include winbase.inc
	include dkrnl32.inc
	include macros.inc
	include isvbop.inc

HXVDD equ 1

if HXVDD

	option dotname

.BASE$XA SEGMENT dword public 'DATA'
        DD offset HXUnloadVDD
.BASE$XA ENDS

	.data

	public g_hVdd

g_hVdd	dd 0
dwBopSel dd 0

	.CODE

runcxx label dword
	RegisterModule
	retf
	UnRegisterModule
	retf
	DispatchCall
	retf
svdd1	db "HXVDD.DLL",0
svdd2	db "Dispatch",0
svdd3	db "Init",0

	align 4

HXDispatch proc public
	mov eax, 2
HXDispatch endp ;fall through

RunBop proc

	lea eax, [eax+eax*4]
	push cs:dwBopSel
	push eax
	mov eax,cs:[g_hVdd]
	call fword ptr [esp]
	lea esp,[esp+8]
	ret
	align 4

RunBop endp

LoadVDD proc uses ebx

	mov cx,1
	xor ax,ax
	int 31h
	jc error
	mov ebx, eax
	mov ecx, offset runcxx
	push ecx
	pop dx
	pop cx
	mov ax,7
	int 31h
	jc error
	mov cx,0
	mov dx,-1
	mov ax,8
	int 31h
	jc error
	mov eax, cs
	lar ecx, eax
	shr ecx, 8
	mov ax,9
	int 31h
	jc error
	mov dwBopSel, ebx
	push esi
	push edi
	mov esi, offset svdd1 - offset runcxx
	mov ebx, offset svdd2 - offset runcxx
	mov edi, offset svdd3 - offset runcxx
	push ds
	push es
	mov es,dwBopSel
	push es
	pop ds
	xor eax, eax
	call RunBop
	pop es
	pop ds
	jc @F
	mov g_hVdd, eax
@@:
	pop edi
	pop esi
error:
	ret
	align 4

LoadVDD endp

HXLoadVDD proc public

	mov eax, g_hVdd
	cmp dwBopSel,0		;was there a try to load HXVDD already?
	jnz exit
	cmp g_bHost, HF_WINNT
	jnz exit
	call LoadVDD
exit:
	ret
	align 4

HXLoadVDD endp

HXUnloadVDD proc

	.if ( g_hVdd )
		mov eax,1	;UnRegisterModule
		call RunBop
		mov g_hVdd, 0
	.endif
	.if ( dwBopSel )
		push ebx
		mov ebx, dwBopSel
		mov ax, 1
		int 31h
		pop ebx
		mov dwBopSel, 0
	.endif
	ret
	align 4

HXUnloadVDD endp

endif

	end

