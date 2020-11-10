
;--- Save/Restore VESA video state

		.386
if ?FLAT
		.MODEL FLAT, stdcall
else
		.MODEL SMALL, stdcall
endif
		option casemap:none
		option proc:private

		include function.inc
		include vesa32.inc
		include dpmi.inc
		include macros.inc

?DISINTS	equ 0
?SAVEPAL	equ 0	;save first 17 registers of attribute controler

		.DATA

		public g_dwRestoreNotify

g_dwRestoreNotify dd 0

		.CODE

;--- uses vesa calls:
;--- int 10h, ax=4F04h
;--- inp: AX=buffer seg
;--- inp: DL=function (0=get size, 1=save state, 2=restore state)

callint104f04 proc uses edi ebx

local   rmcs:RMCS

		lea edi, rmcs
		xor ecx, ecx
		mov rmcs.rSSSP,ecx
		mov rmcs.rFlags,cx
		mov rmcs.rES,ax
		mov byte ptr rmcs.rDX,dl
		mov rmcs.rCX,000Fh	;bits what to save
		mov rmcs.rBX,cx		;offset of state buffer
		mov rmcs.rAX,4F04h
		mov bx,0010h
		mov ax,0300h
		int 31h
		jc error
		cmp rmcs.rAX,004Fh	;supported and ok?
		jnz error
		movzx eax, rmcs.rBX
		clc
		ret
error:
		xor eax,eax
		stc
		ret
		align 4
callint104f04 endp

if ?SAVEPAL

;--- call int 10, ah=10, al=02/12

callint1010xx proc uses edi ebx

local   rmcs:RMCS

		lea edi, rmcs
		xor ecx, ecx
		mov rmcs.rSSSP,ecx
		mov rmcs.rES,ax
		mov rmcs.rDX,cx
		mov rmcs.rBX,cx
		mov rmcs.rFlags,cx
		mov dh,10h
		mov rmcs.rAX,dx
		mov bx,0010h
		mov ax,0300h
		int 31h
		ret
		align 4
callint1010xx endp

endif

GetVesaStateBufferSize proc public
		mov dl,0
		call callint104f04
		jc exit
		shl eax, 6
if ?SAVEPAL
		add eax, 4+20	;extra room for size
else
		add eax, 4		;extra room for size
endif
exit:
		ret
		align 4
GetVesaStateBufferSize endp

SaveVesaVideoState proc public uses esi edi ebx pSaveBuffer:ptr, dwSize:dword

local	dosmemsel:dword
if ?SAVEPAL
local	dosmemseg:dword
endif

		mov edi, pSaveBuffer
		xor eax,eax
		mov dosmemsel,eax
		mov eax, dwSize
if ?SAVEPAL
		lea eax, [eax-(4+20)]	;dont count the "size" dword
else
		lea eax, [eax-4]	;dont count the "size" dword
endif
		stosd
		mov ebx, eax
		mov dwSize, ebx		;save it!
		shr ebx, 4
		inc ebx
		mov ax,0100h		;alloc DOS memory
		int 31h
		jc svmx_er
		mov dosmemsel,edx
if ?SAVEPAL
		mov dosmemseg,eax
endif
		movzx esi, ax
		shl esi, 4
		mov dl,1			;save VESA state
		call callint104f04
		jc svmx_er
		mov ecx, dwSize
ife ?FLAT
		push ds
		push gs
		pop ds
endif
		rep movsb
ife ?FLAT
		pop ds
endif
if ?SAVEPAL
		mov eax, dosmemseg
		movzx esi, ax
		shl esi, 4
		mov dl, 9			;read 16 registers
		call callint1010xx
		mov ecx, 17
  ife ?FLAT
		push ds
		push gs
		pop ds
  endif
		rep movsb
  ife ?FLAT
		pop ds
  endif
endif
		@mov eax,1
		jmp svmx_ex
svmx_er:
		xor eax,eax
svmx_ex:
		mov edx,dosmemsel
		and edx,edx
		jz @F
		push eax
		mov ax,0101h
		int 31h
		pop eax
@@:
		ret
		align 4
SaveVesaVideoState endp

RestoreVesaVideoState proc public uses esi edi ebx pSaveBuffer:ptr

local	dwSize:dword
local   dosmemsel:dword
if ?SAVEPAL
local   dosmemseg:dword
endif

		mov esi, pSaveBuffer
		xor eax,eax
		mov dosmemsel,eax
		lodsd
		mov dwSize, eax		;here no adjustment necessary
		mov ebx, eax
		shr ebx, 4
		inc ebx
		mov ax,0100h		;alloc DOS memory
		int 31h
		jc svmx_er
		mov dosmemsel,edx
if ?SAVEPAL 	   
		mov dosmemseg,eax
endif		 
		movzx edi, ax
		shl edi, 4
		mov ecx, dwSize
		push eax
ife ?FLAT
		push es
		push gs
		pop es
endif
		rep movsb
ife ?FLAT
		pop es
endif
		pop eax
		mov dl,2
if ?DISINTS
		@noints
endif
		call callint104f04
		jc svmx_er1
if ?SAVEPAL
		mov eax, dosmemseg
		push eax
		movzx edi, ax
		shl edi, 4
ife ?FLAT
		push es
		push gs
		pop es
endif
		mov ecx, 17
		rep movsb
  ife ?FLAT
		pop es
  endif
		pop eax
		mov dl, 2			;set 17 registers
		call callint1010xx
endif
		.if (g_dwRestoreNotify)
			call g_dwRestoreNotify
		.endif
if ?DISINTS
		@restoreints
endif
		@mov eax,1
		jmp svmx_ex
svmx_er1:
		@restoreints
svmx_er:
		xor eax,eax
svmx_ex:
		mov edx,dosmemsel
		and edx,edx
		jz @F
		push eax
		mov ax,0101h
		int 31h
		pop eax
@@:
		ret
		align 4
RestoreVesaVideoState endp

		END
