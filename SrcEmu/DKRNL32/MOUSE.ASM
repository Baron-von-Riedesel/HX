

;--- low level console input (mouse)
;--- for keyboard see peekcon.asm and kbdqueue.asm

;--- Win32 API function:
;--- GetNumberOfConsoleMouseButtons
;---
;--- internal functions:
;--- ShowMouse
;--- HideMouse
;--- InitMouse is called by SetConsoleMode
;--- DeinitMouse is called by kernel termination sequence
;--- PeekMouseEvent is called by Read/Peek-ConsoleInput

	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:none
	option proc:private

	include winbase.inc
	include wincon.inc
	include macros.inc
	include dkrnl32.inc
	include dpmi.inc

	option dotname

?USE_RMCB			equ 1	;use real mode callback function for mouse event proc
?HOOKMOUSEINT		equ 1
?HANDLEGETCSRPOS	equ 1
?HANDLESETCSRPOS	equ 1
?CTMOUSE			equ 1	;support CTMOUSE wheel API

.BASE$XC segment dword public 'DATA'
if ?HOOKMOUSEINT
	dd offset DehookMouse
endif
	dd offset DeinitMouse
.BASE$XC ends

if ?FLAT eq 0
DGROUP  group .BASE$XC
endif

protoMouEventHandler typedef proto :DWORD, :DWORD
LPFNMOUEVENTHANDLER typedef ptr protoMouEventHandler

	.DATA

g_dwOldPos label dword
g_wOldPosX		dw -1
g_wOldPosY		dw -1
g_wLastMickeyX	dw 0
g_wLastMickeyY	dw 0
if ?HOOKMOUSEINT
g_wMinX			dw 0
g_wMaxX			dw 32767
g_wMinY			dw 0
g_wMaxY			dw 32767
endif
if ?HOOKMOUSEINT
g_dfOldInt33	df 0
endif

g_wOldBtnState	dw 0
if ?CTMOUSE
g_bWheelCap		db 0	;bit 0: wheels supported
endif
	align 4

g_pEvntQWrite	dd offset g_evntqueue
g_pEvntQRead	dd offset g_evntqueue
g_lpfnHandlerProc	LPFNMOUEVENTHANDLER 0
g_dwCookie		dd 0

g_prevHdlDX			dw 0	;real-mode event proc ES:DX returned by
g_prevHdlES			dw 0	;int 33h, ax=0014h
g_prevHdlCX			dw 0	;mouse mask returned by int 33h, ax=0014h
g_wButtons			dw 0	;number of buttons

if ?USE_RMCB
		align 4
g_rmcb	dd 0
g_rmcs	RMCS <>
endif
g_bShowMouse	db FALSE
g_bInit			db FALSE

	.DATA?

g_evntqueue MOUEVNT 64 dup (<>)
end_of_eventqueue label byte

	.CODE

;--- ShowMouse and HideMouse are called by low-level console
;--- output functions

KernelShowMouse proc public
	.if ((!g_bShowMouse) && g_bInit)
		push eax
		mov ax,1
		int 33h
		pop eax
		mov g_bShowMouse, TRUE
	.endif
	ret
	align 4
KernelShowMouse endp

KernelHideMouse proc public
	.if (g_bShowMouse)
		push eax
		mov ax,2
		int 33h
		pop eax
		mov g_bShowMouse, FALSE
	.endif
	ret
	align 4
KernelHideMouse endp

;--- set mouse event proc
;--- this is done by raw DPMI functions
;--- which has the disadvantage that it isn't reset
;--- if the client is terminated the hard way (terminate s/erver)

seteventproc proc uses ebx edi bSet:dword

local	rmcs:RMCS

	.if (bSet)
		mov dx,word ptr g_rmcb+0
		mov ax,word ptr g_rmcb+2
		mov cx,007Fh
if ?CTMOUSE
		test g_bWheelCap,1
		jz @F
		or cl,80h
