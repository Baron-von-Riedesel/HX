
if _TRACEUSED_

;--- _putchr: display char in AL
;--- _trace_s: display string in cs:ip
;--- _trace_s_bx: display string in E/BX
;--- _dwordout
;--- _wordout
;--- _modnameout
;--- _stroutESI

_USESTROUT_ = 1	;1 1=use string output for trace messages

_TRACE_ = 1

ife _USESTROUT_
;--- dont use @dbgoutstr, output each character in _putchr
_putchr proc
		cmp 	al,lf
		jnz 	@F
		mov 	al,cr
		@dbgout
		mov 	al,lf
@@:
		@dbgout
		ret
_putchr endp        
endif

;--- display string in ds:(e)bx

_trace_s_bx proc public
		pusha
		push	es
		pushf
if _USESTROUT_
  if ?32BIT
		push	esi
		mov 	esi,ebx
  else
		mov 	si,bx
  endif
		push	ds
		pop		es		;was it es:si?
		@dbgoutstr		;display ds:(e)si
  if ?32BIT
		pop		esi
  endif
else
nextchar:
		mov 	al,[bx]	;should this be [ebx] for 32bit?
		and 	al,al
		jz		done
		call	_putchr
		inc 	bx		;should this be ebx for 32bit?
		jmp 	nextchar
endif
done:
		popf
		pop 	es
		popa
		ret
_trace_s_bx	endp

;--- display string in cs:[ip]

_trace_s proc public		 ;_trace_s is used by @trace_s
		@pusha
if ?32BIT
		push	es
		pushf
		mov 	si,[esp+8*4+4]
		add 	word ptr [esp+8*4+4],2
		movzx 	esi,si
else
		mov 	bp,sp
		push	es
		pushf
		mov 	si,[bp+16]
		add 	word ptr [bp+16],2
endif
		mov 	si,cs:[si]
if _USESTROUT_
		push	ds
		push	cs
		pop		ds
		push	cs
		pop		es
  ife ?32BIT
        mov     bx, si  ;since 16 bit works with BX instead of SI
  endif
		@dbgoutstr		;ds:(e)si
		pop 	ds
else
nextchar:
		cs:
		lodsb
		and 	al,al
		jz		done
		call	_putchr
		jmp 	nextchar
endif
done:
		popf
		pop 	es
		@popa
		ret
_trace_s endp

_dwordout proc public
if ?32BIT
		push	[esp+4]
		call	_wordout
		push	[esp+2]
		call	_wordout
else
		push	bp
		mov 	bp,sp
		push	[bp+6]
		call	_wordout
		push	[bp+4]
		call	_wordout
		pop 	bp
endif
		ret 	4
_dwordout endp

_wordout proc public
		pusha
		mov 	bp,sp
		pushf
		push	ds
		mov 	ds,cs:[wLdrDS]
if ?32BIT
		mov 	ax,[esp+22]
else
		mov 	ax,[bp+18]
endif
		mov		di,offset tmpword
		call	WORDOUT
		mov 	byte ptr [di],0
if ?32BIT
		push	ebx
		mov 	ebx,offset tmpword
else
		mov 	bx,offset tmpword
endif
		call	_trace_s_bx
if ?32BIT
		pop		ebx
endif
		pop 	ds
		popf
		popa
		ret 	2
_wordout endp

;*** display name of current module (in es)

if ?32BIT
_modnameout proc near uses ds ebx
else
_modnameout proc near uses ds bx
endif
		push	es
		pop 	ds
if ?32BIT
		mov 	ebx,offset NEHDR.szModPath
else
		mov 	bx,offset NEHDR.szModPath
endif
		call	_trace_s_bx
		ret
_modnameout endp

if ?32BIT

;--- display string in ds:esi

_stroutESI proc uses ax dx

nextchar:
		lods	byte ptr [esi]
		and 	al,al
		jz		done
		cmp 	al,lf
		jnz 	@F
		mov 	al,cr
if _DBGOUT_ or	_TRACE_ or ?DEBUG
		@dbgout
else
		call	printchar
endif
		mov 	al,lf
@@:
if _DBGOUT_ or	_TRACE_ or ?DEBUG
		@dbgout
else
		call	printchar
endif
		jmp 	nextchar
done:
		ret
_stroutESI endp

endif		;?32BIT

_BSS	segment
tmpword	db 6 dup (?)		;word2ascii buffer
_BSS	ends

endif		;_TRACEUSED_

