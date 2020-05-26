
;--- this routine provides for the application being
;--- moved into extended memory. To avoid this,
;--- define public __pMoveHigh in your app like:
;--- public __pMoveHigh
;--- __pMoveHigh dd 0

        .386
;        .MODEL SMALL, stdcall

		include jmppm32.inc

        public stdcall __pMoveHigh

_TEXT32	segment dword public 'CODE'
_movehigh proto stdcall
_TEXT32	ends

DGROUP	group _TEXT32

_DATA	segment dword public 'DATA'

__pMoveHigh  dd  offset DGROUP:_movehigh

_DATA	ends

end