@@:
endif
		@strace <"seteventproc, ax:dx=", eax, ":", edx, ", ecx=", ecx>
	.else
		mov dx,g_prevHdlDX
		mov ax,g_prevHdlES
		mov cx,g_prevHdlCX
	.endif
	mov rmcs.rSSSP,0
	mov rmcs.rES, ax
	mov rmcs.rDX, dx
	mov rmcs.rCX, cx
	mov rmcs.rAX, 0014h
	lea edi,rmcs
	mov bx,0033h
	mov cx,0000h
	mov ax,0300h
	int 31h
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
	@strace <"mouse.seteventproc(", bSet, ")=", eax, ":", edx, " RMCB=", g_rmcb>
	ret
	align 4
seteventproc endp

;--- this is called during interrupt time
;--- so dont change vga status!
;--- out: eax!=0 if graphics mode

InGraphicsMode proc
if ?VGA
	push edx
	mov dx, 3ceh
	in al, dx		;save index register
	mov ah, al
	mov al, 6
	out dx, al
	inc dx
	in al, dx
	xchg ah, al
	dec dx
	out dx, al		;restore index register
	pop edx
	and ah,1
	movzx eax,ah
else
	mov al,ds:[449h]
	cmp al,3
	jbe istext
	cmp al,7
	jz istext
	movzx eax,al
	ret
is_text:
	xor eax,eax
endif
	ret
	align 4
InGraphicsMode endp


;--- InitMouse is called when flag ENABLE_MOUSE_INPUT is set (SetConsoleMode)
;--- this is default setting in windows, but not in dkrnl32.

InitMouse proc public uses ebx

	.if (!g_bInit)
;------------------------ init driver (software reset)
		mov ax,0021h
		int 33h
;------------------------ is driver installed?
		cmp ax,-1
		jnz exit
		mov g_bInit, TRUE
		.if ( bx == -1 )
			mov bx,2
		.endif
		mov g_wButtons, bx
if ?CTMOUSE
		mov ax,0011h
		int 33h
		cmp ax,574Dh
		jnz @F
		mov g_bWheelCap, cl
@@:
endif
if ?HOOKMOUSEINT
		.if (!word ptr g_dfOldInt33+4)
			mov bl,33h
			mov ax,0204h
			int 31h
			mov dword ptr g_dfOldInt33+0,edx
			mov word ptr g_dfOldInt33+4,cx
			mov ecx, cs
			mov edx, offset myint33
			mov ax,0205h
			int 31h
		.endif
endif
;------------------------ show mouse cursor
		invoke KernelShowMouse
if ?USE_RMCB
		pushad
;------------------------- alloc real mode callback
		mov edi, offset g_rmcs
		mov esi, offset evntproc
		push ds
		push cs
		pop ds
		mov ax,0303h
		int 31h
		pop ds
		jc @F
		mov word ptr g_rmcb+0,dx
		mov word ptr g_rmcb+2,cx
		invoke seteventproc, 1
@@:
		mov ax,3	;return pos (CX,DX + button status BX)
  if ?HOOKMOUSEINT
		pushfd
		call g_dfOldInt33
  else
		int 33h
  endif
		mov g_wOldPosX, cx
		mov g_wOldPosY, dx
		popad
else
		push es
		push cs
		pop es
		mov edx, offset evntproc	;es:edx=interrupt proc
		mov cx,007Fh
		mov ax,0014h
		int 33h
		pop es
endif
		@strace <"Dkrnl32.InitMouse done">
	.endif
exit:
	ret
	align 4
InitMouse endp

DeinitMouse proc public

if ?USE_RMCB
local	rmcs:RMCS
endif

	.if (g_bInit)
		mov g_bInit, FALSE
		invoke KernelHideMouse
if ?USE_RMCB
;------------------------- reset mouse event proc
		cmp g_rmcb,0
		jz @F
		invoke seteventproc, 0
;------------------------- free real mode callback
		mov dx,word ptr g_rmcb+0
		mov cx,word ptr g_rmcb+2
		mov ax,0304h
		int 31h
@@:
else
		push es
		mov edx,0
		mov es,edx
		mov ecx,edx
		mov ax,0014h
		int 33h
		pop es
endif
		@strace <"Dkrnl32.DeinitMouse done">
	.endif
exit:
	ret
	align 4
DeinitMouse endp

if ?HOOKMOUSEINT

