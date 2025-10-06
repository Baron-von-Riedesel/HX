
;--- default exception handler
;--- usually displays register dump on the screen
;--- then waits for a keypress

	.386

	include hdpmi.inc
	include external.inc
	include debugsys.inc

	option proc:private

?SETCLIENTPSP	= 1 ;std 1, 1=set original client psp before server exits
?DISPCLSP		= 0 ;std 0, 1=display client stack if ring 0 exception
?SAFERMSTACK	= 0 ;std 0, 1=ensure real-mode stack is usable

;--- switches used if ?FORCETEXTMODE==1 or ?DOSOUTPUT ==0
?POLLKBD		= 0 ;std 0, 1=poll keyboard, 0=use int 16h real-mode
?RESETMOUSE		= 0 ;std 0, 1=reset mouse before getting a key

?CALLDBG equ 1	; 1=call kernel debugger after exception dump

ifdef _DEBUG
?DISPGDT equ 0
else
?DISPGDT equ 0
endif

@checkssattr macro x,y
local xxxx
if ?CHECKSSIS32
ifnb <x>
	mov eax,x
endif
	lar eax,eax
	bt eax,22
	jc xxxx
	movzx e&y,y
xxxx:
endif
endm

	@seg CONST32

_DATA16 segment
bExcMode	db 0		;0=normal,1=suppress [EIP],2=suppress [ESP]
;bPICMask	db 0
ifdef _DEBUG
savedfDebug db 0
endif
_DATA16 ends

;GROUP32 group _TEXT32, CONST32

CONST32 segment

regtexts label byte
	db "CS=",00
	db " SS=",00
	db lf,"DS=",00
	db " ES=",00
	db lf,"FS=",00
	db " GS=",00
	db lf,"LDTR=",00
	db " TR=",00
	db lf,"ERRC=",00

if (?DOSOUTPUT eq 0) or (?FORCETEXTMODE eq 1)
szTerm1	db "terminate ",0
szTerm2	db "(c)lient or ",0
szTerm3	db "(s)erver now? ",0
endif

CONST32 ends

_TEXT32 segment

_LTRACE_ = 0

if ?LOGINT30
externdef lint30:word
endif

;*** get selector bx base (GDT or LDT)
;--- ES=FLAT, DS=GROUP16

	assume ds:GROUP16

mygetbase proc
	movzx ebx,bx
	lar eax,ebx
	jnz error
	test bl,4
	jnz @F
	and bl,0F8h
	add ebx, pdGDT.dwBase
	jmp mgb_1
@@:
	and bl,0F8h
	add ebx, [dwLDTAddr]
mgb_1:
	mov ah,es:[ebx+7]
	mov al,es:[ebx+4]
	shl eax,16
	mov ax,es:[ebx+2]
	clc
	ret
error:
	stc
	ret
mygetbase endp

if ?FORCETEXTMODE or (?DOSOUTPUT eq 0)
forcetextmode proc public
 if ?FORCETEXTMODE
	test ss:fMode2, FM2_FORCETEXT
	jz exit
	call IsTextMode
	jz exit
	push eax
	push ds
	push es
	xor eax, eax
	mov ds, eax		;make sure no ring 0 selectors are in DS,ES
	mov es, eax
	mov al,03		;set std text mode
	@simrmint 10h
	pop es
	pop ds
	pop eax
exit:
 endif
	ret
forcetextmode endp
endif

	assume ds:nothing

;*** display PTE for linear address in eax

PTEout:
	call pm_Linear2PT	;returns address of PTE in EDI
	jc @F				;address not allocated
	@printf "%lX", dword ptr es:[edi]
	ret
@@:
	@printf "???"
	ret

_lfout:
	@printf lf
	ret

;--- display string in cs:[esi]
;--- out: esi -> behind 00
;--- modifies EAX, ESI

_stroutesi proc
	@printf "%ls", cs, esi
nextitem:
	db 2Eh
	lodsb
	and al,al
	jnz nextitem
	ret
_stroutesi endp

;--- ring 0 exception

_exceptZ proc public	;exception in ring 0

	@dprintf "exceptZ entry"
;	@waitesckey

if 0
	push eax
	mov eax, ss
	cmp ax,_SSSEL_
	pop eax
	jnz _except
endif
	cmp ss:bExcMode,0
	jz _except
	add esp, sizeof R3FAULT32
	cmp ss:bExcMode, 1
	mov ss:bExcMode, 0
	jz noeip
	jmp noesp
_exceptZ endp

;--- ring 3 default exception handler

EXCFRX struct
wExcNo	dw ?
		dw ?
		dq ?		;dpmi return address
