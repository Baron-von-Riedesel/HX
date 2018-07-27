
intr31 proto near		; IDT handler int 31
intr31_ proto near		; int 31 default handler

;--- EBP points to I31FR1 if AH==0 or AH==2

I31FR1 struct
		dd ?	;jump vector
dwEbx	dd ?
		dd ?	;return address
union
dwDS	dd ?	;client DS (is used internally)
wDS		dw ?
ends
I31FR1 ends

;--- ah=00

allocsel proto near			;ax=0000
freesel proto near			;ax=0001
allocrmsel proto near		;ax=0002
allocxsel proto near		;ax=0002 helper
getincvalue proto near		;ax=0003
locksel proto near			;ax=0004 (dummy)
unlocksel proto near		;ax=0005 (dummy)
getbase proto near			;ax=0006
setbase proto near			;ax=0007
setlimit proto near			;ax=0008
setaccrights proto near		;ax=0009
getcsalias proto near		;ax=000A
getdesc proto near			;ax=000B
setdesc proto near			;ax=000C
allocspecific proto near	;ax=000D
getmultdesc proto near		;ax=000E
setmultdesc proto near		;ax=000F

checkrmsel proto near
setrmsel proto near	 		;called by setpspsel

ife ?32BIT
allocselx proto near
freeselx proto near
endif

;--- ah=01

freedos proto near
resizedos proto near
allocdos proto near

;--- ah=02

getrmivec proto near
setrmivec proto near 
getpmevec proto near 
setpmevec proto near 
getpmivec proto near 
setpmivec proto near 
if ?DPMI10EXX
geteexcp proto near 
geteexcr proto near 
seteexcp proto near 
seteexcr proto near 
endif

if ?CHECKIRQRM
checkirqrm proto near
endif

;--- ah=03

simrmint proto near
callrmiret proto near
callrmretf proto near
allocrmcb proto near
freermcb proto near
getsraddr proto near
getrmsa proto near

_pm2rm proto near
_retcb proto near
_srtask proto near

;--- ah=05

getmeminfo proto near			;0500
allocmem proto near				;0501
freemem proto near				;0502
resizemem proto near			;0503
if ?DPMI10
allocmemx proto near			;0504
resizememx proto near			;0505
getpageattr proto near			;0506
setpageattr proto near			;0507
if ?DPMI10EX
mapphysx proto near 			;0508
mapdos proto near				;0509
getmemsize proto near			;050A
getmeminfox proto near			;050B
endif
endif

;--- ah=08

mapphysregion proto near
unmapphysregion proto near

;--- ah=0B

allocwatchp proto near
clearwatchp proto near
getwatchpstate proto near
resetwatchpstate proto near

;--- ah=0E

i31f0E proto near

;--- others

;_getspecaddrspace proto near ;alloc specific address space
_freeclientmemory proto near 
ife ?32BIT
_AllocMem proto near
endif
;_AllocMemEx proto near    

if ?DPMI10
_TEXT32 segment dword use32 public 'CODE'
externdef dpmi5functions:byte
_TEXT32 ends
endif

