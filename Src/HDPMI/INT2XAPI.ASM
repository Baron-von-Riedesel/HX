
;--- implements translation services for interrupts 2X except 21h/2Fh

;*** INT 23
;*** INT 24
;*** INT 25
;*** INT 26

	.386

	include hdpmi.inc
	include external.inc

	option proc:private

?EXITONCTRLC  = 0	;terminate client on Ctrl-C (INT 23h)
?EXITWITH4C   = 1	;when terminating on int 23h, terminate with an int 21, 4Ch
?INT24FAIL	  = 1	;always return FAIL on INT 24h

;--- extended disk io structure in protected mode
;--- for 16-bit protected mode, it's the same as in real-mode

DISKIO struct
startsec dd ?
sectors  dw ?
if ?32BIT
buffofs  dd ?
else
buffofs  dw ?
endif
buffseg  dw ?
DISKIO ends

;--- extended disk io structure in real mode

DISKIORM struct
startsec dd ?
sectors  dw ?
buffofs  dw ?
buffseg  dw ?
DISKIORM ends

_TEXT32  segment

	@ResetTrace

;--- protected mode int 23h

intr23 proc near public
if ?EXITONCTRLC
  if ?EXITWITH4C
	externdef _fatappexit2:near
	jmp _fatappexit2
  else
;	jmp __exitapp 
	jmp __exitclient_pm
  endif
else
	@printf "^C"
	@dprintf "an int 23 in pm occured"
;	@iret	;IRETD in 32bit, IRETW in 16-bit
	iretd
endif
	align 4
intr23 endp

	@ResetTrace

ife ?INT24FAIL
	@seg CONST32
CONST32 segment
abmsg	db cr,lf,"I/O-Error - A(bort), R(etry), I(gnore) or F(ail)? $"
crlfstr db cr,lf,"$"
CONST32 ends
endif

intr24 proc near public
	@dprintf "an int 24 in pm occured"
if ?INT24FAIL
	mov al,3
else
	push ds
	push ebx
	push ecx
	push edx
	push cs
	pop ds
	mov edx,offset abmsg
	mov ah,09h
	@int_21
nexttry:
	mov ah,01
	@int_21
	or al,20h
	cmp al,'a'
	jz intr241
	cmp al,'r'
	jz intr242
	cmp  al,'i'
	jz intr243
	cmp al,'f'
	jz intr244
	jmp nexttry
intr241:
;	mov ax,4cffh		;AL=2 (Abort)
;	jmp _exitclient_pm
	mov al,2			;will NOT work
	jmp intr24x
intr242:
	mov al,1			;AL=1 (Retry)
	jmp intr24x			;will NOT work
intr243:
	mov al,0			;AL=0 (Ignore)
	jmp intr24x
intr244:
	mov al,3			;AL=3 (Fail)
intr24x:
	push eax
	mov edx,offset crlfstr
	mov ah,09h
	@int_21
	pop eax
	pop edx
	pop ecx
	pop ebx
	pop ds
endif
	iretd				;IRETD! this is a ring 0 proc
	align 4
intr24 endp


;------ int 25h/26h

	@ResetTrace

;--- copy the disk i/o packet to TLB:0
;--- returns sectors to read/write in AX

copyDiskIo2Tlb proc public
	push es
	push ecx
	push edx

	push byte ptr _TLBSEL_
	pop es
if ?32BIT
	mov edx,[ebx].DISKIO.startsec
	mov cx,[ebx].DISKIO.sectors
else
	mov edx,[bx].DISKIO.startsec
	mov cx,[bx].DISKIO.sectors
endif
	mov es:[DISKIORM.startsec],edx
	mov es:[DISKIORM.sectors],cx
	mov es:[DISKIORM.buffofs],offset 200h
	mov ax,ss:[wSegTLB]
	mov es:[DISKIORM.buffseg],ax
	mov ax,cx
	@dprintf "copyDiskIo2Tlb: startsec=%lX, sectors=%X, buf=%X:%X",\
		dword ptr es:[DISKIORM.startsec], ax,\
		word ptr es:[DISKIORM.buffseg], word ptr es:[DISKIORM.buffofs]
	pop edx
	pop ecx
	pop es
	ret
	align 4
copyDiskIo2Tlb endp

;--- prepare for read: copy io packet to TLB:0 for FAT16/FAT32
;--- all registers preserved
;--- used by int 25h and int 21h, ax=7305h, si=0
;--- restricted to TLBSIZE (8 kB)

PrepareDiskIoRead proc public
	cmp cx,-1		;FAT 16 (> 32 MB)?
	jz isext
	@dprintf "PrepareDiskIoRead: simple disk io format, cx=%X",cx
	cmp cx,?TLBSECS
	ja error
	clc
	ret
isext:
	@dprintf "PrepareDiskIoRead: extended disk io format"
	push eax
	call copyDiskIo2Tlb
	cmp ax,?TLBSECS
	pop eax
	jnc error	;must be one less than ?TLBSECS!
	clc
	ret
error:
	stc
	ret
	align 4
PrepareDiskIoRead endp

;--- prepare for write: copy io packet to TLB:0 for FAT16/FAT32
;--- copy data to TLB:0 / TLB:200 
;--- all registers preserved
;--- used by int 26h and int 21h, ax=7305h, si=1

