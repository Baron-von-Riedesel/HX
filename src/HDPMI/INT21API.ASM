
;--- implements API translation for Int 21h

		.386

		include hdpmi.inc
		include external.inc

		option proc:private

?OPTIMIZETLBCOPY = 1	;dont copy to TLB if src/dst is in dos memory already
ifndef ?LFNSUPPORT
?LFNSUPPORT      = 1	;std=1: support LFN API translation
endif

SIZE_BY_HANDLE_FILE_INFO equ 7*4 + 3*8


@seg	SEG16
@seg	_DATA16
@seg	_TEXT32

;--- the structure of the EXEC parameter block
;--- is not documented anywhere. It is the one
;--- used by Win9x, WinXP, DPMIONE and 32RTM.
;--- For 32bit there is *no* environment segment
;--- and the cmdline pointer is a QWORD.

if ?32BIT

EXECPM struct
cmdline dq ?
fcb1	dq ?
fcb2	dq ?
EXECPM ends

else

EXECPM struct
environ dw ?
cmdline dd ?
fcb1	dd ?
fcb2	dd ?
EXECPM ends

endif

EXECRM struct
environ dw ?
cmdline dd ?
fcb1	dd ?
fcb2	dd ?
res1	dd ?
res2	dd ?
EXECRM ends

if ?INT21API

_DATA16 segment

?DPBSIZE = 33	  ;DOS 4+, (DOS 3.XX 32 Bytes)

if ?SUPPDOS33
		public wDPBSize
wDPBSize	dw ?DPBSIZE
endif

execparm  EXECRM <0,120h,100h,110h,0,0>

_DATA16 ends

_TEXT32 segment

dummyfcb label byte
		db 0
		db 11 dup (' ')
		db 4 dup (0)
dummycmd db 0,cr

		align 4

;*** entry dos api translation
;--- DOS might indicate success not only with CF, but sometimes
;--- with ZF. So retf2exit has to be used!

		@ResetTrace

intr21 proc public

ife ?FASTINT21
		push offset retf2exit
else
		cmp word ptr [esp].IRET32.rCS, _CSSEL_	;is it an internal call?
		jz intr21_ 								;then dont route to ring 3
		cmp word ptr cs:int21vec._Cs,_INTSEL_	;vector modified?
		jz intr21_
		@simintpms 21
		align 4
endif
intr21 endp

intr21_ proc public
if _LTRACE_
		push offset protaftercall
endif
		cld
if ?32BIT
		@strout <"i21 bc: a-d=%X %lX %lX %lX ds=%lX es=%lX",lf>,\
			ax,ebx,ecx,edx,ds,es
;		@waitesckey
else
		@strout <"i21 bc: a=%X b=%X c=%X d=%X si=%X di=%X ds=%lX es=%lX",lf>,\
			ax,bx,cx,dx,si,di,ds,es
endif
if ?FASTINT21
		push offset retf2exit
endif
		cmp ah,74h
		jnb @F
		push ebx
		movzx ebx,ah
		push cs:[ebx*4+offset jmptab]
		mov ebx,[esp+4]
		retn 4
		align 4
@@:
ifdef _DEBUG
;------------------------- cause a protection exception in ring 0
		.if ((eax == 52637485h) && (esi == 12345678h))
			push -1
			pop ds
		.endif
endif
		call setdsreg2tlb
		call setesreg2tlb		 ;just to be sure set DS+ES=TLB
		jmp rmdos
		align 4
intr21_ endp

if _LTRACE_
protaftercall:
		@strout <"i21 ac: a-d=%X %X %X %X si=%X di=%X %lX %lX">,\
			ax,bx,cx,dx,si,di,ds,es
		pushf
		@strout <" fl=%X",lf>
;		@waitesckey
		ret
		align 4
endif

;--- DOS jump table macros

@tabentry macro function
		ifnb <function>
		 dd offset function
		else
		 dd offset rmdos
		endif
		endm

@do 	macro a,b,c,d
		@tabentry a
		@tabentry b
		@tabentry c
		@tabentry d
		endm

jmptab	label dword
		@do intr2100   ,		   ,		   ,		   ;00-03
		@do 		   ,		   ,		   ,		   ;04-07
		@do 		   ,intr2109   ,intr210A   ,		   ;08-0B
		@do intr210C   ,		   ,		   ,unsuppcall ;0C-0F
		@do unsuppcall ,intr2111   ,intr2112   ,intr2113   ;10-13
		@do unsuppcall ,unsuppcall ,unsuppcall ,unsuppcall ;14-17
		@do 		   ,		   ,intr211A   ,intr211B   ;18-1B
		@do intr211C   ,		   ,		   ,intr211F   ;1C-1F
		@do 		   ,unsuppcall ,unsuppcall ,unsuppcall ;20-23
		@do unsuppcall ,intr2125   ,		   ,unsuppcall ;24-27
		@do unsuppcall ,intr2129   ,		   ,		   ;28-2B
		@do 		   ,		   ,		   ,intr212F   ;2C-2F
		@do 		   ,		   ,intr2132   ,		   ;30-33
		@do intr2134   ,intr2135   ,		   ,		   ;34-37
		@do intr2138   ,intr2139   ,intr213A   ,intr213B   ;38-3B
		@do intr213C   ,intr213D   ,		   ,intr213F   ;3C-3F
		@do intr2140   ,intr2141   ,		   ,intr2143   ;40-43
		@do subsys44   ,		   ,		   ,intr2147   ;44-47
		@do intr2148   ,intr2149   ,intr214A   ,intr214B   ;48-4B
		@do intr214C   ,		   ,intr214E   ,intr214F   ;4C-4F
		@do intr2150   ,intr2151   ,intr2152   ,intr2153   ;50-53
		@do 		   ,intr2155   ,intr2156   ,		   ;54-57
		@do 		   ,intr2159   ,intr215A   ,intr215B   ;58-5B
		@do 		   ,subsys5d   ,subsys5e   ,		   ;5C-5F
		@do intr2160   ,		   ,intr2162   ,intr2163   ;60-63
		@do 		   ,intr2165   ,		   ,		   ;64-67
		@do 		   ,intr2169   ,		   ,		   ;68-6B
		@do intr216C   ,		   ,		   ,		   ;6C-6F
		@do 		   ,intr2171   ,		   ,intr2173   ;70-73


		@ResetTrace

else
_TEXT32 segment
intr21 proc public
		cmp ah,4Ch
		jz _exitclient_pm
		push offset retf2exit
intr21 endp
endif

rmdos proc public
		@strout <"enter rmdos call ax=%X,bx=%X,cx=%X,dx=%X",lf>,ax,bx,cx,dx
		@simrmint 21h
		ret
		align 4
rmdos endp

;--- internal dos call. make sure DS+ES do not contain ring 0 selectors

rmdosintern proc public
		push ds
		push es
		push 0
		pop ds
		push 0
		pop es
		call rmdos
		pop es
		pop ds
		ret
		align 4
rmdosintern endp

if ?INT21API

intr214C:
		jmp _exitclient_pm

;*** function 00: kill psp
;--- this terminates the current psp
;--- that is:
;--- + close open files
;*** + activate parent psp at PSP:[0016h]. may be a segment or selector.
;*** unlike the real-mode version this function returns to the caller,
;*** and the MCB of the PSP is *not* freed.
;*** to achieve this goal the int 22h vector in the current psp
;*** is set to an address which returns to protected mode. In real-mode
;*** an int 21h, ah=4Ch function is executed.

		@ResetTrace

		assume es:SEG16

