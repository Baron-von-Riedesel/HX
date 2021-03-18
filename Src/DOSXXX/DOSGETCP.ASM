
		.286
        
        public DOSGETCP

COUNTRYINFO struct
		db ?
        dw ?
        dw ?
wCodePage dw ?
		db 34 dup (?)
COUNTRYINFO ends        

DOSXXX  segment word public 'CODE'

;--- DosGetCp(WORD length, FAR16 WORD buffer, FAR16 WORD pLength)

DOSGETCP proc far pascal length_:word, cplist:far16 ptr, rlen:far16 ptr WORD

local	ci:COUNTRYINFO

		push	es
		push	bx
        push	cx
        push	dx
        push	di
        lea		di,[ci]
        push	ss
        pop		es
        mov		bx,-1		;global code page
        mov		dx,-1		;current country
        mov		cx,sizeof COUNTRYINFO
        mov		ax,6501h
        int		21h
        mov		ax,8		;error code ???
        jc		done
        xor		ax,ax
        mov		cx,length_
        cmp		cx,2
        jb		done
		push	ds
        lds		bx,cplist
        mov		ax,[ci.wCodePage]
        mov		[bx], ax	;return global code page
        lds		bx,rlen
        mov		word ptr [bx], 2
        pop		ds
        xor		ax,ax
done:
		pop		di
        pop		dx
        pop		cx
        pop		bx
        pop		es
        ret
DOSGETCP endp

DOSXXX  ends

		end

