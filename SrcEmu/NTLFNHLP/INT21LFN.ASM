
;--- this code checks if windows nt/2k/xp is active
;--- and will install translation services for DOS LFN functions
;--- it assumes 32-bit clients having a 32-bit stack! 

		.386
if ?FLAT
		.MODEL FLAT, stdcall
else
		.MODEL SMALL, stdcall
endif
		option proc:private
		option casemap:none

		include winbase.inc
		include macros.inc
		include dpmi.inc

?USEFNTAB	equ 1
?CLI		equ 1	;disable interrupts while in this proc

IRETS	struct
if ?CLEARHIGHEBP
rIP		dw ?
rCS		dw ?
rFlags	dw ?
else
rIP		dd ?
rCS		dd ?
rFlags	dd ?
endif
IRETS	ends

LPFAR32 typedef  ptr far32
LPFAR16 typedef  ptr far16

if ?FLAT
		.DATA
else		
		.CODE
endif

g_dwDosLin	dd 0
g_dwDosLin2 dd 0
g_flatsel	dd 0
g_dwDosSel	dd 0
g_wDosSeg	dw 0
		align 4

if ?CLEARHIGHEBP
g_oldvec21	LPFAR16 0
?SEGOFFS	equ 2
else
g_oldvec21	LPFAR32 0
?SEGOFFS	equ 4
endif

		.CODE

;--- to access the global variables use CS prefix. This code
;--- is a (software) interrupt handler and it cannot be assumed
;--- that DS is flat (in the FLAT model) or - in the SMALL model -
;--- has the same base as CS!

;--- call real mode dos with DPMI service 0300h

dos2:
		mov di,260	;cause this is "widely" used
        
dos		proc
local	rmcs:RMCS
		mov		rmcs.rEAX,eax
		mov		rmcs.rEBX,ebx
		mov		rmcs.rECX,ecx
		mov		rmcs.rEDX,edx
		mov		rmcs.rESI,esi
		mov		rmcs.rEDI,edi
		mov		rmcs.rFlags, 1
		mov		ax, cs:g_wDosSeg
		mov		rmcs.rDS, ax
		mov		rmcs.rES, ax
        xor		ecx, ecx			;CX==0000!
		mov		rmcs.rSSSP,ecx
		lea		edi, rmcs
		push	es
		push	ss
		pop		es
		mov		bx,0021h
		mov		ax,0300h
		int		31h
		pop		es
		mov		eax,rmcs.rEAX
		mov		ebx,rmcs.rEBX
		mov		ecx,rmcs.rECX
		mov		edx,rmcs.rEDX
		mov		esi,rmcs.rESI
		mov		edi,rmcs.rEDI
		jc		error
		shr		rmcs.rFlags,1	;move rFlags.CARRY into CF
error:
		ret
dos		endp

;--- 39, 3A, 3B (directory functions)
;--- 41 delete file
;--- 43 get/set file attributes
;--- 47 get current directory
;--- 4E get first filename
;--- 4F get next filename
;--- 56 rename file
;--- 60 canonicalize filename
;--- 6C extended open
;--- A0 get volume info
;--- A2 get next filename (win95)
;--- A6 get file info by handle
;--- A7 file time <-> dos time
;--- A8 generate short name
;--- A9 server create/open file
;--- AA create subst

if ?USEFNTAB
lfnfn   db 39h,3ah,3bh,41h,43h,47h,4eh,4fh,56h,60h,6ch
		db 0a0h,0a2h,0a6h,0a7h,0a8h,0a9h,0aah
sizelfnfn equ $ - lfnfn
lfnjmp  dd asciizinedx, asciizinedx, asciizinedx
        dd asciizinedx, asciizinedx, lfn47
        dd lfn4E, lfn4F, lfn56
        dd lfn60, lfn6C, lfnA0
        dd lfn4F, lfnA6, lfnA7
        dd lfnA8, lfnA9, lfnAA
endif