intr2100:
        @strout <"i21,00: entry ebx=%lX esi=%lX edi=%lX ebp=%lX",lf>,ebx,esi,edi,ebp
		pushad
		push es

		push byte ptr _FLATSEL_
		pop es
		mov eax,ss:[dwSDA]
		movzx ebx,word ptr es:[eax+10h]	;get current psp in bx
		shl ebx,4
		mov ax,es:[ebx+16h]
		@strout <"#i21,00: parent psp value %X",lf>,bx

;--- someone may have converted the parent psp segment to a selector
;--- but now real-mode DOS will use it (and expect a segment value)
;--- so check if it is really a selector to a valid PSP
;--- and if true, transform it back to a segment

		verw ax			;is a valid data selector?
		jnz @F
		push ds
		mov ds,eax
		cmp word ptr ds:[0],20CDh	;points to a PSP?
		pop ds
		jnz @F
		push eax
		call sel2segm
		pop eax
		jc @F
		mov es:[ebx+16h],ax
@@:
		@strout <"#i21,00: will simulate a dos call 4Ch, SP=%X",lf>,sp
		mov eax, ss:[dwHostSeg]
		shl eax,16
		mov ax,offset dormintintern_rm_exit
		mov es:[ebx+000Ah], eax
		mov ax,4C00h
		call rmdos
		@strout <"#i21,00: back from real mode, sp=%X",lf>, sp

intr2100_ex:
		pop es
		popad
		@strout <"#i21,00: exit ebx=%lX esi=%lX edi=%lX ebp=%lX",lf>,ebx,esi,edi,ebp
		ret
		align 4

ife ?DTAINHOSTPSP
getDTA proc
		pushad
		mov ah,2Fh
		call rmdos
		movzx eax, ss:v86iret.rES
		shl eax, 4
		movzx ebx, bx
		add eax, ebx
		mov ss:[dwDTA], eax
		popad
		ret
		align	4
getDTA endp
endif

;*** set DTA (in DS:EDX) ***

		@ResetTrace

intr211A proc
if ?32BIT
		@strout <"i21: dta set to %lX:%lX",lf>,ds,edx
		mov dword ptr ss:[dtaadr+0],edx
else
		@strout <"i21: dta set to %lX:%X",lf>,ds,dx
		mov word ptr ss:[dtaadr+0],dx
endif
		mov word ptr ss:[dtaadr+4],ds
if ?DTAINHOSTPSP
		push edx
		call resetdta
		pop edx
else
		call getDTA	;this is needed!
endif
		ret
		align 4
intr211A endp

;*** get DTA (in ES:E/BX) ***

		@ResetTrace

intr212F proc
		mov bx,word ptr ss:[dtaadr+4]
		verr bx
		jz @F
		@strout <"i21: error - dta selector %X is invalid",lf>,bx
if ?32BIT
		xor ebx,ebx
		mov dword ptr ss:[dtaadr+0],ebx
else
		xor bx,bx
		mov word ptr ss:[dtaadr+0],bx
		mov word ptr ss:[dtaadr+2],bx
endif
		mov word ptr ss:[dtaadr+4],bx
@@:
ife ?DTAINHOSTPSP
		call getDTA
endif
if ?32BIT
		les ebx,fword ptr ss:[dtaadr]
		@strout <"i21: dta get (%lX:%lX)",lf>,es,ebx
else
		mov bx,word ptr ss:[dtaadr+0]
		mov es,word ptr ss:[dtaadr+4]
		@strout <"i21: dta get (%lX:%X)",lf>,es,bx
endif
		ret
		align 4
intr212F endp

		@ResetTrace

;--- get Interrupt vector in ES:E/BX

intr2135 proc
		push eax
		push ecx
		push edx
		mov bl,al
		mov ax,0204h
		@int_31
		mov es,ecx
if ?32BIT
		mov ebx,edx
else
		mov bx,dx
endif
		pop edx
		pop ecx
		pop eax
		ret
		align 4
intr2135 endp

;*** set interrupt vector DS:E/DX ***

intr2125 proc
		pushad
		mov ecx,ds
		mov bl,al
		mov ax,0205h
		@int_31
		popad
		ret
		align 4
intr2125 endp

;-------------------------------------------------

		@ResetTrace

intr2148 proc
		pushad
if ?32BIT
		@strout <"I21, ah=48h: alloc %lX paragraphs",lf>,ebx
		test ebx, 0F0000000h		;4 GB limit is 0FFFFFFFh paragraphs
		jnz error1
else
		@strout <"I21, ah=48h: alloc %X paragraphs",lf>,bx
		cmp bx,-1
		jz error1
		movzx ebx,bx
endif
		shl ebx,4 	;paragraphs -> bytes
		mov ebp, ebx
		push ebx
		pop cx
		pop bx
		mov ax,0501h
		@int_31
		jc error1
		@strout <"I21: memory alloc successfull, Addr=%lX",lf>,bx,cx
		push ebp		;2. argument for selector_alloc: size
		push bx
		push cx			;1. argument for selector_alloc: address
		call selector_alloc
		jc error2
		@strout <"I21: selector tiling successfull, sel=%X",lf>,ax
		mov [esp].PUSHADS.rAX, ax
		popad
		ret
error2:
		mov ax,0502h	;free memory block SI:DI
		@int_31
error1:
		popad
		jmp   availpages
		align 4
intr2148 endp

		@ResetTrace

;*** free DOS memory block in ES
;*** ES is cleared
;--- ds as well if ds == es

intr2149 proc		;DOS free memory
		pushad
		mov ebx, es
		@strout <"free dos mem block %X",lf>, bx
		mov ax, 6
		@int_31
		jc error9
		@strout <"linear address dos memory block=%lX",lf>,cx,dx
		test cx,0FFF0h	;is it conventional memory?
		jnz isextmem
		mov edx, ebx
		mov ax,0101h
		@int_31
		popad
		ret
isextmem:
		mov esi,ecx	;handle is equal to base in HDPMI
		mov edi,edx
		mov ax,0502h
		@int_31
		jc error9
		mov edx,es
		call selector_free
		popad
		ret
error9:
		popad
		mov ax,9
		stc
		ret
		align 4
intr2149 endp

;--- return error 8 and available paragraphs in E/BX

availpages proc
		push ds
		pushad
		push ss
		pop ds
		call _GetNumPhysPages
		sub eax, ecx
		shl eax,8			;pages -> paras
if ?32BIT
		mov [esp].PUSHADS.rEBX,eax
else
		cmp eax,0FFFFh
		jc @F
		mov ax,0FFFEh		;5.6.2004: changed from FFF0h
@@:
		mov [esp].PUSHADS.rBX,ax
endif
		popad
		pop ds
		mov ax,8			;not enough memory
		stc
		ret
		align 4
availpages endp

		@ResetTrace

;--- int 21h, ah=4A, resize memory block
;--- block in ES, new size in E/BX

