
;--- implements Win16 kernel emulation
;--- this is used by both DPMILD16 and DPMILD32
;--- since the latter supports loading of 16bit dlls
;--- best viewed with TABSIZE 4

	.286
	option casemap:none
	option proc:private

if ?32BIT
?LARGEALLOC	equ 0	;always 0, not needed for 32-bit
else
?LARGEALLOC	equ 1	;1=allow more than 1 MB with GlobalAlloc/Realloc/Free
endif

ife ?32BIT
;--- _hmemset(FAR16 dst, WORD value, DWORD cnt), requires __AHINCR
_hmemset proto pascal :dword, :word, :dword
externdef pascal lstrcpy:far
externdef pascal lstrcat:far
externdef pascal lstrlen:far
externdef discardmem:near
endif

WF_PMODE	equ 1
WF_CPU286	equ 2
WF_CPU386	equ 4
WF_CPU486	equ 8
WF_STANDARD equ 10h
WF_ENHANCED	equ 20h

@entercriticalsection macro
if 1
	mov ax,0900h
	int 31h
	push ax
else
	push bp
	mov bp,sp
	push ax
	in al,21h
	push ax
	mov al,0FFh
	out 21h,al
	mov ax,[bp-2]
endif
	endm

@exitcriticalsection macro
local l1
if 1
;	pop bx
;	test bh,2
;	jz l1
;	sti
	mov cx,ax
	pop ax
	int 31h
	mov ax,cx
l1:
else
	mov [bp-2],ax
	pop ax
	out 21h,al
	pop ax
endif
	endm


_TEXT segment dword public 'CODE'
_TEXT ends
CCONST segment word public 'CODE'
CCONST ends
_DATA segment word public 'DATA'
_DATA ends

	include ascii.inc
	include dpmildr.inc
	include kernel16.inc
	include trace.inc

_ITEXT segment word public 'DATA'	;use 'DATA' (OPTLINK bug)
_ITEXT ends

DGROUP group _TEXT,CCONST,_DATA,_ITEXT

	assume CS:DGROUP
	assume DS:DGROUP
	assume SS:NOTHING
	assume ES:DGROUP

if ?32BIT
	.386
endif

@return  macro xx
	retf xx
	endm

@loadbx macro
if ?32BIT
	mov ebx,esp
else
	mov bx,sp
endif
	endm

@loadparm macro ofs,xx
if ?32BIT
	mov xx,ss:[ebx+4+ofs]
else
	mov xx,ss:[bx+4+ofs]
endif
	endm

_TEXT segment

if _PROFSTRING_
	externdef pascal GetPrivateProfileString:far
	externdef pascal WritePrivateProfileString:far
endif

GetDOSEnvironment proc far pascal
	mov ah,51h
	int 21h
	mov es,bx
	mov dx,es:[002Ch]
	xor ax,ax
	ret
GetDOSEnvironment endp

UnlockSegment proc far pascal uSegment:word
UnlockSegment endp

LockSegment proc far pascal uSegment:word

	mov ax,uSegment
	ret

LockSegment endp

IsTaskLocked proc far pascal
	xor ax,ax
	ret
IsTaskLocked endp

UndefDynlink proc far pascal
	invoke string_out_prefix, CStr(<"Unresolved import called",lf>)
	jmp FatalExit
UndefDynlink endp

FatalAppExit proc far pascal
	@loadbx
	@loadparm 2,ds
	@loadparm 0,bx
	call stroutBX
FatalAppExit endp

FatalExit proc far pascal
	mov ds,cs:[wLdrDS]
	invoke string_out_prefix, CStr(<lf,"Fatal exit from application",lf>)
	mov ax,4C00h + RC_FATAL
	int 21h
FatalExit endp

GetVersion proc far pascal
	mov ah,30h
	int 21h
	mov dx,ax
	xchg dh,dl
	mov ax,0A03h
	ret
GetVersion endp

WaitEvent proc far pascal hTask:word
	ret
WaitEvent endp

;*****************************
;*** Local Heap functions  ***
;*****************************

if ?LOCALHEAP

;*** increase local heap segment 
;*** inp: DS=segment, AX=new size (0=64k)
;*** out: C=Fehler, AX=new size
;*** BX,CX,DX,SI,DI not modified

__incseg proc uses bx cx dx

	push ax
	xor cx,cx				  ;0000 -> 10000
	cmp ax,1
	adc cx,cx
	push ds					  ;selector
	push cx
	push ax					  ;CX:AX bytes request  
	push 0					  ;flags (means: FIXED)
	call far ptr GlobalReAlloc
	and ax,ax
	jz error
	pop ax
	clc
	jmp exit
error:
	pop dx
	stc
exit:
	ret
__incseg endp

;*** jump to the end of the local heap
;*** the end is marked with a (near) pointer to itself
;*** inp: DS=heap segment, BX=heap pointer ***
;*** out: BX,AX=^end of heap ***

__findlast proc
@@:
	mov AX,[BX]
	cmp AX,BX
	mov BX,AX
	jnz @B
	ret
__findlast endp

;*** grow heap segment
;*** inp: DS=heapsegm,CX=size,BX->heapdesc,DX=size last free segment

__growseg proc uses cx di

	call __findlast
	cmp ax,0FFF0h
	jnb growseg_err
	mov bx,ax
	sub cx,dx
	cmp cx,2000h
	jbe @F
	inc cx
	add ax,cx
	jc growseg_err
	inc ax
	jmp growseg_1
@@:
	add ax,2002h
	jnc growseg_1
	mov ax,0000 		;set AX to 64k (maximum) 
growseg_1:
	push ax
	push bx
	call __incseg
	pop bx
	pop ax
	jnc done	;jump if ok
growseg_err:
	stc 		;error
	jmp exit
done:			;grow has worked
	dec ax
	mov [bx],AX
	push bx
	and al,0FEh
	mov bx,ax
	mov [bx],ax
	pop bx
exit:
	ret
__growseg endp

;--- sets Win16 Local Heap start at DS:[0006]

LocalInit proc far pascal uSegment:word, uStart:word, uEnd:word

	mov ax,uSegment
	mov cx,uStart
	mov dx,uEnd
	and ax,ax
	jnz @F
	mov ax,ds
@@:
	cmp dx,4
	jb LocalInit_err
	lar bx,ax
	jnz LocalInit_err
	jcxz LocalInit_1
	cmp dx,cx
	jb LocalInit_err
	jmp LocalInit_2
