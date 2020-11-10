
;--- functions:
;--- _trace_s: display near16 string in cs:ip
;--- _stroutx ( worker behind @printf macro )

	option casemap:none
	option proc:private

if ?32BIT
@use16	textequ <use16>
	.386
else
	.286
@use16	textequ <>
endif

?COMPORT = 2	;2 COM#  for Int 14h debug msgs

_TEXT segment dword @use16 public 'CODE'
_TEXT ends
_DATA segment word @use16 public 'DATA'
_DATA ends
_BSS segment word @use16 public 'BSS'
tmpword	db 6 dup (?)		;word2ascii buffer
_BSS ends

	include ascii.inc
	include dpmildr.inc
	include trace.inc

DGROUP group _TEXT, _DATA, _BSS

_TEXT segment

;--- display string in cs:[ip]

_trace_s proc public		 ;_trace_s is used by @trace_s
	pushf
	push ds
	push cs
	pop ds
if ?32BIT
	push esi
	mov si,[esp+4+2+2]
	add word ptr [esp+4+2+2],2
	movzx esi,word ptr cs:[si]
	call _stroutESI  ;^ string in DS:ESI
	pop esi
else
	push bp
	mov bp,sp
	push bx
	mov bx,[bp+2+2+2]
	add word ptr [bp+2+2+2],2
	mov bx,cs:[bx]
	call stroutBX	;^ string in DS:BX
	pop bx
	pop bp
endif
	pop ds
	popf
	ret
_trace_s endp

if 0
;--- display a DWORD value on stack
;--- no register changes

_dwordout proc
if ?32BIT
	push [esp+4]
	call _wordout
	push [esp+2]
	call _wordout
else
	push bp
	mov bp,sp
	push [bp+6]
	call _wordout
	push [bp+4]
	call _wordout
	pop bp
endif
	ret 4
_dwordout endp

endif

;--- display a WORD value on stack
;--- no register changes

_wordout proc
	pusha
	mov bp,sp
	pushf
	push ds
	mov ds,cs:[wLdrDS]
if ?32BIT
	mov ax,[esp+16+3*2]
else
	mov ax,[bp+16+1*2]
endif
	mov di, offset tmpword
	mov bx, di
	call w_2_str
	mov byte ptr [di],0
	call stroutBX
	pop ds
	popf
	popa
	ret 2
_wordout endp

if ?32BIT

;--- display string in ds:esi
;--- modifies ESI and flags

_stroutESI proc uses ax

nextchar:
	lods byte ptr [esi]
	and al,al
	jz done
	cmp al,lf
	jnz @F
	mov al,cr
	call cs:tprintproc
	mov al,lf
@@:
	call cs:tprintproc
	jmp nextchar
done:
	ret
_stroutESI endp

endif	;?32BIT

@getwordfromstack macro reg
if ?32BIT
	mov reg,word ptr [ebp]
	add ebp,2
else
	mov reg,word ptr [bp]
	add bp,2
endif
endm

@getdwordfromstack macro reg
if ?32BIT
	mov reg,dword ptr [ebp]
	add ebp,4
else
	mov reg,dword ptr [bp]
	add bp,4
endif
endm

;--- printf emulation
;--- arguments are onto the stack
;--- all registers including flags preserved, stack cleared
;--- understands:
;--- %X  - 16-bit number
;--- %lX - 32-bit number
;--- %s  - near16 string, requires DS be set to DGROUP
;--- %S  - near16 string, will set DS to DGROUP temporarily
;--- %ls - far16 string
;--- %lS - near32 string, expects DS to be set

_stroutx proc public

if ?32BIT
	push ebp
	lea ebp,[esp+6]
else
	push bp
	mov bp,sp
endif
	pushf
ife ?32BIT
	add bp,4
endif
	cld
	push ax
	push bx
	push si
	@getwordfromstack si
nextitem:
	lods byte ptr cs:[si]
	and al,al
	jz done
	push offset nextitem
	cmp al,'%'
	jz special
	cmp al,lf
	jnz @F
	mov al,cr
	call cs:tprintproc
	mov al,lf
@@:
	jmp cs:tprintproc
special:
	mov bl,0
	lods byte ptr cs:[si]
	cmp al,'X'
	jz stroutx_X
	cmp al,'s'
	jz stroutx_s
	cmp al,'S'
	jz stroutx_S
	cmp al,'l'
	jnz @F
	inc bl
	lods byte ptr cs:[si]
	cmp al,'X'
	jz stroutx_lX
	cmp al,'s'
	jz stroutx_ls
if ?32BIT
	cmp al,'S'
	jz stroutx_lS
endif
@@:
	push ax
	mov al,'%'
	call cs:tprintproc
	pop ax
	call cs:tprintproc
	retn
stroutx_s:						;%s get near16 string
	@getwordfromstack bx
	call stroutBX
	retn
stroutx_S:						;%s get near16 string, DS will be set to DGROUP
	@getwordfromstack ax
	invoke string_out, ax
	retn
stroutx_ls:						;%ls display far16 string
	push ds
	@getwordfromstack ds
	@getwordfromstack bx
	call stroutBX
	pop ds
	retn
if ?32BIT
stroutx_lS:						;%lS display near32 string
	push esi
	@getdwordfromstack esi
	call _stroutESI
	pop esi
	retn
endif
stroutx_lX:						;%lX get 2 words
	@getwordfromstack bx
	@getwordfromstack ax
	push ax
	call _wordout
	push bx
	call _wordout
	retn
stroutx_X:						;%X get 1 word
	@getwordfromstack ax
	push ax
	call _wordout
	retn
done:
	pop si
if ?32BIT
	pop bx
	mov ax,[esp+2+2+4]	;get return address
	mov [ebp-2],ax
	sub ebp,2
	pop ax
	popf
	xchg ebp, [esp]
	pop esp
else
	mov bx,sp
	mov bx,ss:[bx+2+2+2+2]	;get return address
	mov [bp-2],bx
	sub bp,2
	mov bx,sp
	xchg bp,ss:[bx+2+2+2]
	pop bx
	pop ax
	popf
	pop sp
endif
	ret
_stroutx endp

_TEXT ends

end