intr214A proc

		pushad
		@strout <"memselresize: es=%lX, ebx=%lX",lf>, es, ebx
		mov ebx, es
		mov ax, 6
		@int_31
		jc error9
		@strout <"memselresize: selector is valid",lf>
		test cx,0FFF0h	;is it conventional memory?
		jnz isextmem
		mov edx, ebx
		mov ebx, [esp].PUSHADS.rEBX
		mov ax,0102h
		@int_31
		jc @F
		popad
		ret
@@:
		mov word ptr [esp].PUSHADS.rEAX,ax
		mov word ptr [esp].PUSHADS.rEBX,bx
		popad
		ret
isextmem:
		mov esi,ecx	;handle is base in HDPMI
		mov edi,edx
if ?32BIT
		mov ebx, [esp].PUSHADS.rEBX
		test ebx, 0F0000000h
		jnz error8
else
		movzx ebx, [esp].PUSHADS.rBX
endif
		shl ebx,4			;paras -> bytes
ife ?32BIT
		mov edx,es
		call selector_avail	;check if enough free selectors are available
		jc error8			;to map the new size of the block
endif
		push ebx
		pop cx
		pop bx
		mov ax,0503h
		@int_31
		jc error8
		@strout <"memselresize: resizemem succeeded, base=%lX",lf>,cx,bx
		mov edx, ecx
		mov ecx, ebx
		mov ebx, es
		mov ax, 7 			;set segment base
		@int_31
		@strout <"memselresize: base set for %X",lf>, es
if ?32BIT
		mov eax, [esp].PUSHADS.rEBX
else
		movzx eax, [esp].PUSHADS.rBX
endif
		shl eax, 4
		mov edx, es
		call selector_resize	;adjust selector array (should not fail)
		jc error8      	;out of selectors! (16bit only)
		popad
		ret
error9:
		popad
		mov ax,9
		ret
error8:
		popad
		jmp availpages

		align 4
intr214A endp

;-------------------------------------------------------------
resetdta proc public
if ?DTAINHOSTPSP
		mov dx,ss:[wHostPSP]
		mov ss:[v86iret.rDS],dx
		mov dx,0080h
		mov ah,1Ah
		jmp rmdos
else
		call getDTA
		ret
endif
		align 4
resetdta endp

		@ResetTrace

;--- int 21h, ah=4Bh
;--- preserves all registers except AX

intr214B proc
		pushad
		push ds
		push es
if ?32BIT
		@strout <"I21: ax=%X ds:edx=%lX:%lX, es:ebx=%lX:%lX",lf>,ax,ds,edx,es,ebx
		@strout <"   cmdl=%X:%lX">,\
			< word ptr es:[ebx].EXECPM.cmdline+4>,\
			<dword ptr es:[ebx].EXECPM.cmdline+0>
		@strout <" fcb1=%X:%lX">,\
			< word ptr es:[ebx].EXECPM.fcb1+4>,\
			<dword ptr es:[ebx].EXECPM.fcb1+0>
		@strout <" fcb2=%X:%lX",lf>,\
			< word ptr es:[ebx].EXECPM.fcb2+4>,\
			<dword ptr es:[ebx].EXECPM.fcb2+0>
		push dword ptr es:[ebx].EXECPM.cmdline+4
		push dword ptr es:[ebx].EXECPM.cmdline+0
		push dword ptr es:[ebx].EXECPM.fcb2+4
		push dword ptr es:[ebx].EXECPM.fcb2+0
		push dword ptr es:[ebx].EXECPM.fcb1+4
		push dword ptr es:[ebx].EXECPM.fcb1+0
else
		movzx ebx,bx
		@strout <"I21: ax=%X ds:dx=%lX:%X, es:bx=%lX:%X",lf>,ax,ds,dx,es,bx
		push dword ptr es:[ebx].EXECPM.cmdline
		push dword ptr es:[ebx].EXECPM.fcb2
		push dword ptr es:[ebx].EXECPM.fcb1
endif
		mov cl,2
		movzx ecx,cl
		mov edi,100h	   ;destination is TLB.100h
		push byte ptr _TLBSEL_
		pop es
nextfcb:
if ?32BIT
		pop esi
		pop eax
else
		pop si
		movzx esi, si
		pop ax
endif
		verr ax
		jz @F
		mov esi, offset dummyfcb
		mov eax, cs
@@:
		mov ds,eax
		movsd
		movsd
		movsd
		movsd
		dec cl
		jnz nextfcb
if ?32BIT
		pop esi
		pop eax
else
		pop si
		pop ax
endif
        verr ax
		jz @F
		mov esi, offset dummycmd
		mov eax, cs
@@:
		mov ds,eax
		mov cl,[esi]
		inc cl
		inc cl
		rep movsb

		push ss
		pop ds
		assume ds:GROUP16
		mov ax,[wSegTLB]
		mov word ptr [execparm.fcb1+2],ax
		mov word ptr [execparm.fcb2+2],ax
		mov word ptr [execparm.cmdline+2],ax

		pop es

if ?32BIT
  if 1
		call getrmenv		 ;get current environment
  else
		xor eax,eax
  endif
		mov word ptr [execparm.environ],ax
else
		;for 16-bit, environment is included
		;in parameter block. must be a real mode
		;segment, though
		mov bx,es:[bx].EXECPM.environ
		verr bx
		jnz @F
		call bx_sel2segm
		jnc EnvIsValid
@@:
		call getrmenv		;get current environment
		mov bx, ax
EnvIsValid:
		mov word ptr [execparm.environ], bx
endif
		pop ds
if ?32BIT
		@strout <"I21: ah=4Bh ds:edx=%ls",lf>,ds,edx
else
		@strout <"I21: ah=4Bh ds:dx=%s",lf>,ds,dx
endif
		call copyz_dsdx_2_tlb	;DS:(E)DX -> tlb:0, dx=0

		call _freephysmem		;in int15-mode, release some ext memory

		mov bx,offset execparm

		mov eax,ss:[dwHostSeg]
		mov ss:[v86iret.rES], ax

		@strout <"  ds:dx=%X:%X es:bx=%X:%X [env=%X cmdl=%X:%X]",lf>,\
				ss:[v86iret.rDS], dx, ss:[v86iret.rES], bx, ss:[bx].EXECRM.environ,\
				<word ptr ss:[bx].EXECRM.cmdline+2>,<word ptr ss:[bx].EXECRM.cmdline+0>
if _LTRACE_
		push ds
		push byte ptr _TLBSEL_
		pop ds
		@strout <"[cmdline]=%lX %lX %lX",lf>,<dword ptr ds:[120h]>,\
				<dword ptr ds:[124h]>,<dword ptr ds:[128h]>
		pop ds
endif
;		 @waitesckey
		mov eax,[esp].PUSHADS.rEAX
if ?32BIT
		movzx edx, dx
		movzx ebx, bx
		movzx esi, si
		movzx edi, di
endif
		call rmdos
		mov [esp].PUSHADS.rAX,ax
		pushfd
		call resetdta
		call _restorephysmem
		popfd
		popad
		ret
		align 4
intr214B endp

		@ResetTrace

intr2155 proc
		push edx
		push ebx
		mov ebx,edx			 ;BX=PSP selector
		call bx_sel2segm		 ;-> segment
		jc psperror
		call setpspsel		 ;save selector in cache
		mov edx,ebx
		pop ebx
		call rmdos
		pop edx
		ret
psperror:
		pop ebx
		pop edx
		ret
;		push _EAERR5_
;		jmp fataldosexit
		align 4
