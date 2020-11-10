
;--- mouse cursor display routines 
;--- since mouse drivers dont support VESA modes

		.386
if ?FLAT
		.MODEL FLAT, stdcall
else
		.MODEL SMALL, stdcall
endif
		option casemap:none
		option proc:private

?MOUSEEVENT			equ 1
?HANDLEGETCSRPOS	equ 0
?HANDLESETCSRPOS	equ 0
?HANDLEINT104F04	equ 0	;not needed, it is done by dwRestoreNotify
?HANDLEINT104F07	equ 0	;handle "set display start" 
?XOR				equ 1
?CTMOUSE			equ 1	;support wheel mouse

ENABLE_MOUSE_INPUT	equ 10h

		include function.inc
		include macros.inc
		include dpmi.inc
		include vesa32.inc

TRUE	equ 1
FALSE	equ 0

ShowCursor	proto dwNewPos:dword
HideCursor	proto

		.DATA

g_oldint33		df 0
				align 4
g_oldint10		df 0
				align 4
g_csalias		dd 0
g_dwMousePos	dd -1	;low word = X
g_wXRangeMin  	SWORD -1
g_wXRangeMax  	SWORD -1
g_wYRangeMin  	SWORD -1
g_wYRangeMax  	SWORD -1
g_wLastMickeyX	dw 0
g_wLastMickeyY	dw 0
g_dwBMSize		dd 0	;size of screen bitmap (=offset to cursor bitmap)
g_dwHotSpotX	dd 0
g_dwHotSpotY 	dd 0
g_lPitch        dd 0
g_pScreen   	dd 0	;ptr start screen
g_pEndOfScreen	dd -1	;ptr end screen
g_dwScreenSize  dd 0	;size screen in bytes
g_cntShowMouse	SDWORD -1;show mouse counter
g_dwWidth    	dd 0	;cursor width in bytes
g_bDrawing		dd -1
g_bHidden		db 0
g_bHeight   	db 0	;cursor height in rows
g_bIgnMickeys	db 0	;
g_bMask			db 7Fh	;default mouse event mask
g_bVesaLFBMode	db 0	;current mode is a VESA LFB graphics mode
g_bBlack		db 0	;"black" for cursor in 256 palette modes
g_bWhite		db 0FFh	;"white" for cursor in 256 palette modes
				align 4
g_svgainfo		SVGAINFO <>

if ?MOUSEEVENT
	align 4
g_rmcb	dd 0
g_rmcs	RMCS <>
g_prevHdlDX			dw 0
g_prevHdlES			dw 0
g_prevHdlCX			dw 0
endif

		.DATA?
        
g_CsrBM db 32*4*2 dup (?)	;monochrom cursor bitmap (max is 32x32)
							;first comes the screen bitmap (AND)
							;then the cursor bitmap (XOR)
							;then the saved pixels
g_savedPixels db 32*32*4 dup (?)

externdef g_dwRestoreNotify:dword

        .CODE

;--- bScreenColor= used if 1 in screen mask
;--- bCursorColor= used if 1 in cursor mask

SetCursorPaletteEntries proc public bScreenColor:dword, bCursorColor:dword
		mov eax, bScreenColor
		xchg al, g_bBlack
		mov edx, bCursorColor
		xchg dl, g_bWhite
		mov ah,dl
		ret
		align 4
SetCursorPaletteEntries endp

RestoreNotify proc
		call InitNewMode
		ret
		align 4
RestoreNotify endp

;--- set mouse event proc
;--- better do not assume ss=es here!

seteventproc proc uses ebx edi bSet:dword

local	rmcs:RMCS

		.if (bSet)
			mov dx,word ptr g_rmcb+0
			mov ax,word ptr g_rmcb+2
			movzx cx, g_bMask		;get all events, moves and buttons
		.else
			mov dx,g_prevHdlDX
			mov ax,g_prevHdlES
			mov cx,g_prevHdlCX
		.endif
		mov rmcs.rES, ax
		mov rmcs.rDX, dx
		mov rmcs.rCX, cx
		mov rmcs.rAX, 0014h
		xor ecx,ecx
		mov rmcs.rSSSP,ecx
		mov rmcs.rFlags,cx
		lea edi,rmcs
		push es
		push ss
		pop es
		mov bx,0033h
		mov ax,0300h
		int 31h
		pop es
		.if (bSet)
			mov dx, rmcs.rDX
			mov cx, rmcs.rCX
			mov ax, rmcs.rES
		.else
			xor eax, eax
			xor ecx, ecx
			xor edx, edx
		.endif
		mov g_prevHdlDX,dx
		mov g_prevHdlES,ax
		mov g_prevHdlCX,cx
		ret
		align 4
