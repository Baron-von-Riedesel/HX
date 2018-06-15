
;***
;except.inc - definitions for exception handling
;
;Purpose:
;       Structure and constant definitions used by exception handling code.
;
;*******************************************************************************

ifndef EXCEPTION_RECORD	;usually defined in WINNT.INC

EXCEPTION_MAXIMUM_PARAMETERS         equ 15

EXCEPTION_RECORD STRUCT
  ExceptionCode         DWORD      ?
  ExceptionFlags        DWORD      ?
  ExceptionRecord       DWORD      ?
  ExceptionAddress      DWORD      ?
  NumberParameters      DWORD      ?
  ExceptionInformation  DWORD EXCEPTION_MAXIMUM_PARAMETERS dup(?)
EXCEPTION_RECORD ENDS
endif

EXCEPTION_EXECUTE_HANDLER            equ 1
EXCEPTION_CONTINUE_SEARCH            equ 0
EXCEPTION_CONTINUE_EXECUTION         equ -1

; structure used by SEH support function and intrinsics. the information
; passed by the OS exception dispatcher is repackaged in this form by the
; runtime (_except_handler()). returned by _exception_info()

ifndef EXCEPTION_POINTERS	;usually defined in WINNT.INC

PEXCEPTION_RECORD typedef ptr EXCEPTION_RECORD
PCONTEXT typedef ptr CONTEXT

EXCEPTION_POINTERS struct
ExceptionRecord	PEXCEPTION_RECORD ?
ContextRecord	PCONTEXT ?
EXCEPTION_POINTERS ends
endif

_except_handler typedef proto c  :ptr EXCEPTION_RECORD, :ptr , :ptr CONTEXT, :ptr 
LPEXCEPTHANDLER typedef ptr _except_handler


; exception registration record structure.

EXCEPTION_REGISTRATION struct
prev_structure          dd      ?	;WIN32
ExceptionHandler        LPEXCEPTHANDLER ?	;WIN32
ExceptionFilter         dd      ?	;CRT
FilterFrame             dd      ?	;CRT
PExceptionInfoPtrs      dd      ?	;CRT
EXCEPTION_REGISTRATION ends

; size of exception registration record in double words

DWORDS_IN_XREGREC       equ     5

; setjmp/longjmp buffer (i.e., structure underlying jmp_buf array)

_JMP_BUF	struct
ebpsave		dd	?
ebxsave		dd	?
edisave		dd	?
esisave		dd	?
espsave		dd	?
retsave		dd	?
xcptsave	dd	?
_JMP_BUF	ends


; exceptions corresponding to C runtime errors (these are explicitly
; referenced in the startup code)

_XCPT_UNABLE_TO_GROW_STACK      equ             080010001h
_XCPT_INTEGER_DIVIDE_BY_ZERO    equ             0C000009Bh
_XCPT_NONCONTINUABLE_EXCEPTION  equ             0C0000024h
_XCPT_INVALID_DISPOSITION       equ             0C0000025h
_XCPT_SIGABRT                   equ             020000001h


;--- settings in ExceptionFlags

;_EH_NONCONTINUABLE	equ 1
_EH_UNWINDING		equ 2
_EH_EXIT_UNWIND		equ 4
;_EH_STACK_INVALID	equ 8

UNWIND          equ     _EH_UNWINDING OR _EH_EXIT_UNWIND


;--- EXCEPTION_DISPOSITION enum
;--- return values to the exception dispatcher

_XCPT_CONTINUE_EXECUTION	equ 000000000h	;=ExceptionContinueExecution
_XCPT_CONTINUE_SEARCH		equ 000000001h	;=ExceptionContinueSearch