rErr	dd ?		;error code
union
struct
rSP		dd ?
rSS		dw ?
ends
rSSSP	df ?
ends
EXCFRX ends

_exceptX proc public
	cld
	sub esp, 3*4	;12		;make room for a R3FAULT32 item
	push ebp		;+4=16
	mov ebp,esp

	@dprintf "exceptX exc=%X errc=%lX ss:sp=%X:%lX",\
		[ebp+16].EXCFRX.wExcNo, [ebp+16].EXCFRX.rErr,\
		[ebp+16].EXCFRX.rSS, [ebp+16].EXCFRX.rSP
;	@waitesckey

	push ds
	push esi
	push eax
	mov ax,[ebp+16].EXCFRX.wExcNo
	mov [ebp+4],ax
	lds esi,[ebp+16].EXCFRX.rSSSP
	@checkssattr ds,si
	mov eax,[ebp+16].EXCFRX.rErr
	mov [ebp+8].R3FAULT32.rErr,eax
if 0
	@dprintf "sp=%X %X %X %X %X %X",\
		word ptr [esi+00], word ptr [esi+02], word ptr [esi+04],\
		word ptr [esi+06], word ptr [esi+08], word ptr [esi+10]
endif
if ?32BIT
	lodsd
	mov [ebp+8].R3FAULT32.rIP,eax
	lodsd
	mov [ebp+8].R3FAULT32.rCSd,eax
	lodsd
	mov [ebp+8].R3FAULT32.rFL,eax
	lodsd
	mov [ebp+8].R3FAULT32.rSP,eax
	lodsd
	mov [ebp+8].R3FAULT32.rSSd,eax
else
	xor eax,eax
	lodsw
	mov [ebp+8].R3FAULT32.rIP,eax
	lodsw
	mov [ebp+8].R3FAULT32.rCSd,eax
	lodsw
	mov [ebp+8].R3FAULT32.rFL,eax
	lodsw
	mov [ebp+8].R3FAULT32.rSP,eax
	lodsw
	mov [ebp+8].R3FAULT32.rSSd,eax
endif
	pop eax
	pop esi
	pop ds
	pop ebp
_exceptX endp  ;fall through

_exceptY proc public
_exceptY endp

;--- expected stack frame:
;--- esp+0: wExcNo
;--- esp+4: R3FAULT32

;--- on entry generates frame:

R3EXCFRAME struct
rGS		dw ?
		dw ?
rFS		dw ?
		dw ?
rES		dw ?
		dw ?
rDS		dw ?
		dw ?
		PUSHADS <>	;+8
wExcNo	dw ?		;+40
      	dw ?
de  	R3FAULT32 <>;+42	;this is emulated for ring 0 exceptions
R3EXCFRAME ends

_except proc near

	@DebugBreak 0
	pushad
	push ds
	push es
	push fs
	push gs
	mov ebp,esp	  ; 			   16-Bit  32-Bit

	assume ebp:ptr R3EXCFRAME

	cld
	push ss
	pop ds
	push ds
	pop es
	assume ds:GROUP16

if 0
	pushfd
	and byte ptr [esp+1],not 40h	;clear NT flag
	popfd
endif

	@dprintf "except wExc=%X rErr=%lX cs:ip=%X:%lX fl=%lX ss:sp=%X:%lX",\
		[ebp].wExcNo, [ebp].de.rErr, [ebp].de.rCS, [ebp].de.rIP, [ebp].de.rFL,\
		[ebp].de.rSS, [ebp].de.rSP
;	@waitesckey

	inc bExcEntry
	jnz except_2x		;this is fatal

;--- v3.22: prevent reentry thru internal rmcbs
if 0 ;v3.23: reverted - this caused severe problems with exc display in v3.22
	in al, 21h
	mov bPICMask, al
	mov al,-1
	out 21h, al
else
endif
;--- v3.22: prevent reentry thru std rmcbs
;--- v3.23: switch also used to prevent reentry thru internal rmcbs
	mov [bNoRMCBEntry], 1

if ?SAFERMSTACK
	push [wHostPSP]
	pop v86iret.rSS
	mov v86iret.rSP, 100h
endif
if ?FORCETEXTMODE
	call forcetextmode
endif

;	test [fDebug],FDEBUG_KDPRESENT
;	jnz @F
ifdef _DEBUG
 if ?KDSUPP
	mov al, fDebug
	mov savedfDebug, al
 endif
	or fMode2, FM2_LOG	;enable displays in case they were suppressed