seteventproc endp            

;--- returns: eax=0 if no mouse installed, else eax=1

VesaMouseInit proc public uses ebx edi esi

local	rc:dword

		mov rc, 1
		.if (word ptr g_oldint33+4 == 0)
			dec rc
			mov ax,0024h		;get software version
			mov bx,0000h
			int 33h
			cmp ax,-1
			jz exit
			and bx, bx			;not installed
			jz exit
			mov g_csalias, ds
			inc rc

if ?CTMOUSE
			mov ax,0011h
			int 33h
			cmp ax,574Dh
			jnz @F
			or g_bMask,80h
@@:
endif

if ?MOUSEEVENT
if ?FLAT

;--- if dkrnl32 is loaded, make sure console mouse input is enabled
;--- (this avoids problems if 2 mouse event procs are registered)
;--- a better approach would be to tell dkrnl32 our event proc directly

			mov edx, CStr("KERNEL32")
			mov ax,4b82h
			int 21h
			.if (!CARRY?)
				mov ebx, eax
				mov edx, CStr("GetConsoleMode")
				mov ax,4b81h
				int 21h
				.if (!CARRY?)
					push 0
					push esp
					push 0
					call eax
					pop edx
					test dl,ENABLE_MOUSE_INPUT
					.if (ZERO?)
						push edx
						mov edx, CStr("SetConsoleMode")
						mov ax,4b81h
						int 21h
						pop edx
						.if (!CARRY?)
							or dl, ENABLE_MOUSE_INPUT
							push edx
							push 0
							call eax
						.endif
					.endif
				.endif
			.endif
endif
endif
;-------------------------- set INT 33h
			mov bl,33h
			mov ax,204h
			int 31h
if ?CLEARHIGHEBP
			movzx edx,dx
endif
			mov dword ptr [g_oldint33+0],edx
			mov word ptr [g_oldint33+4],cx
			mov ecx, cs
			mov edx, offset myint33
			mov ax,0205h
			int 31h
;-------------------------- set INT 10h
			mov bl,10h
			mov ax,204h
			int 31h
if ?CLEARHIGHEBP
			movzx edx,dx
endif
			mov dword ptr [g_oldint10+0],edx
			mov word ptr [g_oldint10+4],cx
			mov ecx, cs
			mov edx, offset myint10
			mov ax,0205h
			int 31h

if ?MOUSEEVENT
;-------------------------- alloc real mode callback
			mov edi, offset g_rmcs
			mov esi, offset evntproc
			push ds
			push cs
			pop ds
			mov ax,0303h
			int 31h
			pop ds
			jc	@F
			mov word ptr g_rmcb+0,dx
			mov word ptr g_rmcb+2,cx
			invoke seteventproc, 1
@@:
endif
			mov  g_dwRestoreNotify, offset RestoreNotify
			call InitNewMode
			@strace <"VesaMouseInit done">
		.endif
exit:
		mov eax, rc
		ret
		align 4
VesaMouseInit endp

VesaMouseExit proc public uses ebx edi

local	rmcs:RMCS

		xor eax, eax
		.if (word ptr g_oldint33+4)
			invoke HideCursor
			mov g_bVesaLFBMode, 0

if ?MOUSEEVENT
;------------------------- reset mouse event proc
			cmp g_rmcb,0
			jz @F
			invoke seteventproc, 0
;------------------------- free real mode callback
			mov dx,word ptr g_rmcb+0
			mov cx,word ptr g_rmcb+2
			mov ax,0304h
			int 31h
			mov g_rmcb,0
@@:
endif
			mov edx, dword ptr g_oldint10+0
			mov cx, word ptr g_oldint10+4
			mov bl, 10h
			mov ax, 0205h
			int 31h
			mov edx, dword ptr g_oldint33+0
			mov cx, word ptr g_oldint33+4
			mov bl, 33h
			mov ax, 0205h
			int 31h
			mov word ptr g_oldint33+4,0
			mov g_dwRestoreNotify, 0
			@strace <"VesaMouseExit done">
			@mov eax,1
		.endif
exit:
		ret
		align 4
VesaMouseExit endp

;--- int 33 handler

