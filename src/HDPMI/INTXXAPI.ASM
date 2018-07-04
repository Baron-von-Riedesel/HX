
;--- translation services for various interrupts
;*** INT 10
;*** INT 15 (ax=C207h)
;*** INT 4B
;--- best viewed with TABSIZE 4

	.386

	include hdpmi.inc
	include external.inc

	option proc:private

?INT10MAPPING = 1
?SUPI15C207   = 1

	assume DS:GROUP16

if ?SUPI15C207

_DATA16	segment
mouse_rmcs RMCS <>
_DATA16	ends

CDATA32	segment
mouse15_rmcb dd 0		; real mode callback for int15, ax=c207h
if ?32BIT
mouse_evntproc	PF32 0	; mouse event proc for int 15, ax=c207h
else
mouse_evntproc	PF16 0
endif
CDATA32	ends

endif

_TEXT32  segment

	@ResetTrace

intr10_ proc public
	push offset retf2exit

	@strout <"i10 call ax=%X,bx=%X,cx=%X,dx=%X",lf>,ax,bx,cx,dx
if ?INT10MAPPING
	pushfd
	cmp ah,10h
	jz intr1010
	cmp ah,4Fh
	jz intr104F
	popfd
endif

nomappcall::
	@simrmint 10h
	ret
	align 4
intr10_ endp

if ?INT10MAPPING
intr104E:
intr104F:
		popfd
		cmp al,00h
		jz @F
		cmp al,01h
		jz @F
		cmp al,09h
		jz @F
		cmp al,0Ah
		jnz nomappcall
@@:
		push 10h
		call unsupp
		stc
		ret
		align 4

;--- int 10h, ah=10h

intr1010:
	popfd
	cmp al,2
	jz intr10x_02  ;set palette registers (ES:DX ->regs)
	cmp al,9
	jz intr10x_09  ;get palette registers (ES:DX ->regs)
	cmp al,12h
	jz intr10x_12  ;set dac registers (ES:DX -> regs, CX=cnt)
	cmp al,17h
	jz intr10x_17  ;get dac registers (ES:DX -> regs, CX=cnt)
	jmp nomappcall

intr10x_02: 				;02 set palette registers (17 bytes)
	push ecx
	mov cx,17
	jmp @F
intr10x_12: 				;12 set dac registers
	push ecx
	lea ecx,[ecx+ecx*2] ;je 3 bytes
@@:
	push ds
	push es
	pop ds
	call copy_dsdx_2_tlb	;copy cx bytes to TLB:0
	pop ds
	pop ecx
	call setesreg2tlb
	push edx
	xor edx,edx
	call nomappcall
	pop edx
	ret
	align 4

intr10x_09: 				 ;09 get palette registers
	call int10x_0917
	push ecx
	mov cx,17
	jmp int10x_0917post
intr10x_17: 				 ;17 get dac registers
	call int10x_0917
	push ecx
	lea ecx,[ecx+ecx*2] ;je 3 bytes
int10x_0917post:
	push ds
	push es
	pop ds
	call copy_tlb_2_dsdx
	pop ds
	pop ecx
	ret
	align 4

int10x_0917:
	call setesreg2tlb
	push edx
	xor edx,edx
	call nomappcall
	pop edx
	ret
	align 4

endif

;*** int 15 ***

	@ResetTrace

intr15 proc public

	@strout <"i15 call with ax=%X ebx=%lX es=%X",lf>,ax,ebx,es

	pushfd
if ?SUPI15C207
	cmp ax,0C207h				  ;set pointing device proc?
	jz int15c207
endif
	cmp ah,0C0h
	jz int15c0
	popfd
	@callrmsint 15h
int15c0:
	popfd
	@simrmint 15h
	call es_segm2sel
	jmp iret_with_CF_mod
	align 4
intr15 endp

if ?SUPI15C207

	@ResetTrace

int15c207 proc
	popfd			;restore EFlags
	push ds
	push byte ptr _CSALIAS_
	pop ds
	assume ds:GROUP32
if ?32BIT
	mov dword ptr [mouse_evntproc+0],ebx
	mov word ptr [mouse_evntproc+4],es
	cmp word ptr [mouse_evntproc+4],0
else
	mov word ptr [mouse_evntproc+0],bx
	mov word ptr [mouse_evntproc+2],es
	cmp word ptr [mouse_evntproc+2],0
endif
	jnz install

;--- the mouse event proc is reset by the client

	cmp [mouse15_rmcb],0	;was a rm callback allocated?
;	jz iret_with_CF_mod	;no, done
	jz exit				;no, done
	@strout <"deinstall int 15h mouse event proc",lf>
	mov ss:v86iret.rES,0
	@simrmint 15h				;deinstall event proc
	pushad
	xor ecx, ecx
	xchg ecx, [mouse15_rmcb]
	mov edx, ecx
	shr ecx, 16
	call freermcb			;free the rm callback in CX:DX
	popad					;will return with CF on error
	jmp exit