intr2155 endp

		@ResetTrace

intr2150 proc
		@strout <"I21: ah=50h, bx=%X",lf>,bx
		push ebx
		call bx_sel2segm
		jc psperror1
		call rmdos
		pop ebx
		ret
psperror1:
		pop ebx
		ret
;		push _EAERR7_
;		jmp fataldosexit
		align 4
intr2150 endp

		@ResetTrace

intr2147 proc
		call setdsreg2tlb	;set v86-ds to TLB
		push esi
		xor esi,esi
		call rmdos
		pop esi
		jc @F
		call copyz_tlb_2_dssi
@@:
		ret
intr2147 endp

intr210C:
		cmp al,0Ah			;only translate the buffered input
		jnz rmdos

intr210A proc
		push ecx
		push edx
ife ?32BIT
		movzx edx,dx
endif
		mov cl,[edx]
		mov ch,00
		inc ecx
		call copy_dsdx_2_tlb ;copy CX bytes to TLB:0
		xor edx,edx
		call rmdos
		pop edx
		push ds
		push byte ptr _TLBSEL_
		pop ds
		mov cl,ds:[0]
		mov ch,0
		pop ds
		inc ecx				;also copy length + 0D
		inc ecx
		call copy_tlb_2_dsdx
@@:
		pop ecx
		ret
		align 4
intr210A endp

;*** 09: write string to stdout ***

intr2109:
		push edx
		call setdsreg2tlb
		call copy$_dsdx_2_tlb
		xor edx,edx
		call rmdos
		pop edx
		ret
		align 4

;*** copy asciiz string from ds:dx to tlb:0
;*** functions:
;*** 39: create dir
;*** 3A: delete dir
;*** 3B: change dir
;*** 3C: create file
;*** 3D: open file
;*** 41: delete file
;*** 43: get file attributes/get compressed file size
;*** 5A: create temp file
;*** 5B: create new file

		@ResetTrace

intr2139:
intr213A:
intr213B:
intr213C:
intr213D:
intr2141:
intr2143:
intr215A:
intr215B:
if ?32BIT
		@strout <"int 21,ax=%X ds:edx=%ls",lf>,ax,ds,edx
else
		@strout <"int 21,ax=%X ds:dx=%s",lf>,ax,ds,dx
endif
		push edx
		call copyz_dsdx_2_tlb
		call rmdos
		pop edx
		ret

		@ResetTrace

;--- copy country infos (34 bytes) to ds:e/dx

intr2138 proc
		cmp dx,0FFFFh	;if dx == -1, it is SET, not GET infos
		jz rmdos
		push edx
		xor edx,edx
		call setdsreg2tlb
		call rmdos
		pop edx
		jc @F
		push ecx
		mov cx,32		;size is 34, but last 10 bytes aren't used
		call copy_tlb_2_dsdx
		pop ecx
		clc
@@:
		ret
intr2138 endp

;--- get/set extended country infos
;---- AL=0 -> get data, al!=0 -> set data
;---- buffer is es:di, cx is size of buffer

		@ResetTrace

intr2165 proc
		@strout <"int 21,ax=%X es:edi=%X:%lX",lf>,ax,es,edi
		and al,al
		jz intr216500
		cmp al,7
		jbe intr21650107
		push eax
		and al,7Fh
		cmp al,21h
		jz intr216521
		cmp al,22h
		pop eax
		jz intr216522
		jmp rmdos
intr21650107:
		push edi
		call setesreg2tlb
		xor edi,edi			;set es:di to TLB:0
		call rmdos
		pop edi
		jc @F
		call copy_tlb_2_esdi	;size has been returned in CX
@@:
		ret
intr216500:						;set country info (ES:E/DI, size CX)
		push edi
		call copy_esdi_2_tlb	;copy cx bytes to tlb, set es to TLB
		xor edi,edi
		call rmdos
		pop edi
		ret
intr216521::					;capitalize string DS:E/DX, size CX
		pop eax
		call copy_dsdx_2_tlb
		push edx
		xor edx,edx
		call rmdos
		pop edx
		jc @F
		call copy_tlb_2_dsdx	;copy CX bytes back to DS:E/DX
@@:
		ret
intr216522:						;capitalize asciiz in DS:E/DX
		push edx
		call copyz_dsdx_2_tlb
		call rmdos
		pop edx
		jc @F
		call copyz_tlb_2_dsdx
@@:
		ret
intr2165 endp

;*** 56: rename file ***
;	  (DS:DX -> ES:DI)

		@ResetTrace

intr2156 proc
		push edi
		push edx
		call copyz_dsdx_2_tlb

		push es
if ?32BIT
		push edi
else
		push word ptr 0
		push di
endif
		mov edi,100h
		push edi
		call copyz_far32_2_tlbxx
		call setesreg2tlb
		call rmdos
		pop edx
		pop edi
		ret
		align 4
intr2156 endp

;*** get true filename ***

intr2160 proc
		push edi
		push esi
		call copyz_dssi_2_tlb	  ;si=0, v86iret.ds=tlb
		call setesreg2tlb
		mov di,100h
		call rmdos
		pop esi
		pop edi
		jc @F
		push es
if ?32BIT
		push edi
else
		push word ptr 0
		push di
endif
		push 100h
		call copyz_tlbxx_2_far32
@@:
		ret
		align 4
intr2160 endp

;*** 6C: open file ***

		@ResetTrace

intr216C proc
if ?32BIT
		@strout <"int 21,ax=%X ds:esi=%ls ">,ax,ds,esi
else
		@strout <"int 21,ax=%X ds:si=%s" >,ax,ds,si
endif
		push esi
		call copyz_dssi_2_tlb	   ;si=0,v86iret.ds = tlb
		call rmdos
		pop esi
		@strout <"ret ax=%X",lf>,ax
		ret
		align 4
intr216C endp

;*** 4E: find first entry

intr214E proc
		push edx
		call copyz_dsdx_2_tlb
		call rmdos
		pop edx
		jc @F
		push 43
		call copy_tlbdta_2_dta
@@:
		ret
		align 4
intr214E endp

;*** 4F: find next entry

intr214F proc
		push 43
		call copy_dta_2_tlbdta
		call rmdos
		jc @F
		push 43
		call copy_tlbdta_2_dta
@@:
		ret
intr214F endp


;*** here start the functions which need more complex translation


;*** 29 -> FCB parse ***
;*** DS:E/SI -> asciiz
;--- ES:E/DI -> 37 byte (unopened FCB)

;--- copy string to TLB:0
;--- copy FCB to TLB:100h

;--- after the dos call copy FCB back to es:e/di
;--- and DS:ESI should point at the first byte *not* interpreted!

		@ResetTrace

intr2129 proc
if ?32BIT
		@strout <"fcb parse with fcb=%lX:%lX, name=%lX:%lX",lf>,es,edi,ds,esi
else
		@strout <"fcb parse with fcb=%lX:%X, name=%lX:%X",lf>,es,di,ds,si
endif

		push esi
		push edi

		call copyz_dssi_2_tlb	;sets v86-ds to TLB, si=0

		push es
if ?32BIT
		push edi
else
		push word ptr 0
		push di
