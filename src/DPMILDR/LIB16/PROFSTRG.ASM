
		.286

cr	equ 13
lf	equ 10

O_RDONLY	equ 0
O_RDWR		equ 2

_TEXT	segment word public 'CODE'

check:
        push    si
check_0:
        mov     al,[si]
        cmp     al,'a'
        jnc     @F
        or      al,20h
@@:
        mov     ah,es:[di]
        cmp     ah,'a'
        jnc     @F
        or      ah,20h
@@:
        inc     si
        inc     di
        cmp     al,ah
        jnz     @F
        loop    check_0
@@:
        mov     al,[si-1]
        pop     si
        ret

getallkeys:
        xor     al,al
getallkeys_1:
        cmp     al,'='
        jz      getallkeys_5
        lodsb
        stosb
        dec     dx
        jz      getallkeys_4
        loop    getallkeys_1
getallkeys_4:
        mov     byte ptr es:[di-1],0
        ret
getallkeys_5:
        mov     byte ptr es:[di-1],0
getallkeys_3:
        cmp     al,lf
        jz      getallkeys_2
        lodsb
        loop    getallkeys_3
        ret
getallkeys_2:
        mov     al,[si]
        cmp     al,';'
        jz      getallkeys_3
        cmp     al,' '
        jz      getallkeys_3
        cmp     al,'['
        jnz     getallkeys_1
        ret


searchsection:
        xor     di,di
        cld
        jmp     @F
searchsec_0:
        mov     al,lf
        repnz   scasb
@@:
        jcxz    searchsec_er            ;fertig, eintrag nicht gefunden
        mov     al,'['
        scasb
        jnz     searchsec_0       ;--> naechste zeile
        call    check
        jcxz    searchsec_er            ;file zuende
        cmp     byte ptr es:[di-1],']'
        jnz     searchsec_0       ;--> falsche section
        cmp     al,0
        jnz     searchsec_0       ;--> falsche section
;        @cstrout <"section found",cr,lf>
        clc
        ret
searchsec_er:
        stc
        ret

searchentry:
searchentry_0:                          ;<----
        mov     al,lf
        repnz   scasb
        jcxz    searchentry_er2         ;file zuende
        cmp     byte ptr es:[di],'['
        jz      searchentry_er1
        mov     ax,ds
        and     ax,ax
        jz      searchentry_ex
        call    check
        jcxz    searchentry_er
        cmp     byte ptr es:[di-1],'='
        jnz     searchentry_0           ;--> naechsten eintrag suchen
        cmp     al,0
        jnz     searchentry_0           ;--> naechsten eintrag suchen
searchentry_ex:
        ret
searchentry_er2:
searchentry_er1:
searchentry_er:
        stc
        ret

GetPrivateProfileString proc far pascal uses ds es lpszSection:far ptr byte,
		lpszEntry:far ptr byte, lpszDefault:far ptr byte,
        retbuff:far ptr byte, bufsize:word,
		lpszFilename:far ptr byte

local	rc:word
local	sel:word

        pusha
        xor     ax,ax
        mov     rc,ax
        mov     ah,48h
        mov     bx,1000h                ;64k allokieren als puffer
        int     21h
        jc      getpps_ex               ;fehler: kein freier speicher
;        @cstrout <"allokierung 64k ok",cr,lf>
        mov     sel,ax
        lds     dx,lpszFilename
        mov     ax,3Dh*100h + O_RDONLY
        int     21h
        jc      getpps_ex1              ;fehler: file not found
;        @cstrout <"open ok",cr,lf>
        mov     bx,ax
        mov     ds,sel
        xor     dx,dx
        mov     cx,0FFF0h
        mov     ah,3Fh
        int     21h
        jc      getpps_ex2             ;fehler: read error
;        @cstrout <"read ok",cr,lf>
        mov     cx,ax
        mov     es,sel
        lds     si,lpszSection              ;section ueberpruefen
        call    searchsection
        jc      getpps_ex2
        lds     si,lpszEntry
        call    searchentry
        jc      getpps_ex2
        mov     ax,ds
        and     ax,ax
        jnz     @F
        push    es
        pop     ds
        mov     si,di
        mov     dx,bufsize
        les     di,retbuff
        call    getallkeys
        sub     dx,bufsize
        neg     dx
        jmp     getpps_6
@@:
;        @cstrout <"entry found",cr,lf>
        mov     ax,bufsize
        cmp     ax,cx
        jnc     @F
        mov     cx,ax
@@:
        jcxz    getpps_ex2              ;puffersize = 0!
