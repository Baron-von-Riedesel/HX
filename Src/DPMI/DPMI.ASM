
;*** simple check of dpmi host ***

	.286
	.model small
DGROUP group _TEXT
	.stack 500h
	.dosseg
	option casemap:none
	option proc:private

	.386

?MAXNEST equ 32	;max nesting level for option -t

lf	equ 10

PF16 typedef ptr far16

;--- CStr() define a string in .CONST

CStr macro text:VARARG
local sym
	.const
sym db text,0
	.code
	exitm <offset sym>
endm

	include dpmi.inc

	.data

xmsaddr		PF16 0	;far16 address of XMS host
dwXMSHighest dd 0	;highest physical address managed by XMS
dwAlloc		dd 0	;amount of memory to alloc before starting shell
dwLinAddr	dd 400000h;addr of memory to alloc with ax=504h
dwI15		dd 0	;free memory in kB returned by Int 15h ax=e801
dwPort		dd 21h	;default port used for IN benchmark
wXMSVer		dw 0
bXMS		db 0	;XMS host found
b16Bit		db 0	;1=start as 16bit client

;--- exec parameter block used for shell option

execparm label word
wSegEnv dw 0
		dw offset cmdl
wSegCmd dw 0
		dw offset fcb
wSegfcb1 dw 0
		dw offset fcb
wSegfcb2 dw 0
		dd 0
		dd 0

;--- option flags

OP_ALLOC	equ 1	;alloc memory 501
OP_LINALLOC	equ 2	;alloc memory 504
OP_REALLOC	equ 4	;alloc memory 501, then realloc until error
OP_RMCB		equ 8	;alloc real-mode callbacks until error occurs
OP_SHELL	equ 16	;alloc some memory, then start a shell
OP_MODESW	equ 32	;mode switch benchmark
OP_CLISTI	equ 64	;CLI/STI benchmark
OP_IN		equ 128	;IN benchmark
OP2_NESTED	equ 1	;nested execution test
OP2_HSFATAL	equ 2	;host stack exhaustion
OP2_DESC	equ 4	;alloc descriptors
OP2_EXTMEM	equ 8	;use int 31h, ax=50bh

wOpt		label word
bOpt1		db 0
bOpt2		db 0
bFill		db 0	;fill memory allocated with options -m or -s
bWaitKey	db 0	;wait for a key press in pm
bNestLvl	db 2	;nesting level for -t

	.const

szMSDOS	db "MS-DOS",0        
szCOMSP	db "COMSPEC="
fcb		db 0, "           ", 0, 0, 0, 0
cmdl	db 0,13
szHelp label byte
	db "DPMI v2.0, Public Domain, written by Japheth",lf
	db "displays infos about installed DPMI host",lf
	db "usage: DPMI [ -options ]",lf
	db "  -16: use entry for 16-bit client in any case",lf
	db "  -b: allocate real-mode callbacks until error",lf
	db "  -c: measure enable/disable interrupt execution time in protected mode",lf
	db "  -d: allocate descriptors until error",lf
	db "  -e: provoke host stack exhaustion",lf
	db "  -f: fill allocated memory block (-m, -s) with value 'DPMI'",lf
	db "  -i<port>: measure execution time of IN opcode in protected-mode",lf
	db "  -l[addr]: allocate 1000h bytes at addr (def 400000h) with function 504h",lf
	db "  -m: allocate largest free block with function 501h",lf
	db "  -n: realloc a memory block until an error occurs",lf
	db "  -r: measure mode switch execution time",lf
	db "  -s<n>: allocate <n> kB of extended memory, then launch a shell",lf
	db "  -t[n]: test nested execution of mode switches; n: nesting level (def 2)",lf
	db "  -w: wait in protected-mode for a keypress before terminating",lf
	db "  -x: try to get extended memory infos thru function 50Bh",lf
	db 0

	.data?

buffer	db 80h dup (?);used to save task state, and DPMI values
blanks 	db ?MAXNEST * 4 + 1 dup (?)
meminf	MEMINFO <>
rmcs	RMCS <>	;real mode call structure used for mode switch benchmark

;--- values returned by int 2fh, ax=1687h
wVersion	dw ?	;dpmi version
wCPU		dw ?	;cpu
wTaskMem	dw ?	;task specific memory in paras
wFlags		dw ?	;bit 0=1:32bit clients supported
dwPMEntry	dd ?	;far16 address initial switch to pm

dfSaveStatePM label fword	;far32 address to call to save task state in pm
dwSaveStatePM	dd ?		;far16 address to call to save task state in pm
				dw ?
dwSaveStateRM	dd ?		;far16 address to call to save task state in rm
wSaveStateSize	dw ?		;size in bytes for save state
dfRawSwitch2RM	df ?		;raw mode switch to rm
dwRawSwitch2PM	dd ?		;raw mode switch to pm

;--- real-mode DGROUP value ( CS, DS, ES, SS )
wDgrp		dw ?
;--- segment register values after initial switch to pm
wCSSel		dw ?
wSSSel		dw ?
wDSSel		dw ?
wESSel		dw ?
wFSSel		dw ?
wGSSel		dw ?

wEnv		dw ?	;environment selector
wParent		dw ?	;PSP's parent segment
wDPMIFlgs	dw ?	;flags returned by DPMI function 0x400
wPICs		dw ?	;master/slave PICs
dwRMCB		dd ?	;realmode callback used for mode switch bench

	.code

	include printf.inc

;--- in: bl=base (10 or 16)

getnum proc
	xor edx, edx
	movzx ebx,bl
	mov ch,0
	.while (cl > 1)
		mov al,es:[si+1]
		or al,20h
		sub al,'0'
		jb done
		cmp al,9
		jbe @F
		sub al,27h
@@:
		movzx eax, al
		cmp eax, ebx
		jnc done
		push eax
		mov eax, edx
		mul ebx
		pop edx
		add edx, eax
		inc si
		dec cl
		inc ch
	.endw
done:
	cmp ch,1
	ret
getnum endp

startshell proc
	mov eax, dwAlloc
	and eax, eax
	jz @F
	shl eax, 10		;convert kB to bytes
	push eax
	pop cx
	pop bx
	mov ax,0501h
	int 31h
	jc exit1
	cmp bFill,0
	jz @F
	push bx
	push cx
	pop eax
	mov edx,dwAlloc
	shl edx,10
	call fillblock 