myint33 proc
		cmp ah,00
		jnz default
		push ds
		mov ds,cs:g_csalias
		cmp al,00h				;hardware reset
		jz do0000
		cmp al,01h				;show cursor
		jz do0001
		cmp al,02h				;hide cursor
		jz do0002
if ?HANDLEGETCSRPOS 	   
		cmp al,03h				;get cursor pos
		jz do0003
endif		 
if ?HANDLESETCSRPOS 	   
		cmp al,04h				;set cursor pos
		jz do0004
endif
		cmp al,07h				;set X cursor range
		jz do0007
		cmp al,08h				;set Y cursor range
		jz do0008
		cmp al,12h				;set large graphics cursor
		jz do0012
		cmp al,21h				;software reset
		jz do0021
		pop ds
default:
		jmp fword ptr cs:g_oldint33
		align 4
do0001:							;show cursor
		inc g_cntShowMouse
		jnz do0001_done
		pushad
		.if (g_dwMousePos == -1)
			mov ax,3
			pushfd
			call fword ptr g_oldint33
			mov word ptr [g_dwMousePos+0],cx
			mov word ptr [g_dwMousePos+2],dx
			mov g_bIgnMickeys, 1
		.endif
		invoke ShowCursor, g_dwMousePos
		popad
do0001_done:
		pop ds
		iretd
		align 4
do0002:							;hide cursor
		sub g_cntShowMouse,1
		jnc do0002_done
		.if (g_bHeight)
			pushad
			invoke HideCursor
			popad
		.endif
do0002_done:
		pop ds
		iretd
		align 4
if ?HANDLEGETCSRPOS
do0003:
if 1
		pushfd
		call fword ptr g_oldint33
endif
		mov cx,word ptr g_dwMousePos+0	;col
		mov dx,word ptr g_dwMousePos+2	;row
		pop ds
		iretd
		align 4
endif
if ?HANDLESETCSRPOS
do0004:
if 1
		pushfd
		call fword ptr g_oldint33
endif 
		pushad
		push dx
		push cx
		call ShowCursor
;		mov g_bIgnMickeys, 1
		popad
		pop ds
		iretd
endif
		align 4
do0007:
		mov g_wXRangeMin,cx
		mov g_wXRangeMax,dx
		pop ds
		jmp fword ptr cs:g_oldint33
		align 4
do0008:
		mov g_wYRangeMin,cx
		mov g_wYRangeMax,dx
		pop ds
		jmp fword ptr cs:g_oldint33
		align 4
;----------------------- hard + soft reset will clear the event mask!		 
do0000:
do0021:
		pushfd
		call fword ptr g_oldint33
		pushad
		invoke seteventproc, 1
		mov g_cntShowMouse, -1
		invoke HideCursor
		popad
		pop ds
		iretd
		align 4
do0012:

;--- CH=height in pixels
;--- BH=width in words
;--- BL + CL= hotspot

		.if ((ch <= 32) && (bh <= 2))
			pushad
			invoke HideCursor
			mov esi, edx
			mov byte ptr g_dwHotSpotX, bl
			mov byte ptr g_dwHotSpotY, cl
			mov byte ptr g_dwWidth, bh		;width in words
			shl g_dwWidth, 1				;now in bytes
			mov g_bHeight, ch				;height in rows
			movzx eax, bh
			movzx ecx, ch
			mul ecx
			mov ecx, eax
			shl eax, 1
			mov g_dwBMSize, eax
			mov edi, offset g_CsrBM
			push es
			push es
			pop ds
			mov es, cs:[g_csalias]
			cld
			rep movsd
			pop es
			invoke ShowCursor, g_dwMousePos
			popad
			mov ax,-1
		.endif
		pop ds
		iretd
		align 4
myint33 endp

;--- a new mode has been set. this should have happened
;--- within VESA32, but this isn't sure. so dont assume
;--- too much. ds==flat is ok, but SS==FLAT possibly not

InitNewMode proc
		pushad
		push es
		push ds
		pop es
		mov g_bVesaLFBMode, 0
		mov g_dwMousePos, -1
		mov g_bHidden,1
		invoke GetVesaMode
		.if (eax)
			invoke GetVesaModeInfo, eax, offset g_svgainfo
		.endif
		.if (eax)
			mov ax, g_svgainfo.ModeAttributes
			and ax, VESAATTR_IS_GFX_MODE or VESAATTR_LFB_SUPPORTED
			.if (ax ==	VESAATTR_IS_GFX_MODE or VESAATTR_LFB_SUPPORTED)
				.if (g_svgainfo.PhysBasePtr)
					mov g_bVesaLFBMode, 1
				.endif
			.endif
		.endif
		.if (g_bVesaLFBMode)
