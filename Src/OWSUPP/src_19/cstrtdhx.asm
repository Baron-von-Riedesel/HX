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
;* Description:  DOS 32-bit startup code.
;*
;*****************************************************************************


; Note: This module must contain the string 'WATCOM' (all caps) for DOS/4GW
;       to recognize a 'Watcom' executable.

;       This must be assembled using one of the following commands:
;               wasm cstrt386 -bt=DOS -ms -3r
;               wasm cstrt386 -bt=DOS -ms -3s
;
;   NOTE: All C library data should be defined in crwdata.asm -- That way
;         it's also available to ADS applications (who use adstart.asm).
;

        name    cstart

.387
.386p

@cextrn macro x,y
ifdef __JWASM__
extern c x:y
else
extrn "C",x:y
endif
endm

@cpublic macro x
ifdef __JWASM__
public c x
else
public "C",x
endif
endm

include xinit.inc

FLG_NO87        equ     1
FLG_LFN         equ     1

HX      equ 1
DOS4G   equ 0
PHARLAP equ 0

        assume  nothing

        extrn   __CMain              : near
        extrn   __InitRtns           : near
        extrn   __FiniRtns           : near
        extrn   __DOSseg__           : near

        extrn   _edata               : byte  ; end of DATA (start of BSS)
        extrn   _end                 : byte  ; end of BSS (start of STACK)

        @cextrn   _dynend            , dword
        @cextrn   _curbrk            , dword
        @cextrn   _psp               , word
        @cextrn   _osmajor           , byte
        @cextrn   _osminor           , byte
        @cextrn   _STACKLOW          , dword
        @cextrn   _STACKTOP          , dword
        @cextrn   _child             , dword
        extrn    __no87              : byte
        @cextrn   __uselfn           , byte
        @cextrn   _Extender          , byte
        @cextrn   _ExtenderSubtype   , byte
        @cextrn   _Envptr            , dword
        @cextrn   _Envseg            , word
        @cextrn   __FPE_handler      , dword
        @cextrn   _LpCmdLine         , dword
        @cextrn   _LpPgmName         , dword

DGROUP group _NULL,_AFTERNULL,CONST,_DATA,DATA,TIB,TI,TIE,XIB,XI,XIE,YIB,YI,YIE,_BSS,STACK

; this guarantees that no function pointer will equal NULL
; (WLINK will keep segment 'BEGTEXT' in front)
; This segment must be at least 4 bytes in size to avoid confusing the
; signal function.

BEGTEXT  segment use32 para public 'CODE'
        assume  cs:BEGTEXT
forever label   near
        int     3h
        jmp     short forever
___begtext label byte
        nop     ;3
        nop     ;4
        nop     ;5
        nop     ;6
        nop     ;7
        nop     ;8
        nop     ;9
        nop     ;A
        nop     ;B
        nop     ;C
        nop     ;D
        nop     ;E
        nop     ;F
        public ___begtext
        assume  cs:nothing
BEGTEXT  ends

_TEXT   segment use32 dword public 'CODE'

        assume  ds:DGROUP

_NULL   segment para public 'BEGDATA'
__nullarea label word
        db      01h,01h,01h,00h
        public  __nullarea
_NULL   ends

_AFTERNULL segment word public 'BEGDATA'
_AFTERNULL ends

CONST   segment word public 'DATA'
CONST   ends

TIB     segment byte public 'DATA'
TIB     ends
TI      segment byte public 'DATA'
TI      ends
TIE     segment byte public 'DATA'
TIE     ends

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


_DATA    segment dword public 'DATA'
X_ERGO                  equ     0       ; Ergo OS/386 (unsupported)
X_RATIONAL              equ     1       ; DOS/4G(W) or compatible
X_PHARLAP_V2            equ     2       ; PharLap 386|DOS
X_PHARLAP_V3            equ     3
X_PHARLAP_V4            equ     4
X_PHARLAP_V5            equ     5
X_PHARLAP_V6            equ     6       ; PharLap TNT
X_INTEL                 equ     9       ; Intel CodeBuilder (unsupported)
X_WIN386                equ     10      ; Watcom Win386
XS_NONE                 equ     0
XS_RATIONAL_ZEROBASE    equ     0
XS_RATIONAL_NONZEROBASE equ     1
__D16Infoseg   dw       0020h   ; DOS/4G kernel segment
__x386_zero_base_selector dw 0  ; base 0 selector for X-32VM

        public  __D16Infoseg
        public  __x386_zero_base_selector
_DATA    ends


DATA    segment word public 'DATA'
DATA    ends

