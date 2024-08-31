
;--- GlobalRealloc 
;--- this version is included in DOSXXXS.LIB
;--- use DPMILD16:GLOBALREALLOC if available
;--- else use int 21h, ah=4Ah
;--- must only work for sizes up to 64 kB

		.286
        .model small
        
        .code

GLOBALREALLOC proc far pascal public wSel:WORD, dwNewSize:DWORD, uiMode:WORD

local	dwGlobalRealloc:dword

		mov cl,1
        mov dx,cs
		mov ax,4b88h	;get KERNEL module handle in DX
        stc
        int 21h
        jc nodpmildr
        mov cl,1
        mov bx,dx
        mov dx,16		;GlobalReAlloc is @16
        mov ax,4b85h	;GetProcAddress(KERNEL,16)
        int 21h
        mov cx,ax
        or cx, dx
        jz nodpmildr
        mov word ptr dwGlobalRealloc+0,ax
        mov word ptr dwGlobalRealloc+2,dx
        push wSel
        push word ptr dwNewSize+2
        push word ptr dwNewSize+0
        push uiMode
        call dwGlobalRealloc
        jmp done
nodpmildr:

;--- if it is a MZ binary, the block to resize might be DGROUP,
;--- which usually is NOT at the beginning of a DOS memory block!
;--- furthermore, it is allocated with 64 kB by jmppm16.obj already.

		mov ax,wSel
        mov cx,ds         ;assume DS==DGROUP
        cmp ax,cx
        jz	done

		mov bx,word ptr dwNewSize
        add bx,15
        shr bx,4
        and bx,bx
        jnz @F
        mov bx,1000h
@@:        
		push es
        mov es,ax
		mov ah,4ah
        int 21h
        pop es
        jc error
        push ds
        pop ds
        push ss
        pop ss
done:
        ret
error:
		xor ax,ax
        jmp done
        
GLOBALREALLOC endp

        end

