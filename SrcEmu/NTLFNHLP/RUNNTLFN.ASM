
        .386
        .model small,stdcall
        option casemap:none
        
        include dpmi.inc
        include macros.inc

InstallLFNHlp proto stdcall :DWORD

        .CODE

main    proc c

local	rmcs:RMCS
local   szText[80]:byte

		invoke	InstallLFNHlp, 0
        
        push    es
        mov		ah,51h
        int     21h
        mov     es,ebx
        xor		eax,eax
        xchg	ax,es:[002Ch]
        mov     es,eax
        mov     ah,49h
        int     21h
        pop     es

        xor     eax,eax
        mov     rmcs.rSSSP,eax     ;clear SS:SP
        mov     rmcs.rFlags,ax     ;clear flags
        mov     rmcs.rDX,8         ;set DX=8 (no of paragraphs)
        mov     rmcs.rAX,3100h     ;set AX=3100h
        lea     edi,rmcs           ;es:edi points to real mode call struct
        mov     bx,21h
        mov     cx,0
        mov     ax,0300h
        int     31h

main    endp

mainCRTStartup proc c public
		call	main
        mov		ah,4ch
        int		21h
mainCRTStartup endp

        END