_BSS          segment word public 'BSS'
_BSS          ends

STACK_SIZE      equ     10000h

STACK   segment para stack 'STACK'
        db      (STACK_SIZE) dup(?)
STACK   ends


        assume  nothing
        public  _cstart_

        assume  cs:_TEXT

_cstart_ proc near
        jmp     short around

;
; copyright message (special - see comment at top)
;
        db      "Open WATCOM C/C++32 Run-Time system. "
include msgcpyrt.inc

        align   4
        dd      ___begtext      ; make sure dead code elimination
                                ; doesn't kill BEGTEXT
;
; miscellaneous code-segment messages
;
ConsoleName     db      "con",00h

NewLine         db      0Dh,0Ah

around: sti                             ; enable interrupts

        assume  ds:DGROUP

if PHARLAP
PSP_SEG equ     24h
ENV_SEG equ     2ch
endif

if HX

PEHDR struct
sig                 dd ?
fhdr                dd 5 dup (?)
                    dd ?    ; magic, linker version
codesize            dd ?
initdatasize        dd ?
bsssize             dd ?
entry               dd ?
codebaserva         dd ?
databaserva         dd ?
imagebaserva        dd ?
SectionAlignment    dd ?
alignment           dd ?
                    dd ?,?,?,?
imagesize           dd ?
headersize          dd ?
                    dd ?
                    dd ?
stacksize_rsvd      dd ?
stacksize_commit    dd ?
PEHDR ends

;--- hx: esi=linear address module
;---     ebx=linear address psp (loadpe only!)
;--- make code section r/o - if DPMILD32 has been used to load the binary,
;--- this may have been done already.
;--- One problem with DPMILD32 is that the stack is allocated separately,
;--- meaning that it won't be located necessarily "behind" _BSS data.

        add esi,[esi+3Ch]
        mov eax, esp
        add eax, 4096-1
        and ax, 0f000h
        mov _STACKTOP, eax
        mov _curbrk, eax                ; set first available memory location
        sub eax,[esi].PEHDR.stacksize_rsvd
        mov _STACKLOW,eax
else
        and     esp,0fffffffch          ; make sure stack is on a 4 byte bdry
        mov     ebx,esp                 ; get sp
        mov     _STACKTOP,ebx           ; set stack top
        mov     _curbrk,ebx             ; set first available memory location
endif
if PHARLAP
        mov     ax,PSP_SEG              ; get segment address of PSP
        mov     _psp,ax                 ; save segment address of PSP
endif
;
;       get DOS & Extender version number
;
if PHARLAP
        ;mov    ebx,'PHAR'              ; set ebx to "PHAR"
        mov     ebx,50484152h           ; set ebx to "PHAR"
endif
        sub     eax,eax                 ; set eax to 0
        mov     ah,30h
        int     21h                     ; modifies eax,ebx,ecx,edx
        mov     _osmajor,al
        mov     _osminor,ah
        mov     ecx,eax                 ; remember DOS version number
        sub     esi,esi                 ; offset 0 for environment strings
        mov     edi,81H                 ; DOS command buffer es:edi
if PHARLAP
        shr     eax,16                  ; get top 16 bits of eax
        cmp     ax,'DX'                 ; if top 16 bits = "DX"
        jne     not_pharlap             ; then its pharlap
        sub     bl,'0'                  ; - save major version number
        mov     al,bl                   ; - (was in ascii)
        mov     ah,XS_NONE              ; - extender subtype
        push    eax                     ; - save version number
        mov     es,_psp                 ; - point to PSP
        mov     ebx,es:[5Ch]            ; - get highest addr used
        add     ebx,000000FFFh          ; - round up to 4K boundary
        and     ebx,0FFFFF000h          ; - ...
        mov     _curbrk,ebx             ; - set first available memory locn
        shr     ebx,12                  ; - calc. # of 4k pages
        mov     eax,ds                  ; - set ES=data segment
        mov     es,eax                  ; - ...
        mov     ah,4Ah                  ; - shrink block to minimum amount
        int     21h                     ; - ...
        pop     eax                     ; - restore version number
        mov     ebx,ds                  ; - get value of Phar Lap data segment
        mov     cx,ENV_SEG              ; - PharLap environment segment
        jmp     short know_extender     ; else
not_pharlap:                            ; - assume DOS/4G or compatible
endif
if DOS4G
        mov     dx,78h                  ; - see if Rational DOS/4G
        mov     ax,0FF00h               ; - ...
        int     21h                     ; - ...
        cmp     al,0                    ; - ...
