
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

TIBSEG segment use16
TIBSEG ends
	assume fs:TIBSEG	;declare FS=TIB a 16 bit segment (saves space)

	.DATA

?VERBOSE	equ 0	;1=display Set/GetLastError in debug version
?FASTSET	equ 1

	.CODE

GetLastError proc public

;	invoke _GetCurrentThread
;	mov eax, [eax].THREAD.errno
	mov eax,fs:[?LERROROFS]
if ?VERBOSE
	@strace <"GetLastError()=", eax>
endif
	ret
	align 4
GetLastError endp

;--- void SetLastError(int error);

if ?FASTSET
option prologue:none
endif

;--- dont modify EDX!
;--- CygWin assumes edx isn't changed by SetLastError()!!!
;--- and CreateFile() expects EAX to be unchanged!

SetLastError proc public errcode:dword

if ?FASTSET
	pop ecx
	pop dword ptr fs:[?LERROROFS]
	jmp ecx
else
	mov ecx,errcode
	mov fs:[?LERROROFS], ecx
  if ?VERBOSE
	@strace <[ebp+4], "SetLastError(", ecx, ")=void">
  endif
	ret
endif
	align 4

SetLastError endp

	end
