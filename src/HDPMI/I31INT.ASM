
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

@seg _TEXT32

_TEXT32  segment

;*** get/set interrupt vectors RM
;*** this proc is called on several occations
;*** int 31h,ax=200,201
;--- in: DS=flat, bl=int no
;--- out: ds:[ebx] -> rm int vector to get/set

if ?CHECKIRQRM

checkirqrm proc public

		movzx ebx,bl
		cmp bl,1Ch
		jz cirq1c
		cmp bl,23h
		jz cirq23
		cmp bl,24h
		jz cirq24
		cmp bl,?MPICBASE+0
		jb exit
		cmp bl,?MPICBASE+8
		jb int080f
		cmp bl,?SPICBASE+0
		jb exit
		cmp bl,?SPICBASE+8
		jnb exit
		sub bl,?SPICBASE-8
		jmp cirqxx
cirq1c:
		mov bl,10h
		jmp cirqxx
cirq23:
		mov bl,11h
		jmp cirqxx
cirq24:
		mov bl,12h
		jmp cirqxx
int080f:
		sub bl,?MPICBASE
cirqxx:
		shl ebx,4		   ;* 16 (assume size STDRMCB == 16)
		add ebx,offset stdrmcbs
		push ss
		pop ds
		ret
exit:
		shl ebx,2
		ret
		align 4
checkirqrm endp

endif

;*** funktion 0x200 (get rm vector) ***

_LTRACE_ = 0

getrmivec proc public
if ?CHECKIRQRM
		call checkirqrm
else
		movzx ebx,bl
		shl ebx,2
endif
		mov dx,[ebx+0]
		mov cx,[ebx+2]
;		 clc
		ret
		align 4
getrmivec endp

;*** funktion 0x201 (set rm vector) ***

_LTRACE_ = 0

setrmivec proc public
if ?CHECKIRQRM
		call checkirqrm
else
		movzx ebx,bl
		shl ebx,2
endif
		mov [ebx+0],dx
		mov [ebx+2],cx
;		 clc
		ret
		align 4
setrmivec endp

;*** funktion 0x0202 (get exception vector) ***

_LTRACE_ = 0

getpmevec proc public
		cmp bl,20h			   ;exceptions 00-1F!
		jnb error8021
		movzx ebx,bl
  if ?32BIT
		mov edx, cs:[ebx*sizeof R3PROC+offset GROUP32:excvec].R3PROC._Eip
		mov cx, word ptr cs:[ebx*sizeof R3PROC+offset GROUP32:excvec].R3PROC._Cs
		@strout <"get exception vector %X: %X:%lX",lf>, bx, cx, edx
  else
		mov dx, cs:[ebx*sizeof R3PROC+offset GROUP32:excvec].R3PROC._Eip
		mov cx, cs:[ebx*sizeof R3PROC+offset GROUP32:excvec].R3PROC._Cs
		@strout <"get exception vector %X: %X:%X",lf>, bx, cx, dx
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
		mov ds:[ebx*sizeof R3PROC+offset GROUP32:excvec].R3PROC._Eip, edx
		mov word ptr ds:[ebx*sizeof R3PROC+offset GROUP32:excvec].R3PROC._Cs, cx
  else
		mov ds:[ebx*sizeof R3PROC+offset GROUP32:excvec].R3PROC._Eip, dx
		mov ds:[ebx*sizeof R3PROC+offset GROUP32:excvec].R3PROC._Cs, cx
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

getpmptr proc
		movzx ebx,bl

		cmp bl,?LOWEXC			   ;00h - 0F/10/11 are ring 0 gates
		jbe getpmivec1
		cmp bl,20h				   ;20h as well
		jz getpmivec20
if ?FASTINT21
		cmp bl,21h
		jz getpmivec21
endif
if ?WINDBG
		cmp bl,22h				   ;22h if Win9x int 22h dbg API support
		jz getpmivec22
endif
		cmp bl,30h				   ;30h as well
		jz getpmivec30
if ?FASTINT31
		cmp bl,31h
		jz getpmivec31
endif
		cmp bl,41h				   ;41h as well
		jz getpmivec41
		cmp bl,?SPICBASE+0
		jb @F
		cmp bl,?SPICBASE+8
		jb getpmivec2			   ;70h-77h as well
@@:
		shl ebx,3
		add ebx,ss:[pdIDT.dwBase]
		ret
getpmivec41:
		mov bx,LOWWORD(offset GROUP32:r3vect41)
		stc
		ret
getpmivec30:
		mov bx,LOWWORD(offset GROUP32:r3vect30)
		stc
		ret
if ?FASTINT31
getpmivec31:
		mov bx,LOWWORD(offset GROUP32:r3vect31)
		stc
		ret
endif
if ?FASTINT21
getpmivec21:
		mov bx,LOWWORD(offset GROUP32:r3vect21)
		stc
		ret
endif
getpmivec20:
		mov bx,LOWWORD(offset GROUP32:r3vect20)
		stc
		ret
if ?WINDBG
getpmivec22:
		mov bx,LOWWORD(offset GROUP32:r3vect22)
		stc
		ret
endif
getpmivec2:
		sub bl,?SPICBASE
		shl ebx,_SHFACTOR_
		add bx,LOWWORD(offset GROUP32:r3vect70)
		stc
		ret
getpmivec1:
		shl ebx,_SHFACTOR_
		add bx,LOWWORD(offset GROUP32:r3vect00)
		stc
		ret
		align 4
getpmptr endp

;*** 0204: get PM vector

_LTRACE_ = 0

getpmivec proc public

		@strout <"getpmintvec: int %X",lf>,bx
		call getpmptr
		jc getpmivec_1 	   ;C if vector in IDT is ring 0
		mov cx,[ebx.GATE.sel]
if ?32BIT
		mov dx,[ebx.GATE.ofs32]
		shl edx,16
endif
		mov dx,[ebx.GATE.ofs]
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

;*** DPMI funktion 0x0205 (set PM vector) ***

_LTRACE_ = 0

setpmivec proc public
		push eax
		lar eax,ecx		;setting an invalid vector (or 0) will fail
		pop eax			;win9x fails as well, but returns with NC
		jnz error
		@strout <"setpmintvec: int %X with %X:%X",lf>,bx,cx,dx
		call installirqhandler
		@strout <"setpmintvec: return from installirqhandler %X:%lX",lf>,cx,edx
		call getpmptr
		jc setpmivec_1
		mov [ebx.GATE.ofs],dx
		mov [ebx.GATE.sel],cx
if ?32BIT
		push edx
		shr edx,16
		mov [ebx.GATE.ofs32],dx
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

geteexcp proc public
		call getpmevec
		ret
		align 4
geteexcp endp

geteexcr proc public
		stc
		ret
		align 4
geteexcr endp

seteexcp proc public
		call setpmevec
		jc @F
		push ebx
		movzx ebx,bl
		bts ss:[wExcHdlr],bx
		pop ebx
		clc
@@:
		ret
		align 4
seteexcp endp

seteexcr proc public
		stc
		ret
		align 4
seteexcr endp

endif

_TEXT32 ends

		end