LocalInit_1:
	lsl bx,ax
	inc bx
	mov cx,dx
	mov dx,bx
	sub bx,cx
	mov cx,bx
LocalInit_2:
	push ds
	mov ds,ax
	mov ds:[0006],cx
	add word ptr ds:[0006],2
	mov bx,cx
	sub dx,2
	mov [bx],dx
	or byte ptr [bx],1
	mov bx,dx
	mov [bx],dx
	mov ax,1
	pop ds
	jmp LocalInit_ex
LocalInit_err:
	xor ax,ax
LocalInit_ex:
	ret
LocalInit endp

;--- called by LocalAlloc
;*** get a free memory block in local heap
;*** inp: DS=heapsegm, BX= ^heapdesc, CX=size

__searchseg proc
	inc CX
	and CL,0FEh
__searchseg3:
	mov ax,[bx]
	cmp ax,bx
	jbe __searchseg5		;error, end of heap reached
	xor dx,dx
	test al,1				;free?
	jz __searchseg1			;if not -> go on 
	mov dx,ax
	sub dx,bx				;get size
	sub dx,3				;correct it
	cmp cx,dx
	jbe __searchseg2		;block is large enough
	push si 				;if next block is free as well
	and al,0FEh
	mov si,ax
	mov ax,[si]
	test al,1
	jz @F
	mov [bx],ax
	mov si,bx
@@:
	mov ax,si
	pop si
__searchseg1:
	mov bx,ax
	jmp __searchseg3
__searchseg5:
	stc
	ret
__searchseg2:				;found a free item
	mov dx,ax
	lea ax,[bx+2]
	jz __searchseg4			;size matches as well
	add cx,ax
	mov [bx],cx 			;save new pointer
	push bx
	mov bx,cx
	mov [bx],dx 			;save it here as well
	pop bx
__searchseg4:
	and byte ptr [bx],0FEh
	ret
__searchseg endp

LocalAlloc proc far pascal uses si di uFlags:word, uBytes:word

	mov cx,uBytes
	cmp CX,0FFE8h
	ja LocalAlloc1
	mov BX,ds:[0006h]
	and bx,bx
	jz LocalAlloc1
	sub bx,2
	call __searchseg
	jnc LocalAlloc2			;ok, free item found
	call __growseg
	jc LocalAlloc1			;heap cannot grow, error
	mov BX,ds:[0006h]
	sub bx,2
	call __searchseg
	jc LocalAlloc1			;was growing sufficient?
	mov cx,uFlags
	test cl,40h
	jz LocalAlloc2
	push ax
	push di
	mov cx,uBytes
	mov di,ax
	push ds
	pop es
	xor ax,ax
	shr cx,1
	cld
	rep stosw
	adc cl,0
	rep stosb
	pop di
	pop ax
	jmp LocalAlloc2
LocalAlloc1:
	xor AX,AX
LocalAlloc2:
	ret
LocalAlloc endp

LocalFree proc far pascal handle:WORD

	mov ax,handle
	mov bx,ds:[0006]
	and bx,bx
	jz LocalFree_err
	sub bx,2
	sub ax,2
LocalFree_2:
	cmp ax,bx
	jz LocalFree_3
	mov cx,[bx]
	and cl,0FEh
	cmp cx,bx
	mov bx,cx
	jnz LocalFree_2
LocalFree_err:
	xor ax,ax
	jmp LocalFree_ex
LocalFree_3:
	test byte ptr [bx],1
	jnz LocalFree_err
	or byte ptr [bx],1
LocalFree_ex:
	ret
LocalFree endp

LocalReAlloc proc far pascal
	xor ax,ax
	@return 6
LocalReAlloc endp

LocalUnlock proc far pascal
LocalUnlock endp

LocalLock proc far pascal
	pop cx
	pop dx
	pop ax
	push dx
	push cx
	retf
LocalLock endp

LocalSize proc far pascal
	@loadbx
	@loadparm 0,ax
	and ax,ax
	jz localsize_ex
	mov bx,ax
	mov ax,[bx-2]
	sub ax,bx
localsize_ex:
	@return 2
LocalSize endp

LocalCompact proc far pascal
	mov ax,ds:[0006]
	and ax,ax
	jz localcompact_ex
	sub ax,2
	mov bx,ax
	xor cx,cx
localcompact_3:
	mov ax,[bx]
	cmp ax,bx
	jz localcompact_2
	test al,1
	jz localcompact_1
	and al,0FEh
	cmp ax,cx
	jc localcompact_1
	mov cx,ax
localcompact_1:
	mov bx,ax
	jmp localcompact_3
localcompact_2:
	mov ax,cx
localcompact_ex:
	@return 2
LocalCompact endp

endif ;?LOCALHEAP


GlobalSize proc far pascal
	pop bx
	pop cx
	pop ax
	push cx
	push bx
if ?32BIT
	lsl eax,eax
	jnz @F
	push eax
	pop ax
	pop dx
else
	xor dx,dx
	lsl ax,ax
	jnz @F
endif
	add ax,1
	adc dx,0
	jmp exit
@@:
	xor ax,ax
	cwd
exit:
	@return
GlobalSize endp

;--- DWORD GlobalDOSAlloc(DWORD size)
;--- returns selector in ax, segment in dx

GlobalDOSAlloc proc far pascal
	pop bx
	pop cx
	pop ax			;get size into DX:AX
	pop dx
	push cx
	push bx
	mov cl,al
	shr ax,4
	shl dx,12		;skip bits 4-15 of DX
	or ax,dx
	test cl,0Fh
	jz @F
	inc ax
@@:
	mov bx,ax
	mov ax,0100h	;alloc dos memory
	int 31h
	xchg ax,dx
	jnc @F
	xor ax,ax
@@:
	@return
GlobalDOSAlloc endp

GlobalDOSFree proc far pascal
	pop bx
	pop cx
	pop dx
	push cx
	push bx
	mov ax,0101h		;free dos memory
	int 31h
	mov ax,dx
	jc @F
	xor ax,ax			;return 0 on success
@@:
	@return
GlobalDOSFree endp

GetWinFlags proc far pascal
	mov ax,cs:[eWinFlags.wOfs]
	ret
GetWinFlags endp

GetExePtr proc far pascal
	pop cx
	pop dx
	pop ax
	push dx
	push cx
	call checkne
	jnc ismodule
	push si
	mov si,ax
	call Segment2ModuleFirst
	pop si
ismodule:
	@return
GetExePtr endp

