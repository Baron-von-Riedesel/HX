
;*** 1. load hdpmi16.exe if no dpmi host detected
;*** 2. skip first parameter of cmdline
;*** 3. then start windows krnl386.exe

		.286
		.MODEL SMALL, stdcall
		.386
		.dosseg

?XMSHOOK	equ 0		;1 doesnt work reliably!
						;  and setting HDPMI=64 is better

		.stack 1024		;size aligned to paragraphs

		.DATA

wEnviron dw 0

parmb   label byte
envir   dw 0
pcmdl   dw 80h
seg1    dw ?
        dw 5Ch
seg2    dw ?
        dw 6Ch
seg3    dw ?

parmbs  label byte
        dw 0
        dw offset cmdline
seg1s   dw ?
        dw 5Ch
seg2s   dw ?
        dw 6Ch
seg3s   dw ?

		.const

cmdline	db 0,0Dh

szPath	db "PATH="
SIZPATH equ $ - szPath

svrname db "HDPMI16.EXE",0
SIZSVRNAME equ $ - svrname
prg     db "SYSTEM\KRNL386.EXE",0
szErr1	db "cannot launch SYSTEM\KRNL386.EXE",13,10,'$'
szErr2	db "HDPMI16.EXE not found",13,10,'$'

		.data?

szSvr	db 128 dup (?)

		.CODE

SearchPath proc
		SUB DI,DI
		MOV ES,wEnviron
nextitem:
		MOV SI,offset szPath
		MOV CX,SIZPATH
		REPZ CMPSB
		JZ found
		mov al,00
		mov ch,7Fh
		repnz scasb
		cmp al,es:[di]
		JNZ nextitem
		sub di,di
found:
		RET
SearchPath endp

SearchSvr proc

		mov DI,offset szSvr
		PUSH DS
		POP ES
nextitem:								;<----
		PUSH SI
		push es
		pop ds
		mov si,offset svrname
		mov cx,SIZSVRNAME
		rep movsb
		mov es:[di],cl

		mov DX,offset szSvr
		MOV AX,3D00h
		INT 21h
		POP SI
		JNB found						;jmp if found!
		AND SI,SI
		JZ notfound					;PATH not defined, so we are done
		MOV DI,DX
		mov ds,wEnviron
@@:
		lodsb
		stosb
		CMP AL,';'
		JZ @F
		CMP AL,00
		JNZ @B		 					;done, nothing found
		XOR SI,SI
@@:
		DEC DI
		CMP Byte Ptr es:[DI-01],'\'
		JZ nextitem
		MOV Byte Ptr es:[DI],'\'
		INC DI
		JMP nextitem
found:
		MOV BX,AX
		MOV AH,3Eh						;close file
		INT 21h
		CLC
		RET
notfound:
		STC
		RET
SearchSvr endp

if ?XMSHOOK

XMSHook proc

		jmp @F
		nop
		nop
		nop
@@:
		cmp ah,88h
		jz is88
		cmp ah,89h
		jz is89
default:
		db 0eah
oldhook	dd 0
is88:
		call cs:[oldhook]
		cmp eax,10000h
		jnc exit
		mov ah,08
		call cs:[oldhook]
		movzx eax,ax
		movzx edx,dx
exit:
		retf
is89:
		cmp edx,10000h		;is call xms 2+ compatible
		jnc default 		;no, pass thru
if 0
		call cs:[oldhook]	;first try with ah=89h
		cmp ax,1			;succeeded?
		jz exit				;then exit
endif
		mov ah,09			;try with xms 2+ call
		jmp default
XMSHook endp

PF16 typedef far16 ptr

;--- wswap graps up to 65535 kB of XMS memory
;--- and installs a XMS hook. But it doesn't understand
;--- XMS v3.0 function ah=89h and HDPMI usually uses it if
;--- a 3+ driver is installed, making both tools incompatible.
;--- this code installs another XMS hook which tries to
;--- make them work together.