@@:
	mov es, wEnv
	xor di,di
	.while (byte ptr es:[di])
		mov dx, di
		mov si, offset szCOMSP
		mov cx, 8
		repz cmpsb
		jz found
		mov di, dx
		mov cx,-1
		mov al,0
		repnz scasb
	.endw
	jmp exit2
found:
	mov rmcs.rSSSP, 0
	mov rmcs.rDX, di
	mov rmcs.rAX, 4B00h
	mov rmcs.rBX, offset execparm

	@printf <"type 'exit' to return to DPMI">

	mov bx, es
	mov ax, 6
	int 31h
	push cx
	push dx
	pop eax
	shr eax, 4
	mov rmcs.rDS, ax

	mov es, wESSel
	mov es:[002Ch], ax

	mov bx,ds
	mov ax,6
	int 31h
	push cx
	push dx
	pop eax
	shr eax, 4
	mov rmcs.rES, ax
	mov wSegCmd, ax
	mov wSegfcb1, ax
	mov wSegfcb2, ax
	push ds
	pop es
	mov edi, offset rmcs
	mov bx,0021h
	mov cx,0
	mov ax,0300h
	int 31h

	mov es, wESSel
	mov ax, wEnv
	mov es:[002Ch], ax

	@printf <"DPMI: back from shell",lf>
	ret
exit1:
	@printf <"unable to alloc memory",lf>
	ret
exit2:
	@printf <"COMSPEC not found",lf>
	ret
startshell endp        

;--- memory map returned by int 15h ax=e820h

E820ENTRY struct
dwAddrLow	dd ?
dwAddrHigh	dd ?
dwLenLow	dd ?
dwLenHigh	dd ?
dwType		dd ?
E820ENTRY ends

i15_e820 proc

local dwTotal:dword
local dwAddr:dword
local dwSTotal:dword
local dwSMax:dword
local dwSAddr:dword

	xor esi,esi		;esi=Max
	mov dwTotal,esi
	mov dwAddr,esi
	mov dwSTotal,esi
	mov dwSMax,esi
	mov dwSAddr,esi
	xor ebx,ebx		;ebx=0 -> start scan
	push ds
	pop es
	.while (1)
		mov ecx, sizeof E820ENTRY
		mov edx,"SMAP"
		mov eax,0E820h
		mov di, offset buffer	;es:di = buffer
		clc
		int 15h
		.break .if (eax != "SMAP")
		.if ([di].E820ENTRY.dwType == 1)
			mov eax, es:[di].E820ENTRY.dwLenLow
			mov edx, es:[di].E820ENTRY.dwLenHigh
			mov ecx, es:[di].E820ENTRY.dwAddrLow
			mov edi, es:[di].E820ENTRY.dwAddrHigh
			shrd eax,edx,10
			.if edi == 0
				.if ecx < 100000h
				;	;skip conventional memory
				.else
					add dwTotal, eax
					.if eax > esi
						mov esi, eax
						mov dwAddr, ecx
					.endif
				.endif
			.else
				add dwSTotal, eax
				.if eax > dwSMax
					mov dwSMax, eax
					shrd ecx,edi,10
					mov dwSAddr, ecx
				.endif
			.endif
		.endif
		.break .if (ebx == 0)
	.endw
	cmp dwTotal,0
	stc
	jz exit
	@printf <"Int 15h, ax=e820h, free ext. memory:",lf>
	.if dwTotal
		@printf <"  below 4GB: total %lu kB, largest %lu kB at %lx",lf>, dwTotal, esi, dwAddr
	.endif
	.if dwSTotal
		mov eax, dwSAddr
		xor cx,cx
		shld ecx,eax,10
		shl eax,10
		@printf <"  above 4GB: total %lu kB, largest %lu kB at %lp",lf>, dwSTotal, dwSMax, cx, eax
	.else
		@printf <"  above 4GB: none",lf>
	.endif
	clc
exit:
	ret
i15_e820 endp

;--- get extended memory via int 15h

int15mem proc uses bp
	xor bp,bp
;--- first try int 15h ax=e801h
	xor cx,cx
	xor dx,dx
	xor bx,bx
	mov ax,0E801h
	clc				;the carry flag is not reliably set/reset!
	int 15h
	jc noe801
	cmp ah,86h
	jz noe801
	and bx, bx
	jnz @F
	and cx, cx
	jz noe801
@@:
	.if (!ax)		;some bioses return values in CX:DX
		mov ax, cx
		mov bx, dx
	.endif

;--- AX is supposed to contain memory between 100000h and 1000000h in kB
;--- max value is 3C00h (dec 15360)
;--- BX is supposed to contain memory beyond 1000000h in 64 kB
	.if ((ax < 3C00h) && bx)
		jmp noe801
	.endif
	inc bp
	movzx ebx, bx
	shl ebx, 6		;64 kB blocks -> 1 kB blocks
	movzx eax, ax
	add ebx, eax
	mov dwI15, ebx
	@printf <"Int 15h, ax=e801h, extended memory: %lu kB",lf>, ebx
noe801:
	call i15_e820
	jnc @F
	and bp,bp  
	jnz @F
	mov ah,88h
	int 15h
	jc @F
	@printf <"Int 15h, ah=88h, extended memory: %u kB",lf>, ax
@@:
	ret
int15mem endp

xms proc
	mov ax,4300h
	int 2Fh
	mov bXMS,al
	test al,80h
	jz noxms
@@:
	xor bx,bx
	mov es,bx
	mov ax,4310h
	int 2Fh
	mov ax,es
	or ax,bx
	jz noxms
	mov word ptr xmsaddr+0,bx
	mov word ptr xmsaddr+2,es
	mov ah,00
	call xmsaddr
	mov wXMSVer, ax
	movzx cx,al
	movzx ax,ah
	@printf <"XMS v%u.%x host found">, ax, cx

	mov ah,08h				;query free memory
	cmp byte ptr wXMSVer+1,3
	jb @F
	or ah,80h
@@:
	call xmsaddr
	cmp bl,00
	jnz xmsdone
	cmp byte ptr wXMSVer+1,3
	jnb @F
	movzx eax, ax
	movzx ecx, cx
@@:
	mov dx,cx
	and dx,0FFFh
	cmp dx,0FFFh
	jnz @F
	mov dwXMSHighest, ecx