if ?32BIT
GetModuleHandle proc far pascal uses ds esi lpszModuleName:far ptr BYTE
else
GetModuleHandle proc far pascal uses ds si lpszModuleName:far ptr BYTE
endif

	mov si,word ptr lpszModuleName+0
	mov ax,word ptr lpszModuleName+2
if ?32BIT
	movzx esi,si	;SearchModule16 will use ESI in 32bit
endif				;but this proc is for NE-Dlls only
	mov bx,cs:[wMDSta]
	push bx			;the first entry should be kernel
	mov ds,ax
	and ax,ax
	jz @F
	call strlen
@@:
	call SearchModule16
	pop dx
	ret

GetModuleHandle endp

;--- GetModuleFileName(hInstance,lpszFileName,maxlen)
;--- hInstance may be a module handle or an instance handle

GetModuleFileName proc far pascal uses ds si di hInst:word, lpszFileName:far ptr BYTE, uMax:word

	push hInst
	call GetExePtr
	and ax, ax
	jz done
	mov ds, ax
	les di, lpszFileName
	mov cx, uMax
	mov si,offset NEHDR.szModPath
	push cx
@@:
	lodsb
	stosb
	and al,al
	loopnz @B
	pop ax
	sub ax,cx
	dec ax
done:
	ret
GetModuleFileName endp

GetModuleUsage proc far pascal
	pop cx
	pop dx
	pop es
	push dx
	push cx
	mov ax,es:[0002]
	@return
GetModuleUsage endp

DebugBreak proc far pascal
	int 3
	ret
DebugBreak endp

;--- WORD AllocSelectorArray(WORD)

AllocSelectorArray proc far pascal
	pop dx
	pop ax
	pop cx
	push ax
	push dx
	xor ax,ax
	int 31h
	ret
AllocSelectorArray endp

;--- WORD AllocSelector(WORD)
;--- returns 0 if an error occured

AllocSelector proc far pascal
	pop cx
	pop dx
	pop bx
	push dx
	push cx
	mov cx,0001
	xor ax,ax
	int 31h
	jc error
	and bx,bx
	jz @F
	push ds
	mov ds,cs:[wLdrDS]
	call CopyDescriptor	;copy BX -> AX
	pop ds
@@:
	ret
error:
	xor ax,ax
	ret
AllocSelector endp

;--- WORD FreeSelector(WORD)
;--- returns 0 if successful, else the selector!

FreeSelector proc far pascal
	pop cx
	pop dx
	pop bx
	push dx
	push cx
	mov ax,0001
	int 31h
	mov ax,0000
	jnc @F
	mov ax,bx
@@:
	ret
FreeSelector endp

;--- DWORD GetSelectorBase(WORD)

GetSelectorBase proc far pascal
	pop dx
	pop cx
	pop bx
	push cx
	push dx
	mov ax,0006
	int 31h
	jc @F
	mov ax,dx
	mov dx,cx
	ret
@@:
	xor ax,ax
	xor dx,dx
	ret

GetSelectorBase endp

;--- WORD SetSelectorBase(WORD)
;--- returns 0 if an error occured, else the selector value

SetSelectorBase proc far pascal
	@loadbx
	@loadparm 0,dx
	@loadparm 2,cx
	@loadparm 4,bx
	mov ax,0007
	int 31h
	mov ax,0000
	jc @F
	mov ax,bx
@@:
	@return 6
SetSelectorBase endp

;--- DWORD GetSelectorLimit(WORD)

GetSelectorLimit proc far pascal

	pop dx
	pop cx
	pop bx
	push cx
	push dx

if ?32BIT
	lsl eax,ebx
	jnz @F
	xor eax,eax
@@:
	push eax
	pop ax
	pop dx
	ret
else
	push di
	sub sp,8
	mov di,sp
	push ss
	pop es
	mov ax,000Bh	 ;get descriptor
	int 31h
	jc error
	mov ax,es:[di+0]
	mov dl,es:[di+6]
	and dx,000Fh
exit:
	add sp,8
	pop di
	ret
error:
	xor ax,ax
	xor dx,dx
	jmp exit
endif

GetSelectorLimit endp

;--- SetSelectorLimit(WORD);
;--- returns always 0

SetSelectorLimit proc far pascal
	@loadbx
	@loadparm 0,dx
	@loadparm 2,cx
	@loadparm 4,bx
	mov ax,0008
	int 31h
	mov ax,0000
if 0
	jc @F
	mov ax,bx
@@:
endif
	@return 6
SetSelectorLimit endp

;*** OutputDebugString ***

OutputDebugString proc far pascal uses ds si pszString:far ptr BYTE

	lds si,pszString
	mov ax,0012h
	int 41h
	ret
OutputDebugString endp

Dos3Call proc far pascal
	int 21h
	ret
Dos3Call endp

SetErrorMode proc far pascal
	pop cx
	pop ax
	pop dx
	push ax
	push cx
	call _SetErrorMode
	mov ax, dx
	@return
SetErrorMode endp

;--- 

LoadModule proc far pascal uses ds lpszModuleName:far ptr byte, lpParameterBlock:far ptr

	mov ds,cs:[wLdrDS]
	mov [fLoadMod],1	;use a asciiz command line
	lds dx, lpszModuleName
	les bx, lpParameterBlock
if ?32BIT
	movzx ebx,bx
	movzx edx,dx
endif
	mov ax,4B00h
	int 21h
	mov ds,cs:[wLdrDS]
	mov [fLoadMod],0
	ret
LoadModule endp

LoadLibrary proc far pascal uses ds lpszLibrary:far ptr byte
	lds dx, lpszLibrary
	xor bx,bx
	mov es,bx
if ?32BIT
	movzx edx, dx
	movzx ebx, bx
endif
	mov ax,4B00h
	int 21h
	ret
LoadLibrary endp

;void FreeLibrary(hModule);

FreeLibrary proc far pascal
	pop cx
	pop dx
	pop ax
	push dx
	push cx
	call FreeLib16	;C if error
	ret
FreeLibrary endp

;--- GetProcAddress(hInst,lpszProcName)

GetProcAddress proc far pascal uses ds hInst:word, lpszProcName:far ptr byte

	mov bx,hInst
	lds dx,lpszProcName
	xor cx,cx
	mov ax,ds
	and ax,ax
	jnz @F
	inc cx
@@:
	call GetProcAddress16
	ret

GetProcAddress endp

GetCurrentTask proc far pascal
	mov ah,51h
	int 21h
	mov ax,bx
	ret
GetCurrentTask endp