int2171	proc
		cld
        push	offset SetCarry
if ?CLI					;this procedure is not reentrant!
		pushfd
        test	byte ptr [esp+1],2
        jnz		@F
        cli
        mov		dword ptr [esp+4],offset SetCarry2
@@:
		lea     esp,[esp+4]
endif
if ?USEFNTAB
		push	eax		;make room for function address
		push	edi
        push	ecx
        push	es
        push	cs		;no segment override for scasb!
        pop		es
        mov		edi, offset lfnfn
        mov		ecx, sizelfnfn
        repnz	scasb
        pop		es
        jnz		@F
        neg     ecx
        mov     edi,cs:[ecx*4+offset lfnjmp+sizelfnfn*4-4]
        pop		ecx
if ?CLEARHIGHEBP
		push	ebp
        movzx	ebp,sp
        mov 	[ebp+8], edi
        pop		ebp
else
        mov 	[esp+4], edi
endif        
        pop		edi
        ret
@@:
        pop ecx
        pop edi
        pop	eax
else
		cmp		al,39h
		jb		rmdos
		cmp		al,3Bh
		jbe		asciizinedx		;39, 3A, 3B (directory functions)
		cmp		al,41h
		jz		asciizinedx		;41 delete file
		cmp		al,43h
		jz		asciizinedx		;43 get/set file attributes
		cmp		al,47h
		jz		lfn47			;47 get current directory
		cmp		al,4Eh
		jz		lfn4E			;4E get first filename
		cmp		al,4Fh
		jz		lfn4F			;4F get next filename
		cmp		al,56h
		jz		lfn56			;56 rename file
		cmp		al,60h
		jz		lfn60			;60 canonicalize filename
		cmp		al,6Ch
		jz		lfn6C			;6C extended open
		cmp		al,0A0h
		jz		lfnA0			;A0 get volume info
		cmp		al,0A2h
		jz		lfn4F			;A2 get next filename (win95)
		cmp		al,0A6h
		jz		lfnA6			;A6 get file info by handle
		cmp		al,0A7h
		jz		lfnA7			;A7 file time <-> dos time
		cmp		al,0A8h
		jz		lfnA8			;A8 generate short name
		cmp		al,0A9h
		jz		lfnA9			;A9 server create/open file
		cmp		al,0AAh
		jz		lfnAA			;AA create subst
endif   
rmdos::
		call	dos
        ret
int2171	endp

;--- set the carry flag in IRET frame and return to caller

if ?CLI
SetCarry2:
		sti
endif

SetCarry proc
		jc		@F
if ?CLEARHIGHEBP
		push	ebp
		movzx	ebp,sp
		and		byte ptr [ebp+1*4].IRETS.rFlags,not 1	;reset Carry
		pop		ebp
		iret
else
		and		byte ptr [esp].IRETS.rFlags,not 1	;reset Carry
		iretd
endif
@@:		
if ?CLEARHIGHEBP
		push	ebp
		movzx	ebp,sp
		or		byte ptr [ebp+1*4].IRETS.rFlags,1
		pop		ebp
		iret
else
		or		byte ptr [esp].IRETS.rFlags,1
		iretd
endif
SetCarry endp

;--- copy asciiz from DS:ESI to TLB:0, set esi to 0

copy2TLBesi proc
		pushad
		push	es
		mov		edi, cs:g_dwDosLin
		mov		es, cs:g_flatsel
if ?CLEARHIGHEBP
		movzx	esi, si
endif		 
		mov 	ecx, 260
@@: 	   
		lodsb
		stosb
		and al,al
		loopnz @B
		pop es
		popad
        xor esi, esi
		ret
copy2TLBesi endp

;--- copy asciiz from DS:EDX to TLB:0, set edx to 0

copy2TLBedx proc
		push esi
        mov esi,edx
        call copy2TLBesi
        pop esi
        xor edx, edx
        ret
copy2TLBedx endp

;--- copy block from DS:xxx to TLB:260