endif
		mov edi,100h
		push edi 
		push 37
		call copy_far32_2_tlbxx	;copy 37 bytes to TLB:100h
		call setesreg2tlb

		call rmdos

		pushfd
		movzx esi,si
		add [esp+8],esi		;adjust client ESI
		popfd

		pop edi
		pop esi

		pushfd
		push word ptr 37
		push word ptr 100h
		call copy_tlbxx_2_esdi
		popfd
		ret
		align 4
intr2129 endp

		@ResetTrace

checkfileparams proc
		push eax
if ?32BIT
		lea eax, [ecx+edx]
		cmp eax,010000h+1	;offset + bytes must not exceed 64 kB
		jnc @F
endif
		push ds
		call getlinaddr		;get linear address of DS
		jc @F
		test eax,0FFF00000h
		jnz @F
		shr eax,4
		mov dword ptr ss:[v86iret.rDS], eax
		@strout <"no TLB needed for read/write (%lX addr, %X size)",lf>,eax,cx
		pop eax
		add esp,4			;dont return
		jmp rmdos
@@:
		pop eax
		ret
		align 4
checkfileparams endp


;*** 3F -> read file BX, (E)CX bytes into DS:(E)DX ***

		@ResetTrace

intr213F proc
if ?OPTIMIZETLBCOPY
		call checkfileparams
endif
		pushad
ife ?32BIT
		movzx edx,dx
		movzx ecx,cx
endif
		mov ebp,?TLBSIZE
		mov si,ss:[wSegTLB]
if ?DYNTLBALLOC
		cmp ecx,ebp
		jbe @F
		call _AllocDosMemory
		jc @F
		mov bp,?DYNTLBSIZE
		shr edi,4
		mov esi,edi
@@:
endif
		@strout <"start read at %lX:%lX,%lX bytes using %X",lf>,ds,edx,ecx,si
		xor edi,edi 	 ;edi is used to count bytes written
nextblock:
		mov eax,[esp].PUSHADS.rEAX
		push ecx
		push edx
		cmp ecx,ebp
		jb @F
		mov ecx,ebp
@@:
		mov dword ptr ss:[v86iret.rDS],esi
		xor edx,edx
		@strout <"  call rm dos, read (ax=%X) in TLB (=%X:%X) %X bytes",lf>,ax,si,dx,cx
		call rmdos
		pop edx
		pop ecx
		jc intr213FB
		and ax,ax
		jz intr213F_1
		push ecx
		movzx ecx,ax	;copy bytes read to ecx
		add edi,ecx 	;update byte count

		@strout <"  copying from %X to %lX:%lX %X bytes",lf>,si,ds,edx,cx

		push ds
		push edx
		push esi
		call copy_flat_2_far32

		add edx,ecx 	 ;now update  ^ buffer pointer

		pop ecx
		cmp ax,bp		 ;if  AX <> BP we're done
		jnz intr213F_1
		sub ecx,ebp
		ja nextblock
intr213F_1:
		clc
if ?32BIT
		mov eax,edi
else
		mov ax,di
endif
intr213FB:
intr213F_er:
if ?32BIT
		mov [esp].PUSHADS.rEAX,eax
else
		mov [esp].PUSHADS.rAX,ax
endif
if ?DYNTLBALLOC
		pushfd
		cmp bp,?TLBSIZE
		jz @F
		call _FreeDosMemory
@@:        
        popfd
endif
		popad
		ret
		align 4
intr213F endp

;*** 40 -> write file BX (E)CX bytes from DS:(E)DX ***

		@ResetTrace

intr2140 proc
if ?OPTIMIZETLBCOPY
		call checkfileparams
endif
		pushad
ife ?32BIT
		movzx edx,dx
		movzx ecx,cx
endif
		mov ebp,?TLBSIZE
		mov si,ss:[wSegTLB]
if ?DYNTLBALLOC
		cmp ecx,ebp
		jbe @F
		call _AllocDosMemory
		jc @F
		mov bp,?DYNTLBSIZE
		shr edi,4
		mov esi,edi
@@:
endif
		@strout <"start write at %lX:%lX,%lX bytes using %X",lf>,ds,edx,ecx,si
		xor edi,edi 	 ;EDI is used to count bytes written
intr2140A:				 ;<----
		mov eax, [esp].PUSHADS.rEAX
		push ecx
		cmp ecx,ebp
		jb @F
		mov ecx,ebp
@@:
		@strout <"  copying from %lX:%lX to TLB %X bytes",lf>,ds,edx,cx

		push edx

		push ds
		push edx
		push esi
		call copy_far32_2_flat

		xor edx,edx
		mov dword ptr ss:[v86iret.rDS],esi
		call rmdos
		pop edx
		pop ecx
		jc fail
		movzx eax,ax	;bytes written
		add edi,eax		;update byte count
		add edx,eax		;update source ptr
		sub ecx,ebp
		ja intr2140A	;if > TLB another loop is required!
		clc
if ?32BIT
		mov eax,edi
else
		mov ax,di
endif
fail:
if ?32BIT
		mov [esp].PUSHADS.rEAX,eax
else
		mov [esp].PUSHADS.rAX,ax
endif
if ?DYNTLBALLOC
		pushfd
		cmp bp,?TLBSIZE
		jz @F
		call _FreeDosMemory
@@:
        popfd
endif
		popad
		ret
		align 4
intr2140 endp

;*** translate bios parameter block to drive parameter block
;*** inp: DS:SI -> bios parameter block
;*** out: ES:BP -> drive parameter block

		@ResetTrace

?BPBSIZE = 36	  ;

intr2153 proc
		push esi
		push edx
		push ecx
		mov edx,esi
		mov cx,?BPBSIZE
		call copy_dsdx_2_tlb
		call setesreg2tlb
		pop ecx
		pop edx
		push ebp
		mov ebp,100h
if 1
		push ds
		push byte ptr _TLBSEL_
		pop ds
		mov word ptr ds:[ebp],0	  ;die ersten 2 bytes werden nicht init.
		pop ds
endif
		mov si,0000
		call rmdos
		pop ebp
		pop esi
        
		pushfd
		push edi
		mov edi, ebp
if ?SUPPDOS33
		push word ptr ss:[wDPBSize]
else
		push word ptr ?DPBSIZE
endif
		push word ptr 100h
		call copy_tlbxx_2_esdi
		pop edi
		popfd
		ret
		align 4
intr2153 endp

;*** Subsystem AH=44h ***

		@ResetTrace

subsys44 proc
		cmp al,2
		jb rmdos	;00/01 ok
		jz f4402
		cmp al,4
		jb f4403
		jz f4404
		cmp al,5
		jz f4405
		cmp al,0Ch
		jb rmdos	;06/07/08/09/0A/0B ok
		jz f440C
		cmp al,0Eh
		jb intr21440D
		jmp rmdos	;0E/0F/10/11 ok

f4402:				;read ioctrl
f4404:				;read ioblock
		push edx
		call copy_dsdx_2_tlb
		xor edx,edx
		call rmdos
		pop edx
		jc @F
		push ecx
		mov ecx,eax
		call copy_tlb_2_dsdx
		pop ecx
@@:
		ret
f4403:				;write ioctrl
f4405:				;write ioblock
		push edx
		call copy_dsdx_2_tlb
		xor edx,edx
		call rmdos
		pop edx
		ret

;*** AX=440Ch (generic character device request) ***

f440C:
		jmp unsuppcall

subsys44 endp