GetCurrentPDB proc far pascal
	mov ah,51h
	int 21h
	mov ax,bx
	mov dx,cs:[wLdrPSP]
	ret
GetCurrentPDB endp

GlobalLock proc far pascal
	pop cx
	pop bx
	pop dx
	push bx
	push cx
	xor ax,ax
	verr dx
	jnz @F
	retf
@@:
	xor dx,dx
	retf
GlobalLock endp

GlobalUnlock proc far pascal
	pop cx
	pop dx
	pop ax
	push dx
	push cx
	@return
GlobalUnlock endp

;--- GlobalAlloc(WORD flags, DWORD dwSize);
;--- according to win31 docs max size is 16 MB - 64 kB on a 80386
;--- and 1 MB - 80 bytes on a 80286

if ?32BIT
parm1	equ <esp+4>
parm2	equ <esp+4+4>
else
parm1	equ <bp+6>
parm2	equ <bp+6+4>
endif

GlobalAlloc proc far pascal

if ?32BIT
	mov ebx,[parm1]
	add ebx, 16-1
	jc error
	shr ebx,4
else
	push bp
	mov bp,sp
	mov ax,[parm1+0]
	mov dx,[parm1+2]
	mov cx, ax
	mov bx, dx
	add ax, 16-1
	adc dx, 0
	jc error
	test dx,0FFF0h
  if ?LARGEALLOC
	jnz largealloc
  else
	jnz error				;max of int 21h, ah=48h is 0FFFFh paragraphs ( actually, just 0fffeh )
  endif
	shr ax,4
	shl dx,12
	or ax, dx
	cmp ax,-1				;allocating 0FFFFh paras might not work
  if ?LARGEALLOC
	jz largealloc
  else
	jz error
  endif
	xchg bx,ax
endif
	mov ah,48h				;alloc with DOS call, so we need no
	int 21h 				;handle management (ebx paras)
	jc error
allocok:
	mov cx,[parm2]
	test cl,40h				;GMEM_ZEROINIT?
	jz exit
if ?32BIT
	mov ecx,[parm1]
	push ax
	push edi
	mov es,ax
	xor edi,edi
	xor al,al
	rep stos byte ptr es:[edi]
	pop edi
	pop ax
else
	push ax
	xor dx, dx
	invoke _hmemset, ax::dx, dx, [parm1]
	pop ax
endif
exit:
ife ?32BIT
	pop bp
endif
	@return 6
error:
	@trace_s <"GlobalAlloc failed",lf>
	xor ax,ax
	jmp exit

if ?LARGEALLOC

;--- dpmild16: if size in bx:cx is >= 0ffff0h
;--- this cannot be handled by the 16-bit DPMI host.

largealloc:
	test byte ptr cs:[eWinFlags.wOfs], WF_CPU286
	jnz error
	pusha
	mov bp,sp
	add cx, 8		; an 8 byte prefix is needed
	adc bx, 0
	push 0
	push bx
	push cx
	mov ax,0501h
	int 31h
	jc failed
	push bx			;save linear address
	push cx
	mov cx,[bp-4]	;get no of 64 k blocks
	cmp word ptr [bp-6],0
	jz @F
	inc cx
@@:
	mov [bp-2],cx
	xor ax,ax		; alloc selector array
	int 31h
	jc failed2
	mov bx, ax
	pop dx
	pop cx
	mov ax, 7		;set base
	int 31h
	pop dx
	pop cx
	push cx
	sub dx,1		;calc limit
	sbb cx,0
	or dx, 0fffh	;v3.11: ensure page granularity
	mov ax,8		;set limit
	int 31h
	mov es,bx
	mov es:[0],di	;save DPMI handle
	mov es:[2],si
	mov es:[4],bx	;save selector
	mov si,[bp-2]
	mov es:[6],si	;save no of selectors
	mov ax,6
	int 31h
	add dx,8
	adc cx,0
	mov ax,7
	int 31h
	push cx
	mov di,dx
nextdesc:
	dec si
	jz done
	add bx,8
	pop cx
	inc cx
	push cx
	mov dx,di
	mov ax,7
	int 31h
	mov ax,8
	mov dx,-1
	cmp si,1
	jnz @F
	mov cx,es
	lsl dx,cx
@@:
	mov cx,0
	int 31h
	jmp nextdesc
done:
	mov sp,bp
	mov [bp+0Eh],es
	popa
	jmp allocok
failed2:
	mov ax,0502h
	int 31h
failed:
	mov sp,bp
	popa
	jmp error
endif
GlobalAlloc endp

;--- GlobalFree(WORD handle);
;--- rc: ax=0 if successful, else ax=handle

GlobalFree proc far pascal
	pop cx
	pop dx
	pop bx		;get handle
	push dx
	push cx
if ?LARGEALLOC
	test byte ptr cs:[eWinFlags.wOfs], WF_CPU286
	jnz @F
	.386
	lsl eax,ebx
	jnz error
;	test eax,0FFF00000h	;limit >= 100000h
;	jnz largefree
	cmp eax,0FFFEFh			;largest block for int 21h
	jnc largefree
	.286
@@:
endif
	push es
	mov es,bx
	mov ah,49h
	int 21h
	pop ax
	verr ax
	jnz done
	mov es,ax
done:
	xor ax,ax
exit:
	ret
error:
	mov ax,bx
	jmp exit
if ?LARGEALLOC
failed: 
	add dx,8
	adc cx,0
	mov ax,7
	int 31h
	jmp error
largefree:
	mov ax,6		;get base
	int 31h
	jc error
	sub dx,8
	sbb cx,0
	mov ax,7		;set base
	int 31h
	mov es,bx
	cmp bx,es:[4]
	jnz failed
	mov ax,es:[6]
	and ax,ax
	jz failed
	pusha
	mov cx,ax
	mov di,es:[0]
	mov si,es:[2]
	mov ax,0502h
	int 31h
@@:
	mov ax,1
	int 31h
	add bx,8
	loop @B
	popa
	jmp done
endif
GlobalFree endp

;--- resize a module segment in DOS memory
;--- DX:AX = new size
;--- ES:BX-> segment descriptor

resizedosblock proc
	test dx,0FFF0h					;size > 1 MB is impossible
	jnz error
	mov cl,al
	shr ax,4
	shl dx,12
	or ax,dx
	test cl,0Fh
	jz @F
	inc ax
	jz error
@@:
	mov dx,es:[bx].SEGITEM.wDosSel
	xchg ax,bx
	mov ax,0102h
	int 31h
	jc error
	mov ax,dx
	ret
