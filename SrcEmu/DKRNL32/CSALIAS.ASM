
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

	.DATA

;--- this contains a valid data selector as CS alias
;--- used by interrupt routines

g_csalias dd 0
ife ?FLAT
g_flatsel dd 0	;a true FLAT selector for non-zero-based models
endif

	END

