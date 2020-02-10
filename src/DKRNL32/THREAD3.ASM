
;--- thread code has been splitted to avoid large
;--- portions included in MZ binaries which don't use threads at all
;--- this code is directly called from RTC IRQ proc

	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:none
	option proc:private

	include winbase.inc
	include dkrnl32.inc
	include macros.inc

	.DATA

if ?DIRECTDISP
	public g_dwDispProc
g_dwDispProc dd offset stddispproc
endif

g_bDispReq	db 0

	.CODE

;--- this code is called by the RTC timer if it detects
;--- the special dispatch timer event
;--- if DOS mutex is free, set trace flag directly in the
;--- IRET32 stack frame!

_DispatchRequest proc public 
	test cs:g_bDispReq,2		;avoid reentrancy problems
	jnz exit
	push ds
	mov ds,cs:g_csalias
	or g_bDispReq,1
	pop ds
if ?DIRECTDISP
	jmp cs:[g_dwDispProc]
endif
stddispproc::
;----- dispatch has to be done throu exception 01
;----- this works only if in protected mode,
;----- so test the dos mutex and if owned, dont set the trace flag.

	push ebp
if ?USEINDOS
	mov ebp,cs:[g_indosaddr]
  ife ?FLAT
	push @flat
	mov @flat,cs:[g_flatsel]
	cmp byte ptr @flat:[ebp],0
	pop @flat
  else
	cmp byte ptr cs:[ebp],0
  endif
	jnz dispdone
endif
	mov ebp,ss
	lar ebp,ebp
	test ebp,400000h
	mov ebp,esp
	jnz @F
	movzx ebp,bp
@@:
	or byte ptr [ebp+4].IRETDS.rEflags+1,1  ;set trace flag
dispdone:
	pop ebp
exit:
	sti
	@iret
	align 4
_DispatchRequest endp

	end