@@:
	@printf <", largest free block: %lu kB",lf>, eax
;	mov [si + 18],eax		;largest block
;	mov [si + 26],edx		;total extended mem
	jmp xmsdone
noxms:
	@printf <"No XMS host found",lf>
	mov dwXMSHighest, 0
	ret
xmsdone:

	mov ecx,dwI15		;free memory returned by Int15, ax=e801h
	jecxz noi15
	mov eax, dwXMSHighest
	cmp eax, 10FFF0h
	jb noi15
	inc eax
	sub eax, 1024
	shr eax, 10			;convert to kB
	sub ecx, eax
	jbe noi15
	@printf <"extended memory not managed by XMS: %lu kB",lf>, ecx
noi15:
	ret
xms endp

vcpi proc
	mov ax,3567h
	int 21h
	mov ax,es
	or ax,bx
	jz novcpi
	mov ax,0DE00h
	int 67h
	cmp ah,00
	jz @F
novcpi:
	@printf <"No VCPI host found",lf>
	jmp vcpidone
@@:
	push bx
	mov ax,0DE03h		;get free 4K Pages
	int 67h
	pop bx
	movzx ax,bh
	movzx cx,bl
	mov ebx, edx
	shl ebx, 2
	@printf <"VCPI v%u.%u host found, free pages: %lu (%lu kB)",lf>, ax, cx, edx, ebx
vcpidone:
	ret
vcpi endp

;--- myint69/myint69ex runs in real-mode

myint69 proc
	iret
myint69 endp

myint69ex proc
	sti		; reenable interrupts
	mov ecx, 100000
nextloop:
	call cs:[dwRMCB]
	dec ecx
	jnz nextloop
	iret
myint69ex endp

;--- realmode callback
;--- ds:e/si -> realmode stack
;--- es:e/di -> rmcs
;--- interrupts disabled

mycb32 proc
	cld
	db 67h
	lodsd
	mov es:[edi].RMCS.rCSIP,eax
	add es:[edi].RMCS.rSP,sizeof dword
	iretd
mycb32 endp

mycb16 proc
	cld
	lodsd
	mov es:[di].RMCS.rCSIP,eax
	add es:[di].RMCS.rSP,sizeof dword
	iret
mycb16 endp

if 0
gettimer proc
	push ds
	mov ax,0040h
	mov ds,ax
	mov eax,ds:[6Ch]
	pop ds
	ret
gettimer endp
endif

;--- this returns timer value in ms

_GetTimerValue proc uses es bx

	push 0040h
	pop es
	mov ax,0900h	;disable interrupts
	int 31h
	mov bx, ax
tryagain:
	mov edx,es:[06ch] 
	mov al,0C2h		;read timer 0 status + value low/high
	out 43h, al
	xchg edx, edx
	in al,40h
	mov cl,al		;CL = status
	xchg edx, edx
	in al,40h
	mov ah, al		;AH = value low
	xchg edx, edx
	in al,40h		;AL = value high

	test cl,40h		;was latch valid?
	jnz tryagain
	cmp edx,es:[06ch]	;did an interrupt occur in the meantime?
	jnz tryagain		;then do it again!

	push ax
	mov ax, bx
	int 31h		;restore interrupts
	pop ax

	xchg al,ah
;--- usually (counter mode 3) the timer is set to count down *twice*! 
;--- however, sometimes counter mode 2 is set!
	mov ch,cl
	and ch,0110B	;bit 1+2 relevant
	cmp ch,0110B	;counter mode 3?
	jnz @F
;--- in mode 3, PIN status of OUT0 will become bit 15
	shr ax,1
	and cl,80h
	or ah, cl
@@:
;--- now the counter is in AX (counts from FFFF to 0000)
	neg ax
;--- now the count is from 0 to FFFF
	ret
_GetTimerValue endp

;--- get timer value in ms in eax

gettimer proc
	call _GetTimerValue

;--- the timer ticks are in EDX:AX, timer counts down 
;--- a 16bit value with 1,193,180 Hz -> 1193180/65536 = 18.20648 Hz
;--- which are 54.83 ms
;--- to convert in ms:
;--- 1. subticks in ms: AX / 1193
;--- 2. ticks in ms: EDX * 55
;--- 3. total 1+2

	push edx
	movzx eax,ax	;step 1
	cdq
	mov ecx, 1193
	div ecx
	mov ecx, eax
	pop eax 		;step 2
	mov edx, 55
	mul edx
	add eax, ecx	;step 3
	ret
gettimer endp

savereststate proc
	cmp wSaveStateSize,0
	jz done
	mov edi, offset buffer
	cmp b16Bit,1
	jz @F
	call dfSaveStatePM
	ret
@@:
	call dwSaveStatePM
done:
	ret
savereststate endp

enableints proc
	pushf
	pop ax
	test ah,2
	jnz @F
	mov ax,0901h
	int 31h
	@printf <"Interrupts enabled for benchmark",lf>
@@:
	ret
enableints endp

isreliable proc
	test di,200h
	jnz @F
	@printf <"results are unreliable since host has disabled interrupts!",lf>
@@:
	ret
isreliable endp

;--- mode switch tests
;--- 1. pm->rm->pm via INT 69h
;--- 2. pm->rm->pm via int 31h,ax=0300h
;--- 3. rm->pm->rm via realmode callback
;--- 4. pm->rm->pm via raw mode switches

modeswtest proc

;--- set int 69h real-mode

	mov bl,69h
	mov ax,0200h
	int 31h

	push cx
	push dx

	mov cx, wDgrp
	mov dx, offset myint69
	mov ax,0201h
	int 31h

	call enableints

;--- benchmark calling int 69h real-mode directly via INT instruction

	call gettimer
	mov esi, eax
	mov ecx,100000
@@:
	int 69h
	dec ecx
	jnz @B
	call gettimer
	sub eax,esi
	@printf <"time executing 100.000 * INT 69h: %lu ms",lf>, eax

;--- benchmark calling int 69h real-mode via int 31h, ax=0300h

	call gettimer
	mov esi, eax
	mov edi, offset rmcs
	mov rmcs.rSSSP,0
	pushf
	pop rmcs.rFlags
	push ds
	pop es
	mov ecx,100000
