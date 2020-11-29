
;--- scans DOS MCB chain to find installed instances of hdpmi
;--- will only find instances of current version!

	.486P

	include hdpmi.inc
	include external.inc

	option proc:private

	@seg _ITEXT16

GDTSEG segment para use16 public 'CODE'
endofgdtseg label near
GDTSEG ends
GROUP16 group GDTSEG

_ITEXT16 segment

	@ResetTrace

;--- display word in decimal
;--- @rprintf knows hexadecimal only!

printword proc stdcall uses bx di number:word

local outb[8]:byte

	mov di, 10
	mov ax, number
	lea bx,outb+7
	mov BYTE PTR ss:[bx],0
	dec bx
nextdigit:
	xor dx, dx
	div di
	add dl,'0'
	mov ss:[bx],dl
	dec bx
	and ax, ax
	jne nextdigit
	inc bx
	@rprintf <"%ls">, ss, bx
	ret
printword endp

;--- print mode flags

printmode proc
	test si, FM_RESIDENT
	jz @F
	@rprintf <" resident">
@@:
	test si, FM_IVTVECS
	jz @F
	@rprintf <" modIRQs">
@@:
	test si, FM_DISABLED
	jz @F
	@rprintf <" disabled">
@@:
	test si, FM_CLONE
	jz @F
	@rprintf <" clone">
@@:
	test si, FM_INIT
	jz @F
	@rprintf <" initialized">
@@:
	ret
printmode endp

;--- print hdpmi version
;--- in: ES:DI -> hdpmi string

printversion proc
	@rprintf <"hdpmi">
	.if byte ptr es:[di+7]
		@rprintf <"32">
	.else
		@rprintf <"16">
	.endif
	@rprintf <" v">
	movzx ax,byte ptr es:[di+5]
	invoke printword, ax
	@rprintf <".">
	movzx ax,byte ptr es:[di+6]
	invoke printword, ax
	ret
printversion endp

;--- display global variables in conv memory of an instance
;--- inp: AX=hdpmi instance

checkinstance proc uses es bx
	mov es,ax
	mov di,offset logo
	mov si,di
	mov cx,llogo
	push di
	repz cmpsb
	pop di
	jnz noinstance
	assume es:GROUP16
	inc bp
	invoke printword, bp
	@rprintf <". ">

	call printversion
	@rprintf <" instance found at %X",lf>, es
	movzx ax,cApps
	@rprintf <"   host stack=%lX, Clients=%X, TLB=%X, rmStack=%X:%X",lf>, dwHostStack, ax, wSegTLB, v86iret.rSS, v86iret.rSP
	@rprintf <"   hostPSP=%X, hostSeg=%X, envFlags=%X",lf>, wHostPSP, wHostSeg, wEnvFlags
	@rprintf <"   CR3=%lX, GDT=%lX, IDT=%lX, LDT=%lX",lf>, v86topm._cr3, pdGDT.dwBase, pdIDT.dwBase, dwLDTAddr
	mov si, word ptr fMode
	@rprintf <"   mode=%X [">, si
	call printmode
	@rprintf <" ]",lf>
	assume es:nothing
	ret
noinstance:
	cmp cx,2
	ja @F
	call printversion
	@rprintf <" instance found at %X",lf>, es
@@:
	ret
checkinstance endp

;--- scan DOS memory for hdpmi instances

hdpmistat proc public

	mov ax,5802h			;get umb link status
	int 21h
	xor ah,ah
	push ax
	mov ax,5803h			;link umbs
	mov bx,0001h
	int 21h
	mov ah,52h
	int 21h
	mov es,es:[bx-2]
	xor bp,bp
	xor bx,bx
	.while (byte ptr es:[bx] != 'Z')
		mov ax,es
		inc ax
		.if (ax == es:[bx+1])	;PSP MCB?
			add ax,10h			;skip PSP
			mov cx,cs
			.if (ax != cx)		;skip our instance!
				call checkinstance
			.endif
		.elseif word ptr es:[bx+1] != 0 && word ptr es:[bx+3] > 20h
			add ax,20h		;a clone has no PSP, but a preceding 200h real-mode stack!
			call checkinstance
		.endif
		mov ax,es:[bx+3]
		mov cx,es
		add ax,cx
		inc ax
		mov es,ax
	.endw
	pop bx				;restore umb link status
	mov ax,5803h
	int 21h
	and bp,bp
	jnz @F
	@rprintf <"no hdpmi v">
	invoke printword, ?VERMAJOR
	@rprintf <".">
	invoke printword, ?VERMINOR
	@rprintf <" instance found",lf>
@@:
	ret

hdpmistat endp

	public mystart

mystart:
	cld
	push cs
	pop ds
;--- free unused dos mem 
	mov bx,ss
	mov cx,es
	sub bx,cx
	mov cx,sp
	shr cx,4
	add bx,cx
	mov ah,4Ah
	int 21h
	call hdpmistat
	mov ax,4C00h
	int 21h


_ITEXT16 ends

	end mystart