install:
	call installc207handler
exit:
	pop ds
	jmp iret_with_CF_mod
	align 4

int15c207 endp

;--- install a real int 15h mouse event proc
;--- if not already done.
;--- DS=CGROUP32
;--- out: Carry on errors

installc207handler proc

	cmp [mouse15_rmcb],0		;is a rm callback allocated?
	jnz done1					;jump if yes

	pushad
	push ds
	push es

	push byte ptr _CSR3SEL_
	pop ds
	push byte ptr _DSR3SEL_
	pop es
if ?32BIT
	mov esi,offset mouse_eventproc
	mov edi,offset mouse_rmcs
else
	mov si,LOWWORD(offset mouse_eventproc)
	mov di,LOWWORD(offset mouse_rmcs)
endif
	call allocrmcb		;ds:esi -> pm proc, es:edi -> rmcs
	pop es
	pop ds
	jc @F
	mov word ptr [mouse15_rmcb+0],dx
	mov word ptr [mouse15_rmcb+2],cx
@@:
	popad
	jc exit
done1:
	push ebx
	@strout <"install int 15h mouse event proc",lf>
	mov bx,word ptr [mouse15_rmcb+2]
	mov ss:v86iret.rES,bx
	mov bx,word ptr [mouse15_rmcb+0]
	@simrmint 15h					;set the event proc (ax=C207)
	pop ebx
exit:
	ret
	align 4
installc207handler endp

	assume ds:nothing

;--- this is a ring3 protected-mode proc!
;--- the original int 15 event proc is called with 4 words onto the stack
;--- which should remain there!
;--- DS:E/SI = real mode SS:SP
;--- ES:E/DI = rmcs
;--- SS:E/SP = LPMS?
;--- to access GROUP32 use CS here (should have value _CSR3SEL_)
;--- displays are possible because the video output should work in ring 3
;--- this is a real-mode callback proc, registers may be modified
;--- es:edi point to rmcs

	@ResetTrace

mouse_eventproc proc
	cld
if ?32BIT
	@strout <"mouse event (C207) in pm, SS:ESP=%lX:%lX,DS:ESI=%lX:%lX",lf>,ss,esp,ds,esi
;--- pop CS:IP from real-mode stack and adjust real mode SP
	lodsd
	mov es:[edi].RMCS.rCSIP, eax
	mov es:[edi].RMCS.rSP, si
;--- transfer 4 WORDs from real-mode to protected mode stack
	push dword ptr [esi+4]
	push dword ptr [esi+0]
	@strout <"calling %X:%lX",lf>,<word ptr cs:mouse_evntproc+4>,<dword ptr cs:mouse_evntproc+0>
	call cs:[mouse_evntproc]
	add esp,4*2
else
	@strout <"mouse event (C207) in pm, SS:SP=%lX:%X,DS:SI=%lX:%X",lf>,ss,sp,ds,si
	@useext
	lodsd
	mov es:[di].RMCS.rCSIP, eax
	mov es:[di].RMCS.rSP, si
	push dword ptr [si+4]
	push dword ptr [si+0]
	@strout <"calling %X:%X",lf>,<word ptr cs:mouse_evntproc+2>,<word ptr cs:mouse_evntproc+0>
	call cs:[mouse_evntproc]
	add sp,4*2
endif
	@strout <"mouse event (C207), return to rm",lf>
	@iret
	align 4
mouse_eventproc endp

if ?MOU15RESET

;--- set int 15h mouse event proc to the value
;--- which it had before the client was started
;--- inp: eax=previous state of mouse event proc

mouse15_reset proc public
	cmp eax, cs:[mouse15_rmcb]	;has the rmcb changed?
	jz @F
	mov bx,word ptr cs:[mouse15_rmcb+0]
	mov ax,word ptr cs:[mouse15_rmcb+2]
	mov ss:v86iret.rES,ax
	mov ax,0C207h
	@simrmint 15h					;set the event proc (ax=C207)
@@:
	ret
	align 4
mouse15_reset endp

endif

endif	;?SUPI15C207

	@ResetTrace

;--- DDS, used by 03-04, 07-08, 09-0A

DDS struc
dwSize	dd ?	;size of region
dwOfs	dd ?	;offset virtual start address
wSeg	dw ?	;segment/selector virtual start address (or 0000)
wID		dw ?	;buffer ID
dwPhys	dd ?	;physical address
DDS ends

;--- EDDS, used by 05-06

EDDS struct
dwSize		dd ?	;+0
dwOfs		dd ?	;+4
wSel		dw ?	;+8
wRes		dw ?	;+10
wNumAvail	dw ?	;+12
wNumUsed	dw ?	;+14
EDDS ends