@@:
	push ecx
	mov bl,69h
	mov cx,0
	mov ax,0300h
	int 31h
	pop ecx
	dec ecx
	jnz @B
	call gettimer
	sub eax,esi
	@printf <"time executing 100.000 * INT 31h, AX=0300h (Sim INT 69h): %lu ms",lf>, eax

;--- benchmark realmode callback

	mov cx, wDgrp
	mov dx, offset myint69ex
	mov bl,69h
	mov ax,0201h
	int 31h

	push ds
	push cs
	pop ds
	.if b16Bit == 1
		mov si,offset mycb16
		mov di,offset rmcs
	.else
		mov esi,offset mycb32;DS:ESI -> CS:EIP of protected mode routine
		mov edi,offset rmcs	;ES:EDI -> rmcs to be used
	.endif
	mov ax,0303h	;alloc realmode callback
	int 31h
	pop ds
	jc normcb
	mov word ptr dwRMCB+0,dx
	mov word ptr dwRMCB+2,cx
	call gettimer
	mov esi, eax
	int 69h
	call gettimer
	sub eax,esi
	@printf <"time executing 100.000 * real-mode callback: %lu ms",lf>, eax

	mov dx, word ptr dwRMCB+0
	mov cx, word ptr dwRMCB+2
	mov ax,0304h	;free realmode callback
	int 31h
	jmp rmcb_done
normcb:
	@printf <"no realmode callback could be allocated",lf>
rmcb_done:
;--- restore int 69h real-mode vector
	pop dx
	pop cx
	mov bl,69h
	mov ax,0201h
	int 31h

;--- benchmark raw mode switches

	call gettimer
	push eax
	push ds
	pop es
	mov al,00
	call savereststate
	mov ebp, 100000		;register EBP is guaranteed to be preserved 
nexttrip:
	mov ax,wDgrp		;rm DS
	mov dx,ax			;rm SS
	mov si,ax			;rm CS
	mov cx,ax			;rm ES
	mov di,offset raw_rm;rm IP
	mov bx,sp			;rm SP
	jmp dfRawSwitch2RM
raw_rm:					;in real mode now
	mov dx,wSSSel		;pm SS
	mov si,wCSSel		;pm CS
	mov edi,offset raw_pm;pm E/IP
	mov ax,wDSSel		;pm DS
	mov cx,ax			;pm ES
	movzx ebx,sp		;pm E/SP
	jmp dwRawSwitch2PM
raw_pm:					;back in protected mode
	dec ebp
	jnz nexttrip
	mov al,01
	call savereststate
	pushf
	pop di				;save interrupt status
	call gettimer
	pop esi
	sub eax,esi
	@printf <"time executing 100.000 * raw mode switches PM-",3Eh,"RM-",3Eh,"PM: %lu ms",lf>, eax
	call isreliable
	ret

modeswtest endp

;--- test execution speed of disable/enable interrupts

clitest proc
	pushfd
	pop eax
	mov cx,ax
	shr cx,12
	and cl,3
	@printf <"EFlags: %lx (IOPL=%u)",lf>, eax, cx

;--- measure CLI/STI execution time

	call gettimer
	mov esi, eax
	mov ecx, 500000
@@:
	CLI
	nop
	STI
	dec ecx
	jnz @B
	call gettimer
	sub eax,esi
	@printf <"time executing 500.000 * CLI/STI: %lu ms",lf>, eax

;--- measure int 31h, ax=090xh execution time

	call gettimer
	mov esi, eax
	mov ecx, 500000
@@:
	mov ax,0900h
	int 31h
	nop
	int 31h	;restore value
	dec ecx
	jnz @B
	call gettimer
	sub eax,esi
	@printf <"time executing 500.000 * disable/enable interrupts via DPMI: %lu ms",lf>, eax

	ret
clitest endp

;--- test execution speed of IN

inptest proc
	pushfd
	pop eax
	mov cx,ax
	shr cx,12
	and cl,3
	@printf <"EFlags: %lx (IOPL=%u)",lf>, eax,cx

	call enableints

	call gettimer
	mov esi, eax
	mov ecx,200000
	mov edx, dwPort
@@:
	in al,dx
	dec ecx
	jnz @B
	call gettimer
	sub eax,esi
	mov edx, dwPort
	@printf <"time executing 200.000 * IN %x: %lu ms",lf>, dx, eax
	ret
inptest endp

;--- test RMCB allocation

rmcbtest proc uses bp
	xor bp,bp
	.while bp < 256
		push cs
		pop ds
		mov esi,offset mycb32 ;DS:E/SI -> CS:E/IP of protected mode routine
		mov edi,offset rmcs	;ES:E/DI -> rmcs to be used
		mov ax,0303h
		int 31h
		push es
		pop ds
		jc done
		push cx
		push dx
		inc bp
		@printf <"callback %u (%x:%x) allocated",lf>, bp, cx, dx
	.endw
done:
	.while bp > 0
		dec bp
		pop dx
		pop cx
		mov ax,0304h
		int 31h
		jnc @F
		@printf <"free rmcb %x:%x returned error",lf>, cx, dx
@@:
	.endw
	ret
rmcbtest endp

;--- 32-bit real-mode callback

rmcb32 proc

	assume ds:nothing,es:nothing,ss:nothing

	cld
	cmp b16Bit,1
	jnz @F
	movzx edi,di
	movzx esi,si
@@:
	db 67h
	lodsd
;--- simulate a RETF in real-mode
	add es:[edi].RMCS.rSP,sizeof dword

	mov ecx, esp
	push eax		;save rm cs:ip

	mov dx,ds
	push es
	pop ds
	@printf <"%sinside rm callback, ss:esp=%x:%lx, ds:esi=%x:%lx",lf>, offset blanks, ss, ecx, dx, esi
	@printf <"%ses:edi=%x:%lx, rm ss:sp=%x:%x, rm cx=%x",lf>, offset blanks, es, edi,\
		es:[edi].RMCS.rSS, es:[edi].RMCS.rSP, es:[edi].RMCS.rCX
	mov al, bNestLvl
	.if ( al > byte ptr es:[edi].RMCS.rCX )
		inc word ptr es:[edi].RMCS.rCX
		mov es:[edi].RMCS.rIP,offset myrmproc
		mov ax, wDgrp
		mov es:[edi].RMCS.rCS,ax
		@printf <"%scalling rm proc [%x:%x]",lf>, offset blanks, es:[edi].RMCS.rCS, es:[edi].RMCS.rIP
		push es:[edi].RMCS.rSSSP	;dpmi ax=0301h may not update rm SP correctly
		mov cx,0
		mov ax,0301h
		int 31h
		@printf <"%sback in rm callback, rm ss:sp=%x:%x, rm cx=%x; exiting",lf>, offset blanks,\
			es:[edi].RMCS.rSS, es:[edi].RMCS.rSP, es:[edi].RMCS.rCX
		pop es:[edi].RMCS.rSSSP
	.else
		@printf <"%sexiting",lf>, offset blanks
	.endif

	pop eax
	mov es:[edi].RMCS.rCSIP, eax

	cmp cs:b16Bit,1
	jz @F
	iretd
