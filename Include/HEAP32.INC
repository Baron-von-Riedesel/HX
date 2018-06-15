
;
; --- Heap descriptor
;

HEAPDESC  struct
    mutex           dd  ?   ; heap mutex
    flags           dd  ?   ; flags
    pNextRegion     dd  ?   ; heap has more than 1 region
    start           dd  ?   ; offset of first heap entry
    rover           dd  ?   ; rover offset
    dwSize          dd  ?   ; uncommitted size of current region
    last            dd  ?   ; offset to end-of-heap marker
HEAPDESC ends

;
; flags bits
;

;_HEAP_NO_SERIALIZE equ    01h           ; same as HEAP_NO_SERIALIZE
;_HEAP_GROWABLE     equ    02h           ; same as HEAP_GROWABLE
_HEAP_GROWING      equ    08h           ; heap is currently growing

;
; --- General Use Heap Constants ---
;

_HEAP_END       equ     0FFFFFFFEh      ; End-of-heap flag
_HEAP_COALESCE  equ     0FFFFFFFEh      ; Coalesce segment value
_HEAP_GROWSEG   equ     8000h           ; Default (32K) heap seg growth increment
_HEAP_MAXREQ    equ     0FFFFFFFCh - (size HEAPDESC)  ; Max heap request size
_HEAP_MINSEG    equ     ((size HEAPDESC) + 4) ; Min size heap segment


