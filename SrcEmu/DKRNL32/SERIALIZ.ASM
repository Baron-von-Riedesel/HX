
	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:none

	include winbase.inc
	include macros.inc
	include dkrnl32.inc

if ?USERTC
?MASKRTC	equ 1
else
?MASKRTC	equ 0
endif

	.CODE

;--- dont change edx, ebx, esi, edi

;--- using CLI/STI may be significantly faster if IOPL=3
;--- but even if IOPL=0 it seems to be faster, at least for win9x, winxp

;--- this code is no real substitute for
;--- "pushfd, cli" 
;--- "pop reg, test reg+1,2, jz @F, sti, @@:"
;--- because it doesnt save the previous interrupt state!

EnterSerialization proc
	test g_bDispatchFlags,FTI_INIT		;multiple threads?
	jnz @F
	ret
@@:
if ?USECLISTI
	cli
else
	push eax
  if ?MASKRTC
	in al,0A1h
	or al, 1
	out 0A1h,al
  else
	mov ax,0900h
	int 31h
  endif
	pop eax
endif
	ret
	align 4
EnterSerialization endp

LeaveSerialization proc

	test g_bDispatchFlags,FTI_INIT
	jnz @F
	ret
@@:
if ?USECLISTI
	sti
else
	push eax
  if ?MASKRTC
	in al,0A1h
	and al,not 1
	out 0A1h,al
  else
	mov ax,0901h
	int 31h
  endif
	pop eax
endif
	ret
	align 4
LeaveSerialization endp

	end