@@:
	iret
rmcb32 endp


myrmproc proc far
	mov ds,cs:[wDgrp]
	assume ds:DGROUP
	mov ax,sp
	.if cx <= ?MAXNEST
		mov word ptr [bx],'  '
		add bx,2
		mov byte ptr [bx],0
		@printf <"%sinside rm proc, ss:sp=%x:%x, cx=%x",lf>, offset blanks, ss, ax, cx
		@printf <"%scalling rm callback %x:%x",lf>, offset blanks, word ptr dwRMCB+2, word ptr dwRMCB+0
		mov word ptr [bx],'  '
		add bx,2
		mov byte ptr [bx],0
		call [dwRMCB]
		sub bx, 2
		mov byte ptr [bx],0
		@printf <"%sback in rm proc, ss:sp=%x:%x; exiting",lf>, offset blanks, ss, sp
		sub bx, 2
		mov byte ptr [bx],0
	.else
		@printf <"unexpected call of rm proc, ss:sp=%x:%x, cx=%x; exiting",lf>, ss, ax, cx
	.endif
	ret
myrmproc endp

	assume es:DGROUP,ss:DGROUP
;--- test nested execution

nesttest proc
	mov esi,offset rmcb32	;DS:ESI -> CS:EIP of protected mode routine
	push cs
	pop ds
	mov edi,offset rmcs		;ES:E/DI -> rmcs to be used
	mov ax,0303h
	int 31h
	push es
	pop ds
	jc error
	mov word ptr dwRMCB+0,dx
	mov word ptr dwRMCB+2,cx
	@printf <"allocated rm callback %x:%x, rmcs=%x:%lx",lf>, cx, dx, es, edi

	sub sp, sizeof RMCS
	movzx edi, sp
	mov [di].RMCS.rSSSP,0
	mov [di].RMCS.rIP,offset myrmproc
	mov ax,wDgrp
	mov [di].RMCS.rCS,ax
	mov [di].RMCS.rCX,1
	mov [di].RMCS.rBX,offset blanks
	@printf <"calling rm proc [%x:%x], rm cx=%x",lf>, wDgrp, [di].RMCS.rIP, [di].RMCS.rCX
	mov [di].RMCS.rFlags,0
	mov cx,0
	mov ax,0301h
	int 31h
	jnc @F
	@printf <"calling rm proc failed",lf>
	jmp done
@@:
	@printf <"back in protected-mode, rm ss:sp=%x:%x, rm cx=%x",lf>, [di].RMCS.rSS, [di].RMCS.rSP, [di].RMCS.rCX
done:
	lea esp,[esp+sizeof RMCS]
	mov dx,word ptr dwRMCB+0
	mov cx,word ptr dwRMCB+2
	mov ax,0304h
	int 31h
	ret
error:
	@printf <"could not allocate a rm callback",lf>
	ret
nesttest endp

;--- option -e
;--- cause host stack exhaustion by using INT to switch to real-mode
;--- and a raw mode switch to switch back to protected-mode

hsfatal proc
local loops:word
local trmcs:RMCS

	mov loops,0
newloop:
	mov ax,wDgrp
	mov trmcs.rDX,sp
	mov trmcs.rBP,bp
	mov trmcs.rFlags,3202h
	mov trmcs.rES,ax
	mov trmcs.rDS,ax
	mov trmcs.rIP,offset hsfatalrm
	mov trmcs.rCS,ax
	mov trmcs.rSSSP,0
	push ss
	pop es
	lea edi,trmcs
	mov bx,0
	mov cx,0
	mov ax,0301h
	int 31h
	ret
hsfatalx:
	inc loops
	@printf <"%u. iteration",lf>, loops
	jmp newloop
hsfatalrm:
	add sp,4			;no need to return from "far proc"
	movzx ebx,dx		;pm E/SP
	@printf <"in rm, ss:sp=%x:%x",lf>,ss,sp
	mov dx,wSSSel		;pm SS
	mov si,wCSSel		;pm CS
	mov edi,offset hsfatalx;pm E/IP
	mov ax,wDSSel		;pm DS
	mov cx,ax			;pm ES
	jmp dwRawSwitch2PM

hsfatal endp

descalloc proc

	mov bx,0
next:
	mov cx,1
	mov ax,0
	int 31h
	jc error
	inc bx
	jmp next
error:
	@printf <"%u descriptors allocated",lf>, bx
	ret

descalloc endp

;--- get a flat selector

getflatsel proc
	mov cx,1
	mov ax,0
	int 31h
	jc exit
	mov bx,ax
	mov cx,0
	mov dx,0
	mov ax,7
	int 31h
	jc exit
	mov cx,-1
	mov dx,-1
	mov ax,8
	int 31h
exit:
	ret
getflatsel endp

;--- fill a memory block with "DPMI"
;--- eax = block linear address
;--- edx = size in bytes

fillblock proc uses es
	push eax
	push edx
	call getflatsel
	pop ecx
	pop edi
	jc exit
	mov es,bx
	mov eax, "IMPD"
	shr ecx, 2
	cld
	db 67h
	rep stosd
	@printf <"memory block filled with value 'DPMI'",lf>
	push ds
	pop es
	mov ax,1
	int 31h
exit:
	ret
fillblock endp

stdalloc proc
	mov cx,word ptr meminf.maxBlock+0
	mov bx,word ptr meminf.maxBlock+2
	mov ax,0501h
	int 31h
	jc memalloc_failed
	mov eax, meminf.maxBlock
	shr eax, 10
	push si
	push di
	pop esi
	push bx
	push cx
	pop ecx
	@printf <"alloc largest mem block (size=%lu kB) returned handle %lx, base %lx",lf>,\
		eax, esi, ecx
	cmp bFill, 1
	jnz @F
	push bx
	push cx
	pop eax		;linear address in eax
	mov edx,meminf.maxBlock   
	call fillblock
