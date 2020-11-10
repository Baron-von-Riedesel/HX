
;*** trace macros and equates

if _TRACE_
_TEXT segment
_trace_s		proto near
_stroutx		proto near
_TEXT ends
endif

;********** Macros **********

; @tracewait: wait for a keypress

@tracewait macro
if _TRACE_
	pusha
	pushf
	mov ah,10h
	int 16h
	popf
	popa
endif
endm

;--- @trace_s: define and display a string

@trace_s macro xx
if _TRACE_
	call _trace_s
	dw CStr(<xx>)
endif
endm

; @printf: print formated strings
; understands %X, %lX, %s, %S, %ls, %lS
; %s  = near16 string, DS must be preset
; %S  = like %s, inits DS to DGROUP internally
; %ls = far16 string
; %lS = near32 string, DS must be preset

@printf macro xx,a1,a2,a3,a4,a5,a6,a7,a8
if _TRACE_
	ifnb <a8>
	  echo too many parameters for @printf
	  .err1
	endif
	for arg,<a7,a6,a5,a4,a3,a2,a1>
	 ifnb <arg>
	  push arg
	 endif
	endm
	push CStr(<xx>)
	call _stroutx
endif
	endm

