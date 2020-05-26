
;*** copy executable into extended memory   ***

        .386
;        .MODEL SMALL, stdcall

        include protmode.inc
        include dpmi.inc

        include jmppm32.inc

_DATA   segment dword public 'DATA'
externdef __ressize:dword
_DATA   ends

_TEXT32	segment dword public 'CODE'

movehigh proc c private dwSize:dword

local   sel:dword
local   descript:desc

		@trace	<"movehigh enter",13,10>
        xor     ax,ax              ;alloc 1 selector
        mov     cx,1
        int     31h
        jc      error
        mov     sel,eax

		mov		eax,dwSize
		add 	eax,__STACKSIZE
		add 	eax,__HEAPSIZE
        push	eax
        pop		cx
        pop		bx
        mov     ax,0501h           ;alloc extended memory
        int     31h
        jc      error

		@trace	<"movehigh milestone 1",13,10>

        push    bx
        push    cx
        pop     edi
        push    edi
        sub     edi,[__baseadd]    ;copy all 
        xor     esi,esi
        mov     ecx,dwSize         ;from DS:0 to ES:EDI
        shr     ecx,2
        rep     movsd

		@trace	<"movehigh milestone 2",13,10>

        mov     ebx,cs
        lea     edi,descript
        mov     ax,000Bh           ;get descriptor of CS
        int     31h
        pop     esi                ;new base -> esi
        jc      error

		@trace	<"movehigh milestone 3",13,10>

        mov     eax,esi
        mov     [edi.desc.A0015],ax  ;set new base in descriptor
        shr     eax,16
        mov     [edi.desc.A1623],al
        mov     [edi.desc.A2431],ah
        mov     ebx,sel
        mov     ax,000Ch
        int     31h
        jc      error

		@trace	<"movehigh milestone 4",13,10>

;		int 3
        mov     eax,cs               ;retf will set new CS
        push    ebx
        push    offset DGROUP:xxxx
        retf
xxxx:
		@trace	<"movehigh milestone 5",13,10>
        
        xor     [edi.desc.attrib],08 ;now construct a DATA segment
        mov     ebx,eax              ;we will use old CS selector for that
        mov     ax,000Ch
        int     31h
        jc      error
		@trace	<"movehigh milestone 6",13,10>
        mov     eax,ebx
        mov     ebx,ds

        mov     ds,eax               ;refresh all segment registers
        mov     es,eax
        mov     ss,eax

        mov     ax,0001              ;free old DS selector 
        int     31h
		@trace	<"movehigh milestone 7",13,10>

        mov     [__baseadd],esi

        jmp     exit
error:
        xor     eax,eax
exit:
		@trace	<"movehigh exit",13,10>
        ret
movehigh endp

;*** may change registers ***
;--- C if error occured

_movehigh proc stdcall

		@trace	<"_movehigh enter",13,10>
        invoke	movehigh,[__dossize]
        and     eax,eax
        stc
        jz      @F
		mov		ebx, [__psp]
        mov     ax,0006
        int     31h
        jc      @F
        sub     esp,sizeof RMCS + 2
        mov     edi,esp
        push    cx
        push    dx
        pop     eax			;linear address of PSP -> eax
        shr     eax,4

        mov     byte ptr [edi.RMCS.rEAX+1],4Ah    ;resize dos memory
        mov		edx, [__ressize]
        mov     word ptr [edi.RMCS.rEBX],dx
        mov     word ptr [edi.RMCS.rES],ax
        xor     ecx,ecx
        mov     dword ptr [edi.RMCS.rSP],ecx
        mov     bx,0021h
        mov     ax,0300h                          ;simulate real mode int
        int     31h
        add     esp,sizeof RMCS + 2
@@:
		@trace	<"_movehigh exit",13,10>
        ret
_movehigh endp

_TEXT32	ends

DGROUP	group _TEXT32

        end