;------------------------------ make sure pal entry FF is "white"
			mov al, g_svgainfo.BitsPerPixel
			.if (al == 8)
				push -1
				invoke SetVesaPaletteEntries, 0FFh, 1, esp
				pop ecx
			.elseif (al == 15)
				mov g_svgainfo.BitsPerPixel, 16
			.elseif (al & 7)
				mov g_bVesaLFBMode, 0
				jmp exit
			.endif
			movzx ecx, g_svgainfo.BytesPerScanLine
			mov g_lPitch, ecx
			movzx eax, g_svgainfo.YResolution
			mul ecx			;eax=screen size
			mov g_dwScreenSize, eax
			mov ecx, g_svgainfo.PhysBasePtr
			mov g_pScreen, ecx
			add eax, ecx
			mov g_pEndOfScreen, eax

			mov dx,g_svgainfo.XResolution
			dec dx
			xor cx,cx
			mov ax,0007
			int 33h
			mov dx,g_svgainfo.YResolution
			dec dx
			xor cx,cx
			mov ax,0008
			int 33h
if 1
			mov cx,8		;X (def=8)
			mov dx,8		;Y (def=16)
			mov ax,000Fh	;set mickey/8-pixels ratio
			int 33h
endif
if 0
			mov bx,16
			mov cx,16
			mov dx,64		;double speed
			mov ax,001Ah	;set sensitivity
			int 33h
endif
		.endif
exit:
		pop es
		popad
		ret
		align 4
InitNewMode endp        

;--- eax=new display offset

MouseSetDisplayStart proc public
		.if (g_cntShowMouse >= 0)
			pushad
			invoke HideCursor
			popad
		.endif
		add eax, g_svgainfo.PhysBasePtr
		mov g_pScreen, eax
		add eax, g_dwScreenSize
		mov g_pEndOfScreen, eax
		.if (g_cntShowMouse >= 0)
			pushad
			invoke ShowCursor, g_dwMousePos
			popad
		.endif
		ret
MouseSetDisplayStart endp

;--- int 10 handler

myint10 proc
		cmp ax,4F02h	;set VESA video mode
		jz ax4f02
		cmp ah,00
		jz ah00
if ?HANDLEINT104F04
		cmp ax,4F04h	;save/restore VESA state
		jz ax4f04
endif
if ?HANDLEINT104F07
		cmp ax,4F07h
		jz ax4f07
endif
default:
		jmp fword ptr cs:g_oldint10
		align 4
ah00:
		mov g_bVesaLFBMode, 0
		jmp default
		align 4
if ?HANDLEINT104F04 	   
ax4f04:
		cmp dl,02		;restore VESA state?
		jnz default
endif
ax4f02:
		pushfd
		call fword ptr cs:g_oldint10
		cmp ax,004Fh
		jnz exit
		push ds
		mov ds,cs:g_csalias
		call InitNewMode
		pop ds
exit:
		iretd
		align 4
if ?HANDLEINT104F07
ax4f07:
		test bl,7Dh		;dont test bit 1 and 7
		jnz default		;is it SET or GET?
		pushfd
		call fword ptr g_oldint10
		cmp ax,004Fh
		jnz ax4f07done
		push ds
		mov ds,cs:g_csalias
		push eax
		push edx
		movzx eax, g_svgainfo.BytesPerScanLine
		movzx edx, dx
		mul edx
		call MouseSetDisplayStart
		pop edx
		pop eax
		pop ds
ax4f07done:
		iretd
		align 4
endif
myint10 endp

;--- show or hide the graphics cursor

ShowHide proc dwPos:dword, bHide:dword