;*** AX=440Dh Subsystem (generic block device request) ***
;*** BL=drive#, CL=minor code ,CH=8 -> fixed disk ***
;*** DOS 3.2+
;*** 40h set device parameters (38+[38]*4+2)
;*** 41h write track
;*** 42h format track
;*** 60h get device parameters (38)
;*** 61h read track
;*** 62h verify track
;*** DOS 4.0+
;*** 46h set volume serial#
;*** 47h set access flag
;*** 66h get volume serial#
;*** 67h get access flag
;*** DOS 5.0+
;*** 68h sense media type
;*** 5xh,7xh -> PCMCIA
;*** DOS 7.0+
;*** 4Ah lock/unlock drive (no translation required)
;--- 6Dh enumerate open files
;--- 6Eh find swap file

		@ResetTrace

intr21440D proc

		@strout <"I21: call AX=%X,BX=%X,CX=%X,DX=%X",lf>,ax,bx,cx,dx
		push esi
		cmp cl,40h
		jnz not440D40
if ?32BIT
		mov ax,[edx+38]
else
		mov si,dx
		mov ax,[si+38]
endif
		shl ax,2
		add ax,38+2
		pop esi
		jmp f440D_ok1
f440D_notrans:
		call setdsreg2tlb	;just to be safe
		mov ax,440Dh
		pop esi
		jmp rmdos
not440D40:
		mov esi,offset tab440D
@@:
		db 2Eh			;CS prefix
		lodsw
		cmp al,-1
;;  	jz f440D_er	;why error? in this case just no translation!
		jz f440D_notrans
		cmp al,cl
		jnz @B
		pop esi
		mov al,ah
		mov ah,00
f440D_ok1:
		push ecx
		mov ecx,eax
		@strout <"I21: func 440d: copy %X bytes to tlb",lf>,cx
		call copy_dsdx_2_tlb
		pop ecx
		cmp cl,41h
		jnz @F
		call f440D41b
@@:
		cmp cl,61h
		jnz @F
		call f440D61b
@@:
		call setdsreg2tlb
		push edx
		xor edx,edx
		mov ax,440Dh
		call rmdos
		pop edx
		jc error
		push esi
		mov esi,offset tab440D2
@@:
		cmp byte ptr cs:[esi],-1
		jz f440D2_ok2
		cmp cl,cs:[esi]
		jz f440D2_ok
		inc esi
		inc esi
		jmp @B
f440D2_ok:
		push ecx
		movzx cx,byte ptr cs:[esi+1]
		@strout <"I21: func 440d: copy %X bytes from tlb",lf>,cx
		call copy_tlb_2_dsdx
		pop ecx
f440D2_ok2:
		pop esi
		cmp cl,61h
		jnz @F
		call f440D61a
@@:
		clc
error:
		ret

LOGTRACKPARM struct
special	db ?
head	dw ?
cyl		dw ?
sector	dw ?
numsecs	dw ?
dta		dd ?			;this is a FAR16 address!
LOGTRACKPARM ends

;--- prepare read track. set

f440D61b:
		@strout <"I21: func 440d,41+61: set transfer buffer to rm",lf>
		push ds
		push byte ptr _TLBSEL_
		pop ds
		push word ptr ss:[wSegTLB]
		push word ptr 0020h
		pop dword ptr ds:[LOGTRACKPARM.dta]
		pop ds
		ret

;--- write track: copy [DS:E/DX+9] -> TLB.20

f440D41b:
		call f440D61b

		pushad					 ;copy track [DS:DX+9] -> TLB
		push ds
		push es
ife ?32BIT
		movzx edx,dx
endif
		movzx ecx,[edx].LOGTRACKPARM.numsecs
		lds si,[edx].LOGTRACKPARM.dta
		movzx esi, si
		shl ecx,9			 ;sectors -> bytes
		@strout <"I21: func 440d,41: copy %lX bytes to tlb.20",lf>,ecx
		push byte ptr _TLBSEL_
		pop es
		mov edi,20h
		rep movsb

		pop es
		pop ds
		popad
		ret
        
;--- read track. copy TLB.20 -> [DS:E/DX+9]

f440D61a:
		pushad
		push ds
		push es
ife ?32BIT
		movzx edx, dx
endif
		movzx ecx,[edx].LOGTRACKPARM.numsecs
		les di,[edx].LOGTRACKPARM.dta
		movzx edi, di
		shl ecx,9			 ;sektors -> bytes
		@strout <"I21: func 440d,11: copy %X bytes from tlb.20",lf>,cx
		push byte ptr _TLBSEL_
		pop ds
		mov esi,20h
		rep movsb

		pop es
		pop ds
		popad
		ret

;--- table of int 21h, ax=440D, subfunction CL
;--- bytes to copy from DS:E/DX

tab440D label byte
		db 41h,13
		db 42h,4
		db 46h,25
		db 47h,2
		db 60h,38
		db 61h,13
		db 62h,4
		db 66h,25
		db 67h,2
		db 68h,2
		db -1

;--- table of int 21h, ax=440D, subfunction CL
;--- bytes to copy back to DS:E/DX

tab440D2 label byte
		db 60h,38
		db 61h,13-4
		db 62h,4
		db 66h,25
		db 67h,2
		db 68h,2
;		db 6Dh,255		;enum open files
;		db 6Eh,255		;find swap file path
		db -1h

intr21440D endp

;*** Subsystem AH=5Dh - server function call ***

		@ResetTrace

subsys5d proc
		cmp al,6			;get address of SDA?
		jb error			;0,1,2,3,4,5
		jz f5d06			;6
		cmp al,0Ah   		;7,8,9 ist ok
		jb rmdos
		ja error
		push ecx				;0Ah: set extended error info
		mov cx,22
		call copy_dsdx_2_tlb
		pop ecx
		push edx
		xor edx,edx
		call rmdos
		pop edx
		ret
f5d06:
		call rmdos		;get SDA in DS:E/SI
		jmp ds_segm2sel ;no need to clear HIWORD(esi)!
error:
		jmp unsuppcall

subsys5d endp

;*** Subsystem AH=5Eh - network ***

		@ResetTrace

subsys5e proc
		cmp al,0
		jnz rmdos
;;		jz f5e00
f5e00:
		push edx
		call setdsreg2tlb
		xor edx,edx
		push ds
		push byte ptr _TLBSEL_
		pop ds
		mov ds:[0010h],dl
		pop ds
		call rmdos
		pop edx
		jc @F
		push esi
		mov esi,edx
		call copyz_tlb_2_dssi ;copy to DS:(E)SI
		pop esi
@@:
		ret
subsys5e endp

;*** subsystem FCBs 0Fh-17h ***

		@ResetTrace

intr210F:
intr2110:
intr2114:
intr2115:
intr2116:
intr2117:
unsuppcall:
		push 21h
		call unsupp
		stc
		ret
intr2111:
intr2112:
intr2113:							   ;ds:dx -> fcb
		push ecx
		push edx
		mov cx,0025h			   ;size of "normal fcb" is 37 bytes
ife ?32BIT
		movzx edx,dx
endif
		cmp byte ptr [edx],0FFh	   ;extended fcb?
		jnz @F
		mov cl,25h+7			   ;then size 44 bytes