EDDSRG struct
dwAddr	dd ?
dwSize	dd ?
EDDSRG ends

?SUPP4B8105	equ 1	;support VDS 05/06 returning PTEs
?SUPP4B81XX	equ 1	;support translation of VDS 03/04 and 07-0A


intr4B proc near public

;*** if ah=81h (VDS), just al=0B/0C ok to route to real-mode

	@strout <"int4B: AX=%X,ES:DI=%X:%X",lf>,ax,es,di
	cmp ah,81h
	jnz @F
	cmp al,02h	;00 and 01 are NOPs, 02 just register API
	jbe @F
if ?SUPP4B8105		  
	cmp al,05h	;05 scatter lock will be translated!
	jz vds_05
	cmp al,06h	;05 scatter unlock is accepted
	jz vds_06
endif
	cmp al,0Bh
	jb vds_xx
@@:
	@callrmsint 4Bh
vds_xx:
if ?SUPP4B81XX
	push ecx
	mov cx,sizeof DDS
	call copy_esdi_2_tlb
	pop ecx
	push edi
	xor edi,edi
	@simrmint 4Bh
	pop edi
	pushfd
	push ecx
	mov cx,sizeof DDS
	call copy_tlb_2_esdi
	pop ecx
	popfd
else
	mov al,0Fh
	stc
endif
	jmp iret_with_CF_mod
if ?SUPP4B8105
vds_06:
vds_05:
	push ds
	pushad
	push byte ptr _FLATSEL_
	pop ds
	test dx,0FF3Fh
	jnz error10
;	test dl,40h
;	jz error0F
ife ?32BIT
	movzx edi,di
endif
	xor eax, eax
	mov es:[edi].EDDS.wNumUsed,ax
	cmp eax,es:[edi].EDDS.dwSize	;zero sized region is ok
	je done
	movzx ebx,es:[edi].EDDS.wSel
	and ebx, ebx
	jz @F
	mov al,6
	@int_31
	jc error07
	push cx
	push dx
	pop eax
@@:
	mov ebx, edi
	add eax,es:[edi].EDDS.dwOfs
	mov ebp, eax
	mov esi,es:[edi].EDDS.dwSize
	lea esi, [eax+esi-1]
	call _Linear2PT
	jc error07
	push edi
	mov eax, esi
	call _Linear2PT
	mov ecx, edi
	pop edi
	jc error07
	sub ecx, edi
	jc error07
	shr ecx, 2
	inc ecx
	test ecx, 0FFFF0000h
	jnz error07
	cmp byte ptr [esp].PUSHADS.rEAX, 06	;is it "unlock"?
	jz done
	cld
	test byte ptr [esp].PUSHADS.rEDX,40h
	jnz storePTEs
	shl ebp, 16
	mov bp, si
	and bp, 0FFFh
	inc bp
	mov esi, edi
	mov edi, ebx
	or ebx, -1
	mov eax, ebx
nextitem2:
	lea edx, [eax+1000h]
	lodsd
	test al,01
	jz error07
	and ax,0F000h
	cmp eax, edx
	jz samereg
	inc ebx
	cmp bx, es:[edi].EDDS.wNumAvail
	jnc @F
	mov es:[edi+ebx*8+sizeof EDDS].EDDSRG.dwAddr, eax
	mov es:[edi+ebx*8+sizeof EDDS].EDDSRG.dwSize, 0
@@:
samereg:
	add es:[edi+ebx*8+sizeof EDDS].EDDSRG.dwSize, 1000h
	loop nextitem2
	mov eax, 1000h
	sub ax, bp
	sub es:[edi+ebx*8+sizeof EDDS].EDDSRG.dwSize, eax
	inc ebx
	mov es:[edi].EDDS.wNumUsed,bx
	shr ebp, 16
	and bp,0FFFh
	or es:[edi+sizeof EDDS].EDDSRG.dwAddr, ebp
	sub es:[edi+sizeof EDDS].EDDSRG.dwSize, ebp
	jmp done
storePTEs:
	mov es:[ebx].EDDS.wNumUsed,cx
	cmp cx, es:[ebx].EDDS.wNumAvail
	ja error09
	mov esi, edi
	lea edi, [ebx+sizeof EDDS]
nextitem:
	lodsd
	test al,01
	jnz @F
	xor eax, eax
@@:
	and ax,0F001h
	stosd
	loop nextitem
	and bp,0FFFh
	mov [esp].PUSHADS.rBX, bp
done:
	popad
	pop ds
	jmp iret_with_CF_mod
error10:
	mov al,10h
	jmp @F
error0F:
	mov al,0Fh
	jmp @F
error09:
	mov al,09h
	jmp @F
error07:
	mov al,07h	;invalid region
@@:
	mov byte ptr [esp].PUSHADS.rEAX,al
	stc
	jmp done
endif

intr4B endp

_TEXT32 ends

end

