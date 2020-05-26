
;*** dont copy executable into extended memory   ***

        .386

        include jmppm32.inc

_TEXT32	segment dword public 'CODE'

_movehigh proc stdcall
		stc
        ret
_movehigh endp

_TEXT32	ends

        end