@@:
		push ecx
		call copy_dsdx_2_tlb 	   ;copy cx bytes to tlb:0
		xor edx,edx
		call rmdos
		pop ecx
		pop edx
		call copy_tlb_2_dsdx 	   ;copy back! - may have been modified
		cmp al,0FFh 			   ;error?
		jz @F
;		@strout <"I21: fcb call was successful",lf>
		push word ptr 0
		push cx
		call copy_tlbdta_2_dta	   ;copy cx bytes tlbdta -> dta
@@:
		pop ecx
		ret

;*** 1B: get actual drive info DS:E/BX
;*** 1C: get drive info DS:E/BX
;*** 1F: get DPB for default drive in DS:E/BX
;*** 32: get DPB for drive in DL in DS:E/BX

		@ResetTrace

intr211B:
intr211C:
intr211F:
intr2132:
		@strout <"I21: ax=%X,dx=%X",lf>,ax,dx
		call rmdos
;--- al=FF indicates error, set Carry flag then
		@strout <"I21: ret, ax=%X, rmDS:bx=%X:%X",lf>,ax,ss:[v86iret.rDS],bx
		cmp al,0FFh
		jz @F
		call ds_segm2sel
		@strout <"I21: ds=%X translated to %lX",lf>,ss:[v86iret.rDS],ds
if ?32BIT
		movzx ebx,bx
endif
		clc
		ret
@@:
		stc
		ret

;*** 34: indos flag (ES:BX) ***
;*** 52: get ListofList (ES:BX) ***

		@ResetTrace

intr2134:
intr2152:
		call rmdos
		call es_segm2sel
if ?32BIT
		movzx ebx,bx
endif
		ret
		align 4

;*** 51: get psp (BX) ***
;*** 62: get psp (BX) ***

intr2151:
intr2162:
		call rmdos
		call getpspsel
		ret

;*** get extended error info (ES:DI]
;--- this call may modify v86.rES to 0000

intr2159 proc
		call rmdos
		pushfd
		cmp al,22h		;for this code a pointer is in es:e/di
		jnz @F
		call es_segm2sel
@@:
		popfd
		ret
intr2159 endp

;--- get DBCS table in DS:E/SI

intr2163 proc
		cmp al,0
		jnz rmdos
		call rmdos
;		jc @F				;test for Carry may not work for 21,6300!!!
		pushfd
		cmp al,0
		jnz @F
		call ds_segm2sel
if ?32BIT
		movzx esi,si
endif
@@:
		popfd
		ret
intr2163 endp

;--- get/set disk serial number

intr2169 proc
		push ecx
		mov cx,25
		call intr216521
		pop ecx
		ret
		align 4
intr2169 endp

;*** long filename functions
;*** these arent supported from real mode dos, but
;*** for tracing its good to implement it
;*** and there exist real mode drivers LFNDOS/DOSLFN, which
;*** implements these functions in real dos

		@ResetTrace

if ?LFNSUPPORT

int2171a7 proc
		cmp bl,1
		jz @F
		push esi
		call setdsreg2tlb
		push es
if ?32BIT
		push esi
else
		push word ptr 0
		push si
endif
		xor esi, esi
		push esi
		push sizeof QWORD
		call copy_far32_2_tlbxx	;copy 37 bytes to TLB:100h
		call rmdoswithcarry
		pop esi
		ret
@@:
		push edi
		call setesreg2tlb
		xor edi, edi
		call rmdoswithcarry
		pop edi
		jc @F
		push word ptr sizeof QWORD
		push word ptr 0
		call copy_tlbxx_2_esdi
@@:
		ret
int2171a7 endp

;--- bh=0 -> ds:edx -> tlb:0
;--- bh=2 -> tlb:0 -> ds:edx
        
int2171aa proc
		@strout <"int 21,ax=71AA",lf>
		cmp bh,0
		jz copyz_dsdx
		cmp bh,2
		jnz rmdoswithcarry
		push edx
		call setdsreg2tlb
		call rmdoswithcarry
		pop edx
		jc @F
		call copyz_tlb_2_dsdx
@@:
		ret
		align 4
int2171aa endp

;--- int 21, ax=7139 | 713A | 713B | 7141 | 7143        
        
copyz_dsdx proc
if ?32BIT
		@strout <"int 21,ax=%X ds:edx=%ls",lf>,ax,ds,edx
else
		@strout <"int 21,ax=%X ds:dx=%s",lf>,ax,ds,dx
endif
		push edx
		call copyz_dsdx_2_tlb
		call rmdoswithcarry
		pop edx
		ret
		align 4
copyz_dsdx endp


endif

intr2171 proc
if ?LFNSUPPORT
		test ss:[bEnvFlags], ENVF_NOLFN
		jnz unsupp71
		cmp al,39h
		jb rmdoswithcarry
		cmp al,3bh		;39/3a/3b create/remove/change dir
		jbe copyz_dsdx
		cmp al,41h		;delete file
		JZ copyz_dsdx
		cmp al,43h		;get/set file attr
		JZ copyz_dsdx
		cmp al,47h		;get cur dir
		jz int217147
		cmp al,4Eh		;get first file  
		jz int21714e
		cmp al,4Fh		;get next file
		jz int21714f
		cmp al,56h		;rename file
		jz int217156
		cmp al,60h		;get canonical form
		jz int217160
		cmp al,6ch		;create/open file
		jz int21716c
		cmp al,0A0h		;get volume info
		jz int2171a0
		cmp al,0A2h		;same as 714F
		jz int2171a2
		cmp al,0A6h		;get file info by handle
		jz int2171a6
		cmp al,0A7h		;file time to dos time/dos time to file time
		jz int2171a7
		cmp al,0A8h		;generate short filename
		jz int2171a8
		cmp al,0AAh		;subst
		jz int2171aa
		jb rmdoswithcarry
unsupp71:				;A0, A7, A8, A9, AA
		mov al,00
		stc
		ret
		align 4
rmdoswithcarry::
		stc
		jmp rmdos
		align 4

intr2171 endp

;--- int 21, ax=716C (open file)        
;--- translate ds:e/si
        
int21716c proc
if ?32BIT
		@strout <"int 21,ax=%X ds:esi=%ls",lf>,ax,ds,esi
else
		@strout <"int 21,ax=%X ds:si=%s",lf>,ax,ds,si
endif
		push esi
		call copyz_dssi_2_tlb
		call rmdoswithcarry
		pop esi
		ret
		align 4
int21716c endp

;--- int 21, ax=7147 (get cur dir into ds:e/si)        

int217147 proc
		@strout <"int 21,ax=7147",lf>
		push esi
		xor esi,esi
		call setdsreg2tlb
		call rmdoswithcarry
		pop esi
		jc @F
		call copyz_tlb_2_dssi
@@:
		ret
		align 4
int217147 endp

;--- int 21, ax=7156 (rename file)        
        
int217156 proc
if ?32BIT
		@strout <"int 21,ax=%X ds:edx=%ls",lf>,ax,ds,edx
else
		@strout <"int 21,ax=%X ds:dx=%s",lf>,ax,ds,dx
endif
		push edx
		push edi

		call copyz_dsdx_2_tlb

		push es
if ?32BIT
		push edi
else
		push word ptr 0
		push di
endif
		mov edi,100h
		push edi
		call copyz_far32_2_tlbxx
		call setesreg2tlb
		call rmdoswithcarry

		pop edi
		pop edx
		ret
		align 4