InstallXMSHook proc

local	xmsaddr:PF16

		mov ax,4300h
		int 2Fh
		cmp al,80h
		jnz exit

		mov ax,4310h
		int 2Fh
		mov word ptr xmsaddr+0,bx
		mov word ptr xmsaddr+2,es
		mov ah,0
		call xmsaddr
		cmp ah,3		;is a version 3+ driver installed?
		jb exit		;no, then exit

		les bx,[xmsaddr]
@@:
		cmp byte ptr es:[bx],0EBh
		jz @F
		les bx,es:[bx+1]
		jmp @B
@@:
		mov byte ptr es:[bx+0],0EAh
		mov es:[bx+1],offset XMSHook
		mov es:[bx+3],cs
		add bx,5
		mov word ptr [oldhook+0],bx
		mov word ptr [oldhook+2],es
exit:
		ret

InstallXMSHook endp

RemoveXMSHook proc

		push cs
		pop ds
		les di,[oldhook]
		mov ax,es
		or ax,di
		jz @F
		cld
		mov si,offset XMSHook
		mov cx,5
		sub di,cx
		rep movsb
@@:
		ret

RemoveXMSHook endp

endif

main    proc c

		mov ax,es:[2Ch]
		mov wEnviron, ax

		mov word ptr seg1,es
		mov word ptr seg2,es
		mov word ptr seg3,es

		mov word ptr seg1s,ds
		mov word ptr seg2s,ds
		mov word ptr seg3s,ds

if ?XMSHOOK
		call InstallXMSHook
endif
;--------------------- load HDPMI (is a tsr) if no dpmi server present
		mov ax,1687h
		int 2fh
		and ax,ax
		jz @F
		call SearchPath
		mov si,di
		call SearchSvr
		jc error2
		mov bx,offset parmbs
		push ds
		pop es
		mov dx,offset szSvr
		mov ax,4B00h
		int 21h
		jnc @F
error2:
		mov ah,9
		mov dx,offset szErr2
		int 21h
		jmp done
@@:

;--------------------- skip first parameter of the cmdline
		pusha
		push ds
		lds si,dword ptr pcmdl
if 0
		pusha
		mov ax,3
		int 10h
		lodsb
		mov cl,al
		.while (cl)
			lodsb
			mov dl,al
			mov ah,2
			int 21h
			dec cl
		.endw
		mov dl,13
		mov ah,2
		int 21h
		mov dl,10
		mov ah,2
		int 21h
		mov ah,0
		int 16h
		popa
endif
		mov bx,si
		lodsb
		mov cl,al
		mov ch,00
		mov [bx],ch
		mov di,si
		inc cx			;copy terminating 0D as well
		mov dl,1
		.while (cx)
			lodsb
			.if (dl)
			   .if (al > ' ')
					mov dl,2
			   .elseif (dl == 2)
					mov dl,0
					dec si
					.continue
			   .endif
			.else
				mov [di],al
				inc di
				.if (al != 13)
					inc byte ptr [bx]
				.endif
			.endif
			dec cx
		.endw
		pop ds
		popa

;--------------------- now call KRNL386

		mov bx,offset parmb
		push ds
		pop es
		mov dx,offset prg
		mov ax,4B00h
		int 21h
		jnc @F
		mov ah,9
		mov dx,offset szErr1
		int 21h
@@:
done:
if ?XMSHOOK
		call RemoveXMSHook
endif
		ret

main    endp

start:
		mov ax,dgroup
		mov ds,ax
		mov cx,ss
		sub cx,ax
		shl cx,4
		push ds
		pop ss
		add sp,cx
		mov bx,ax
		mov cx,es
		sub bx,cx
		mov cx,sp
		shr cx,4
;		inc cx
		add bx,cx
;		add bx,10h
		mov ah,4Ah
		int 21h
		call main
		mov ah,4ch
		int 21h

		END start
