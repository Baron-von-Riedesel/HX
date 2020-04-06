        
;--- stub to load a PX file 
;--- imports are NOT supported, the binary
;--- must be "self-contained".

	.386
	.nolist
	include winnt.inc
	include dpmi.inc
	.list

?MZMINSIZ	equ 40h	;size of MZ header to expect/read

ifdef __JWASM__
	option MZ:?MZMINSIZ	;min size of MZ header if jwasm's -mz option is used
endif

ifndef ?HDPMI
?HDPMI	equ 0		;HDPMI included as a BLOB
endif

ifndef ?NORELOCS
?NORELOCS equ 0
endif

ife ?HDPMI
?LOADSERVER	equ 1	;try to find HDPMI if no DPMI host has been found
?SHRINKHDR	equ 0
?LOADHDR	equ 1	;load PE header into image in memory
else
?LOADSERVER	equ 1
?SHRINKHDR	equ 0	;0 or 1? 
?LOADHDR	equ 1	;must be 0 if ?SHINKHDR=1
endif

?ADDSTACK	equ 2000h	;amount to add to reserved stack
?TEST386	equ 1		;1=test for 386 cpu (needed?)
?RESTPE		equ 1		;1=restore "PE" (some code checks this)
?BUFSIZE	equ 8192

if ?HDPMI	;include the HDPMI host as a binary object?

HDPMI segment use16 public 'CODE'
inithost:
	include ..\hdpmi\stub32\hdpmi32.inc
	align 16
endhdpmi label byte        
HDPMI ends

endif

_TEXT segment dword public 'CODE'

;--- load PX image
;--- no imports are allowed.
;--- CS,SS,DS,ES=FLAT, FS,GS=0
;--- SI=real-mode segment PSP
;--- DI=real-mode buffer segment (8K)

;--- 1. copy filename to buffer
;--- 2. set ES flat
;--- 3. read MZ+PE header
;--- 4. alloc memory and copy section contents
;--- 5. resolve base fixups
;--- 6. call entry point for app/dlls
;--- 7. return (for dlls) with Carry if dll returned with eax=0


LoadPE proc

if ?HDPMI
	push edx
dwHostRes equ <[ebp+8]>
endif
	movzx esi,si
	push esi		;rmSeg
	movzx edi,di
	shl edi,4
	push edi		;buffer

rmSeg	equ <[ebp+4]>
buffer	equ <[ebp+0]>

	mov ebp,esp
if ?SHRINKHDR
	sub esp,sizeof IMAGE_NT_HEADERS + 4
dwPos	equ <[ebp-4]>
pehdr	equ <[ebp-(sizeof IMAGE_NT_HEADERS+4)].IMAGE_NT_HEADERS>
else
	sub esp,sizeof IMAGE_NT_HEADERS
pehdr	equ <[ebp-sizeof IMAGE_NT_HEADERS].IMAGE_NT_HEADERS>
endif
    
;--- open the binary, read MZ and PE header

	mov ax,3D00h
	call dosint
	jc error
	xchg ebx, eax	;=mov ebx, eax
	mov cx,?MZMINSIZ
	mov ah,3Fh
	call dosint		;load MZ header
	jc error
if ?SHRINKHDR
	mov eax,[edi+3Ch]	;position of PE header in binary
	mov dwPos, eax
endif
	mov dx,word ptr [edi+3Ch]
	mov cx,word ptr [edi+3Eh]
	mov ax,4200h
	int 21h
	jc error
	mov cx,sizeof IMAGE_NT_HEADERS
	mov ah,3Fh
	call dosint		;load PE header
	jc error
	mov esi,edi
	movzx ecx,cx
	mov edi,esp		;=lea edi,pehdr
	rep movsb
	mov edi,esp		;=lea edi,pehdr
	cmp word ptr [edi].IMAGE_NT_HEADERS.Signature,"XP"
	jnz error

;--- alloc memory for binary

if ?SHRINKHDR
	mov eax, dwPos
	and ax,0F000h
	sub [edi].IMAGE_NT_HEADERS.OptionalHeader.SizeOfImage, eax
	sub [edi].IMAGE_NT_HEADERS.OptionalHeader.AddressOfEntryPoint, eax
endif
	mov eax, [edi].IMAGE_NT_HEADERS.OptionalHeader.SizeOfImage
	push eax
;	 test [edi].IMAGE_NT_HEADERS.FileHeader.Characteristics, IMAGE_FILE_DLL
;	 jnz @F
	add eax, [edi].IMAGE_NT_HEADERS.OptionalHeader.SizeOfStackReserve
	add eax, ?ADDSTACK