int217156 endp

;--- int 21, ax=714E
;--- DS:E/DX -> file spec
;--- ES:E/DI -> finddata record
;--- SI = date format
;--- CX = attributes

int21714e proc
		push edx
		call copyz_dsdx_ret_esdi
		pop edx
		jc exit
		push word ptr 13eh	;13E = finddata size
		push word ptr 100h	;offset in TLB
		call copy_tlbxx_2_esdi
exit:
		ret
		align 4
int21714e endp

;--- int 21, ax=71A0
;--- DS:E/DX -> [in] root ("C:\")
;--- ES:E/DI -> [out] file system buffer 
;--- CX = [in] size of buffer, [out] max length of file name (usually FFh)
;--- DX = [out] max length of path

int2171a0 proc
		push cx				;size of buffer (2. param copy_tlbxx_2_esdi)
		push word ptr 100h	;offset in TLB (1. param copy_tlbxx_2_esdi)
		call copyz_dsdx_ret_esdi
		jc error
if ?32BIT
		@strout <"int 21,ax=71A0 ok, es:edi=%lX:%lX, cx=%X",lf>,es,edi,cx
else
		@strout <"int 21,ax=71A0 ok, es:di=%lX:%X, cx=%X",lf>,es,di,cx
endif
		call copy_tlbxx_2_esdi
		ret
error:
		add esp,4
		stc
		ret
		align 4
int2171a0 endp

;--- used by ax=714e and 71a0
;--- dont save dx here, dx returns value for 71a0

copyz_dsdx_ret_esdi proc

if ?32BIT
		@strout <"int 21 ax=%X ds:edx=%ls es:edi=%lX:%lX cx=%X",lf>,ax,ds,edx,es,edi,cx
else
		@strout <"int 21 ax=%X ds:dx=%s es:di=%lX:%X cx=%X",lf>,ax,ds,dx,es,di,cx
endif
		push edi
		call copyz_dsdx_2_tlb	;copy ds:dx to TLB:0, set dx=0, v86-ds=TLB
		mov di,100h
		call setesreg2tlb		;es:di = TLB:100h
		call rmdoswithcarry
		pop edi
		ret
		align 4

copyz_dsdx_ret_esdi endp
        
;--- int 21, ax=714F
;--- int 21, ax=71A2

int21714f:
int2171a2:

copy_esdi_ret_esdi proc
		push edi
		push ecx
		mov cx,13Eh
		call copy_esdi_2_tlb
		pop ecx
		xor edi,edi
		call rmdoswithcarry
		pop edi
		jc exit
		push word ptr 13Eh
		push word ptr 0
		call copy_tlbxx_2_esdi
exit:
		ret
copy_esdi_ret_esdi endp

;--- copy asciiz ds:esi to tlb:0, return asciiz from tlb:100h into es:edi
        
int2171a8:
        
;--- int 21, ax=7160 (get canonical form)
;--- DS:E/SI -> path
;--- ES:E/DI -> output buffer
;--- CX = minor code

int217160 proc

if ?32BIT
		@strout <"int 21 ax=%X ds:esi=%ls es:edi=%lX:%lX",lf>,ax,ds,esi,es,edi
else
		@strout <"int 21 ax=%X ds:si=%s es:di=%lX:%X",lf>,ax,ds,si,es,di
endif
		push esi
		push edi
		call copyz_dssi_2_tlb
		mov di,100h
		call setesreg2tlb
		call rmdoswithcarry
		pop edi
		pop esi
		jc exit
		push es
if ?32BIT
		push edi
else
		push word ptr 0
		push di
endif
		push 100h
		call copyz_tlbxx_2_far32
exit:
		ret
int217160 endp

;--- int 21, ax=71A6
;--- return TLB:0 to ds:e/dx

int2171a6 proc
		push edx
		call setdsreg2tlb
		xor edx,edx
		call rmdoswithcarry
		pop edx
		jc exit
		push ecx
		mov cx,SIZE_BY_HANDLE_FILE_INFO
		call copy_tlb_2_dsdx
		pop ecx
exit:
		ret
int2171a6 endp
		
		
else					;no LFN support
		mov al,00
		stc
		ret
intr2171 endp

endif

;*** FAT32 support
;*** AL=00:get drive flags (no pointers used)
;*** AL=01:set drive flags (no pointers used)
;*** AL=02:get extended DPB into ES:(E)DI, CX=size of buffer
;*** AL=03:get extended free space into ES:(E)DI, DS:(E)DX is pointer
;*** AL=04:set DPB to use for formatting in ES:(E)DI
;*** AL=05:extended absolute disk read/write, pointer in DS:(E)BX

		@ResetTrace

intr2173 proc

		cmp al,2			;AL=0,1 -> drive locking/flushing
		jc i217300
		cmp al,5
		jz i217305			;AL=5 -> absolute disk read/write FAT32
		jnc i217300
		push edi				;AL=2,3,4
		push edx
		call copy_esdi_2_tlb	;copy CX bytes to TLB:0, rmES=TLB
		cmp al,3
		jnz @F
		push ds				;for ax=7303 DS:E/DX is asciiz ptr
if ?32BIT
		push edx
else
		push word ptr 0
		push dx
endif
		mov edx,100h
		push edx				;offset in tlb
        call copyz_far32_2_tlbxx
		call setdsreg2tlb	;rmDS=TLB
@@:
		xor edi,edi
		call rmdos
		pop edx
		pop edi
		jc @F				;call may also fail with NC if FAT32 isn't
							;implemented, but this shouldn't harm.
		call copy_tlb_2_esdi;copy CX bytes from TLB:0 to ES:E/DI
@@:
		ret
i217300:
i217301:
		call rmdos
        ret
        
;--- FAT32 absolute disk read/write        
;--- AX=7305
;--- CX=FFFF
;--- DL=drive number (01=A,...)
;--- DS:E/BX->io packet (same as for Int 25/26)
;--- SI=flags (bit 0: 0=read, 1=write)

i217305:
		call setdsreg2tlb
		test si,1
		jnz iswrite
		call PrepareDiskIoRead
		jc @F
		push ebx
		mov ebx, 0
		call rmdos
		pop ebx
		jc @F
		call AfterDiskIoRead
		clc
@@:
		ret
iswrite:
		call PrepareDiskIoWrite
		jc @F
		push ebx
		mov ebx, 0
		call rmdos
		pop ebx
@@:
		ret
intr2173 endp

;--- get current environment as a real mode segment
;--- out: real mode environment in AX

getrmenv proc
		push ebx
		push ds
		push byte ptr _FLATSEL_
		pop ds
		mov ebx, ss:[dwSDA]
		movzx ebx, word ptr [ebx+10h]
		shl ebx, 4
		mov bx, [ebx+2ch]
		pop ds
		call bx_sel2segm
		mov ax, bx
		pop ebx
		ret
getrmenv endp

;---------------------------------------------

if 0
fataldosexit:
		mov ebp,esp
if ?32BIT
		mov si,[ebp+8]
else
		mov si,[ebp+6]
endif
		mov di,[ebp+4]
		@printf <"I21: fatal error (ax=%X bx=%X cx=%X dx=%X cs:ip=%X:%X)",lf>,ax,bx,cx,dx,si,di
		pop eax			;errorcode
		jmp __exitappx
endif

endif

_TEXT32  ends

end