DehookMouse proc
	.if (word ptr g_dfOldInt33+4)
		push ebx
		mov bl,33h
		xor ecx, ecx
		xchg cx, word ptr g_dfOldInt33+4
		mov edx, dword ptr g_dfOldInt33+0
		mov ax,0205h
		int 31h
		pop ebx
	.endif
	ret
	align 4
DehookMouse endp

;--- int 33h proc

myint33 proc
	cmp cs:[g_bIsActive],1
	jb default
if ?HANDLEGETCSRPOS
	cmp ax,3
	jz int330003
endif
if ?HANDLESETCSRPOS
	cmp ax,4
	jz int330004
endif
	cmp ax,7
	jz int330007
	cmp ax,8
	jz int330008
default:
	jmp cs:[g_dfOldInt33]
if ?HANDLEGETCSRPOS
	align 4
int330003:
	mov cx,cs:g_wOldPosX
	mov dx,cs:g_wOldPosY
	iretd
endif
if ?HANDLESETCSRPOS
	align 4
int330004:
	push ds
	mov ds, cs:g_csalias
	mov g_wOldPosX, cx
	mov g_wOldPosY, dx
	pop ds
	jmp default
endif
	align 4
int330007:
	push ds
	mov ds, cs:g_csalias
	mov g_wMinX, cx
	mov g_wMaxX, dx
	pop ds
	jmp default
	align 4
int330008:
	push ds
	mov ds, cs:g_csalias
	mov g_wMinY, cx
	mov g_wMaxY, dx
	pop ds
	jmp default
	align 4
myint33 endp

endif

;--- mouse event proc
;--- most DPMI hosts won't implement translation service for
;--- int 33h, ax=000Ch or ax=0014h,
;--- so a real mode callback is used.
;--- It works however for win9x, HDPMI, DPMIONE (and DosEmu?)

;--- interrupts are disabled here, stack is not flat (LPMS)
;--- so dont call any Win32 functions

;--- no need to save registers (except ES:EDI)

evntproc proc
	push ds
if ?DPMI16
	movzx edi,di
	movzx esi,si
endif

if ?USE_RMCB

;--- DS:ESI points to real-mode SS:SP
;--- (ESI is not necessarily == real-mode SP!)

	mov eax,dword ptr cs:g_prevHdlDX
	.if ((!eax) || (!cs:g_prevHdlCX))
		mov eax,ds:[esi]			;get value from real mode [SS:SP]
		add es:[edi].RMCS.rSP,4
	.endif
	mov es:[edi].RMCS.rCSIP, eax
endif

	mov ds,cs:[g_csalias]
	cmp [g_bIsActive],1
	jb skip_event
	invoke InGraphicsMode
	.if (eax)
		mov cx,es:[edi].RMCS.rSI
		mov dx,es:[edi].RMCS.rDI
		.if (g_dwOldPos == -1)
			mov g_wLastMickeyX, cx
			mov g_wLastMickeyY, dx
			mov cx,es:[edi].RMCS.rCX	;cursor column
			mov dx,es:[edi].RMCS.rDX	;cursor row
		.else
			mov ax, g_wLastMickeyX
			mov g_wLastMickeyX, cx
			sub cx, ax
			mov ax, g_wLastMickeyY
			mov g_wLastMickeyY, dx
			sub dx, ax
			add cx, g_wOldPosX
			add dx, g_wOldPosY
			.if (SWORD ptr cx < g_wMinX)
				mov cx, g_wMinX
			.elseif (SWORD ptr cx > g_wMaxX)
				mov cx, g_wMaxX
			.endif
			.if (SWORD ptr dx < g_wMinY)
				mov dx, g_wMinY
			.elseif (SWORD ptr dx > g_wMaxY)
				mov dx, g_wMaxY
			.endif
		.endif
	.else
		mov cx,es:[edi].RMCS.rCX	;cursor column
		mov dx,es:[edi].RMCS.rDX	;cursor row
		shr cx,3
		shr dx,3
	.endif
	mov ax,es:[edi].RMCS.rAX	;event mask
if ?CTMOUSE
	xor bp, bp
	test g_bWheelCap,1
	jz @F
	test al,80h
	jz maskset
	movsx bx, byte ptr es:[edi].RMCS.rBX+1
	imul bx, -120
	mov bp, bx
	jmp maskset