@@:
if ?NORELOCS
	push ebx
	mov ebx, [edi.IMAGE_NT_HEADERS.OptionalHeader.ImageBase]
	mov ecx, eax	;size of mem block
	mov edx, 1		;allocated memory
	mov ax,504h
	int 31h
	jc memerror
	mov edi, ebx
	pop ebx
else
	test byte ptr [edi].IMAGE_NT_HEADERS.FileHeader.Characteristics,IMAGE_FILE_RELOCS_STRIPPED
	jnz error
	push ebx
	push eax		;size into BX:CX
	pop cx
	pop bx
	mov ax,501h
	int 31h
	jc memerror
	push bx		;linear address into EDI
	push cx
	pop edi
	pop ebx
endif

	pop ecx		;size of image

;--- clear image memory

	push edi
	xor eax,eax
	shr ecx,2
	rep stosd
	pop edi

;--- load section table

	movzx ecx, pehdr.FileHeader.NumberOfSections
	mov eax,sizeof IMAGE_SECTION_HEADER
	mul ecx
	sub esp,eax
	push ecx
	mov ecx,eax
	mov ah,3Fh
	call dosint
	jc error

if ?SHRINKHDR
	push edi
	add edi,3Ch
	mov eax,40h
	stosd
	lea esi,pehdr
	push ecx
	mov ecx,sizeof pehdr
	rep movsb
	pop ecx
	mov esi,buffer
	mov edx,edi
	rep movsb
	pop edi
	pop ecx		;get section count
	mov esi,edx

	mov eax,dwPos
	and ax,0F000h
	mov dwPos,eax
else
	mov esi,buffer
	push edi
	lea edi,[esp+8]
	rep movsb
	pop edi
	pop ecx		;restore section cnt
	mov esi,esp
endif
if ?LOADHDR
	sub esi,sizeof IMAGE_SECTION_HEADER
	mov esp,esi
	mov eax, pehdr.OptionalHeader.SizeOfHeaders
	mov [esi].IMAGE_SECTION_HEADER.SizeOfRawData, eax
	xor eax,eax
	mov [esi].IMAGE_SECTION_HEADER.PointerToRawData,eax
	mov [esi].IMAGE_SECTION_HEADER.VirtualAddress,eax
	inc ecx
else
	jecxz sectiondone
endif
nextsection:
	pushad
	call loadsection
	popad
	jc error
	add esi, sizeof IMAGE_SECTION_HEADER
	loop nextsection
sectiondone:
	mov esp, esi

;--- close image file

	mov ah,3Eh
	int 21h
    
if ?RESTPE
	mov eax,[edi+3Ch]
	mov byte ptr [edi+eax+1],'E'
endif

ife ?NORELOCS

;--- handle base relocations

	mov ecx, pehdr.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_BASERELOC*8].Size_
	mov esi, pehdr.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_BASERELOC*8].VirtualAddress
if ?SHRINKHDR
	sub esi, dwPos
endif
	mov edx, edi
	sub edx, pehdr.OptionalHeader.ImageBase

	add esi, edi	;RVA->linear
	add ecx, esi	;ecx=end of relocs (linear)

nextpage:
	cmp esi, ecx
	jnc reloc_done
	push ecx
	lodsd				;get RVA of page
	mov ebx, eax
	add ebx, edi		;convert RVA to linear address
if ?SHRINKHDR
	sub ebx, dwPos
endif
	lodsd
	lea ecx, [esi+eax-8];ecx=end of relocs for this page
	xor eax, eax
nextreloc:
	lodsw
	test ah,0F0h
	jz ignreloc
	and ah,0Fh
	add [eax+ebx], edx
ignreloc:
	cmp esi, ecx
	jb nextreloc
	pop ecx
	jmp nextpage
reloc_done:

endif	;?NORELOCS

;--- search EIP, store it in EDX
;--- store dll/exe flag in CL

	mov esi,edi
	mov edx,pehdr.OptionalHeader.AddressOfEntryPoint
	add edx,esi
	mov cl, byte ptr pehdr.FileHeader.Characteristics+1
    
;	test cl,IMAGE_FILE_DLL shr 8
;	jnz @F
	mov eax,esi
	add eax, pehdr.OptionalHeader.SizeOfImage
	add eax, pehdr.OptionalHeader.SizeOfStackReserve
	add eax, ?ADDSTACK
	mov esp,eax
@@:
	mov eax,sizexcode
	sub esp,eax
	mov edi,esp
	test cl, IMAGE_FILE_DLL shr 8
	jz isapp
	push 0			;dwReserved
	push 1			;DLL_PROCESS_ATTACH
	push esi		;hModule
