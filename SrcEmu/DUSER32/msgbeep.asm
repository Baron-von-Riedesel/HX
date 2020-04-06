
		.386
if ?FLAT
		.MODEL FLAT, stdcall
else
		.MODEL SMALL, stdcall
endif
		option casemap:none
        option proc:private

		include winbase.inc
		include winuser.inc
		include wincon.inc
        include macros.inc
        include duser32.inc

		.code

MessageBeep proc public dwType:DWORD
		invoke Beep,800,20
		@strace	<"MessageBeep(", dwType, ")=", eax>
		ret
        align 4
MessageBeep endp

		end
        