local	dwHeight:dword
local	dwBytesPerPixel:dword
local	pScreen:dword
local	dwProc:dword
local	dwAddBM:dword
local	bWidth:BYTE
local	bRes:BYTE
local	wXorMask:word

		inc g_bDrawing
		jnz exit
		cmp g_bVesaLFBMode,0
		jz exit
		movzx ecx, g_bHeight
		and ecx, ecx
		jz done
		mov dwHeight, ecx
		movsx eax, word ptr dwPos+2			;YPos
		sub eax, g_dwHotSpotY
		mul g_lPitch
		mov ecx, eax
		movsx eax, word ptr dwPos+0			;XPos
		sub eax, g_dwHotSpotX
		movzx edx, g_svgainfo.BitsPerPixel
		shr edx, 3
		mul edx
		add eax, ecx
		add eax, g_pScreen
		mov edi, eax

		movzx eax, g_svgainfo.XResolution
		movsx ecx, word ptr dwPos+0
		sub ecx, g_dwHotSpotX
		mov edx, g_dwWidth		;width in bytes
		shl edx, 3
		add ecx, edx
		sub ecx, eax
		jnc @F
		xor ecx, ecx
@@:
		sub edx, ecx
		mov bWidth, dl			;width in pixels
		add edx,8-1
		shr edx,3
		sub edx,g_dwWidth
		neg edx
		mov dwAddBM,edx

		movzx eax, g_svgainfo.BitsPerPixel
		shr eax, 3
		mov dwBytesPerPixel, eax	;8-1, 16->2, 24->3, 32->4
		dec eax
		shl eax, 4
		.if (bHide)
			lea edx, [eax + offset hideprocs]
		.else
			lea edx, [eax + offset showprocs]
		.endif
		mov dwProc, edx
		mov ebx, offset g_CsrBM
		mov esi, offset g_savedPixels
		.while (edi < g_svgainfo.PhysBasePtr)
			add edi, g_lPitch
			add ebx, g_dwWidth
			dec dwHeight
		.endw
nextrow:
		cmp edi, g_pEndOfScreen
		jnb done
		mov pScreen, edi
		xor cl,cl
nextcol:
		test cl,7
		jnz @F
		mov eax, g_dwBMSize
		mov dl,[ebx+eax]	;get XOR mask
		mov dh,[ebx]		;get AND mask
		inc ebx
@@:
;--- convert:
;--- AND 0, XOR 0 -> 0  (bg)
;--- AND 0, XOR 1 -> 1  (fg)
;--- AND 1, XOR 0 -> 2  (screen)
;--- AND 1, XOR 1 -> 3  (xor screen) 

		xor eax,eax
		shl dh,1	;move AND bit to eax[1] 	
		adc al,0
		shl al,1
		shl dl,1
		adc al,0	;move XOR bit to eax[0]	
		shl eax,2
		add eax,[dwProc]
		call dword ptr [eax]
		inc cl
		cmp cl,bWidth
		jnz nextcol
		mov edi, pScreen
		add ebx, dwAddBM
		add edi, g_lPitch
		dec dwHeight
		jnz nextrow
done:
		mov eax, bHide
		mov g_bHidden, al
exit:
		dec g_bDrawing
		ret
		align 4

hideprocs dd offset hide1,   offset hide1,   offset void_,  offset hide1
          dd offset hide2,   offset hide2,   offset void_,  offset hide2
          dd offset hide3,   offset hide3,   offset void_,  offset hide3
          dd offset hide4,   offset hide4,   offset void_,  offset hide4
showprocs label dword
          dd offset move1bg, offset move1fg, offset void_,  offset move1xx
          dd offset move2bg, offset move2fg, offset void_,  offset move2xx
          dd offset move3bg, offset move3fg, offset void_,  offset move3xx
          dd offset move4bg, offset move4fg, offset void_,  offset move4xx
void_:
		add edi, dwBytesPerPixel
		retn
		align 4
hide1:
		movsb
		retn
		align 4
hide2:
		movsw
		retn
		align 4
hide3:
		movsw
		movsb
		retn
		align 4
hide4:
		movsd
		retn
		align 4
move1bg:			;AND 0, XOR 0
		mov ah,[edi]
		mov al,g_bBlack
		mov [esi],ah
		stosb
		add esi, 1
		retn
		align 4
move1fg:			;AND 0, XOR 1
		mov ah,[edi]
		mov al,g_bWhite
		mov [esi],ah
		stosb
		add esi, 1
		retn
		align 4
move2bg:
		mov ax, [edi]
		mov [esi], ax
		mov ax,0
		add esi,2
		stosw
		retn
		align 4
move2fg:
		mov ax, [edi]
		mov [esi], ax
		mov ax,-1
		add esi,2
		stosw
		retn
		align 4
move3bg:
		mov ax,[edi+0]
		mov ch,[edi+2]
		mov [esi+0],ax
		mov [esi+2],ch
		xor eax,eax
		add esi,3
		stosw
		stosb
		retn
		align 4