copy2TLBn proc pSrc:dword, dwSize:dword
		pushad
		push	es
		mov		edi, cs:g_dwDosLin2
		mov		es, cs:g_flatsel
if ?CLEARHIGHEBP
		movzx	esi, word ptr pSrc
else
		mov		esi, pSrc
endif		 
		mov 	ecx, dwSize
		rep		movsb
		pop es
		popad
		ret
copy2TLBn endp

;--- copy asciiz from ES:EDI to TLB:260 
		
copy2TLBesedi proc
		pushad
		push	es
		push	ds
		push	es
		pop		ds
if ?CLEARHIGHEBP
		movzx	esi, di
else
		mov		esi, edi
endif	
		mov		edi, cs:g_dwDosLin2
		mov		es, cs:g_flatsel
		mov 	ecx, 260
@@: 	   
		lodsb
		stosb
		and al,al
		loopnz @B
		pop ds
		pop es
		popad
		ret
copy2TLBesedi endp

;--- copy asciiz from TLB:260 to ES:xxx

copyfromTLB	proc pDest:dword
		pushad
		push	ds
		mov		ds, cs:g_flatsel
		mov		esi, cs:g_dwDosLin2
if ?CLEARHIGHEBP
		movzx	edi, word ptr pDest
else
		mov		edi, pDest
endif		 
		mov 	ecx, 260
@@: 	   
		lodsb
		stosb
		and al,al
		loopnz @B
		pop ds
		popad
		ret
copyfromTLB endp

;--- copy block from TLB:260 to ES:xxx

copyfromTLBn proc pDest:dword, dwSize:dword
		pushad
		push	ds
		mov		ds, cs:g_flatsel
		mov		esi, cs:g_dwDosLin2
if ?CLEARHIGHEBP
		movzx	edi, word ptr pDest
else
		mov		edi, pDest
endif		 
		mov 	ecx, dwSize
		rep movsb
		pop ds
		popad
		ret
copyfromTLBn endp

;--- lfn 39h, 3Ah, 3Bh, 41h, 43h - inp: ds:edx

asciizinedx proc
		push edx
		call copy2TLBedx
		call dos
		pop edx
        ret
asciizinedx endp

;--- lfn 47: out:ds:esi

lfn47 proc
		push esi
		mov si, 260
		call dos
		pop esi
		jc @F
		push es
		push ds
		pop es
		invoke	copyfromTLB, esi
		pop es
@@: 	
		ret
lfn47 endp

;--- lfn 56 inp: ds:edx + es:edi

lfn56 proc
		push edx
		push edi
		call copy2TLBedx
		call copy2TLBesedi
		call dos2
		pop edi
		pop edx
        ret
lfn56 endp

;--- lfn 60 - inp DS:ESI out:ES:EDI

lfn60 proc
		push esi
		push edi
		call copy2TLBesi
		call dos2
		pop edi
		pop esi
		jc	exit
		invoke copyfromTLB, edi
exit:	
		ret
lfn60 endp


;--- lfn 6C - inp: DS:ESI

lfn6C proc
		push esi
		call copy2TLBesi
		call dos
		pop esi
        ret
lfn6C endp

;--- lfn A9 - inp: DS:ESI

lfnA9 proc
		jmp	lfn6C
lfnA9 endp

;--- lfn A0 - inp: DS:EDX, out: ES:EDI (asciiz)

lfnA0 proc
		push edx
		push edi
		call copy2TLBedx
		call dos2
		pop edi
		pop edx
		jc	exit
		invoke copyfromTLB, edi
exit:	
		ret
lfnA0 endp

;--- lfn A6 - out: DS:EDX
;--- structure is SIZE_BY_HANDLE_FILE_INFO

SIZE_BY_HANDLE_FILE_INFO equ 7*4 + 3*8
	
lfnA6 proc
		push edx
		mov dx, 260
		call dos
		pop edx
		jc	exit
		push es
		push ds
		pop es
		invoke copyfromTLBn, edx, SIZE_BY_HANDLE_FILE_INFO
		pop es
