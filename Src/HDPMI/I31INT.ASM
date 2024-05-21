
;*** implements int 31h, functions ax=02xx (get/set int vectors)
;*** EBX + DS can be modified here, they are saved
;*** DS initialized to FLAT

	.386

	include hdpmi.inc
	include external.inc

	option proc:private

if (sizeof R3PROC eq 4)
_SHFACTOR_ equ 2
else
_SHFACTOR_ equ 3
endif

_TEXT32  segment

;*** ax=0x200 (get rm vector) ***

_LTRACE_ = 0

getrmivec proc public
	movzx ebx,bl
	shl ebx,2
	mov dx,[ebx+0]
	mov cx,[ebx+2]
;	clc
	ret
	align 4
getrmivec endp

;*** ax=0x201 (set rm vector) ***

_LTRACE_ = 0

setrmivec proc public
	movzx ebx,bl
	shl ebx,2
	mov [ebx+0],dx
	mov [ebx+2],cx
;	clc
	ret
	align 4
setrmivec endp

;*** ax=0x0202 (get exception vector) ***

_LTRACE_ = 0

getpmevec proc public
	cmp bl,20h			   ;exceptions 00-1F!
	jnb error8021
	movzx ebx,bl
  if ?32BIT
	mov edx, cs:[ebx*sizeof R3PROC+offset excvec].R3PROC._Eip
	mov cx, word ptr cs:[ebx*sizeof R3PROC+offset excvec].R3PROC._Cs
	@dprintf "get exception vector %X: %X:%lX", bx, cx, edx
  else
	mov dx, cs:[ebx*sizeof R3PROC+offset excvec].R3PROC._Eip
	mov cx, cs:[ebx*sizeof R3PROC+offset excvec].R3PROC._Cs
	@dprintf "get exception vector %X: %X:%X", bx, cx, dx
  endif
	clc
	ret
	align 4
getpmevec endp

error8021:
	mov ax,8021h
	stc
	ret
	align 4

;*** 0203: set exception vector
;--- in: BL=exception # (00-1F)
;---     CX:E/DX=exception handler
;--- out: C if error, code in AX (8021 if BL > 1F, 8022 if CX invalid)
;--- this proc must exit with int# preserved in BL!

_LTRACE_ = 0

setpmevec proc public

	cmp bl,20h
	jnb error8021
	push eax
	lar eax,ecx
	jnz setpmvec_er
	test ah,8			;must be a code segment
	jz setpmvec_er
	pop eax
	movzx ebx,bl
	push byte ptr _CSALIAS_
	pop ds
if 1
  if ?32BIT
	mov ds:[ebx*sizeof R3PROC+offset excvec].R3PROC._Eip, edx
	mov word ptr ds:[ebx*sizeof R3PROC+offset excvec].R3PROC._Cs, cx
  else
	mov ds:[ebx*sizeof R3PROC+offset excvec].R3PROC._Eip, dx
	mov ds:[ebx*sizeof R3PROC+offset excvec].R3PROC._Cs, cx
  endif
endif
	clc
	ret
setpmvec_er:
	pop eax
	mov ax,8022h
	stc
	ret
	align 4
setpmevec endp

?LOWEXC	= 0Fh	;support 00-0F
if ?INT10SUPP
?LOWEXC = 10h	;support 00-10
endif
if ?INT11SUPP
?LOWEXC = 11h	;support 00-11
endif

;--- check if protected-mode interrupt vector is
;--- stored directly in IDT or in r3vect table.

getpmptr proc

	movzx ebx,bl
	cmp bl,?LOWEXC			;00h - 0F/10/11 are ring 0 gates
	jbe getpmivec1
if ?ENHANCED
	cmp bl,20h				;20h as well
	jz getpmivec20
endif
if ?FASTINT21
	cmp bl,21h
	jz getpmivec21
endif
if ?WINDBG
	cmp bl,22h				;22h if Win9x int 22h dbg API support
	jz getpmivec22
endif
	cmp bl,30h				;30h as well
	jz getpmivec30
if ?FASTINT31
	cmp bl,31h
	jz getpmivec31
endif
	cmp bl,41h				;41h as well
	jz getpmivec41
	cmp bl,?SPICBASE+0
	jb @F
	cmp bl,?SPICBASE+8
	jb getpmivec2			;70h-77h as well
@@:
	shl ebx,3
	add ebx,ss:[pdIDT.dwBase]
	ret
getpmivec41:
	mov bx,LOWWORD offset r3vect41
	stc
	ret
getpmivec30:
	mov bx,LOWWORD offset r3vect30
	stc
	ret
