
;--- implements Int 31h services (general)
;--- also included functions:
;--- ax=04xx (dpmi host capabilities/version)
;--- ax=06xx (virtual memory)
;--- ax=07xx (swapping)
;--- ax=09xx (virtual interrupt flag)

	.386P

	include hdpmi.inc
	include external.inc

	option proc:private

@seg _TEXT32
if ?LOGINT31
@seg _DATA
endif

if ?LOGINT31
_DATA	segment
        public i31func
i31func dw 0
_DATA	ends
endif

_TEXT32 segment

	@ResetTrace

;*** INT 31h API dispatcher
;--- intr31: this is the address in the IDT if ?FASTINT31

intr31  proc public
ife ?FASTINT31
	push offset iret_with_CF_mod
else
	cmp word ptr cs:r3vect31._Cs,_INTSEL_	;vector modified?
	jz intr31_
	cmp word ptr [esp].IRET32.rCS, _CSSEL_	;is it an internal call?
	jz intr31_								;then dont route to ring 3
	@simintpms 31
endif
intr31 endp

intr31_ proc public
	@strout <"i31 a-d=%X %X %X %X di=%lX,">,\
		ax,bx,cx,dx,edi
;	@waitesckey

if ?LOGINT31
	mov ss:[i31func],ax
endif
	push ds
	call _i31srvr
	pop ds
if _LTRACE_
	jc @F
	@strout <"NC ">
	jmp intr31ex_1
@@:
	@strout <" C ">
intr31ex_1:
	@strout <"a-d=%X %X %X %X",lf>,ax,bx,cx,dx
endif
if ?FASTINT31
	jmp iret_with_CF_mod
  if 0
	jc @F
	and byte ptr [esp].IRET32.rFL, not 1	;reset carry
	iretd
@@:
	or byte ptr [esp].IRET32.rFL, 1 	;set carry
	iretd
  endif
else
	ret
endif
	align 4
intr31_ endp

;--- support DPMI 1.0: 
;--- 000E, 000F
;--- (0210, 0212) [DPMI10EXX]
;--- 0401
;--- 0504, 0505, 0506, 0507 (,0508, 0509, 050A, 050B) [DPMI10EX]
;--- 0801

?FUNC00 = 0Eh
?FUNC02 = 06h
?FUNC04 = 01h
?FUNC05 = 04h
?FUNC08 = 01h

if ?DPMI10
?FUNC00 = 10h
if ?DPMI10EXX
?FUNC02 = 14h
endif
?FUNC04 = 02h
?FUNC05 = 08h
if ?DPMI10EX
?FUNC05 = 0Ch
endif
?FUNC08 = 02h
endif

subfunctab label byte
	db ?FUNC00			;00
	db 03h				;01
	db ?FUNC02,07h		;02-03
	db ?FUNC04			;04
dpmi5functions db ?FUNC05	;05 (may be modified while this code is low)
	db 05h,04h			;06-07
	db ?FUNC08			;08
	db 03h,00h,04h		;09-0B
	db 00h,00h,02h		;0C-0E

	align 4

@defl macro x
	exitm <offset x>
	endm

functab label dword
	dd @defl(func00), @defl(func01), @defl(func02), @defl(func03)
	dd @defl(func04), @defl(func05), @defl(func06), @defl(func07)
	dd @defl(func08), @defl(func09), @defl(func0A), @defl(func0B)
	dd @defl(func0C), @defl(func0D), @defl(i31f0E)

jmpvector0 label dword
	dd @defl(allocsel)	;0
	dd @defl(freesel)	;1
	dd @defl(allocrmsel);2
	dd @defl(getincvalue);3
	dd @defl(locksel)	;4
	dd @defl(unlocksel) ;5
	dd @defl(getbase)	;6
	dd @defl(setbase)	;7
	dd @defl(setlimit)	;8
	dd @defl(setaccrights);9
	dd @defl(getcsalias);A
	dd @defl(getdesc)	;B
	dd @defl(setdesc)	;C
	dd @defl(allocspecific)  ;D
if ?DPMI10
	dd @defl(getmultdesc);E
	dd @defl(setmultdesc);F
endif

jmpvector1 label dword
	dd @defl(allocdos)  ;0
	dd @defl(freedos)	;1
	dd @defl(resizedos) ;2

jmpvector2 label dword
	dd @defl(getrmivec) ;0
	dd @defl(setrmivec) ;1
	dd @defl(getpmevec) ;2
	dd @defl(setpmevec) ;3
	dd @defl(getpmivec) ;4
	dd @defl(setpmivec) ;5