endif
;--- dump exception number

	@printf "Exception %b", word ptr [ebp].wExcNo
	mov al,byte ptr [ebp].wExcNo
	cmp al,10h
	jnz @F
	fninit					;clear FSW, FCW and FTW of FPU
@@:
	lar eax,[ebp].de.rSSd
	and ah,60h
	jz @F
	call _lfout
	jmp except_cont
@@:

;--- exception in ring 0, dump client CS:EIP, SS:ESP

	@printf <" in ring 0",lf>
;	cmp cApps, 0
;	jz @F
	mov ebx,taskseg._Esp0
	and ebx,ebx
	jz @F
	@printf <"client CS:EIP=%X:%lX SS:ESP=%X:%lX",lf>,\
		[ebx-sizeof IRET32].IRET32.rCS, [ebx-sizeof IRET32].IRET32.rIP,\
		[ebx-sizeof IRET32].IRET32.rSS, [ebx-sizeof IRET32].IRET32.rSP
if ?DISPCLSP
	push ds
	lds esi,[ebx-sizeof IRET32].IRET32.rSSSP]
	@printf <"client [ESP]=%lX,%lX,%lX",lf>,\
		dword ptr [esi+0], dword ptr [esi+4], dword ptr [esi+8]
	pop ds
endif
@@:
	@dprintf "r0sp=%X %X %X %X %X %X %X %X %X", bx,\
		word ptr [ebx-16], word ptr [ebx-14], word ptr [ebx-12],\
		word ptr [ebx-10], word ptr [ebx-08], word ptr [ebx-06],\
		word ptr [ebx-04], word ptr [ebx-02]


except_cont:

;--- dump standard registers

	@printf <"EAX=%lX EBX=%lX ECX=%lX EDX=%lX ESI=%lX",lf>,\
		[ebp].rEAX,[ebp].rEBX,[ebp].rECX,[ebp].rEDX,[ebp].rESI
	@printf <"EDI=%lX EBP=%lX ESP=%lX EFL=%lX EIP=%lX",lf>,\
		[ebp].rEDI,[ebp].rEBP,[ebp].de.rSP,[ebp].de.rFL,[ebp].de.rIP

	push byte ptr _FLATSEL_
	pop es
	push ss
	pop ds

;--- dump segment registers

	mov ax, word ptr [ebp].de.rErr
	push ax
	str ax
	push ax
	sldt ax
	push ax
	push word ptr [ebp].rGS
	push word ptr [ebp].rFS
	push word ptr [ebp].rES
	push word ptr [ebp].rDS
	push [ebp].de.rSS
	push [ebp].de.rCS

	mov esi,offset regtexts
	mov cl,9
nextsegm:
	call _stroutesi
	pop di
	lar eax,edi
	jnz novalidsel
	mov ebx,edi
	call mygetbase
	mov ebx, eax
	lsl eax, edi
	lar edx, edi
	shr edx, 8
	@printf "%X (%lX,%lX,%X)", di, ebx, eax, dx
	jmp @F
novalidsel:
	@printf "%X (********,********,****)", di
@@:
	dec cl
	jnz nextsegm

	sldt bx
	call mygetbase
	jc @F
	and eax, eax
	jz @F
	@printf " PTE 1. Page LDT="
	call PTEout
@@:
	call _lfout

;--- dump special registers (GDTR, IDTR, CRx, ...)

	sub esp,2*6
	sidt [esp+6]
	sgdt [esp+0]
if ?DISPGDT
	mov edx,[esp+2]
endif
	@printf "GDTR=%X:%lX IDTR=%X:%lX PTE CR2="
;	add esp,2*6
	mov eax,cr2
	call PTEout
if 0
	@printf <" Stat=%X",lf>, word ptr cApps
else
	call _lfout
endif

if ?DISPGDT
	@printf <" relTSS=%lX",lf>, dwTSSdesc
	mov ecx,4
@@:
	mov ah,es:[edx+7]
	mov al,es:[edx+4]
	shl eax,16
	mov ax,es:[edx+2]
	mov bh,es:[edx+7+8]
	mov bl,es:[edx+4+8]
	shl ebx,16
	mov bx,es:[edx+2+8]
	@printf <"GDT: %X-%lX-%X %X-%lX-%X",lf>, word ptr es:[edx+0], eax, word ptr es:[edx+5], word ptr es:[edx+8], ebx, word ptr es:[edx+5+8]
	add edx,16
	loop @B
endif

	mov eax,cr3
	push eax
	mov eax,cr2
	push eax
	mov eax,cr0
	push eax
	@printf "CR0=%lX CR2=%lX CR3=%lX "
	cmp _cpu,5
	jb @F
	@mov_eax_cr4
	@printf "CR4=%lX ", eax
