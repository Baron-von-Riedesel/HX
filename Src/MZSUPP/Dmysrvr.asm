
;*** dummy loadserver proc
;*** include this module in link step as object module if no search for
;*** DPMI server HDPMI32 should be done.
;*** Such modules only work if a DPMI server is already running

        .386
;		.model small, stdcall
        
        include jmppm32.inc

_TEXT16  segment use16 word public '16_CODE'


loadserver  proc stdcall
        ret
loadserver endp

_TEXT16 ends

        end