exit:	
		ret
lfnA6 endp

;--- lfn A7 - bl=0 -> inp DS:ESI, bl=1 -> out ES:EDI

lfnA7 proc
		.if (bl == 0)
			push esi
			invoke copy2TLBn, esi, sizeof QWORD
			mov si, 260
			call dos
			pop esi
		.else
			push edi
			call dos2
			pop edi
			jc @F
			invoke copyfromTLBn, edi, sizeof QWORD
@@: 		   
		.endif
        ret
lfnA7 endp

;--- lfn A8 - inp DS:ESI, out ES:EDI

lfnA8 proc
		push esi
		push edi
		call copy2TLBesi
		call dos2
		pop edi
		pop esi
		jc @F
		invoke copyfromTLB, edi
@@: 	
		ret
lfnA8 endp

;--- lfn 4E - inp: DS:EDX, out ES:EDI

lfn4E proc
		push edx
		push edi
		call copy2TLBedx
		call dos2
		pop edi
		pop edx
		jc	exit
		invoke copyfromTLBn, edi, 13Eh
exit:	
		ret
lfn4E endp

;--- lfn AA - bl=0 inp: DS:EDX, bl=1 no translation, bl=2 inp DS:EDX, out ds:edx

lfnAA proc
		cmp bl,1
		jb asciizinedx
		jz rmdos
		push edx
		mov dx, 260
		call dos
		pop edx
		jc @F
		push es
		push ds
		pop es
		invoke copyfromTLB, edx
		pop es
@@: 		   
		ret
lfnAA endp

;--- lfn 4F - inp: ES:EDI - out ES:EDI

lfn4F proc
		push ds
		push es
		pop ds
		invoke copy2TLBn, edi, 13Eh
		pop ds
		push edi
		call dos2
		pop edi
		jc	exit
		invoke copyfromTLBn, edi, 13Eh
exit:	
		ret
lfn4F endp

myint21	proc
		cmp 	ah,71h					;LFN?
		jz		int2171
		stc
		jmp		cs:[g_oldvec21]
myint21	endp

;--- end of interrupt handling code

;--- installation/deinstallation
;--- here we know value of DS/ES!

ife ?FLAT
		assume DS:_TEXT
endif		 

InstallLFNHLP proc public uses ebx bCheckOS:dword

		cmp		bCheckOS,0
        jz		@F
		mov		ax,3306h
		int		21h
		cmp		bx,3205h		;NT, 2k, XP?
		jnz 	exit
@@:        
		mov		ax,0100h
		mov		bx,25h			;room for MAX_PATH + FIND_DATA (13Eh)
		int		31h
		jc		exit
		mov		g_dwDosSel, edx
		mov		g_wDosSeg,ax
		movzx	eax,ax
		shl		eax, 4
		mov		g_dwDosLin, eax
		add		eax, 260
		mov		g_dwDosLin2, eax
if ?FLAT
		mov		g_flatsel, ds
else
		mov		g_flatsel, gs
endif
		mov		ax,0204h
		mov		bl,21h
		int		31h
		mov		dword ptr g_oldvec21+0,edx
		mov		word ptr g_oldvec21+?SEGOFFS,cx
		mov		edx,offset myint21
		mov		ecx,cs
		mov		ax,0205h
		int		31h
exit:
		ret
InstallLFNHLP endp

DeinstallLFNHLP proc public uses ebx

		mov		cx,word ptr g_oldvec21+?SEGOFFS
		and		cx,cx
		jz		@F
		mov		edx,dword ptr g_oldvec21+0
		mov		bl,21h
		mov		ax,0205h
		int		31h
@@:
		xor		edx,edx
		xchg	edx,g_dwDosSel
		and		edx,edx
		jz		@F
		mov		ax,0101h
		int		31h
@@: 	   
		ret
DeinstallLFNHLP endp

		END