isapp:
	push edi
	mov ecx,eax
	call xcopy
xcode:
;   xor ecx,ecx	;ecx is null already
	push ecx
	push ecx
	sub esp,2Ch	;resize the DOS memory block to the minimum needed
	mov edi,esp
	mov eax,rmSeg
	mov [edi].RMCS.rES,ax
if ?HDPMI
	mov eax,dwHostRes
	add eax,10h
	mov [edi].RMCS.rBX,ax
else
	mov [edi].RMCS.rBX,0010h
endif
	mov byte ptr [edi].RMCS.rAX+1,4Ah
	mov bx,0021h
	mov ax,0300h
	int 31h
	add esp,34h

;--- call app/dll entry point

	mov ebx,rmSeg
	shl ebx, 4
	xor ebp,ebp
	call edx
	mov ah,4Ch
	int 21h
sizexcode equ ($ - xcode + 3) and not 3
xcopy:
	xchg esi,[esp]
	rep movsb
	pop esi
	retn
memerror:
	call display
if ?NORELOCS
	db "memory allocation error",13,10,0	;may be 'out of memory' or 'no memory for req base address'
else
	db "out of memory",13,10,0
endif
error:
	mov ax,4CFFh
	int 21h

display:
	xchg esi,[esp]
nextchar:
	lodsb
	and al,al
	jz display_done
	mov dl,al
	mov ah,2
	int 21h
	jmp nextchar
display_done:
	xchg esi,[esp]
	retn

;--- esi=section header
;--- edi=image linear base
;--- bx=file handle

loadsection:
	add edi, [esi].IMAGE_SECTION_HEADER.VirtualAddress
if ?SHRINKHDR
	sub edi, dwPos
endif
	mov eax, [esi].IMAGE_SECTION_HEADER.PointerToRawData
	push eax
	pop dx
	pop cx
	mov ax,4200h
	int 21h
	jc failed
	mov ecx, [esi].IMAGE_SECTION_HEADER.SizeOfRawData
nextblock:
	jecxz readdone
	push ecx
	cmp ecx,?BUFSIZE
	jc @F
	mov ecx,?BUFSIZE
@@:
	mov ah,3Fh
	call dosint
	jc failed2
	sub [esp],ecx
	mov esi,buffer
	rep movsb
	pop ecx
	jmp nextblock
readdone:
	retn
failed2:
	pop ecx
failed: 
	retn

;--- use this proc for int 21h, ah=3Dh and 3Fh

dosint:
	push edi
	sub esp,34h
	mov edi,esp
	mov [edi].RMCS.rECX,ecx
	xor ecx,ecx
	mov [edi].RMCS.rSSSP,ecx
	mov [edi].RMCS.rEBX,ebx
	mov [edi].RMCS.rEDX,ecx
	mov [edi].RMCS.rEAX,eax
	mov eax,buffer
	shr eax,4
	mov [edi].RMCS.rDS,ax
	mov bx,0021h
	mov ax,0300h
	int 31h
	mov ebx,[edi].RMCS.rEBX
	mov ecx,[edi].RMCS.rECX
	mov ah,byte ptr [edi].RMCS.rFlags
	sahf
	mov eax,[edi].RMCS.rEAX
	lea esp,[esp+34h]
	pop edi
	retn

dwHostRes	equ <>
rmSeg		equ <>
buffer		equ <>
pehdr		equ <>
dwPos		equ <>
    
LoadPE endp

_TEXT ends

_TEXT16 segment use16 word public '16_CODE'

;loadserver proto near stdcall

;--- this is the real mode entry with functions
;--- 1. check if DPMI is there
;--- 2. if not, try to load HDPMI32 (in UMBs if available)
;--- 3. switch to PM as 32bit dpmi client
;--- 4. set all segment registers to FLAT
;--- 5. jump to proc LoadPE

start:

if ?HDPMI
hostres equ [bp+0]
endif
status1	equ [bp-2]
status2	equ [bp-4]
lpproc	equ [bp-8]

InitPM proc

if ?TEST386
	PUSHF
	mov AH,70h
	PUSH AX
	POPF				; on a 80386 in real-mode, bits 15..12
	PUSHF				; should be 7, on a 8086 they are F,
	POP AX				; on a 80286 they are 0
	POPF
	and ah,0F0h
	JS @F
	JNZ IS386
@@:
	mov dx,offset errmsg0
	jmp error
IS386:
endif
	mov ax,sp		;free DOS memory
	shr ax,4
	mov bx,ss
	add bx,ax
	mov ax,es
	sub bx,ax
	mov ah,4Ah
	int 21h

	shl bx,4
	push ds
	pop ss
	mov sp,bx
