
;*** implements API translation for Int 2Fh

		.386

		include hdpmi.inc
		include external.inc

		option proc:private


?IDLEFILTER    = 0	;std=0, 1=dont route all int 2Fh, ax=1689 to real-mode 
?SUPI2F1683    = 1	;std=1, 1=support int 2F,ax=1683 (get vm id)
if ?ENHANCED
?SUPI2F1684    = 1	;1=support int 2F,ax=1684 (vxds)
else
?SUPI2F1684    = 0	;0=dont support int 2F,ax=1684 (vxds)
endif
?SUPI2F168A    = 1	;std=1, support int 2F,ax=168A
?SUPI2F168A100 = 1	;std=1, int 2f,ax=168A,bx=100 ("Get LDT Selector")
?SUPI2F4300    = 1	;std=1, int 2f,ax=4300: don't route to real-mode

?PRTI2F15	   = 0	;std=0, display unsupported int 2f,ah=15 calls
?PRTI2F16	   = 0	;std=0, display unsupported int 2f,ah=16 calls
?PRTI2F168A    = 0	;std=0, display unsupported int 2f,ax=168A calls

?32RTMSUPP	   = 1	;"VIRTUAL SUPPORT" is queried both in real/prot mode

@seg _TEXT32

if ?IDLEFILTER
@seg _DATA16
_DATA16	segment	
i2FRefl   db 0		;reflect int 2F (ax=0x1689) into real mode
_DATA16	ends
endif


_TEXT32  segment

_LTRACE_ = 0

intr2F	proc public
if _LTRACE_
		cmp ah,40h			;???
		jz @F
		cmp ax,1680h
		jz @F
		cmp ax,1689h		;don't log the idle calls
		jz @F
		@strout <"I2F: ax=%X bx=%X cx=%X dx=%X si=%lX",lf>,ax,bx,cx,dx,esi
@@:
endif
		cmp ah,15h			;CD-ROM?
		jz int2f15
		cmp ah,16h			;Windows?
		jz int2f16
if ?SUPI2F4300
		cmp ax,4300h		;XMS installed?
		jz error			;required by 16bit winsetup.exe
endif
callok:
		@callrmsint 2Fh

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
error:
		stc
		jmp iret_with_CF_mod

int2f16:
		cmp al,86h			  ;1686? prot mode only
		jnz @F
		xor ax,ax
		iretd
@@:

if ?SUPI2F1683
		cmp al,83h			  ;1683 "get vm id"?
		jnz @F
		mov bx,1
		iretd
@@:
endif

if ?SUPI2F1684
		cmp al,84h			  ;1684?
		jnz @F
		call checkvxd
		push eax
		lahf
		mov byte ptr [esp+4].IRET32.rFL,ah
		pop eax
		iretd
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
		cmp al,8Ah			  ;168A - 32 Bit extensions
		jnz @F
if ?32BIT
		@strout <"I2F: ax=168a, ds:esi=%ls",lf>,ds,esi
else
		@strout <"I2F: ax=168a, ds:si=%s",lf>,ds,si
endif
		push es
		push cs
		pop es
		pushad
if ?INT21API
		mov edi, offset szMsdos
		mov ecx, 7
  ife ?32BIT
		movzx esi, si
  endif
		repz cmpsb
		jz isMsDos
endif
if ?32BIT
if ?32RTMSUPP
  if 0
		mov esi, [esp].PUSHADS.rESI
		mov edi, offset szVirtual
		mov ecx, 7+1+7+1			;"VIRTUAL" + " " + "SUPPORT" + 00
		repz cmpsb
		jz isVirtual
  else
		popad
		pop es
		push esi
		call copyz_dssi_2_tlb	;copy ds:esi to tlb, ds=tlb, si=0
		@simrmint 2Fh
		pop esi
		iretd
  endif
endif
endif
		@strout <"I2F: return ax=168a, unsupported",lf>
		popad
		pop es
		iretd
if ?INT21API
isMsDos:
  if ?32BIT
		mov [esp].PUSHADS.rEDI,_I2F168A_
  else
		mov [esp].PUSHADS.rDI,_I2F168A_
  endif
		mov word ptr [esp + sizeof PUSHADS],_INTSEL_
endif
isVirtual:
		@strout <"I2F: return ax=168a, supported",lf>
		popad
		pop es
		mov al,00
		iretd

szMsdos db "MS-DOS",0
@@:
endif
if ?PRTI2F16
		cmp al,89h
		jz @F
		cmp al,80h
		jz @F
		push 2Fh
		call unsupp
		or byte ptr [esp].IRET32.rFL+1,1	;set trace flag
@@:
endif
		@callrmsint 2Fh
intr2F endp


;*** callback fuer 32-Bit DPMI extensions ***
;*** adresse wird ueber int 2f erfragt ***

_LTRACE_ = 0

if ?SUPI2F168A
_I2f168A proc near public
		 push offset iret_with_CF_mod
if ?SUPI2F168A100
		 cmp ax,0100h		;get LDT selector?
		 jnz @F
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
		 stc
		 ret
_I2f168A endp
endif

;--- external call (i21srvr.asm)

unsupp proc public
		@printf <"int %X ">,<word ptr [esp+4]>
		call unsuppcallx
		ret 4
unsupp endp

unsuppcallx proc public
		@printf <"ax=%X bx=%X cx=%X dx=%X unsupported",lf>,ax,bx,cx,dx
		ret
unsuppcallx endp

_TEXT32 ends

end