@@:
endif
	and al,7Fh
maskset:
	cmp al,1					;is it just a move event?
	jnz @F
	cmp cx, g_wOldPosX
	jnz @F
	cmp dx, g_wOldPosY
	jz skip_event
@@:
	mov bx,es:[edi].RMCS.rBX	;button state
	mov g_wOldPosX, cx
	mov g_wOldPosY, dx
	mov esi, g_pEvntQWrite
	mov [esi].MOUEVNT.wPosX,cx
	mov [esi].MOUEVNT.wPosY,dx
if ?CTMOUSE
	mov [esi].MOUEVNT.wPosZ,bp
	mov bh,0
endif
	mov [esi].MOUEVNT.wState,bx
	mov [esi].MOUEVNT.wMask,ax

	cmp g_lpfnHandlerProc, 0
	jz @F
	pushad
	invoke g_lpfnHandlerProc, g_dwCookie, esi
	popad
	jnc dontqueueevent
@@:

	lea esi, [esi + sizeof MOUEVNT]
	cmp esi, offset end_of_eventqueue
	jnz @F
	mov esi, offset g_evntqueue
@@:
	mov g_pEvntQWrite, esi
	mov eax, g_pEvntQRead
	cmp esi, eax				;queue full?
	jnz skip_event
	lea eax, [eax + sizeof MOUEVNT]
	cmp eax, offset end_of_eventqueue	;skip oldest event
	jnz @F
	mov eax, offset g_evntqueue
@@:
	mov g_pEvntQRead, eax
dontqueueevent:
skip_event:
	pop ds
if ?USE_RMCB
	@iret
else
	retf
endif
	align 4
evntproc endp

;--- this proc is called by Read/PeekConsoleInput if no
;--- key event is available
;--- returns a certain mouse event in EAX
;--- if event isn't available, EAX is 0

_PeekMouEvent proc public dwIndex:DWORD

	mov ecx, dwIndex
	mov eax, g_pEvntQRead
	.repeat
		cmp eax, g_pEvntQWrite
		jz queue_empty
		jecxz done
		add eax, sizeof MOUEVNT
		cmp eax, offset end_of_eventqueue
		jnz @F
		mov eax, offset g_evntqueue
@@:
		dec ecx
	.until (0)
done:
	ret
queue_empty:
	xor eax,eax
	ret
	align 4
_PeekMouEvent endp

;--- get next mouse event in EAX ( 0 if no event )

_GetMouEvent proc public
	mov eax, g_pEvntQRead
	cmp eax, g_pEvntQWrite
	jz queue_empty
	mov ecx, eax
	add ecx, sizeof MOUEVNT
	cmp ecx, offset end_of_eventqueue
	jnz @F
	mov ecx, offset g_evntqueue
@@:
	mov g_pEvntQRead, ecx
	ret
queue_empty:
	xor eax, eax
	ret
	align 4
_GetMouEvent endp

;--- get number of mouse event in EAX

_GetNumberOfMouEvents proc public
	mov ecx, g_pEvntQRead
	xor eax, eax
@@:
	cmp ecx, g_pEvntQWrite
	jz @F
	inc eax
	add ecx, sizeof MOUEVNT
	cmp ecx, offset end_of_eventqueue
	jnz @B
	mov ecx, offset g_evntqueue
	jmp @B
@@:
	ret
	align 4
_GetNumberOfMouEvents endp

_SetMouEventHandler proc public pHandlerProc:DWORD, dwCookie:DWORD
	.if (pHandlerProc == -1)
		mov eax, g_lpfnHandlerProc
		mov edx, g_dwCookie
		jmp exit
	.endif
	@noints
	mov edx, dwCookie
	mov ecx, pHandlerProc
	xchg edx, g_dwCookie
	xchg ecx, g_lpfnHandlerProc
	@restoreints
	mov eax, ecx
exit:
	ret
	align 4
_SetMouEventHandler endp

GetNumberOfConsoleMouseButtons proc public pnumBtns:ptr DWORD
	movzx eax, g_wButtons
	mov ecx, pnumBtns
	mov [ecx],eax
	@mov eax, 1
	ret
	align 4
GetNumberOfConsoleMouseButtons endp

	END