PrepareDiskIoWrite proc public
	cmp cx,-1		;FAT16 (> 32 MB)?
	jz isext
	@dprintf "PrepareDiskIoWrite: simple disk io format, cx=%X",cx
	cmp cx,?TLBSECS
	ja error
	push ecx
	push edx
	shl ecx,9			;sectors -> bytes
if ?32BIT
	mov edx,ebx
else
	movzx edx,bx
endif
	call copy_dsdx_2_tlb	;copy CX bytes from DS:E/DX to TLB:0
	pop edx
	pop ecx
	clc
	ret
isext:
	@dprintf "PrepareDiskIoWrite: extended disk io format"
	push eax
	call copyDiskIo2Tlb
	cmp ax,?TLBSECS
	jnc checkcxwrite_err
	push ds
	push edx
	push ecx
if ?32BIT
	lds edx,fword ptr [ebx].DISKIO.buffofs
else
	lds dx,dword ptr [bx].DISKIO.buffofs
	movzx edx,dx
endif
	push ds				;1. parameter QWORD
	push edx				;	parameter fuer copy_xx_2_flat
	mov cx,ss:[wSegTLB]
	add cx,0020h
	push ecx				;2. parameter fuer copy_xx_2_flat DWORD
	mov ecx,eax
	shl ecx,9			;sectors -> bytes (only CX counts)
	@dprintf "PrepareDiskIoWrite: copy %X bytes from %lX:%lX to TLB:200",cx,ds,edx
	call copy_far32_2_flat
	pop ecx
	pop edx
	pop ds
	pop eax
	clc
	ret
checkcxwrite_err:
	pop eax
error:
	stc
	ret
	align 4

PrepareDiskIoWrite endp

;--- copies data from TLB:0 / TLB:200 to buffer address in DS:E/BX
;--- no registers modified

AfterDiskIoRead proc public uses ds esi ecx ebx
	mov si,ss:[wSegTLB]
	cmp cx,0FFFFh
	jnz @F
if ?32BIT
	mov cx, ds:[ebx].DISKIO.sectors
	lds ebx, fword ptr ds:[ebx].DISKIO.buffofs
	@dprintf "AfterDiskIoRead: copy from tlb to ds:ebx=%lX:%lX, sectors=%X",ds,ebx,cx
else
	movzx ebx,bx
	mov cx, ds:[ebx].DISKIO.sectors
	lds bx, dword ptr ds:[ebx].DISKIO.buffofs
	@dprintf "AfterDiskIoRead: copy from tlb to ds:bx=%lX:%X, sectors=%X",ds,bx,cx
endif
	add si,0020h			;first 200h bytes used otherwise
@@:
	shl cx,9
	push ds
	push ebx
	push esi					;src segment
	call copy_flat_2_far32	;copy CX bytes from SEGM to far32
	ret
	align 4
AfterDiskIoRead endp

;*** absolute disk read ***
;*** al=drive
;*** cx=sectors (or -1)
;*** if cx == -1
;***   DS:EBX= DISKIO structure
;*** else
;***   DS:EBX=data buffer
;***   dx=start sector

	@ResetTrace

intr25 proc near public

if ?32BIT
	@dprintf "int 25, before call: ax=%X,ds:ebx=%lX:%lX,cx=%X,dx=%X,cs:eip=%X:%lX",\
		ax,ds,ebx,cx,dx,[esp+4].IRETS.rCS,[esp].IRETS.rIP
else
	@dprintf "int 25, before call: ax=%X,ds:bx=%lX:%X,cx=%X,dx=%X,cs:ip=%X:%X",\
		ax,ds,bx,cx,dx,[esp+2].IRETS.rCS,[esp].IRETS.rIP
endif
	call PrepareDiskIoRead
	jc intr25_1
	push ebx
	mov bx, 0
	call setdsreg2tlb
	@simrmint 25h
if _LTRACE_
	pushfd
	pop esi
	@dprintf "int 25,after call: ax=%X, fl=%X",ax,si
endif
	pop ebx
	jc @F
	call AfterDiskIoRead
@@:
intr25_1:

;--- the flags (FL/EFL) have to be pushed onto the client stack

seti2526stack::
	pushad
	lahf
	mov byte ptr [esp+sizeof PUSHADS].IRET32.rFL,ah
	mov eax,[esp+sizeof PUSHADS].IRET32.rFL
	mov edx,ds
	lds ebx,[esp+sizeof PUSHADS].IRET32.rSSSP
	lea ebx,[ebx-?RSIZE]
if ?32BIT
	mov [ebx],eax
else
	mov [ebx],ax
endif
	mov ds,edx
	mov [esp+sizeof PUSHADS].IRET32.rSP,ebx
	popad
	iretd
	align 4
intr25 endp

;*** absolute disk write ***

intr26 proc near public

	@dprintf "int 26, before call: ax=%X, ds:ebx=%lX:%lX, cx=%X, dx=%X",ax,ds,ebx,cx,dx
	call PrepareDiskIoWrite
	jc intr26_1

	push ebx
	mov bx, 0
	call setdsreg2tlb
	@simrmint 26h
	pop ebx
if _LTRACE_
	pushfd
	pop esi
	@dprintf "int 26, after call: ax=%X, fl=%X",ax,si
endif
intr26_1:
	jmp seti2526stack

intr26 endp

_TEXT32 ends

end

