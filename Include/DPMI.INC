
;*** definitions DOS Protected Mode Interface ***

RMCS    struct          ;real mode call structure
union
rEDI    dd ?            ;+0
rDI		dw ?
ends
union
rESI    dd ?            ;+4
rSI		dw ?
ends
union
rEBP    dd ?            ;+8
rBP		dw ?
ends
RESERVE dd ?            ;+12
union
rEBX    dd ?            ;+16
rBX     dw ?
ends
union
rEDX    dd ?            ;+20
rDX     dw ?
ends
union
rECX    dd ?            ;+24
rCX		dw ?
ends
union
rEAX    dd ?            ;+28
rAX		dw ?
ends
rFlags  dw ?            ;+32
rES     dw ?            ;+34
rDS     dw ?            ;+36
rFS     dw ?            ;+38    
rGS     dw ?            ;+40  
union
rCSIP	dd ?            ;+42
struct
rIP     dw ?
rCS     dw ?
ends
ends
union
rSSSP	dd ?            ;+46
struct
rSP     dw ?
rSS     dw ?
ends
ends
RMCS    ends

MEMINFO struct
maxBlock      dd ?            ;0	;in bytes
freeUnlocked  dd ?            ;4	;pages (max unlocked allocation)
maxLockable   dd ?            ;8	;pages (max locked allocation)
totalAdrSpace dd ?            ;12
unlocked      dd ?            ;16	;total unlocked (=virtual)
freePhys      dd ?            ;20
totalPhys     dd ?            ;24
freeAdrSpace  dd ?            ;28
swapFile      dd ?            ;32
res           db 12 dup (?)
MEMINFO ends

MEMINFOX struct	;used by int 31h, ax=50bh
dwTotalPhys   dd ?
dwTotalHost   dd ?
dwFreeHost    dd ?
dwTotalVM     dd ?
dwFreeVM      dd ?
dwTotalClient dd ?
dwFreeClient  dd ?
dwTotalLocked dd ?
dwMaxLocked   dd ?
dwHighestAddr dd ?
dwLargestBlock dd ?
dwMinSize     dd ?
dwAllocUnit   dd ?
MEMINFOX ends

EXCFRAME struct
_dpmieip	dd ?
_dpmics		dd ?
errorcode	dd ?
_eip		dd ?
_cs			dd ?
_eflags		dd ?
_esp		dd ?
_ss			dd ?
EXCFRAME ends

EXCFRAME16 struct
_dpmieip	dw ?
_dpmics		dw ?
errorcode	dw ?
_eip		dw ?
_cs			dw ?
_eflags		dw ?
_esp		dw ?
_ss			dw ?
EXCFRAME16 ends

EXCFRAMEV10 struct
	EXCFRAME <?>
rDPMIIPx	dd ?	;+20h
rDPMICSx	dd ?	;+24h
rErrx		dd ?	;+28h	;filled with dr6 if exc 01
rEIPx		dd ?	;+2Ch
rCSx		dw ?	;+30h
rInfoBits	dw ?	;+32h
rEFLx		dd ?	;+34h
rESPx		dd ?	;+38h
rSSx		dd ?	;+3Ch
rESx		dd ?	;+40h
rDSx		dd ?	;+44h
rFSx		dd ?	;+48h
rGSx		dd ?	;+4Ch
rCR2		dd ?	;+50h	;exc 0E only
rPTE		dd ?	;+54h	;exc 0E only, bits 0-8 of PTE only
EXCFRAMEV10 ends