if ?DPMI10EXX
	dd @defl(error02)	;6
	dd @defl(error02)	;7
	dd @defl(error02)	;8
	dd @defl(error02)	;9
	dd @defl(error02)	;A
	dd @defl(error02)	;B
	dd @defl(error02)	;C
	dd @defl(error02)	;D
	dd @defl(error02)	;E
	dd @defl(error02)	;F
	dd @defl(geteexcp)  ;10
	dd @defl(geteexcr)  ;11
	dd @defl(seteexcp)  ;12
	dd @defl(seteexcr)  ;13
endif

jmpvector3 label dword
	dd @defl(simrmint)  ;0
	dd @defl(callrmretf);1
	dd @defl(callrmiret);2
	dd @defl(allocrmcb) ;3
	dd @defl(freermcb)  ;4
	dd @defl(getsraddr) ;5 Get State Save/Restore Addresses
	dd @defl(getrmsa)	;6

jmpvector5 label dword
	dd @defl(getmeminfo);0500
	dd @defl(allocmem)  ;0501
	dd @defl(freemem)	;0502
	dd @defl(resizemem) ;0503
if ?DPMI10
	dd @defl(allocmemx)	;0504
	dd @defl(resizememx);0505
	dd @defl(getpageattr);0506
	dd @defl(setpageattr);0507
  if ?DPMI10EX
	dd @defl(mapphysx) 	;0508
	dd @defl(mapdos)	;0509
	dd @defl(getmemsize);050A
	dd @defl(getmeminfox);050B
  endif
endif

if 0
jmpvector9 label dword
	dd @defl(disableint)
	dd @defl(enableint)
	dd @defl(getintstate)
endif

jmpvectorB label dword
	dd @defl(allocwatch)
	dd @defl(clearwatch)
	dd @defl(getwatchstate)
	dd @defl(resetwatchstate)

if 0
jmpvectorE label dword
	dd @defl(getcostate)
	dd @defl(setcostate)
endif

	@ResetTrace

_i31srvr proc near

	cmp ah,0Fh
	jnb error1
	push ebx
	movzx ebx,ah
	cmp al,byte ptr cs:[ebx + offset subfunctab]
	jnc error2
	cld
	jmp dword ptr cs:[ebx*4 + offset functab]
error2:
	pop ebx
error1:
if 1
	mov ax,8001h				;unsupported function
endif
	@strout <"int31, ax=%X unsupported, bx-di=%X %X %X %X %X",lf>,ax,bx,cx,dx,si,di
	stc
	ret
_i31srvr endp

	@ResetTrace

;--- descriptor (LDT) functions

func00:
	push offset jmpvector0
	mov ds,ss:[selLDT]
	jmp func_00_02
	align 4

;--- interrupt (IDT) functions

func02:
if ?ENHANCED
	and al,7Fh
endif
	push offset jmpvector2
	push byte ptr _FLATSEL_
	pop ds

func_00_02:
	movzx ebx,al
	shl ebx, 2
	add ebx,[esp]
	mov [esp], offset return
	push dword ptr cs:[ebx]
	mov ebx, [esp+4].I31FR1.dwEbx
	retn
return:
	pop ebx
	ret
if ?DPMI10EXX
error02:
	stc
	ret
endif
	align 4

I31FR2 struct
dwJumpVec	dd ?
dwEbx		dd ?
			dd ?	;returnaddress
dwDS		dd ?
I31FR2 ends

;--- dos memory functions

func01:
		push offset jmpvector1
		jmp func_01_03_05_0B
		align 4

;--- mode switch functions

func03:
		push offset jmpvector3
		jmp func_01_03_05_0B
		align 4

;--- watchpoint functions

func0B:
		push offset jmpvectorB
		jmp func_01_03_05_0B
		align 4

;--- extended memory functions

func05:
		push offset jmpvector5
;		push byte ptr _FLATSEL_
;		pop ds
func_01_03_05_0B:
		movzx ebx, al
		shl ebx, 2
		add ebx, [esp].I31FR2.dwJumpVec
		mov ebx, cs:[ebx]
		mov [esp].I31FR2.dwJumpVec, ebx
		mov ebx, [esp].I31FR2.dwEbx
		retn 4
		align 4

		@ResetTrace

HF_32BIT	equ 1	;running under a 32-bit implementation
HF_INTINRM	equ 2	;ints reflected to real-mode
HF_VIRTMEM	equ 4	;virtual memory supported


func04:
		pop ebx
if ?DPMI10
		and al,al
		jnz func0401
endif
		mov ax,ss:[wVersion] 
		mov bx,HF_32BIT
		test ss:[fHost], FH_VCPI
		jnz @F
		or bl,HF_INTINRM
