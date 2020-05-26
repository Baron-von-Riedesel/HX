
;--- this is the real mode MZ stack, just used in the very beginning
;--- but only if switch ?NORELOCS is set (which is NOT the case as default)

?DEFSTKSIZ  = 180h

        .386

;        .MODEL SMALL, stdcall

		include jmppm32.inc

STACK   segment para  stack 'STACK'
        db ?DEFSTKSIZ dup (?)
STACK   ends

DGROUP  group STACK


end

