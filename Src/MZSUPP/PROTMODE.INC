
;*** struktur segment descriptor ***

desc    struct          ;8 byte segment deskriptor
limit   dw ?            ;+0 limit[0..15]
A0015   dw ?            ;+2 basis addr[0..15]
A1623   db ?            ;+4 basis addr[16..23]
attrib  db ?            ;+5 attribute
                        ;bits 0-3: type
                        ;bit    4: 1=memory segments,0=gates
                        ;bit  5-6: descriptor privilege level
                        ;bit    7: Present bit (1=present)
lim_gr  db ?            ;+6 bits 0-3:limit[16..19] (80386)
                        ;bit    4:AVL = available to software
                        ;bit    5:0
                        ;bit    6:default size (0=16 Bit,1=32 Bit)
                        ;bit    7:granularity (80386)
A2431   db ?            ;+7 adresse [24..31]  (80386)
desc    ends

gate    struct
ofs     dw ?
sel     dw ?
attrib  dw ?
ofs32   dw ?
gate    ends

;*** type (memory segments):
;*** bit 3 = 1 -> CODE,0 -> DATA
;*** bit 2 = 1 -> DATA:expand down,CODE:conforming
;*** bit 1 = 1 -> DATA:writable,CODE:readable
;*** bit 0 = 1 -> accessed

;*** 4G 16-Bit-Code-Segment -> <0ffffh,0,0,9fh,08fh,0>
;*** 4G 32-Bit-Code-Segment -> <0ffffh,0,0,9fh,0cfh,0>
;*** 4G 16-Bit-Data-Segment -> <0ffffh,0,0,93h,08fh,0>

;*** type (system segments (TSS) ***
;*** bit 3 = 1 -> 386
;*** bit 2 = 1 -> Gate
;*** bit 1 = 1 ->
;*** bit 0 = 1 ->
;also 7/F -> trap gate
;     6/E -> Interrupt gate
;     4/C -> Call gate

@AllocDescriptor  macro addr,laenge
@defext AllocDescriptor,far
                @pushd addr
                @pushw laenge
                call AllocDescriptor
                endm