@@:
	mov ax,0502h
	int 31h
	ret
memalloc_failed:
	@printf <"alloc largest block (%lx) failed, AX=%x",lf>,meminf.maxBlock, ax
	ret
stdalloc endp

realloc proc uses ebp

	mov ebp, 1000h
	mov ax,0501h
nexttry:
	push ebp
	pop cx
	pop bx
	int 31h
	jc memalloc_failed
;--- handle in SI:DI now
	mov eax, ebp
	shr eax, 10
	push bx
	push cx
	pop ecx
	@printf <"(re)alloc memory block ok, linear address=%lx, size=%lu kB",lf>, ecx, eax
	add ebp, 100000h	;resize in 1 MB chunks
	jc done	;overflow, shouldn't happen
	mov bp,0
	mov ax,0503h
	jmp nexttry
memalloc_failed:
	.if (ebp > 1000h)
		mov eax, ebp
		shr eax,10
		push si
		push di
		pop esi
		@printf <"realloc memory block (handle=%lx) failed, req. size=%lu kB",lf>, esi, eax
	.else
		@printf <"alloc memory block failed, size= 4 kB",lf>
	.endif
done:
	ret
realloc endp

linalloc proc
	mov ebx,dwLinAddr
	mov ecx,1000h
	mov edx,1
	mov ax,0504h
	int 31h
	jc linalloc_failed
	@printf <"alloc linear memory at %lxh returned handle %lx, base %lx",lf>, dwLinAddr, esi, ebx
	ret
linalloc_failed:
	@printf <"alloc linear memory at %lxh failed, AX=%x",lf>,dwLinAddr,ax
	ret
linalloc endp

dispextmem proc
local mix:MEMINFOX
	lea di,mix
	push ss
	pop es
	mov ax,050Bh
	int 31h
	jc notsupp
	mov eax, mix.dwTotalPhys
	shr eax, 10
	@printf <"total physical=%lx (%lu kB)",lf>, mix.dwTotalPhys, eax
	mov eax, mix.dwTotalHost
	shr eax, 10
	mov ecx, mix.dwFreeHost
	shr ecx, 10
	@printf <"total/free host=%lx/%lx (%lu/%lu kB)",lf>, mix.dwTotalHost, mix.dwFreeHost, eax, ecx
	mov eax, mix.dwTotalVM
	shr eax, 10
	mov ecx, mix.dwFreeVM
	shr ecx, 10
	@printf <"total/free VM=%lx/%lx (%lu/%lu kB)",lf>, mix.dwTotalVM, mix.dwFreeVM, eax, ecx
	mov eax, mix.dwTotalClient
	shr eax, 10
	mov ecx, mix.dwFreeClient
	shr ecx, 10
	@printf <"total/free Client=%lx/%lx (%lu/%lu kB)",lf>, mix.dwTotalClient, mix.dwFreeClient, eax, ecx
	mov eax, mix.dwTotalLocked
	shr eax, 10
	mov ecx, mix.dwMaxLocked
	shr ecx, 10
	@printf <"total/max locked=%lx/%lx (%lu/%lu kB)",lf>, mix.dwTotalLocked, mix.dwMaxLocked, eax, ecx
	@printf <"highest addr=%lx",lf>, mix.dwHighestAddr
	mov eax, mix.dwLargestBlock
	shr eax, 10
	@printf <"largest block=%lx (%lu kB)",lf>, mix.dwLargestBlock, eax
	@printf <"min. size=%lx",lf>, mix.dwMinSize
	@printf <"allocation unit=%lx",lf>, mix.dwAllocUnit
	ret
notsupp:
	@printf <"int 31h, ax=50Bh not supported",lf>
	ret
dispextmem endp

;--- check for vendor MS-DOS

chk2f168a proc
	push 0
	pop es
	xor edi, edi
	mov ax,168Ah
	mov esi, offset szMSDOS
	int 2Fh
	cmp al,0
	jnz failed
	@printf <"vendor 'MS-DOS' API entry: %x:%lx",lf>,es,edi
	cmp b16Bit,0
	jnz @F
	push es
	push edi
	mov ax,100h		;get LDT selector
	call far32 ptr [esp]
	lea esp, [esp+6]
	jc failed2
	jmp ok
@@:
	push es
	push di
	mov ax,100h		;get LDT selector
	mov bp,sp
	call far16 ptr [bp]
	sahf
	add sp,4
	test ah,1
	jnz failed2
ok:
	@printf <"'MS-DOS' API, ax=100h (get LDT selector): %x",lf>, ax
done:
	ret
failed:
	@printf <"no API entry for vendor 'MS-DOS' found",lf>
	ret
failed2:
	@printf <"call 'MS-DOS' API, ax=100h failed",lf>
	ret
chk2f168a endp

print_caps proc
	@printf <"capabilities: %x [">, bx
	test bl,1
	jz @F
	@printf <"paged_acc/dirty ">
@@:
	test bl,2
	jz @F
	@printf <"exc_restartability ">
@@:
	test bl,4
	jz @F
	@printf <"dev_mapping ">
@@:
	test bl,8
	jz @F
	@printf <"conv_mem_mapping ">
@@:
	test bl,16
	jz @F
	@printf <"demand_zero-fill ">
@@:
	test bl,32
	jz @F
	@printf <"write-prot_client ">
@@:
	test bl,64
	jz @F
	@printf <"write-prot_host ">
@@:
	@printf <"]",lf>
	ret
print_caps endp

;*** main for protected-mode 