if ?HDPMI
	push 0
endif
	mov bp,sp

	mov ax,5802h		;save status umb
	int 21h
	xor ah,ah
	push ax				;status 1
	mov ax,5800h		;save memory alloc strategy
	int 21h
	xor ah,ah
	push ax				;status 2
	mov bx,0081h		;first high,then low
	mov cx,0001h		;include umbs
	call setumbstatus

	mov ax,1687h		;is DPMI existing?
	int 2fh
	and ax,ax
if ?LOADSERVER
	jz @F
 if ?HDPMI
	call inithdpmi
	mov hostres,dx
 else
	call loadserver
 endif
	mov ax,1687h
	int 2fh
	and ax,ax
	jnz nodpmihost
@@:
else
	jnz nodpmihost 		;error: no DPMI host
endif
	push es
	push di				;lpproc

	and si,si
	jz nomemneeded
							;alloc req real mode mem
	mov ah,48h
	mov bx,si
	int 21h
	jc outofmem

	mov es,ax
nomemneeded:
	call restoreumbstatus
	mov si,ds
	mov ax,0001 			;32 bit application
	call dword ptr [lpproc]	;jump to PM
	jc initfailed			;error: jmp to pm didnt work
	add sp,4+2+2

;--- here es=PSP, ds=ss=DGROUP, cs=TEXT16
;--- limits are 0FFFFh, except for PSP

	mov cx,1
	xor ax,ax
	int 31h 			;alloc selector for flat CS
	jc nodescriptor
	mov bx,ax
	xor cx,cx
	xor dx,dx
	mov ax,7			;set base CS to 0
	int 31h
	dec cx
	dec dx
	mov ax,8			;set limit to -1
	int 31h
	mov cx,cs
	lar ecx,ecx
	shr ecx,8
	or ch,0CFh
	mov ax,9
	int 31h
if ?HDPMI
	sub sp,?BUFSIZE-2
else
	sub sp,?BUFSIZE
endif

;	mov		es,ds:[2Ch]		;avoid the MASM 32bit offset
	db 8eh,06h,2Ch,00h

	SUB DI,DI
	mov al,00
	or cx,-1
	cld
@@:
	repnz scasb		;search end of environ (00,00)
	scasb
	jnz @B
	inc di			;skip 0001
	inc di

if ?HDPMI
	mov dx,hostres
endif

	mov bp,sp
	mov cx,260
@@:
	mov al,es:[di]
	mov [bp],al
	inc bp
	inc di
	and al,al
	loopnz @B

	mov di,sp
	shr di,4
	add di,si
	mov ax,000Ah
	int 31h				;create alias for CS
	jc nodescriptor
	push ebx
	mov cx,si
	movzx ecx,cx
	shl ecx,4
	mov ds,ax
	mov es,ax
	mov ss,ax
	add esp,ecx
	add ecx,00100h		;the _TEXT segment is first
if ?HDPMI
	add ecx,offset endhdpmi
endif
	push ecx
	db 66h
	retf

restoreumbstatus:
	mov cx,status1
	mov bx,status2
setumbstatus:
	push cx
	mov ax,5801h		;memory alloc strat restore
	int 21h
	pop bx
	mov ax,5803h		;umb link restore
	int 21h
	retn

nodpmihost:
	call restoreumbstatus
	mov dx,offset errmsg1
	jmp error
outofmem:
	call restoreumbstatus
initfailed:
nodescriptor:
	mov dx,offset errmsg2
error:
	push cs
	pop ds
	mov ah,09		;display error msg
	int 21h
	mov ax,4CFFh	;and exit to DOS
	int 21h
InitPM endp

if ?HDPMI

;--- this is for the standalone DPMILD32.BIN stub
;--- runs in real-mode!

inithdpmi proc
	push ds
	push bp
	mov bx,es
	add bx,10h
	push bx
	push offset Inithost
	mov bp,sp
	call far ptr [bp]
	pop bp	;skip the 2 words
	pop bp
	pop bp
	pop ds
;	mov ah,0
;	cmp al,4
;	cmc
	ret
inithdpmi endp

endif

if ?TEST386
errmsg0 db "80386 needed",13,10,'$'
endif
errmsg1 db "no DPMI host found",13,10,'$'
errmsg2 db "DPMI initialization failed",13,10,'$'

	align 2

_TEXT16 ends

if ?LOADSERVER
 ife ?HDPMI
	include loadsrvr.inc
 endif
endif

STACK segment para stack 'STACK'
	db ?BUFSIZE+2048 dup (?)
STACK ends

	END start