@@:
		mov cl,ss:[_cpu]			;CPU=80386/80486
		mov dx,?MPICBASE*100h+?SPICBASE  ;PIC bases
		ret
		align 4

if ?DPMI10

DPMI10_PAGE_ACCDIRTY	equ 1	;support to get/set dirty/accessed PTE flags
DPMI10_EXCRESTART		equ 2	;allow client to handle ring 0 exceptions
DPMI10_DEVICEMAPPING	equ 4	;support int 31h, ax=0508h
DPMI10_CONVMEMMAPPING	equ 8	;support int 31h, ax=0509h
DPMI10_DEMANDZEROFILL	equ 16	;fill newly committed pages with 00
DPMI10_WRITEPROTCLIENT	equ 32	;client cannot modify r/o pages
DPMI10_WRITEPROTHOST	equ 64	;host cannot modify r/o pages

if ?EXCRESTART
HOSTCAPS equ DPMI10_PAGE_ACCDIRTY + DPMI10_EXCRESTART + \
		DPMI10_DEVICEMAPPING + DPMI10_CONVMEMMAPPING + DPMI10_WRITEPROTCLIENT
else
HOSTCAPS equ DPMI10_PAGE_ACCDIRTY + DPMI10_DEVICEMAPPING + \
		DPMI10_CONVMEMMAPPING + DPMI10_WRITEPROTCLIENT
endif

dpmi10str	db ?VERMAJOR,?VERMINOR,"HDPMI",0
SIZEDPMI10	equ $ - dpmi10str

func0401:
	pushad
	mov esi, offset dpmi10str
	mov ecx, SIZEDPMI10
ife ?32BIT
	movzx edi, di
endif
	db 2Eh				;CS segment prefix
	rep movsb
	popad
	xor cx,cx
	xor dx,dx
	mov ax,HOSTCAPS
	cmp cs:dpmi5functions,5
	jnc @F
	mov al,DPMI10_WRITEPROTCLIENT
@@:
	clc
	ret
endif
func08:                                 ;map real -> virt
	pop ebx
if ?DPMI10
	cmp al,1
	jz unmapphysregion
endif
	jmp mapphysregion

;--- paging
;--- ax=0700: mark pages as paging candidates BX:CX, SI:DI
;--- ax=0701: discard pages BX:CX, SI:DI
;--- ax=0702: mark pages as demand paging candidates BX:CX, SI:DI
;--- ax=0703: discard page contents BX:CX, SI:DI

func07 proc


	pop ebx
if 0
	cmp bx,0011h			;address < 110000h?
	jb exit
	push eax
	push edx
	xor edx,edx				;reset accessed (+ dirty) flags
	test al,1
	mov ax,PTF_ACCESSED
	jz @F
	or ax,PTF_DIRTY
@@:
	call _setregionattributes
	pop edx
	pop eax
exit:
else
	clc		;--- just exit with NC
endif
	ret
	align 4
func07 endp

;--- virtual memory functions
;--- ax=0600: lock linear region BX:CX, size SI:DI
;--- ax=0601: unlock linear region BX:CX, size SI:DI
;--- ax=0602: mark real-mode region as pageable, BX:CX, size SI:DI
;--- ax=0603: relock real-mode region, BX:CX, size SI:DI
;--- ax=0604: return page size

func06 proc
	pop ebx
	cmp al,04			;added 29.2.2004
	jb lockunlock
	mov cx,1000h		;return page size in BX:CX
	xor bx,bx
	ret

;--- since virtual memory is not supported, dont do anything here
        
lockunlock:
	clc
	ret
func06 endp

func0A:
func0C:
func0D:
	pop ebx
	stc
	ret
	align 4

;*** int 31h, ax=09xxh ***

I3109FR struct
rEBX	dd ?
dwRet	dd ?	;_i31srvr
rDS		dd ?
ife ?FASTINT31
dwRet2	dd ?	;iret_with_CF_mod if ?FASTINT31 == 0
endif
I3109FR ends

;--- interrupt flag functions
;--- ax=0900h: disable virtual interrupt state
;--- ax=0901h: enable virtual interrupt state
;--- ax=0902h: get virtual interrupt state

func09 proc
	mov ebx,[esp].I3109FR.rEBX
	add esp, sizeof I3109FR
	and byte ptr [esp].IRET32.rFL,not 1	;clear carry
	cmp al,1
	jz enableint
	jnc getintstate
disableint:
	btr word ptr [esp].IRET32.rFL,9
	setc al
	iretd
	align 4
enableint:
	bts word ptr [esp].IRET32.rFL,9
	setc al
	iretd
	align 4
getintstate:
	bt word ptr [esp].IRET32.rFL,9
	setc al
	iretd
	align 4
func09 endp

_TEXT32 ends

	end
