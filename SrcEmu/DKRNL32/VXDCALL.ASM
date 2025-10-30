
	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:none
	option proc:private

;	include winbase.inc
;	include dkrnl32.inc
;	include macros.inc

	.CODE

;--- these are exports 0-8 in dkrnl32
;--- they are meant to call out to a VxD in win9x

	option prologue:none
	option epilogue:none
VxDCall0 proc public dwId:dword
	int 3
	ret 1*4
VxDCall0 endp
VxDCall1 proc public dwId:dword, p1:dword
	int 3
	ret 2*4
VxDCall1 endp
VxDCall2 proc public dwId:dword, p1:dword, p2:dword
	int 3
	ret 3*4
VxDCall2 endp
VxDCall3 proc public dwId:dword, p1:dword, p2:dword, p3:dword
	int 3
	ret 4*4
VxDCall3 endp
VxDCall4 proc public dwId:dword, p1:dword, p2:dword, p3:dword, p4:dword
	int 3
	ret 5*4
VxDCall4 endp
VxDCall5 proc public dwId:dword, p1:dword, p2:dword, p3:dword, p4:dword, p5:dword
	int 3
	ret 6*4
VxDCall5 endp
VxDCall6 proc public dwId:dword, p1:dword, p2:dword, p3:dword, p4:dword, p5:dword, p6:dword
	int 3
	ret 7*4
VxDCall6 endp
VxDCall7 proc public dwId:dword, p1:dword, p2:dword, p3:dword, p4:dword, p5:dword, p6:dword, p7:dword
	int 3
	ret 8*4
VxDCall7 endp
VxDCall8 proc public dwId:dword, p1:dword, p2:dword, p3:dword, p4:dword, p5:dword, p6:dword, p7:dword, p8:dword
	int 3
	ret 9*4
VxDCall8 endp

	END

