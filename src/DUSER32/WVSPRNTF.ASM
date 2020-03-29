
        .386
if ?FLAT
		.MODEL FLAT, stdcall
else        
        .MODEL SMALL, stdcall
endif        
		option casemap:none
        option proc:private

        include winbase.inc
        include macros.inc

?DIRECT	equ 1

;--- the vsprintf used is type stdcall! 
;--- this will avoid that is is mistakenly used
;--- instead of the standard CRT vsprintf proc

        .CODE

vsprintf proto stdcall a1:dword, a2:dword, a3:dword		

if ?DIRECT
		option prologue:none
endif   

wvsprintfA proc public a1:ptr byte, a2:ptr byte, a3:ptr

if ?DIRECT
        jmp vsprintf
else    
        invoke vsprintf, a1, a2, a3
		@strace <"wvsprintfA()">
		ret
endif   

wvsprintfA endp


        end