error:
	xor ax,ax
	stc
	ret
resizedosblock endp

;--- resize a module segment in extended memory
;--- DX:AX = new size
;--- ES:BX-> segment descriptor

resizeextmemblock proc
	push dx
	push ax
	push cx				;selector 1
	xor cx,cx
	test word ptr es:[bx.SEGITEM.flags],SF_ALIAS
	jz @F
	mov bx,word ptr es:[bx].SEGITEM.dwHdl+0
	mov cx,es:[bx].SEGITEM.wSel
@@:
	push cx				;selector 2
	push bx
	mov si,word ptr es:[bx].SEGITEM.dwHdl+2
	mov di,word ptr es:[bx].SEGITEM.dwHdl+0
	mov cx,ax
	mov bx,dx
	mov ax,0503h		;resize dpmi memory block
	int 31h
	mov dx,cx			;base address -> cx:dx
	mov cx,bx
	pop bx
	pop ax				;selector 2
	jc error0
	mov word ptr es:[bx].SEGITEM.dwHdl+2,si
	mov word ptr es:[bx].SEGITEM.dwHdl+0,di
	and ax,ax
	jz @F
	mov bx,ax
	mov ax,0007h		;set segment base address
	int 31h
@@:
	pop bx				;selector 1
	mov ax,0007h		;set segment base address
	int 31h
	jc error1
if ?32BIT
	pop ecx 			;new requested size
	dec ecx
	lsl eax,ebx
	cmp eax,ecx
	mov ax,bx
	jnc exit			;just grow, dont shrink
	mov dx,cx
	shr ecx,16
else
	pop dx
	pop cx
	sub dx,1
	sbb cx,0
endif
	mov ax,0008h		;set limit
	int 31h
	jc error2
	mov ax,bx
exit:
	clc
	ret
error0:
	pop ax
error1:
	pop dx
	pop cx
error2:
	xor ax,ax
	stc
	ret
resizeextmemblock endp

;*** called by GlobalRealloc(): the block to be resized is a module segment
;*** (E)SI is saved already
;--- ES:BX-> segment descriptor
;--- DX:AX=new size
;--- CX=Selector

;*** segment to resize might be DGROUP (SS == DGROUP)!
;*** there is a problem: the segment's linear base address
;*** may change. If SS (or CS?) are using this block
;*** the segment descriptor cache has to be reloaded.
;*** fix: the loader's stack is used during resizing.

resizemodulesegm proc uses di
	mov di, ax
	@entercriticalsection	;this routine is not reentrant
	mov ax, di
	mov di, ss			;switch to loader stack
if ?32BIT
	mov esi,esp
	mov ss,cs:[wLdrDS]
	mov esp,cs:[dStktop]
	push di
	push esi
else
	mov si,sp
	mov ss,cs:[wLdrDS]
	mov sp,cs:[wStktop]
	push di
	push si
endif
	cmp es:[bx].SEGITEM.wDosSel,0	;conventional memory?
	jz @F
	call resizedosblock
	jmp resizemodseg_1
@@:
	call resizeextmemblock
resizemodseg_1:
if ?32BIT
	pop esi
	pop ss
	mov esp,esi
else
	pop si
	pop ss
	mov sp,si
endif
	@exitcriticalsection
	ret

resizemodulesegm endp

;--- GlobalReAlloc(WORD hMem, DWORD dwSize, WORD flags);
;--- generally, this function is partly a stub. Quite a few things that work
;--- with the Windows version of GlobalRealloc won't work.
;--- todo: if block increases and GMEM_ZEROINIT is set, additional memory
;--- should be zeroed.

if ?32BIT
GlobalReAlloc proc far pascal uses esi hMem:WORD, dwNewsize:DWORD, uiMode:WORD 
else
GlobalReAlloc proc far pascal uses si hMem:WORD, dwNewsize:DWORD, uiMode:WORD 
endif

	mov si, hMem

	push si
	call Segment2ModuleFirst		;is it a module segment?
	pop cx
	mov ax, word ptr dwNewsize+0
	mov dx, word ptr dwNewsize+2
	jc @F
	call resizemodulesegm
	jmp exit
@@:
	mov es, cx
if ?32BIT
	mov cl,al
	push dx
	push ax
	pop eax
	adc eax, 16-1
	jc globalreallocerr
	shr eax, 4
	mov ebx,eax
else
	test dx,0FFF0h
	jnz globalreallocerr		;for 16-bit 1 MB - 10h is maximum
	mov cl,al
	shr ax,4
	shl dx,12
	or ax,dx
	test cl,0Fh					;since no D bit exists
	jz @F
	inc ax
	jz globalreallocerr
@@:
	xchg bx,ax
endif
	push es
	mov ah,4Ah
	int 21h
	pop ax
	jnc exit

globalreallocerr:
	xor ax,ax
exit:
	ret

GlobalReAlloc endp

GlobalUnfix proc far pascal
GlobalUnfix endp
GlobalFix proc far pascal
	@return 2
GlobalFix endp

GlobalHandle proc far pascal
	pop cx
	pop dx
	pop ax
	push dx
	push cx
	mov dx,ax
	@return
GlobalHandle endp

ife ?32BIT

;--- DWORD GlobalCompact(DWORD);
;--- returns the largest free memory object if dwMinFree != 0

GlobalCompact proc far pascal dwMinFree:DWORD

	mov ax,word ptr dwMinFree+0
	mov dx,word ptr dwMinFree+2
	mov cx,ax
	and cx,dx
	inc cx
	jnz @F
	push ds
	mov ds,cs:[wLdrDS]
	call discardmem
	pop ds
@@:
	push 0
	call GetFreeSpace
	ret
GlobalCompact endp

GetFreeSpace proc far pascal
	push es
	push di
	sub sp,48
	mov di,sp
	push ss
	pop es
	mov ax,0500h
	int 31h
	pop ax		;get the first dword in DX:AX
	pop dx
	add sp,48-4
	pop di
	pop es
	retf 2
GetFreeSpace endp

endif

AllocCSToDSAlias proc far pascal
	pop cx
	pop dx
	pop bx
	push dx
	push cx
	mov ax,000Ah
	int 31h
	jnc @F
	xor ax,ax
@@:
	@return
AllocCSToDSAlias endp

AllocDSToCSAlias proc far pascal
	pop dx
	pop cx
	pop bx
	push cx
	push dx
	mov cx,1
	xor ax,ax
	int 31h
	jc @F
	call CreateAlias
	jnc exit