@@:
	@printf <"TSS:ESP0=%lX",lf>, taskseg._Esp0
	mov eax,dr7
	push eax
	mov eax,dr6
	push eax
	mov eax,dr3
	push eax
	mov eax,dr2
	push eax
	mov eax,dr1
	push eax
	mov eax,dr0
	push eax
	@printf <"DR0-3=%lX %lX %lX %lX DR6=%lX DR7=%lX",lf>

;--- clear dr7 to avoid I/O watchpoints                
	xor eax, eax
	mov dr7, eax

;--- dump some host variables (LPMS, RMS, RMCB, ...)

	call closeinterrupts	;returns ISR in AX

	@printf <"LPMS=%X(%b) RMS=%X:%X cRMCB=%X IRQ=%b%X ISR=%X",lf>,\
		word ptr _LPMSSEL_, word ptr [bLPMSused],\
		v86iret.rSS, v86iret.rSP, [cRMCB], word ptr [dwIrqRouted+2], word ptr [dwIrqRouted], ax

;--- now try to display memory contents [EIP] + [ESP]
;--- this may fail, in which case just display some ??? and continue

	mov [bExcMode], 1

	@printf "   [EIP]="
	mov esi,[ebp].de.rIP
	mov ax,[ebp].de.rCS
	verr ax
	jnz noeip
	mov ds, eax
	mov cl, 12
nextbyte_eip:
	lodsb
	@printf "%b ",ax
	dec cl
	jnz nextbyte_eip
	jmp eip_done
noeip::
	@printf "??"
eip_done:
	call _lfout
	push ss
	pop ds

;--- try to display [ESP]

	mov [bExcMode], 2
	@printf "   [ESP]="
	mov eax,[ebp].de.rSSd
	verr ax
	jnz noesp
	lds esi,[ebp].de.rSSSP
	lar eax,eax
	test eax,400000h
	jnz @F
	movzx esi,si
@@:
	mov ch,06
	jmp start_stackdump
nextline_stack:
	@printf <lf,"%lX=">,esi
start_stackdump:
	mov cl,08
nextword:
	lodsw
	@printf "%X ",ax
	dec cl
	jnz nextword
	dec ch
	jnz nextline_stack
	jmp esp_done
noesp::
	@printf "????"
esp_done:
	call _lfout
	push ss
	pop ds
	mov [bExcMode], 0

if ?LOGINT30
	@dprintf "last int 30=%X",[lint30]
endif

ifdef _DEBUG
 if ?KDSUPP
	mov al,[savedfDebug]
	mov [fDebug], al
 endif
endif

;--- dump is done

	dec bExcEntry
;--- v3.23: reverted change in v3.22
;	mov al, bPICMask
;	out 21h, al
	mov [bNoRMCBEntry], 0

if ?KDSUPP and ?CALLDBG
	test [fDebug],FDEBUG_KDPRESENT
	jnz calldebugger
endif

if 0
	mov eax,[ebp].de.rSSd	;if client has no valid stack, terminate
	verw ax
	jnz serverexit
	lsl eax,eax
	cmp eax,[ebp].de.rSP
	jae serverexit
endif

if (?DOSOUTPUT eq 1) and (?FORCETEXTMODE eq 0)

;--- v3.20: to avoid a loop, force client termination if fatappexit caused another exc
	mov dl,'s'
	cmp [ebp].de.rSS, _LPMSSEL_
	jnz noloop
	cmp [ebp].de.rSP, 200h
	jb @F
noloop:
	test fMode, FM_RESIDENT
	jz @F
	mov dl,'c'
@@:
else
	mov esi, offset szTerm1
	call _stroutesi
	cmp [cApps],0
	jz @F
	call _stroutesi
@@:
	mov esi, offset szTerm3
	call _stroutesi
tryagain:
	inc bExcEntry
if ?POLLKBD
@@:
	in al,64h		;key from keyboard arrived?
	test al,1
	jz @B
	mov ah,al
	in al,60h		;get data (ack interrupt)
	test ah,20h		;input from PS/2 device?
	jnz @B
	mov dl,al
else
	pushd offset getakey
	call callrmprocintern
endif
	dec bExcEntry
endif ;?DOSOUTPUT
	cmp cApps,0
	jz @F
if ?POLLKBD
	cmp dl,2EH+80h	;key "c"
	jz fatappexit
@@:
	cmp dl,1FH+80h	;key "s"
	jnz tryagain
else
	cmp dl,'c'
	jz fatappexit
@@:
 ife ?DOSOUTPUT
	cmp dl,'s'
	jnz tryagain
 endif
