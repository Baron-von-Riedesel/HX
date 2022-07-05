
;*** implements API translation for Int 2Fh

	.386

	include hdpmi.inc
	include external.inc

	option proc:private
	option casemap:none

?IDLEFILTER    = 0	;std=0, 1=dont route all int 2Fh, ax=1689 to real-mode 
?INT2F15       = 0	;std=0, was 1 prior to v3.19
if ?ENHANCED
?SUPI2F1683    = 1	;std=1, 1=support int 2F,ax=1683 (get vm id)
?SUPI2F1684    = 1	;std=1, 1=support int 2F,ax=1684 (vxds)
else
?SUPI2F1683    = 0	;std=0
?SUPI2F1684    = 0	;std=0
endif
?SUPI2F168A    = 1	;std=1, support int 2F,ax=168A

;--- vendor "MS-DOS", Get LDT Selector function int 2f,ax=168A,bx=100
;--- required by Win3, should probably be supported in 16-bit only.
?MSDOS_LDTSEL = 1	;std=1

;--- "XMS installed?" call in protected-mode
;--- 1=don't route to real-mode, return with carry set
;--- allegedly required by winsetup.exe?
;--- v3.19: restrict this to 16-bit host.
if ?32BIT
?I2F4300ERR    = 0
else
?I2F4300ERR    = 1
endif

?PRTI2F15	   = 0	;std=0, display unsupported int 2f,ah=15 calls
?PRTI2F16	   = 0	;std=0, display unsupported int 2f,ah=16 calls
?PRTI2F168A    = 0	;std=0, display unsupported int 2f,ax=168A calls


if ?IDLEFILTER
_DATA16 segment
i2FRefl   db 0		;reflect int 2F (ax=0x1689) into real mode
_DATA16 ends
endif

_TEXT32 segment

_LTRACE_ = 0

intr2F proc public
if _LTRACE_
 ife ?32BIT
	cmp ah,40h			;Win3x video virtualization?
	jz @F
	cmp ax,1689h		;don't log the win kernel idle calls
	jz @F
 endif
	cmp ax,1680h
	jz @F
	@dprintf "I2F: ax=%X bx=%X cx=%X dx=%X si=%lX",ax,bx,cx,dx,esi
@@:
endif
if ?INT2F15
	cmp ah,15h			;CD-ROM?
	jz int2f15
endif
	cmp ah,16h			;DPMI, Windows?
	jz int2f16
if ?I2F4300ERR
	cmp ax,4300h		;XMS installed?
	jz error			;don't route ( required by 16bit winsetup.exe )
endif
callok:
	@callrmsint 2Fh		;route call to real-mode (this is a JMP!)
error:
	stc
	jmp iret_with_CF_mod

if ?INT2F15
int2f15:
	cmp al,0
	jz callok
	cmp al,6
	jz callok
	cmp al,7
	jz callok
	cmp al,0Ah
	jz callok
	cmp al,0Bh
	jz callok
	cmp al,0Ch
	jz callok
	cmp al,0Eh
	jz callok
 if ?PRTI2F15
	push 2Fh
	call unsupp
 endif
 	jmp error
endif

int2f16:
	cmp al,86h			  ;ax=1686h? prot mode only
	jnz @F
	xor ax,ax
	iretd
@@:

if ?SUPI2F1683
	cmp al,83h			  ;ax=1683h? "get vm id"
	jnz @F
	mov bx,1
	iretd
@@:
endif

if ?SUPI2F1684
	cmp al,84h			  ;ax=1684h? "get vxd entry"
	jnz @F
	call checkvxd
	jmp iret_with_CF_mod
@@:
endif

if ?IDLEFILTER
	cmp al,89h			  ;1689 - VM idle?
	jnz @F
	dec byte ptr ss:[i2frefl]
	test byte ptr ss:[i2frefl],001Fh
	jz @F
	iretd
@@:
endif

if ?SUPI2F168A
	cmp al,8Ah			  ;168A - get vendor-specific API
	jz is168a
endif