@@:
	xor ax,ax
exit:
	@return

AllocDSToCSAlias endp

PrestoChangoSelector proc far pascal
	pop cx
	pop dx
	pop ax
	pop bx
	push dx
	push cx
	call CreateAlias	 ;BX -> AX
	@return

PrestoChangoSelector endp

if ?32BIT eq 0

_lclose proc far pascal
	@loadbx
	@loadparm 0,bx
	mov ah,3Eh
	int 21h
	jnc @F
	mov ax,-1
@@:
	@return 2
_lclose endp

_lread proc far pascal
	@loadbx
	push ds
	@loadparm 0,cx
	@loadparm 2,dx
	@loadparm 4,ds
	@loadparm 6,bx
	mov ah,3Fh
	int 21h
	jnc @F
	mov ax,-1
@@:
	pop ds
	@return 8
_lread endp

_lwrite proc far pascal
	@loadbx
	push ds
	@loadparm 0,cx
	@loadparm 2,dx
	@loadparm 4,ds
	@loadparm 6,bx
	mov ah,40h
	int 21h
	jnc @F
	mov ax,-1
@@:
	pop ds
	@return 8
_lwrite endp

_llseek proc far pascal
	@loadbx
	@loadparm 0,al
	@loadparm 2,dx
	@loadparm 4,cx
	@loadparm 6,bx
	mov ah,42h
	int 21h
	jnc @F
	mov ax,-1
@@:
	@return 8
_llseek endp

_lopen proc far pascal
	@loadbx
	push ds
	@loadparm 0,al
	@loadparm 2,dx
	@loadparm 4,ds
	mov ah,3Dh
	int 21h
	jnc @F
	mov ax,-1
@@:
	pop ds
	@return 6
_lopen endp

_lcreat proc far pascal
	@loadbx
	push ds
	@loadparm 0,al
	@loadparm 2,dx
	@loadparm 4,ds
	mov ah,3Ch
	int 21h
	jnc @F
	mov ax,-1
@@:
	pop ds
	@return 6
_lcreat endp

endif

;*** InitTask - this may be called by DPMI16 apps only.
;*** DPMI16 may be splitted to RTM and Win16 compatibles.
;*** this makes the initialization a bit confusing
;*** register values on entry:
;*** BX: Stacksize
;*** CX: Heapsize
;*** DI: might be Instance handle (== DGROUP)
;*** SI: 
;*** ES: PSP
;*** DS: DGROUP or PSP (if RTM compatible)
;*** SS: DGROUP
;*** SP: top of Stack
;*** Out: CX=stack limit
;*** SI=0 (previous instance)
;*** DI=module Handle
;*** ES=PSP
;*** ES:BX=CmdLine

ife ?32BIT

InitTask proc far pascal uses ds

	@trace_s <"InitTask enter",lf>
	mov ax,ss		;RTM compatibles may have DS == PSP
	mov ds,ax
	mov ax,sp
	add ax,2*3		;account for DS,IP,CS
	mov dx,ax
	sub dx,bx
	add dx,60h
	cmp word ptr ds:[0004],5
	jnz @F
	mov ds:[000Ah],dx	;stack bottom
	mov ds:[000Ch],ax
	mov ds:[000Eh],ax	;stack top
@@:
	push dx
if ?LOCALHEAP
	jcxz @F
	push ds			;data segment
	push 0			;start
	push cx			;end
	push cs
	call near ptr LocalInit	;preserves ES
@@:
endif
	call InitDlls
	pop cx		;stack limit
	mov ax,0
	jc error
	mov bx,0081h
	mov dx,1	;cmdshow?
	mov ax,es
	xor si,si	;previous instance
error:
exit:
	@printf <"InitTask exit, ax=%X",lf>,ax
	ret

InitTask endp

endif

_TEXT ends

_ITEXT segment

SetWinFlags proc
	mov ax,0400h			;get CPU
	int 31h
	mov ah,byte ptr [wEquip]
	and ah,2				;FPU?
	shl ah,1
	mov al,1
	dec cl
	cmp cl,3
	jbe @F
	mov cl,3
@@:
	shl al,cl				;processor (2=286,4=386,8=486)
	or al,WF_PMODE or WF_STANDARD
;	mov [WinFlags],ax
	mov [eWinFlags.wOfs],ax
	ret
SetWinFlags endp

if 0
SetProcAddress:
	push bx				 ;offset of procedure
	call GetProcAddr16	 ;search entry AX in module ES
	mov bx,cx
	pop ax
	jc @F
	mov es:[bx].ENTRY.wOfs,ax
	clc
@@:
	ret
endif

segments label word
ife ?32BIT
	dw eA000, 0A000h
	dw eB000, 0B000h
	dw eB800, 0B800h
	dw e0000, 00000h
	dw eF000, 0F000h
	dw eC000, 0C000h
endif
SIZESEGS equ ($ - segments) / 4


InitKernel proc public
	pusha
	mov KernelNE.ne_cseg, 1
	mov KernelNE.ne_segtab, KernelSeg -  KernelNE
	mov KernelNE.ne_restab, KernelNames - KernelNE
	mov KernelSeg.wSel, cs

	call SetWinFlags

if SIZESEGS
	mov si,offset segments
	mov cx,SIZESEGS
nextseg:
	lodsw
	push ax
	lodsw
	xchg bx,ax
	mov ax,0002	;alloc rm selector
	int 31h
	pop bx
	jc @F
	mov [bx].ENTRY.wOfs,ax
@@:
	loop nextseg
endif

	mov ax,0003 		   ;get AHINC value
	int 31h
	jc @F
	mov [eINCR.wOfs],ax
@@:

if ?MEMFORKERNEL
	xor bx,bx
	mov cx,1000h	;alloc 4 kB
	mov ax,501h
	int 31h
	jc exit
	mov word ptr KernelNE.MEMHDL+0,si
	mov word ptr KernelNE.MEMHDL+2,di
	push bx
	push cx
	mov cx,1
	xor ax,ax		;alloc 1 descriptor
	int 31h
	pop dx
	pop cx
	jc exit
	mov bx,ax
else
	mov cx,1
	xor ax,ax
	int 31h
	jc exit
	push ax
	mov bx,cs
	mov ax,6		;get base of CS
	int 31h
	pop bx
	add dx,offset KernelNE
	adc cx,0
