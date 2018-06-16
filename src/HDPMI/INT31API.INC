
@proto intr31             ; IDT handler int 31
@proto intr31_            ; int 31 default handler

;--- EBP points to I31FR1 if AH==0 or AH==2

I31FR1 struct
         	dd ?	;jump vector
dwEbx		dd ?
			dd ?	;return address
union       
dwDS		dd ?	;client DS (is used internally)
wDS			dw ?
ends
I31FR1 ends

;--- ah=00

@proto allocsel     		;ax=0000
@proto freesel      		;ax=0001
@proto allocrmsel   		;ax=0002
@proto allocxsel    		;ax=0002 helper
@proto getincvalue  		;ax=0003
@proto locksel      		;ax=0004 (dummy)
@proto unlocksel    		;ax=0005 (dummy)
@proto getbase      		;ax=0006
@proto setbase      		;ax=0007
@proto setlimit     		;ax=0008
@proto setaccrights 		;ax=0009
@proto getcsalias   		;ax=000A
@proto getdesc      		;ax=000B
@proto setdesc      		;ax=000C
@proto allocspecific 		;ax=000D
@proto getmultdesc	 		;ax=000E
@proto setmultdesc	 		;ax=000F

@proto checkrmsel   
@proto setrmsel     	 	;called by setpspsel

ife ?32BIT
@proto allocselx
@proto freeselx
endif

;--- ah=01

@proto freedos
@proto resizedos
@proto allocdos

;--- ah=02

@proto getrmivec 
@proto setrmivec 
@proto getpmevec 
@proto setpmevec 
@proto getpmivec 
@proto setpmivec 
if ?DPMI10EXX
@proto geteexcp 
@proto geteexcr 
@proto seteexcp 
@proto seteexcr 
endif

if ?CHECKIRQRM
@proto checkirqrm
endif

;--- ah=03

@proto simrmint   
@proto callrmiret 
@proto callrmretf 
@proto allocrmcb    
@proto freermcb     
@proto getsraddr  
@proto getrmsa    

@proto _pm2rm  
@proto _retcb  
@proto _srtask 

;--- ah=05

@proto getmeminfo			;0500
@proto allocmem				;0501
@proto freemem				;0502
@proto resizemem			;0503
if ?DPMI10
@proto allocmemx       		;0504
@proto resizememx      		;0505
@proto getpageattr	   		;0506
@proto setpageattr     		;0507
if ?DPMI10EX
@proto mapphysx        		;0508
@proto mapdos          		;0509
@proto getmemsize      		;050A
@proto getmeminfox     		;050B
endif
endif

;--- ah=08

@proto mapphysregion
@proto unmapphysregion

;--- ah=0B

@proto allocwatch
@proto clearwatch
@proto getwatchstate
@proto resetwatchstate

;--- ah=0E

@proto i31f0E

;--- others

;@proto _getspecaddrspace ;alloc specific address space
@proto _freeclientmemory 
ife ?32BIT
@proto _AllocMem		
endif
;@proto _AllocMemEx		

if ?DPMI10
_TEXT32 segment dword use32 public 'CODE'
externdef   dpmi5functions:byte
_TEXT32	ends
endif