;        @cstrout <"copy entry value",cr,lf>
        push    es
        pop     ds
        mov     si,di
        les     di,retbuff
        xor     dx,dx
getpps_5:
        lodsb
        cmp     al,cr
        jz      getpps_6
        stosb
        inc     dx
        loop    getpps_5
getpps_6:
        xor     al,al
        stosb
        mov     rc,dx
getpps_ex2:
        mov     ah,3eh                  ;close file
        int     21h
getpps_ex1:
        mov     es,sel
        mov     ah,49h
        int     21h
getpps_ex:
        popa
        mov     ax,rc
        ret

GetprivateProfileString endp

WritePrivateProfileString proc far pascal uses ds es lpszSection:far ptr byte,
        lpszEntry:far ptr byte, lpszString:far ptr byte, lpszFilename:far ptr byte

local	rc:word
local	sel:word
local	lbuf:word

        pusha
        xor     ax,ax
        mov     rc,ax
        mov     ah,48h
        mov     bx,1000h                ;64k allokieren als puffer
        int     21h
        jc      writepps_ex             ;fehler: kein freier speicher
;        @cstrout <"allokierung 64k ok",cr,lf>
        mov     sel,ax
        lds     dx,lpszFilename
        mov     ax,3Dh*100h + O_RDWR
        int     21h
        jc      writepps_1              ;file nicht da
;        @cstrout <"open ok",cr,lf>
        mov     bx,ax
        mov     ds,sel
        xor		dx,dx
        mov     cx,0FFF0h
        mov     ah,3Fh
        int     21h
        jc      writepps_ex2              ;fehler: read error
;        @cstrout <"read ok",cr,lf>
        mov     cx,ax
        mov     es,sel
        mov     di,ax
        mov     byte ptr es:[di],0
        lds     si,lpszSection              ;section ueberpruefen
        call    searchsection
        jc      writepps_2
        lds     si,lpszEntry
        call    searchentry
        pushf
        jcxz    @F
        mov     dx,di
        mov     cx,0
        mov     ax,4200h
        int     21h
@@:
        popf
        jc      writepps_3              ;eintrag nicht gefunden
        call    writevalue
        call    skipline
        jmp     writepps_4
writepps_1:                             ;create file
        mov     ax,3C00h
        int     21h
        jc      writepps_ex1
        mov     bx,ax
;        @cstrout <"create ok",cr,lf>
writepps_2:                             ;section not found
        call    writeseckap
writepps_3:                             ;entry not found
        call    writeentry
        call    writevalue
writepps_4:
        call    writerest
writepps_ex2:
        mov     ah,3eh                  ;close file
        int     21h
writepps_ex1:
        mov     es,sel
        mov     ah,49h
        int     21h
writepps_ex:
        popa
        mov     ax,rc
        ret

writerest:
;        @cstrout <"write rest",cr,lf>
        mov     dx,di
        push    es
        pop     ds
        call    getstrlen
        jcxz    @F
        mov     ah,40h
        int     21h
		xor		cx,cx
@@:
        mov     ah,40h		;write with CX=0 will truncate file
        int     21h
        retn
writeseckap:
;        @cstrout <"write section capital",cr,lf>
        mov     al,'['
        call    writechar
        lds     dx,lpszSection
        call    getstrlen
        jcxz    @F
        mov     ah,40h
        int     21h
@@:
        mov     al,']'
        call    writechar
        call    writecrlf
        retn
writeentry:
;        @cstrout <"write entry",cr,lf>
        lds     dx,lpszEntry
        call    getstrlen
        jcxz    @F
        mov     ah,40h
        int     21h
@@:
        mov     al,'='
        call    writechar
        retn
writevalue:
;        @cstrout <"write value",cr,lf>
        lds     dx,lpszString
        call    getstrlen
        mov     ah,40h
        int     21h
        call    writecrlf
        retn
writecrlf:
        mov     al,cr
        call    writechar
        mov     al,lf
        call    writechar
        retn
writechar:
        push    ds
        push    ss
        pop     ds
        mov     byte ptr lbuf,al
        lea     dx,lbuf
        mov     cx,1
        mov     ah,40h
        int     21h
        pop     ds
        retn
getstrlen:
		xor		cx,cx
        push    bx
        mov     bx,dx
@@:
        mov     al,[bx]
        inc     cx
        inc     bx
        cmp     al,0
        jnz     @B
        dec     cx
        pop     bx
        retn
skipline:
@@:
        mov     al,es:[di]
        cmp     al,00
        jz      @F
        inc     di
        cmp     al,lf
        jnz     @B
@@:
        retn
        
WritePrivateProfileString endp

_TEXT	ends

        end