do_protmode proc

	cmp wOpt, 0
	jnz @F

	@printf <"now in protected mode, client CS/SS/DS/FS/GS: %x/%x/%x/%x/%x",lf>,\
		wCSSel, wSSSel, wDSSel, wFSSel, wGSSel
	pushfd
	pop eax
	@printf <"Eflags=%lx, ES (=PSP): %x (environment: %x, parent PSP segm: %x)",lf>,\
		eax, wESSel, wEnv, wParent
	sub sp,6
	mov bp,sp
	sgdt [bp]
	@printf <"GDTR: %x.%lx">, word ptr [bp],dword ptr [bp+2]
	sidt [bp]
	@printf <" IDTR: %x.%lx">, word ptr [bp],dword ptr [bp+2]
	sldt ax
	@printf <" LDTR: %x">,ax
	str ax
	@printf <" TR: %x",lf>, ax
	add sp,6

	mov ax,0400h
	int 31h
	xchg dh,dl
	mov [wDPMIFlgs],bx
	mov [wPICs],dx
	@printf <"DPMI version flags: %x",lf>, wDPMIFlgs
	movzx ax, byte ptr wPICs+0
	movzx cx, byte ptr wPICs+1
	@printf <"master/slave PICs base: %b/%b",lf>, ax, cx
@@:
;--- get save/restore state addresses, BX:CX for rm, SI:E/DI for pm
;--- size of buffer in AX
	mov ax,305h
	int 31h
	mov [wSaveStateSize],ax
	mov word ptr [dwSaveStateRM+0],cx
	mov word ptr [dwSaveStateRM+2],bx
	.if b16Bit == 1
		mov word ptr [dwSaveStatePM+0],di
		mov word ptr [dwSaveStatePM+2],si
	.else
		mov dword ptr [dfSaveStatePM+0],edi
		mov word ptr [dfSaveStatePM+4],si
	.endif
	cmp wOpt, 0
	jnz @F
	.if b16Bit == 1
		@printf <"state save protected-mode: %x:%x">, si, di
	.else
		@printf <"state save protected-mode: %x:%lx">, si, edi
	.endif
	@printf <", real-mode: %x:%x",lf>, word ptr [dwSaveStateRM+2], word ptr [dwSaveStateRM+0]
	@printf <"size state save buffer: %u bytes",lf>, wSaveStateSize
@@:
;--- get raw mode switch addresses, BX:CX for switch to pm, SI:E/DI for switch to rm
	movzx edi,di
	mov ax,0306h
	int 31h
	mov word ptr [dwRawSwitch2PM+0],cx	;offs real (CX)
	mov word ptr [dwRawSwitch2PM+2],bx	;seg  real (BX)
	mov dword ptr [dfRawSwitch2RM+0],edi;offs prot (EDI)
	mov word ptr [dfRawSwitch2RM+4],si	;seg  prot (SI)
	cmp wOpt, 0
	jnz @F
	.if b16Bit == 1
		@printf <"raw jump to real-mode: %x:%x">, si, di
	.else
		@printf <"raw jump to real-mode: %x:%lx">, si, edi
	.endif
	@printf <", protected-mode: %x:%x",lf>, word ptr [dwRawSwitch2PM+2], word ptr [dwRawSwitch2PM+0]
@@:
;--- get memory info into es:e/di
	mov di, offset meminf
	movzx edi,di
	mov ax,0500h
	int 31h

	cmp wOpt, 0
	jnz status_displayed

	mov eax, [di.MEMINFO.maxBlock]
	shr eax, 10 						; bytes -> kBytes
	mov ecx, [di.MEMINFO.maxLockable]
	shl ecx, 2							; pages -> kBytes
	@printf <"largest free/lockable memory block (kB): %lu/%lu",lf>, eax, ecx
	mov eax, [di.MEMINFO.freeUnlocked]
	.if (eax != -1)
		shl eax,2
	.endif
	@printf <"free unlocked (=virtual) memory (kB): %lu",lf>, eax
	mov eax, [di.MEMINFO.totalAdrSpace]
	.if (eax != -1)
		shl eax,2
	.endif
	mov ecx, [di.MEMINFO.freeAdrSpace]
	.if (ecx != -1)
		shl ecx,2
	.endif
	@printf <"total/free address space (kB): %lu/%lu",lf>, eax, ecx
	mov eax, [di.MEMINFO.totalPhys]
	.if (eax != -1)
		shl eax,2
	.endif
	mov ecx, [di.MEMINFO.freePhys]
	.if (ecx != -1)
		shl ecx,2
	.endif
	@printf <"total/free physical memory (kB): %lu/%lu",lf>, eax, ecx

	mov ax,0E00h
	stc
	int 31h
	.if CARRY?
		@printf <"Int 31h, ax=0E00h (get FPU status) not supported",lf>
	.else
		@printf <'Coprocessor status: %x',lf>, ax
	.endif

;--- get dpmi 1.0 infos into es:e/di
;--- make sure the first 3 bytes are cleared, since
;--- WinXP may return with Carry cleared!

	mov di,offset buffer
	movzx edi,di
	mov word ptr [di],0
	mov byte ptr [di+2],0
	mov ax,401h
	int 31h
	jc no401
	push ax
	movzx ax, buffer+0
	movzx cx, buffer+1
	lea si, buffer+2
	@printf <"vendor: %s, version: %u.%u",lf>, si, ax, cx
	pop bx
	call print_caps
no401:
	call chk2f168a

status_displayed:
	test bOpt1, OP_ALLOC
	jz @F
	call stdalloc
@@:
	test bOpt1, OP_REALLOC
	jz @F
	call realloc
@@:
	test bOpt1, OP_LINALLOC
	jz @F
	call linalloc
@@:
	test bOpt1, OP_RMCB
	jz @F
	call rmcbtest
@@:
	test bOpt1, OP_MODESW
	jz @F
	call modeswtest
@@:
	test bOpt1, OP_CLISTI
	jz @F
	call clitest
@@:
	test bOpt1, OP_IN
	jz @F
	call inptest
@@:
	test bOpt2, OP2_NESTED
	jz @F
	call nesttest
@@:
	test bOpt2, OP2_HSFATAL
	jz @F
	call hsfatal
@@:
	test bOpt2, OP2_DESC
	jz @F
	call descalloc
@@:
	test bOpt2, OP2_EXTMEM
	jz @F
	call dispextmem
@@:
	test bOpt1, OP_SHELL
	jz @F
	call startshell
@@:
	cmp bWaitKey, 0
	jz @F
	@printf <"press a key to exit protected-mode...">
	mov ah,10h
	int 16h
	@printf <lf>
@@:
	ret
do_protmode endp

;--- main: cs,ds,ss = dgroup, es = psp