;        je      short know_extender    ; - quit if not Rational DOS/4G
        je      short not_DOS4G         ; - jmp to non-DOS/4G
        mov     eax,gs                  ; - get segment address of kernel
        cmp     ax,0                    ; - if not zero
        je      short rat9              ; - then
        mov     __D16Infoseg,ax         ; - - remember it
rat9:                                   ; - endif
        mov     ax,6                    ; - check data segment base
        mov     bx,ds                   ; - set up data segment
        int     31h                     ; - DPMI call
        mov     al,X_RATIONAL           ; - asssume Rational 32-bit Extender
        mov     ah,XS_RATIONAL_ZEROBASE ; - extender subtype
        or      dx,cx                   ; - if base is non-zero
        jz      rat10                   ; - then
        mov     ah,XS_RATIONAL_NONZEROBASE; - DOS/4G non-zero based data
rat10:                                  ; - endif
        mov     _psp,es                 ; - save segment address of PSP
        mov     cx,es:[02ch]            ; - get environment segment into cx
        jmp     short know_extender     ; else
;--- added for non-DOS4G support
not_DOS4G:
endif
if HX
 if 0
        mov     ah,51h                  ; assume we get the PSP selector
        int     21h                     ; by a simple DOS call (HDPMI/DPMIONE/Windows only)
 else
        push edi
        xor ecx, ecx
        push ecx
        sub esp, 2Eh
        mov edi, esp
        mov byte ptr [edi+1Dh], 51h
        mov [edi+20h], ecx
        mov bx, 21h
        mov ax, 300h
        int 31h
        mov bx, [edi+10h]
        add esp, 32h
        pop edi
        mov ax, 2
        int 31h
        mov ebx, eax
 endif
        mov     _psp,bx
        mov     es,ebx
        mov     cx,es:[2Ch]
        mov     ebx,ds
        mov     al,X_RATIONAL
        mov     ah,XS_NONE              ; default is zerobased FLAT
else
        xor eax, eax
endif

;--- ax=extender type, bx=code alias, cx=env seg, esi=env ofs, edi=cmdline ofs in PSP

know_extender:                          ; endif
        mov     _Extender,al            ; record extender type
        mov     _ExtenderSubtype,ah     ; record extender subtype
        mov     es,bx                   ; get access to code segment
        mov     es:__saved_DS,ds        ; save DS value
        mov     _Envptr,esi             ; save address of environment strings
        mov     _Envseg,cx              ; save segment of environment area
        push    esi                     ; save address of environment strings
;
;       copy command line into bottom of stack
;
        mov     es,_psp                 ; point to PSP
if HX
        mov     edx, _STACKLOW
else
        mov     edx,offset DGROUP:_end
        add     edx,0FH
        and     dl,0F0H
endif
        sub     ecx,ecx
        mov     cl,es:[edi-1]           ; get length of command
        cld                             ; set direction forward
        mov     al,' '
        repe    scasb
        lea     esi,[edi-1]
        mov     edi,edx
        mov     ebx,es
        mov     edx,ds
        mov     ds,ebx
        mov     es,edx                  ; es:edi is destination
        je      noparm
        inc     ecx
        rep     movsb
noparm: sub     al,al
        stosb                           ; store NULLCHAR
        stosb                           ; assume no pgm name
        pop     esi                     ; restore address of environment strings
        dec     edi                     ; back up pointer 1
        push    edi                     ; save pointer to pgm name
        push    edx                     ; save ds(stored in dx)
        ;fixme-start
        ;mov    ds,es:_Envseg           ; get segment addr of environment area
        db      26h                     ; force ES segment override
        mov     ds,_Envseg              ; get segment addr of environment area
        ;fixme-end
        mov     bx,FLG_LFN*256          ; assume 'lfn=n' env. var. not present / assume 'no87=' env. var. not present
L1:     mov     eax,[esi]               ; get first 4 characters
        or      eax,20202020h           ; map to lower case
        ;cmp    eax,'78on'              ; check for "no87"
        cmp     eax,37386f6eh           ; check for "no87"
        jne     short L2                ; skip if not "no87"
        cmp     byte ptr 4[esi],'='     ; make sure next char is "="
        jne     short L2                ; no
        or      bl,FLG_NO87             ; - indicate 'no87' was present
L2:
        cmp     eax,3d6e666ch           ; check for 'lfn='
        jne     short L4                ; skip if not 'lfn='
        mov     al,byte ptr 4[esi]      ; get next character
        or      al,20h                  ; map to lower case
        cmp     al,'n'                  ; make sure next char is 'n'
        jne     short L4                ; no
        and     bh,not FLG_LFN          ; indicate no 'lfn=n' present
