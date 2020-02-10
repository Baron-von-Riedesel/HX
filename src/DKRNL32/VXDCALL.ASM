
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

	.CODE

;--- these are exports 0-8 in dkrnl32
;--- they are meant to call out to a VxD in win9x

VxDCall0 proc public dwId:dword
VxDCall0 endp
VxDCall1 proc public dwId:dword, p1:dword
VxDCall1 endp
VxDCall2 proc public dwId:dword, p1:dword, p2:dword
VxDCall2 endp
VxDCall3 proc public dwId:dword, p1:dword, p2:dword, p3:dword
VxDCall3 endp
VxDCall4 proc public dwId:dword, p1:dword, p2:dword, p3:dword, p4:dword
VxDCall4 endp
VxDCall5 proc public dwId:dword, p1:dword, p2:dword, p3:dword, p4:dword, p5:dword
VxDCall5 endp
VxDCall6 proc public dwId:dword, p1:dword, p2:dword, p3:dword, p4:dword, p5:dword, p6:dword
VxDCall6 endp
VxDCall7 proc public dwId:dword, p1:dword, p2:dword, p3:dword, p4:dword, p5:dword, p6:dword, p7:dword
VxDCall7 endp
VxDCall8 proc public dwId:dword, p1:dword, p2:dword, p3:dword, p4:dword, p5:dword, p6:dword, p7:dword, p8:dword
VxDCall8 endp
	int 3
	ret

	END