main proc c

	mov wDgrp, ds

	mov si,80h
	mov cl,es:[si]
	mov ah,0
	.while (cl)
		inc si
		mov al,es:[si]
		.if ((ah == '/') || (ah == '-'))
			or al,20h
			.if (al == 'm')
				or bOpt1, OP_ALLOC
			.elseif (al == 'n')
				or bOpt1, OP_REALLOC
			.elseif (al == 'b')
				or bOpt1, OP_RMCB
			.elseif (al == 'c')
				or bOpt1, OP_CLISTI
			.elseif (al == 'd')
				or bOpt2, OP2_DESC
			.elseif (al == 'x')
				or bOpt2, OP2_EXTMEM
			.elseif (al == 'e')
				or bOpt2, OP2_HSFATAL
			.elseif (al == 'f')
				mov bFill, 1
			.elseif (al == 'l')
				or bOpt1, OP_LINALLOC
				mov bl,16
				call getnum
				jc @F
				mov dwLinAddr, edx
@@:
			.elseif (al == 's')
				or bOpt1, OP_SHELL
				mov bl,10
				call getnum
				jc @F
				mov dwAlloc, edx
@@:
			.elseif (al == 'i')
				or bOpt1, OP_IN
				mov bl,16
				call getnum
				jc @F
				mov dwPort, edx
@@:
			.elseif (al == 'r')
				or bOpt1, OP_MODESW
			.elseif (al == 't')
				or bOpt2, OP2_NESTED
				mov bl,10
				call getnum
				jc @F
				.if edx == 0 || edx > ?MAXNEST
					@printf <"error: nesting level must be > 0 and <= %u",lf>, ?MAXNEST
					jmp pmexit
				.endif
				mov bNestLvl, dl
@@:
			.elseif ((al == '1') && (byte ptr es:[si+1] == '6') && (cl > 1))
				mov b16Bit, 1
				dec cl
				inc si
			.elseif (al == 'w')
				mov bWaitKey, 1
			.else
				mov ax, offset szHelp
				call _strout
				jmp pmexit
			.endif
		.endif
		mov ah,al
		dec cl
	.endw

	cmp wOpt, 0
	jnz main0

	smsw ax
	mov bx,CStr(<"real">)
	test al,1
	jz @F
	mov bx,CStr(<"V86">)
@@:
	@printf <"Cpu is in %s-mode",lf>, bx

	call int15mem
	call xms
	call vcpi
main0:
	mov ax,1687h				;DPMI server installed?
	int 2fh
	and ax,ax
	jnz error1
	mov [wVersion],dx			;version
	mov [wCPU],cx				;CL=prozessor
	mov [wTaskMem],si			;task memory block size in paragraphs
	mov [wFlags],bx				;flags (bit 0=32bit apps)
	mov word ptr [dwPMEntry+0],di	 ;entry protected mode
	mov word ptr [dwPMEntry+2],es

	cmp wOpt, 0
	jnz @F
	movzx ax,byte ptr wVersion+1
	movzx bx,byte ptr wVersion+0
	movzx cx,byte ptr wCPU
	@printf <"DPMI v%u.%u host found, cpu: %b, support of 32-bit clients: %x",lf>,ax,bx,cx,wFlags
	@printf <"entry initial switch to protected-mode: %x:%x",lf>, word ptr dwPMEntry+2, word ptr dwPMEntry+0
	@printf <"size task-specific memory: %u paragraphs",lf>, wTaskMem
@@:
	mov bx,[wTaskMem]
	and bx,bx
	jz main_1
	mov ax,4800h
	int 21h
	jc error2
	mov es,ax
if 0
	cmp wOpt, 0
	jnz main_1
	@printf <"segment task-specific memory: %x",lf>,ax
endif
main_1:
	movzx eax,ax	;clear register hiwords, just to be safe
	movzx edx,dx
	movzx ecx,cx
	movzx ebx,bx
	movzx esi,si
	movzx edi,di
	movzx ebp,bp	;hiword EBP must be cleared for LEAVE in 32-bit client!
	movzx esp,sp

	cmp b16Bit, 1
	jz _use16
	test byte ptr [wFlags],1    ;32-Bit apps supported?
	jnz @F
	mov b16Bit, 1
_use16:
	mov ax,0000
	call dword ptr [dwPMEntry]  ;Entry 16 Bit Client
	jc error3
	jmp displ
@@:
	mov b16Bit, 0
	mov ax,0001
	call dword ptr [dwPMEntry]  ;Entry 32 Bit Client
	jc error3

;--- now in protected mode

displ:
	mov [wDSSel],ds
	mov [wCSSel],cs
	mov [wESSel],es
	mov [wSSSel],ss
	mov [wFSSel],fs
	mov [wGSSel],gs
	mov ax,es:[002Ch]
	mov [wEnv],ax
	mov ax,es:[0016h]
	mov [wParent],ax
	push ds
	pop es

if 0	;notify real-mode debugger
	mov edi,offset rmcs
	pushf
	pop es:[edi].RMCS.rFlags
	mov es:[edi].RMCS.rSSSP,0
	mov cx,0
	mov bl,1
	mov ax,0300h
	int 31h
endif
	call do_protmode
pmexit:
	mov ax,4c00h
	int 21h
error1:
	@printf <"No DPMI host found",lf>
	jmp exit
error2:
	@printf <"No more DOS memory for DPMI initial switch",lf>
	jmp exit
error3:
	@printf <"Initial switch to protected mode failed",lf>
exit:
	ret
main endp

	.8086

Is386 proc
	pushf
	mov ah,70h
	push ax
	popf				; on a 80386 in real-mode, bits 15..12
	pushf				; should be 7, on a 8086 they are F,
	pop ax				; on a 80286 they are 0
	popf
	and ah,0F0h
	js No_386
	jz No_386
	ret
No_386:
	mov ax, CStr(<"80386 or better required",lf>)
	call _strout
	mov ax,4c01h
	int 21h

Is386 endp

;--- start program, cs = dgroup, ds,es = psp, ss = stack

start:
	push cs
	pop ds
	call Is386

	.386

;--- release memory

	mov cx,es
	mov ax,ss
	sub ax,cx
	mov bx,sp
	shr bx,4
	add bx,ax	;bx now contains new block size in paras
	push bx
	mov ah,4Ah
	int 21h
	pop bx
	sub bx,10h
	shl bx,4

;--- set CS=DS=SS=DGROUP

	push cs
	pop ds
	push ds
	pop ss
	mov sp,bx
	call main
	mov ax,4C00h
	int 21h

	END start