move3fg:
		mov ax,[edi+0]
		mov ch,[edi+2]
		mov [esi+0],ax
		mov [esi+2],ch
		or eax,-1
		add esi,3
		stosw
		stosb
		retn
		align 4
move4bg:
		mov eax, [edi]
		mov [esi], eax
		xor eax,eax
		add esi,4
		stosd
		retn
		align 4
move4fg:
		mov eax, [edi]
		mov [esi], eax
		or eax,-1
		add esi,4
		stosd
		retn
		align 4
if ?XOR
move1xx:			;AND 1, XOR 1
		mov al,[edi]
		mov [esi],al
		xor al,-1
		add esi,1
		stosb
		retn
		align 4
move2xx:
		mov ax, [edi]
		mov [esi], ax
		xor ax,-1
		add esi,2
		stosw
		retn
		align 4
move3xx:
		mov ax,[edi+0]
		mov ch,[edi+2]
		mov [esi+0],ax
		mov [esi+2],ch
		xor ax,-1
		xor ch,-1
		stosw
		add esi,3
		mov al,ch
		stosb
		retn
		align 4
move4xx:
		mov eax, [edi]
		mov [esi], eax
		xor eax,-1
		add esi,4
		stosd
		retn
		align 4
endif
ShowHide endp

;--- hide the cursor
;--- be careful: SS may be LPMS here !!!
;--- and interrupts disabled!

HideCursor proc            

		.if (!g_bHidden)
			pushad
			invoke ShowHide, g_dwMousePos, 1
			popad
		.endif
		ret
		align 4

HideCursor endp

;--- be careful: SS may be LPMS here !!!
;--- and interrupts disabled!
;--- ds=flat

ShowCursor proc dwNewPos:dword

		.if (g_cntShowMouse >= 0)
			invoke HideCursor
			invoke ShowHide, dwNewPos, 0
		.endif
		mov eax, dwNewPos
		mov g_dwMousePos, eax
		ret
		align 4

ShowCursor endp

;--- called by mouse event proc
;--- interrupts are disabled here, stack is not flat (LPMS)
;--- es:edi -> RMCS
;--- ds:esi -> real mode stack
;--- in RMCS:
;--- BX = button state
;--- CX = column (X)
;--- DX = row (Y)
;--- SI = mickeys X
;--- DI = mickeys Y

evntproc proc

		mov eax,dword ptr cs:g_prevHdlDX
		.if ((!eax) || (!cs:g_prevHdlCX))
			mov eax,ds:[esi]			;get value from real mode [SS:SP]
			add es:[edi].RMCS.rSP,4
		.endif
		mov es:[edi].RMCS.rCSIP, eax			

		test byte ptr es:[edi].RMCS.rAX,1	;move event?
		jz exit

		push ds
		push edi
		mov ds,cs:[g_csalias]			;now at least ds=es=flat

		mov cx,es:[edi].RMCS.rSI		;X (mickeys)
		mov dx,es:[edi].RMCS.rDI		;Y (mickeys)
		.if (g_bIgnMickeys)
			mov g_bIgnMickeys, 0
			mov g_wLastMickeyX, cx
			mov g_wLastMickeyY, dx
		.endif
		.if (g_dwMousePos == -1)
			mov g_wLastMickeyX, cx
			mov g_wLastMickeyY, dx
			mov cx,es:[edi].RMCS.rCX
			mov dx,es:[edi].RMCS.rDX
		.else
			mov ax, g_wLastMickeyX
			mov bx, g_wLastMickeyY
			mov g_wLastMickeyX, cx
			mov g_wLastMickeyY, dx
			sub cx, ax
			sub dx, bx
			add cx, word ptr g_dwMousePos+0
			add dx, word ptr g_dwMousePos+2
			.if (SWORD ptr cx < g_wXRangeMin)
				mov cx, g_wXRangeMin
			.elseif (SWORD ptr cx > g_wXRangeMax)
				mov cx, g_wXRangeMax
			.endif
			.if (SWORD ptr dx < g_wYRangeMin)
				mov dx, g_wYRangeMin
			.elseif (SWORD ptr dx > g_wYRangeMax)
				mov dx, g_wYRangeMax
			.endif
		.endif
		push dx
		push cx
		call ShowCursor
		pop edi
		pop ds
exit:
		iretd
		align 4

evntproc endp

		END

