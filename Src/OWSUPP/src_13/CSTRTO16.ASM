;*****************************************************************************
;*
;*                            Open Watcom Project
;*
;*    Portions Copyright (c) 1983-2002 Sybase, Inc. All Rights Reserved.
;*
;*  ========================================================================
;*
;*    This file contains Original Code and/or Modifications of Original
;*    Code as defined in and that are subject to the Sybase Open Watcom
;*    Public License version 1.0 (the 'License'). You may not use this file
;*    except in compliance with the License. BY USING THIS FILE YOU AGREE TO
;*    ALL TERMS AND CONDITIONS OF THE LICENSE. A copy of the License is
;*    provided with the Original Code and Modifications, and is also
;*    available at www.sybase.com/developer/opensource.
;*
;*    The Original Code and all software distributed under the License are
;*    distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
;*    EXPRESS OR IMPLIED, AND SYBASE AND ALL CONTRIBUTORS HEREBY DISCLAIM
;*    ALL SUCH WARRANTIES, INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF
;*    MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, QUIET ENJOYMENT OR
;*    NON-INFRINGEMENT. Please see the License for the specific language
;*    governing rights and limitations under the License.
;*
;*  ========================================================================
;*
;* Description:  C/C++ OS/2 16-bit console and DLL startup code.
;*
;*****************************************************************************


;       This must be assembled using one of the following commands:
;               wasm cstrto16 -bt=OS2 -ms -2r
;               wasm cstrto16 -bt=OS2 -mm -2r
;               wasm cstrto16 -bt=OS2 -mc -2r
;               wasm cstrto16 -bt=OS2 -ml -2r
;               wasm cstrto16 -bt=OS2 -mh -2r
;
; NOTE: This code must NEVER NEVER NEVER NEVER define any variable or routines
;       which are needed by the C Library. It should also be MINIMAL.
;       This is so we can make CLIB DLL's.
;
include mdef.inc

        name    cstart

        assume  nothing


        xref    __OS2Main
        extrn   __DOSseg__      : byte


 DGROUP group _NULL,_AFTERNULL,CONST,STRINGS,_DATA,_BSS,STACK,XIB,XI,XIE,YIB,YI,YIE

ife _MODEL and _BIG_CODE

; this guarantees that no function pointer will equal NULL
; (WLINK will keep segment 'BEGTEXT' in front)
; This segment must be at least 4 bytes in size to avoid confusing the
; signal function.
; need a symbol defined here to prevent the dead code elimination from
; eliminating the segment.
; (the int 3h is useful for quickly revealing jumps to NULL code pointers)

BEGTEXT  segment word public 'CODE'
        assume  cs:BEGTEXT
forever label   near
        int     3h
        jmp     short forever
___begtext label byte
        nop
        nop
        nop
        nop
        public ___begtext
        assume  cs:nothing
BEGTEXT  ends

endif

_TEXT   segment para public 'CODE'

        assume  ds:DGROUP

        INIT_VAL        equ 0101h
        NUM_VAL         equ 16

XIB     segment word public 'DATA'
XIB     ends
XI      segment word public 'DATA'
XI      ends
XIE     segment word public 'DATA'
XIE     ends

YIB     segment word public 'DATA'
YIB     ends
YI      segment word public 'DATA'
YI      ends
YIE     segment word public 'DATA'
YIE     ends

_NULL   segment para public 'BEGDATA'
public  __nullarea
__nullarea  label   word
        dw      NUM_VAL dup(INIT_VAL)
_NULL   ends

_AFTERNULL segment word public 'BEGDATA'
        dw      0                       ; nullchar for string at address 0
_AFTERNULL ends

CONST   segment word public 'DATA'
CONST   ends

STRINGS segment word public 'DATA'
STRINGS ends

_DATA   segment word public 'DATA'
_DATA   ends

_BSS          segment word public 'BSS'
_BSS          ends

STACK   segment para stack 'STACK'
        stklow  label   word
        db      1000h dup(?)
STACK   ends

        assume  nothing
        public  _cstart_
        public  __DLLstart_

        assume  cs:_TEXT

 _cstart_ proc near
        assume  ds:DGROUP
__DLLstart_:
        jmp     around

;
; copyright message
;
        db      "Open Watcom C/C++16 Run-Time system. "
        db      "Portions Copyright (c) Sybase, Inc. 1988-2002."
ife _MODEL and _BIG_CODE
        dw      ___begtext      ; make sure dead code elimination
                                ; doesn't kill BEGTEXT
endif

around:
ifdef ?MZ
externdef _AllocCSAlias:near
		call	_AllocCSAlias
endif
		call	makeenv
        push    bx                      ; save registers
        push    cx                      ; ...
        push    dx                      ; ...
        push    si                      ; ...
        push    di                      ; ...
        push    es                      ; ...
        push    bp                      ; ...
        mov     bp,sp                   ; point to saved registers
        push    bx                      ; command offset
        push    ax                      ; environment segment
        mov     cx,ss                   ; ...
        mov     bx,sp                   ; get bottom of stack in cx:dx
        add     bx,4                    ; adjust for two pushes
        mov     dx,ss                   ; get stklow dx:ax
        mov     ax,offset DGROUP:stklow ; ...
        call    __OS2Main               ; call main startup
        mov     sp,bp                   ; restore stack pointer
        pop     bp                      ; restore registers
        pop     es                      ; ...
        pop     di                      ; ...
        pop     si                      ; ...
        pop     dx                      ; ...
        pop     cx                      ; ...
        pop     bx                      ; ...
        retf                            ; return


_cstart_ endp

;--- dpmild16 doesnt supply cmdline as expected by os2 binaries

		.286

makeenv proc

local	wpsp:word
local	wenv:word
local	pgmname:word
local	cmdofs:word

        and si,si		;is it DPMILD16?
        jnz exit
		mov cmdofs,bx
		pusha
        push es
        push ds
        mov  ah,51h
        int 21h
        mov wpsp,bx
        mov es,bx
        mov es,es:[002Ch]
        mov wenv,es
        xor di,di
        or cx,-1
        mov al,0
@@:        
        repnz scasb
        scasb
        jnz @B
        add di,2
        mov pgmname,di
        repnz scasb
        mov bx,di
        push bx
        add bx,15+128+128
        shr bx,4
        mov ah,48h
        int 21h
        pop cx
        jc  done
        push es
        pop	 ds
        mov es,ax
        mov wenv,ax
        xor si,si
        xor di,di
        rep movsb
        push es
        pop ds
        mov si,pgmname
@@:        
        lodsb
        stosb
        and al,al
        jnz @B
        mov cmdofs,di
        sub cmdofs,2	;???
        mov ds,wpsp
        mov si,80h
        lodsb
        mov cl,al
        mov ch,0
if 1        
        rep movsb
        mov al,0
        stosb
else        
nextchar:        
        jcxz parmsdone
        cmp byte ptr [si],' '
        ja @F
        inc si
        dec cl
        jmp nextchar
@@:
		lodsb
        cmp al,13
        jz  argdone
        cmp al,' '
        jz  argdone
        stosb
        loop @B
argdone:
		mov al,0
        stosb
        jmp nextchar
parmsdone:
		mov ax,0
        stosw
endif
done:        
        pop ds
        pop es
        popa
        mov ax, wenv
        mov bx, cmdofs
exit:        
		ret
makeenv endp

_TEXT   ends

;--- WLINK complains if more than 1 start address has been
;--- found. Since the true start address has to be in
;--- JMPPM16 for MZ, avoid to define another one here.

ifdef ?MZ
endlabel textequ <>
else
endlabel textequ _cstart_
endif

        end endlabel