endif
	mov ax,7		;set base
	int 31h
	mov dx,(EndKernelNE - KernelNE) - 1
	or dl,0Fh
	xor cx,cx
	mov ax,8		;set limit
	int 31h
	mov es,bx
	mov [wMDSta],bx
	@printf <"InitKernel: Module=%X, limit=%X",lf>, bx, dx
if ?MEMFORKERNEL
	xor di,di
	mov si,offset KernelNE
	mov cx,EndKernelNE - KernelNE
	rep movsb
endif
	clc
exit:
	popa
	ret
InitKernel endp

_ITEXT ends

ENTHDR struct
bCnt	db ?
bValid	db ?
ENTHDR ends

ENTRY struct
bSegm	db ?
wOfs	dw ?
ENTRY ends

_DATA segment

KernelNE NEHDR <"EN", 1, KernelEntries - KernelNE, 0, 0, NEHDR.szModPath - 8, 0, AF_DLL or AF_INIT>
        db 79 dup (0)

externdef _end:abs

KernelSeg SEGITEM <0,_end, 0, _end>

KernelEntries label byte
	ENTHDR <1,1>			; 1
	ENTRY <1,FatalExit>
	ENTHDR <1,0>			; 2 skipped
ife ?32BIT
	ENTHDR <8,1>			; 3-10
	ENTRY <1,GetVersion>	; 3
	ENTRY <1,LocalInit>		; 4
	ENTRY <1,LocalAlloc>
	ENTRY <1,LocalReAlloc>
	ENTRY <1,LocalFree>
	ENTRY <1,LocalLock>
	ENTRY <1,LocalUnlock>
	ENTRY <1,LocalSize>		; 10
	ENTHDR <2,0>			; 11-12 skipped
	ENTHDR <1,1>			; 13
	ENTRY <1,LocalCompact>
	ENTHDR <1,0>			; 14 skipped
else
	ENTHDR <1,1>			; 3
	ENTRY <1,GetVersion>
	ENTHDR <11,0>			; 4-14 skipped
endif
	ENTHDR <7,1>			; 15-21
	ENTRY <1,GlobalAlloc>
	ENTRY <1,GlobalReAlloc>
	ENTRY <1,GlobalFree>
	ENTRY <1,GlobalLock>
	ENTRY <1,GlobalUnlock>
	ENTRY <1,GlobalSize>
	ENTRY <1,GlobalHandle>	; 21
	ENTHDR <1,0>			; 22 skipped
ife ?32BIT
	ENTHDR <3,1>			; 23-25
else
	ENTHDR <2,1>			; 23-24
endif
	ENTRY <1,LockSegment>	; 23
	ENTRY <1,UnlockSegment>
ife ?32BIT
	ENTRY <1,GlobalCompact>	; 25
	ENTHDR <4,0>			; 26-29 skipped
else
	ENTHDR <5,0>			; 25-29 skipped
endif
	ENTHDR <1,1>			; 30
	ENTRY <1,WaitEvent>
	ENTHDR <5,0>			; 31-35 skipped
	ENTHDR <2,1>			; 36-37
	ENTRY <1,GetCurrentTask>
	ENTRY <1,GetCurrentPDB>
	ENTHDR <7,0>			; 38-44 skipped
	ENTHDR <1,1>			; 45
	ENTRY <1,LoadModule>
	ENTHDR <1,0>			; 46 skipped
	ENTHDR <4,1>			; 47-50
	ENTRY <1,GetModuleHandle>
	ENTRY <1,GetModuleUsage>
	ENTRY <1,GetModuleFileName>
	ENTRY <1,GetProcAddress>
	ENTHDR <30,0>			; 51-80 skipped
ife ?32BIT
	ENTHDR <6,1>			; 81-86
	ENTRY <1,_lclose>
	ENTRY <1,_lread>
	ENTRY <1,_lcreat>
	ENTRY <1,_llseek>
	ENTRY <1,_lopen>
	ENTRY <1,_lwrite>
	ENTHDR <1,0>			; 87 skipped
	ENTHDR <4,1>			; 88-91
	ENTRY <1,lstrcpy>
	ENTRY <1,lstrcat>
	ENTRY <1,lstrlen>
	ENTRY <1,InitTask>
	ENTHDR <3,0>			; 92-94 skipped
else
	ENTHDR <14,0>			; 81-94 skipped
endif
	ENTHDR <2,1>			; 95-96
	ENTRY <1,LoadLibrary>
	ENTRY <1,FreeLibrary>
	ENTHDR <5,0>			; 97-101 skipped
	ENTHDR <1,1>			; 102
	ENTRY <1,Dos3Call>
	ENTHDR <4,0>			; 103-106 skipped
	ENTHDR <1,1>			; 107
	ENTRY <1,SetErrorMode>
	ENTHDR <5,0>			; 108-112 skipped
	ENTHDR <2,-2>			; 113-114
eSHIFT	ENTRY <1,3>			; 113 _AHSHIFT
eINCR	ENTRY <1,8>			; 114 _AHINCR
	ENTHDR <1,1>			; 115
	ENTRY <1,OutputDebugString>
	ENTHDR <4,0>			; 116-119 skipped
	ENTHDR <1,1>			; 120
	ENTRY <1,UndefDynlink>
	ENTHDR <1,0>			; 121 skipped
	ENTHDR <1,1>			; 122
	ENTRY <1,IsTaskLocked>
if _PROFSTRING_
	ENTHDR <5,0>			; 123-127 skipped
	ENTHDR <2,1>			; 128-129
	ENTRY <1,GetPrivateProfileString>
	ENTRY <1,WritePrivateProfileString>
	ENTHDR <1,0>			; 130 skipped
else
	ENTHDR <8,0>			; 123-130 skipped
endif
	ENTHDR <3,1>			; 131-133
	ENTRY <1,GetDOSEnvironment>
	ENTRY <1,GetWinFlags>
	ENTRY <1,GetExePtr>
	ENTHDR <3,0>			; 134-136 skipped
	ENTHDR <1,1>			; 137
	ENTRY <1,FatalAppExit>
ife ?32BIT
	ENTHDR <31,0>			; 138-168 skipped
	ENTHDR <1,1>			; 169
	ENTRY <1,GetFreeSpace>
else
	ENTHDR <32,0>			; 138-169 skipped
endif
	ENTHDR <2,1>			; 170-171
	ENTRY <1,AllocCSToDSAlias>
	ENTRY <1,AllocDSToCSAlias>
if ?32BIT eq 0
	ENTHDR <2,0>			; 172-173 skipped
	ENTHDR <1,-2>			; 174