L4:
        cmp     byte ptr [esi],0        ; end of string ?
        lodsb
        jne     L4                      ; until end of string
        cmp     byte ptr [esi],0        ; end of all strings ?
        jne     L1                      ; if not, then skip next string
        lodsb
        inc     esi                     ; point to program name
        inc     esi                     ; . . .
;
;       copy the program name into bottom of stack
;
L5:     cmp     byte ptr [esi],0        ; end of pgm name ?
        movsb                           ; copy a byte
        jne     L5                      ; until end of pgm name
        pop     ds                      ; restore ds
        pop     esi                     ; restore address of pgm name

        assume  ds:DGROUP
        mov     __no87,bl               ; set state of "no87" enironment var
        and     __uselfn,bh             ; set "LFN" support status
        mov     ebx,esp                 ; end of stack in data segment
        mov     _dynend,ebx             ; set top of dynamic memory area
if HX
        push edi
else
        mov     _STACKLOW,edi           ; save low address of stack
endif

        mov     ecx,offset DGROUP:_end  ; end of _BSS segment (start of STACK)
        mov     edi,offset DGROUP:_edata; start of _BSS segment
        sub     ecx,edi                 ; calc # of bytes in _BSS segment
if DOS4G
        cmp     byte ptr _Extender,X_RATIONAL   ; if not Rational DOS extender
        jne     short zerobss           ; then zero whole BSS
        cmp     ecx,1000h               ; if size of BSS <= 4K
        jbe     short zerobss           ; then just zero it
        mov     ecx,1000h               ; only zero first 4K under Rational
endif
                                        ; DOS extender will zero rest of pages
zerobss:mov     dl,cl                   ; save bottom 2 bits of count in edx
        shr     ecx,2                   ; calc # of dwords
        sub     eax,eax                 ; zero the _BSS segment
        rep     stosd                   ; ...
        mov     cl,dl                   ; get bottom 2 bits of count
        and     cl,3                    ; ...
        rep     stosb                   ; ...

if HX
        pop eax
        xchg eax, _STACKLOW
else
        mov     eax,offset DGROUP:_end  ; cmd buffer pointed at by EAX
        add     eax,0FH
        and     al,0F0H
endif
        mov     _LpCmdLine,eax          ; save command line address
        mov     _LpPgmName,esi          ; save program name address
        mov     eax,0FFH                ; run all initalizers
        call    __InitRtns              ; call initializer routines
        sub     ebp,ebp                 ; ebp=0 indicate end of ebp chain
        call    __CMain
_cstart_ endp

;       don't touch AL in __exit, it has the return code

ifdef FC
EXITCC equ <fastcall>
else
EXITCC equ <>
endif
        public  EXITCC __exit

__exit  proc near EXITCC
ifdef __STACK__
        pop     eax                     ; get return code into eax
endif
        jmp     short   ok

        public  __do_exit_with_msg__

; input: ( char *msg, int rc )  always in registers

ifdef __JWASM__
__do_exit_with_msg__::
else
__do_exit_with_msg__:
endif
        push    edx                     ; save return code
        push    eax                     ; save address of msg
        mov     edx,offset ConsoleName
        mov     ax,03d01h               ; write-only access to screen
        int     021h
        mov     bx,ax                   ; get file handle
        pop     edx                     ; restore address of msg
        mov     esi,edx                 ; get address of msg
        cld                             ; make sure direction forward
L4:     lodsb                           ; get char
        cmp     al,0                    ; end of string?
        jne     L4                      ; no
        mov     ecx,esi                 ; calc length of string
        sub     ecx,edx                 ; . . .
        dec     ecx                     ; . . .
        mov     ah,040h                 ; write out the string
        int     021h                    ; . . .
        pop     eax                     ; restore return code
ok:
        push    eax                     ; save return code
        mov     eax,00H                 ; run finalizers
        mov     edx,FINI_PRIORITY_EXIT-1; less than exit
        call    __FiniRtns              ; call finializer routines
        pop     eax                     ; restore return code
        mov     ah,04cH                 ; DOS call to exit with return code
        int     021h                    ; back to DOS
__exit endp

        public  __GETDS
        align   4

__GETDS proc    near
@cpublic __GETDSStart_
__GETDSStart_ label near
        mov     ds,cs:__saved_DS        ; load saved DS value
        ret                             ; return

if HX
_DATA segment
endif
__saved_DS  dw  0                       ; DS save area for interrupt routines
if HX
_DATA ends
endif

@cpublic __GETDSEnd_

__GETDSEnd_ label near
__GETDS endp

_TEXT   ends

        end     _cstart_