endif
serverexit:
	call _lfout
if ?SETCLIENTPSP        
	cmp cApps,0			;is there a client?
	jz @F
	mov bx,[wPSPSegm]	;set client's initial PSP
	mov ah,50h
	call rmdosintern
@@:
endif
	and fMode, not FM_RESIDENT
if 0
	mov ax, _EAERR2_
	jmp _exitclientEx
else
	mov al,-1
	jmp _exitclient_pm
endif
except_2x:
	@printf <lf,"FATAL exception at %X:%lX in ring 0. Stopped.",lf>,[ebp].de.rCS, [ebp].de.rIP
	cli
	hlt

_except endp

;*** client fatal exit ***

fatappexit proc
	call _lfout
fatappexit endp	;fall throu

fatappexit2 proc public
	xor eax, eax
	mov es, eax
	mov ds, eax
	push _LPMSSEL_
	push 200h
	push ax	;clear HiWord(EFL)
	pushf
	push byte ptr _CSR3SEL_
	push offset myexitr3
	iretd
fatappexit2 endp        

_TEXT32R3 segment dword ?USE32 public ?CODER3
myexitr3:
	mov ax,4cffh
	int 21h
	push cs
	pop ss	;in case the int 21h did return cause a GPF now
_TEXT32R3 ends

if ?KDSUPP and ?CALLDBG

 if 0
EXCSTR struct
nr		db ?
pszText	word ?
EXCSTR ends

exc00str	db "divide error",lf,0
exc06str	db "invalid instruction",lf,0
exc0Bstr	db "segment fault",lf, 0
exc0Cstr	db "stack fault",lf,0
exc0Dstr	db "protection exception",lf,0
exc0Estr	db "page fault",lf,0
defaultstr	db "exception 0"
excnr_		db "0",lf,0

excstrtab label byte
	EXCSTR {00h, offset exc00str}
	EXCSTR {06h, offset exc06str}
	EXCSTR {0Bh, offset exc0Bstr}
	EXCSTR {0Ch, offset exc0Cstr}
	EXCSTR {0Dh, offset exc0Dstr}
	EXCSTR {0Eh, offset exc0Estr}
NUMEXCSTR equ ($ - offset excstrtab) / sizeof EXCSTR
	EXCSTR {0FFh, offset defaultstr}
 endif

;*** cause the debugger to break
;*** inp: EBP -> exception frame

calldebugger proc
 if 0
	push ds
	push ss
	pop ds
;;	dec     bExcEntry
	mov al, byte ptr [ebp].wExcNo
	mov cl, NUMEXCSTR
	mov si, offset excstrtab
nextitem:        
	cmp al,[si].EXCSTR.nr
	jz @F
	add si, sizeof EXCSTR
	dec cl
	jnz nextitem
@@:        
	mov si, [si].EXCSTR.pszText
	.if (al >= 10)
		add al, 7
	.endif
	add ds:excnr_, al
	movzx esi, si
	mov ax,DS_Out_Str
	int Debug_Serv_Int
	pop ds
 endif
 if ?386SWAT
;--- todo
 endif
 if ?WDEB386
  if 0
;--- setting up an INT stack frame? Why?
	mov ebx,[ebp].de.rIP
	mov ecx,[ebp].de.rCSd
	mov eax,[ebp].de.rFL
	lds esi,[ebp].de.rSSSP
	sub esi,3*4
	mov [esi+0],ebx
	mov [esi+4],ecx
	mov [esi+8],eax
	mov [ebp].de.rSP,esi
	mov ax,DS_ForcedGO	;set BP at cx:ebx
	int Debug_Serv_Int
  endif
	mov es, dword ptr [ebp].rES
	mov ds, dword ptr [ebp].rDS
	lea esp,[ebp].rEDI
	popad
;	lss esp,[esp+4].R3FAULT32.rSSSP
	add esp, 2*4	; skipp excno & errorcode
	int 3
;	iretd		; this returns to the faulting opcode!?
 endif
	jmp fatappexit

calldebugger endp

endif

_TEXT32 ends

if (?DOSOUTPUT eq 0) or (?FORCETEXTMODE eq 1)

_TEXT16 segment

getakey proc near

	in al, 21h
	push ax
	mov al, 0FDh
	out 21h, al
  if ?RESETMOUSE
	xor ax,ax		;reset mouse. since the host (hopefully) isn't reentered
	int 33h			;during exception handling, this isn't needed.
  endif
	mov ah,0
	int 16h
	or al,20h
	mov dl,al
	pop ax
	out 21h, al
	ret
getakey endp

_TEXT16 ends

endif

	end