eA000 ENTRY <1,00h>			; 174 _A000H
else
	ENTHDR <3,0>			; 172-174 skipped
endif
	ENTHDR <3,1>			; 175-177
	ENTRY <1,AllocSelector>
	ENTRY <1,FreeSelector>
	ENTRY <1,PrestoChangoSelector>
	ENTHDR <1,-2>			; 178
eWinFlags ENTRY <1,0>		; 178 __WINFLAGS

if ?32BIT eq 0
	ENTHDR <2,0>			; 179-180 skipped
	ENTHDR <3,-2>			; 181-183
eB000 ENTRY <1,0>			; 181 _B000H
eB800 ENTRY <1,0>			; 182 _B800H
e0000 ENTRY <1,0>			; 183 _0000H
else
	ENTHDR <5,0>			; 179-183 skipped
endif
	ENTHDR <6,1>			; 184-189
	ENTRY <1,GlobalDOSAlloc>
	ENTRY <1,GlobalDOSFree>
	ENTRY <1,GetSelectorBase>
	ENTRY <1,SetSelectorBase>
	ENTRY <1,GetSelectorLimit>
	ENTRY <1,SetSelectorLimit>
	ENTHDR <3,0>			; 190-192 skipped
ife ?32BIT
	ENTHDR <3,-2>			; 193-195
e0040 ENTRY <1,0040h>		; 193 _0040H
eF000 ENTRY <1,0>			; 194 _F000H
eC000 ENTRY <1,0>			; 195 _C000H
else
	ENTHDR <1,-2>			; 193
e0040 ENTRY <1,0040h>		; 193 _0040h
	ENTHDR <2,0>			; 194-195 skipped
endif
	ENTHDR <1,0>			; 196 skipped
	ENTHDR <2,1>			; 197-198
	ENTRY <1,GlobalFix>
	ENTRY <1,GlobalUnfix>
	ENTHDR <4,0>			; 199-202 skipped
	ENTHDR <1,1>			; 203
	ENTRY <1,DebugBreak>
	ENTHDR <2,0>			; 204-205 skipped
	ENTHDR <1,1>			; 206
	ENTRY <1,AllocSelectorArray>
	db 0

NENAME macro name, export
local x1,x2
	db x2 - x1
x1	equ $
	db name
x2	equ $
	dw export
	endm

KernelNames label byte
	NENAME "KERNEL"    ,0
	NENAME "FATALEXIT" ,1
	NENAME "GETVERSION",3
ife ?32BIT
	NENAME "LOCALINIT"   ,4
	NENAME "LOCALALLOC"  ,5
	NENAME "LOCALREALLOC",6
	NENAME "LOCALFREE"   ,7
	NENAME "LOCALLOCK"   ,8
	NENAME "LOCALUNLOCK" ,9
	NENAME "LOCALSIZE"   ,10
	NENAME "LOCALCOMPACT",13
endif
	NENAME "GLOBALALLOC"  ,15
	NENAME "GLOBALREALLOC",16
	NENAME "GLOBALFREE"   ,17
	NENAME "GLOBALLOCK"   ,18
	NENAME "GLOBALUNLOCK" ,19
	NENAME "GLOBALSIZE"   ,20
	NENAME "GLOBALHANDLE" ,21
	NENAME "LOCKSEGMENT"  ,23
	NENAME "UNLOCKSEGMENT",24
ife ?32BIT
	NENAME "GLOBALCOMPACT",25
endif
	NENAME "WAITEVENT"        ,30
	NENAME "GETCURRENTTASK"   ,36
	NENAME "GETCURRENTPDB"    ,37
	NENAME "LOADMODULE"       ,45
	NENAME "GETMODULEHANDLE"  ,47
	NENAME "GETMODULEUSAGE"   ,48
	NENAME "GETMODULEFILENAME",49
	NENAME "GETPROCADDRESS"   ,50
ife ?32BIT
	NENAME "_LCLOSE",81
	NENAME "_LREAD" ,82
	NENAME "_LCREAT",83
	NENAME "_LLSEEK",84
	NENAME "_LOPEN" ,85
	NENAME "_LWRITE",86
	NENAME "LSTRCPY",88
	NENAME "LSTRCAT",89
	NENAME "LSTRLEN",90
	NENAME "INITTASK"    ,91
endif
	NENAME "LOADLIBRARY" ,95
	NENAME "FREELIBRARY" ,96
	NENAME "DOS3CALL"    ,102
	NENAME "SETERRORMODE",107
	NENAME "__AHSHIFT"   ,113
	NENAME "__AHINCR"    ,114

	NENAME "OUTPUTDEBUGSTRING", 115
	NENAME "UNDEFDYNLINK",      120
	NENAME "ISTASKLOCKED",      122
if _PROFSTRING_
	NENAME "GETPRIVATEPROFILESTRING"  ,128
	NENAME "WRITEPRIVATEPROFILESTRING",129
endif
	NENAME "GETDOSENVIRONMENT", 131
	NENAME "GETWINFLAGS"      , 132
	NENAME "GETEXEPTR"        , 133
	NENAME "FATALAPPEXIT"     , 137
ife ?32BIT
	NENAME "GETFREESPACE"     , 169
endif
	NENAME "ALLOCCSTODSALIAS" , 170
	NENAME "ALLOCDSTOCSALIAS" , 171
if ?32BIT eq 0
	NENAME "__A000H", 174
endif
	NENAME "ALLOCSELECTOR"       , 175
	NENAME "FREESELECTOR"        , 176
	NENAME "PRESTOCHANGOSELECTOR", 177
	NENAME "__WINFLAGS"          , 178
if ?32BIT eq 0
	NENAME "__B000H", 181
	NENAME "__B800H", 182
	NENAME "__0000H", 183
endif
	NENAME "GLOBALDOSALLOC"   ,184
	NENAME "GLOBALDOSFREE"    ,185
	NENAME "GETSELECTORBASE"  ,186
	NENAME "SETSELECTORBASE"  ,187
	NENAME "GETSELECTORLIMIT" ,188
	NENAME "SETSELECTORLIMIT" ,189
	NENAME "__0040H"          ,193
ife ?32BIT
	NENAME "__F000H", 194
	NENAME "__C000H", 195
endif
	NENAME "GLOBALFIX"          ,197
	NENAME "GLOBALUNFIX"        ,198
	NENAME "DEBUGBREAK"         ,203
	NENAME "ALLOCSELECTORARRAY" ,206
	db 0

EndKernelNE equ $

_DATA ends

	end
