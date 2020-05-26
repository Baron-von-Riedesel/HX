
;*** defines default stack + heap size
;*** may be overwritten by defining publics
;*** __STACKSIZE and __HEAPSIZE in the app directly

;*** if you want to use WIN32 emulation by DKRNL32S.LIB, you can
;*** set __HEAPSIZE to zero, because the emulator code will create
;*** its own heaps. Just use GetProcessHeap or HeapCreate API.

        .386
;		.MODEL SMALL, stdcall

		include jmppm32.inc

__STACKSIZE equ  80000h
__HEAPSIZE  equ  80000h

end