if ?PRTI2F16
	cmp al,89h
	jz @F
	cmp al,80h
	jz @F
	push 2Fh
	call unsupp
 if 1
	or byte ptr [esp].IRET32.rFL+1,1	;set trace flag
 endif
@@:
endif
	@callrmsint 2Fh	;route call to real-mode


if ?SUPI2F168A
is168a:
 if ?32BIT
	@dprintf "I2F: ax=168a, ds:esi=%ls",ds,esi
 else
	@dprintf "I2F: ax=168a, ds:si=%s",ds,si
 endif
	push es
	pushad

	push cs
	pop es

 ife ?32BIT
	movzx esi, si
 endif

	mov edi, offset szVendors
nextvendor:
	movzx ecx, byte ptr es:[edi]
	jecxz done
	inc edi
	lea eax, [edi+ecx+sizeof word]
	push esi
	repz cmpsb
	pop esi
	jz found
	mov edi, eax
	jmp nextvendor
done:
;--- unknown vendor, just return, unchanged AL will indicate an error
	@dprintf "I2F: return ax=168a, unsupported vendor"
	popad
	pop es
	iretd  

szVendors label byte
 if ?INT21API
	db 7,"MS-DOS",0
	dw _I2F168A_MSDOS
 endif
 if ?I2FHDPMI
	db 6,"HDPMI",0
	dw _I2F168A_HDPMI
 endif
	db 0

found:
if ?32BIT
	movzx eax, word ptr es:[edi]
	mov [esp].PUSHADS.rEDI, eax
else
	mov ax, word ptr es:[edi]
	mov word ptr [esp].PUSHADS.rEDI, ax
endif
	mov word ptr [esp+sizeof PUSHADS], _INTSEL_
	popad
	pop es
	mov al, 0
	iretd

endif ;?SUPI2F168A

intr2F endp


;*** callback for MS-DOS DPMI extensions
;*** address was returned via int 2F, ax=168ah

_LTRACE_ = 0

if ?INT21API

_I2f168A_Msdos proc near public
	push offset iret_with_CF_mod
 if ?MSDOS_LDTSEL
	cmp ax,0100h		;get LDT selector?
	jnz @F
	test ss:bEnvFlags2, ENVF2_SYSPROT	;v3.18: no LDT selector in "safe" mode
	jnz error
  if ?LDTROSEL
	mov ax,_SELLDTSAFE_
  else
	mov ax,_SELLDT_
  endif
	clc
	ret
@@:
 endif
 if ?PRTI2F168A
	call unsuppcallx
 endif
error:
	stc
	ret
_I2f168A_Msdos endp
endif

if ?I2FHDPMI

 ifdef _DEBUG
displayhdltab proto near
 endif

;*** callback for HDPMI extensions

_I2f168A_Hdpmi proc near public
	push offset iret_with_CF_mod
 ifdef _DEBUG
	cmp ax,0
	jz is0000
	cmp ax,1
	jz is0001
	cmp ax,2
	jz is0002
	cmp ax,3
	jz is0003
 endif
	cmp ax,4	; disable host?
	jz is0004
	stc
	ret
 ifdef _DEBUG
is0000:
	and ss:fMode2,not FM2_LOG
	ret
is0001:
	or  ss:fMode2,FM2_LOG
	ret
is0002:
	mov ss:traceflgs,bx	;see HDPMI.INC, ?LOG_xxx for flags details
	ret
is0003:
	push ds
	push ss
	pop ds
	call displayhdltab
	pop ds
	ret
 endif
is0004:
	or ss:fMode, FM_DISABLED
	ret
_I2f168A_Hdpmi endp

endif

;--- external call (i21srvr.asm)

unsupp proc public
	@printf <"int %X ">, word ptr [esp+4]
	call unsuppcallx
	ret 4
unsupp endp

unsuppcallx proc public
	@printf <"ax=%X bx=%X cx=%X dx=%X unsupported",lf>,ax,bx,cx,dx
	ret
unsuppcallx endp

_TEXT32 ends

end
