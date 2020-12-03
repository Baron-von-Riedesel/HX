
;--- patch all relocs in MZ binary
;--- this code requires a 80386!

if 0
		.286
		.MODEL SMALL
		.386
CGROUP	group _TEXT
endif

        include winnt.inc

;		.CONST

szError1	db "binary not found",13,10,'$'
szError2	db "binary is invalid",13,10,'$'
szError4	db "no selectors available",13,10,'$'

;		.CODE

PatchRelocs proc uses es

local	pszPath:dword
local	wSP:WORD
local	MzHdr[32]:byte

        pushad
        mov		wSP, sp

;--- get path of executable        
        
		mov	es, es:[2ch]
        xor	di, di
        or	cx,-1
       	mov al,0
@@:        
        repnz scasb
        scasb
        jnz @B
        cmp	word ptr es:[di],1
        jnz	exit
        inc	di
        inc	di
        mov	word ptr pszPath+0,di
        mov	word ptr pszPath+2,es

;--- open image

		push	ds
		lds		dx, pszPath
        mov		ax, 3D00h
        int		21h
        pop		ds
        jc		error1
        mov		bx,ax
        
        mov		cx,sizeof MzHdr
        lea		dx,MzHdr
      	mov		ax,3f00h
        int		21h
        jc		error2
        cmp		ax,cx
        jc		error2

        mov		dx, MzHdr.IMAGE_DOS_HEADER.e_lfarlc		;offset relocs
        xor		cx, cx
      	mov		ax,4200h
        int		21h
        jc		error2

;--- read relocs

        mov		cx, MzHdr.IMAGE_DOS_HEADER.e_crlc		;no of relocs
        shl		cx, 2									;size reloc is 4
        sub		sp, cx
        mov		dx, sp
        mov		ax, 3f00h
        int		21h
        jc		error2
        cmp		ax,cx
        jnz		error2
        mov		si, dx

		mov		ah,3Eh
        int		21h
        
        mov		ah,51h
        int		21h
        mov		ax,6
        int		31h
        push	cx
        push	dx
        pop		edi
        add		edi,100h

;--- build a flat selector

		xor		ax,ax
        mov		cx,1
        int		31h
        jc		error4
        mov		bx,ax
        mov		es,ax
        or 		cx,-1
        mov		dx,cx
        mov		ax,8
        int		31h

;--- handle relocations

        mov		cx, MzHdr.IMAGE_DOS_HEADER.e_crlc		;no of relocs
        mov		bx, CGROUP
        push	bp
        mov		bp, DGROUP
        jcxz	done
nextitem:
		lodsw
        movzx edx,ax
        lodsw
       	movzx eax,ax
        shl eax,4
        add eax, edx
        mov dx, es:[edi+eax]
        cmp dx, bp
        jz isdgroup
        cmp dx, bx
        jz iscgroup 
;--- this is an error, but just do nothing. if the
;--- segment is used, it will cause a GPF
        jmp @F
isdgroup:
        mov word ptr es:[edi+eax],ds
        jmp @F
iscgroup:   
       	mov word ptr es:[edi+eax],cs
@@:     
        loop nextitem
done:            
        pop	bp
        
;--- free scratchsel 

        mov	bx, es
        push 0
        pop	es
        mov ax,1
        int 31h

        jmp	exit
error1:
		mov dx,offset szError1
        jmp	errout
error2:
        mov ah,3eh
        int 21h
		mov dx,offset szError2
        jmp	errout
error4:
		mov dx,offset szError4
errout:
		push ds
        push cs
        pop ds
		mov ah,9
        int 21h
        pop ds
exit:
        mov sp, wSP
    	popad
		ret
PatchRelocs endp

if 0
		end
endif
