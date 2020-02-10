
	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:none
	option proc:private

	include winbase.inc
	include wincon.inc
	include macros.inc
	include dkrnl32.inc

;--- except for bit 0 (ENABLE_PROCESSED_xxxPUT) these flags
;--- currently are global and both for STDIN and STDOUT.
;--- this doesnt matter cause the other flags arent used as of yet

	.DATA

g_consoleflags dd ENABLE_PROCESSED_INPUT or ENABLE_LINE_INPUT or ENABLE_ECHO_INPUT

;--- handles 0,1,2 are processed

g_bProcessed dd 7, 7 dup(0)

	end

