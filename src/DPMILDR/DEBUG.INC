
;*** debug macros and equates

; @dbgout    : display char in AL
; @dbgoutstr : display string in DS:ESI / DS:BX
; @trace_s   : define and display string
; @trace_sx  : display an already defined string
; @trace_w   : display a word
; @trace_d   : display a dword


;-- if neither 41 nor 14 are set, output is to DOS

ifndef ?USEINT41
?USEINT41	 = 1	;1=use Int 41h for debug output
endif
?USEINT14	 = 0	;1=use Int 14h for debug output

_DBGOUT_	 = 0	;1=route normal msgs to debug terminal

;-- if std messages are to be displayed on debug terminal
;-- ensure that either 41 or 14 is active

if _DBGOUT_
ife ?USEINT14
?USEINT41	 = 1
endif
endif

?TRAPINT41 equ ?USEINT41

@condbrk macro what
ifndef what
what equ 0
endif	
endm

	@condbrk _INT01PGMENTRY_	;1=int 01 on program entry (obsolete)
	@condbrk _INT03PGMEXIT_		;0 1=int 03 on program termination
	@condbrk _INT03RETEXEC_		;0 1=int 03 after int 21h, ax=4B00h
	@condbrk _INT03NAMEIMP_		;0 1=int 03 on a "reference by name"
	@condbrk _INT03JMPPM_		;0 1=int 03 after initial switch to protected mode
	@condbrk _INT03REALLOC_		;0 1=int 03 on realloc memory block
	@condbrk _TESTIMPORT_		;0 1=display debug msg on relocation fixups

_PORT_		 = 2	;2 COM#  for Int 14h debug msgs

;********** Macros **********

@tracejmp macro x
        if _TRACE_
        jmp short x
        endif
        endm

@int3   macro x	;conditional break
if x
        int 3
endif
        endm

;--- display char in AL to debugger

@dbgout macro
if ?USEINT14
	push	dx
        mov     ah,01
        mov     dx,_PORT_ - 1
        int     14h
        pop	dx
elseif ?USEINT41
	push	dx
	mov	dl,al
        xor     ax,ax
        int     41h
        pop	dx
else
	call	printchar
endif
        endm

;--- display string in ESI/BX

@dbgoutstr macro
  if ?32BIT
        call    _stroutESI  ;^ string in DS:ESI
  else
        call    stroutBX	;^ string in DS:BX
  endif
        endm

;--- define and display a string

@trace_s macro xx
local xxxx
if _TRACE_
_TRACEUSED_ = 1
  ifidni <xx>,<lf>
   xxxx equ szLF
  else
CCONST  segment
   xxxx   db xx
          db 0
CCONST  ends
  endif
_trace_s proto near		;used if trace on
        call _trace_s
        dw   offset xxxx
endif
        endm

;--- display a 16-bit string

@trace_sx macro xx
local xxxx
if _TRACE_
_TRACEUSED_ = 1
		push bx
        mov  bx,xx
        call stroutBX
        pop  bx
endif
        endm

@tracewait macro
if _TRACE_
        pusha
        pushf
        mov     ah,10h
        int     16h
        popf
        popa
endif
        endm

@trace_w macro xx
if _TRACE_
_TRACEUSED_ = 1
        push    xx
        call    _wordout
endif
        endm

@trace_d macro xx
if _TRACE_
_TRACEUSED_ = 1
        push    xx
        call    _dwordout
endif
        endm

@checkreturn macro xx
if _TRACE_
        push    bp
        mov     bp,sp
        @trace_s <"return addr=">
        @trace_w [bp+2]
      ifnb <xx>
        @trace_s <" ",xx>
      endif
        @trace_s lf
        pop     bp
endif
        endm

@tracemodule macro
if _TRACE_
_TRACEUSED_ = 1
        call    _modnameout
endif
        endm

@waitkey macro key
local x1, x2
		push ax
		pushf
        cli
        nop
x1:        
        in al,60h
        cmp al,key
        jnz x1
        pop ax
        test ah,2
        jz x2
        sti
x2:
		pop ax
        endm

