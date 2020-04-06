
	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:none
	option proc:private
	option dotname

	include winbase.inc
	include winuser.inc
	include duser32.inc
	include macros.inc

;--- these segment definitions will ensure that
;--- the constructor/destructor is called if g_csUser
;--- is used with statically linked duser32 code

.BASE$IU segment dword public 'DATA'
	dd InitUser
.BASE$IU ends
.BASE$XU segment dword public 'DATA'
	dd DeinitUser
.BASE$XU ends

	.data

g_csUser CRITICAL_SECTION <>

	.CODE

InitUser proc public                

	invoke InitializeCriticalSection, addr g_csUser
	ret
	align 4

InitUser endp

DeinitUser proc public

	invoke DeleteCriticalSection, addr g_csUser
	ret
	align 4

DeinitUser endp

	end

