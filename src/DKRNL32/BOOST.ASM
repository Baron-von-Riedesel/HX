
;*** boostproc: boostproc sleeps as long as no threads are used

	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option proc:private
	option casemap:none

	include winbase.inc
	include dkrnl32.inc

	.DATA

g_dwBoostProc dd offset _ret

	.CODE

_ret:   ret

	end