if ?FASTINT31
getpmivec31:
	mov bx,LOWWORD offset r3vect31
	stc
	ret
endif
if ?FASTINT21
getpmivec21:
	mov bx,LOWWORD offset r3vect21
	stc
	ret
endif
if ?ENHANCED
getpmivec20:
	mov bx,LOWWORD offset r3vect20
	stc
	ret
endif
if ?WINDBG
getpmivec22:
	mov bx,LOWWORD offset r3vect22
	stc
	ret
endif
getpmivec2:
	sub bl,?SPICBASE
	shl ebx,_SHFACTOR_
	add bx,LOWWORD offset r3vect70
	stc
	ret
getpmivec1:
	shl ebx,_SHFACTOR_
	add bx,LOWWORD offset r3vect00
	stc
	ret
	align 4
getpmptr endp

;*** 0204: get PM vector

_LTRACE_ = 0

getpmivec proc public

	@dprintf "getpmintvec: int %X",bx
	call getpmptr
	jc getpmivec_1 	   ;C if vector in IDT is ring 0
	mov cx,[ebx].GATE.sel
if ?32BIT
	mov dx,[ebx].GATE.ofs32
	shl edx,16
endif
	mov dx,[ebx].GATE.ofs
	clc
	ret
getpmivec_1:
if ?32BIT
	mov edx, cs:[ebx].R3PROC._Eip
	mov cx, word ptr cs:[ebx].R3PROC._Cs
else
	mov dx, cs:[ebx].R3PROC._Eip
	mov cx, cs:[ebx].R3PROC._Cs
endif
	clc
	ret
	align 4
getpmivec endp

;*** ax=0x0205 (set PM vector)
;--- interrupt in BL, vector in CX:E/DX
;--- DS=flat

_LTRACE_ = 0

setpmivec proc public
	push eax
	lar eax,ecx		;setting an invalid vector (or 0) will fail
	pop eax			;win9x fails as well, but returns with NC
	jnz error
if ?32BIT
	@dprintf "setpmintvec: int %X with %X:%lX",bx,cx,edx
else
	@dprintf "setpmintvec: int %X with %X:%X",bx,cx,dx
endif
	call installirqhandler
	call getpmptr
	jc setpmivec_1
	mov [ebx].GATE.ofs,dx
	mov [ebx].GATE.sel,cx
if ?32BIT
;	shld dword ptr [ebx].GATE.ofs32, edx, 16
	push edx
	shr edx,16
	mov [ebx].GATE.ofs32,dx
	pop edx
endif
	clc
	ret
setpmivec_1:
	push byte ptr  _CSALIAS_
	pop ds
if ?32BIT
	mov ds:[ebx].R3PROC._Eip, edx
	mov word ptr ds:[ebx].R3PROC._Cs, cx
else
	mov ds:[ebx].R3PROC._Eip, dx
	mov ds:[ebx].R3PROC._Cs, cx
endif
	clc
	ret
error:
	mov ax,8022h
	stc
	ret
	align 4
setpmivec endp

if ?DPMI10EXX

;--- int 31h, ax=0210h
;--- get protected-mode exception handler
;--- in: BL=exception no (00-1F)
;--- out: C if error, code in AX (8021: BL > 1F)
;---     NC ok, CS:E/IP of handler in CX:E/DX

geteexcp proc public
	call getpmevec
	ret
	align 4
geteexcp endp

;--- int 31h, ax=0211h
;--- get real/v86-mode exception handler
;--- in: BL=exception no (00-1F)
;--- out: C if error, code in AX (8021: BL > 1F)
;---     NC ok, CS:E/IP of handler in CX:E/DX

geteexcr proc public
	stc
	ret
	align 4
geteexcr endp

;--- int 31h, ax=0212h
;--- set protected-mode exception handler
;--- in: BL=exception no (00-1F)
;---     CX:E/DX: cs:e/ip of exception handler
;--- out: C if error, code in AX (8021: BL > 1F, 8022: CX invalid)

seteexcp proc public
	call setpmevec
	jc @F
	push ebx
	movzx ebx,bl
;--- set the bit to tell that an extended frame is to be generated for this exception.
;--- these bits are not reset until the client terminates.
	bts ss:[wExcHdlr],bx
	pop ebx
	clc
@@:
	ret
	align 4
seteexcp endp

;--- int 31h, ax=0213h
;--- set real/v86-mode exception handler
;--- in: BL=exception no (00-1F)
;---     CX:E/DX: cs:e/ip of exception handler
;--- out: C if error, code in AX (8021: BL > 1F, 8022: CX invalid)

seteexcr proc public
	stc
	ret
	align 4
seteexcr endp

endif

_TEXT32 ends

	end

