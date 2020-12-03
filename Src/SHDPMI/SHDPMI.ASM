
;*** protect some memory regions by modifying PTEs
;*** requires page table write access

		.386
if ?FLAT		
		.MODEL FLAT,stdcall
@flat	equ <ds>		
else
		.MODEL SMALL,stdcall
@flat	equ <gs>		
DGROUP	group _TEXT
endif
		option casemap:none

externdef __HEAPSIZE:abs
externdef __STACKSIZE:abs

__HEAPSIZE equ 0		;no heap required
__STACKSIZE equ 8000h	;keep this tool small, no need for 512 kb stack

		.nolist
		.nocref
        include function.inc
		include vesa32.inc
		include macros.inc
		include dpmi.inc
		.list
		.cref

wvsprintfA proto stdcall :dword, :dword, :dword

		.data

F_LOWDOS	equ 01h
F_HIGHDOS	equ 02h
F_PAGETABS	equ 04h
F_IDT		equ 08h
F_LDT		equ 10h
F_SYSTEM	equ 20h
F_GDT		equ 40h

bUsage	db 0
bFlags	db 0
bShdpmir db 0

		.const
        
szUsage label byte        
        db "SHDPMI (C) Japheth 2006",10
        db "protect memory ranges and/or system tables from being modified or",10
        db "accessed in protected mode. This is done by modifying the page tables of",10
        db "a residently installed instance of HDPMI32 (it will not work for other hosts).",10
        db "Be aware that after protecting the page tables nothing can be changed anymore.",10
        db "Furthermore, setting IDT or GDT to 'system' may not work.",10
        db "usage: SHDPMI <-h> <-d> <-p> <-i> <-l> <-s>",10
        db "  -h: protect address range C0000-10FFFF",10
		db "  -d: protect address range 01000-00FFFF (requires SHDPMIR)",10
		db "  -p: protect page tables",10
		db "  -g: protect GDT",10
		db "  -i: protect IDT",10
		db "  -l: protect LDT",10
		db "  -s: PTEs will be set to 'system' (default is 'read-only')",10
        db 0

		.CODE

WriteConsole proc uses esi pszText:ptr byte

		mov esi, pszText
		.while (1)
			lodsb
			.break .if (!al)
            .if (al == 10)
            	mov dl,13
                mov ah,2
                int 21h
                mov al,10
            .endif
			mov dl,al
			mov ah,2
			int 21h
		.endw		
		ret
WriteConsole endp

;--- printf emulation. No need to include the C runtime modules

printf	proc c pszText:ptr byte, parms:VARARG

local	dwWritten:DWORD
local	szText[128]:byte

		invoke wvsprintfA,addr szText,pszText, addr parms
		invoke WriteConsole, addr szText
		ret
printf	endp		

;--- set/reset the PTEs

SetPTE	proc bSet:dword

local	dwCR3:dword
local	dwPageDir:dword
local	dwPageTab0:dword
local	dwPageTabS:dword
local	fidt:fword
local	fgdt:fword
local	wldt:word
local	dwldtbase:dword

		or eax,-1
        mov dwPageDir,eax
        mov dwPageTab0,eax
        mov dwPageTabS,eax

;--- get cr3 (works in hdpmi only)

		mov eax, cr3
        mov dwCR3, eax
        
;--- map page dir to a linear address

        and ax,0F000h
        push eax
        pop cx
        pop bx
        mov si,0000h
        mov di,1000h
        mov ax,0800h
        int 31h
        jc error3
        push bx
        push cx
        pop eax
        mov dwPageDir, eax

;--- map page table for region 0-3FFFFF to a linear address

		mov edi, dwPageDir        
        mov eax, @flat:[edi+0]		;PTE for page table 0-3FFFFF
        and ax,0F000h
        push eax
        pop cx
        pop bx
        mov si,0000h
        mov di,1000h
        mov ax,0800h
        int 31h
        jc error4
        push bx
        push cx
        pop eax
        mov dwPageTab0, eax

;--- map page table for region FF800000-FFBFFFFF to a linear address

		mov edi, dwPageDir        
   	    mov eax, @flat:[edi+0FF8h]
        and ax,0F000h
   	    push eax
        pop cx
   	    pop bx
        mov si,0000h
   	    mov di,1000h
        mov ax,0800h
   	    int 31h
        jc error5
        push bx
   	    push cx
        pop eax
        mov dwPageTabS, eax

		sgdt fgdt
		sidt fidt
		sldt wldt

		.if (cs:bFlags & F_IDT)
        	mov eax, dword ptr fidt+2
            .if (eax < 0FF800000h)
                jmp error6
            .endif
        .endif
		.if (cs:bFlags & F_GDT)
        	mov eax, dword ptr fgdt+2
            .if (eax < 0FF800000h)
                jmp error7
            .endif
        .endif

		.if (cs:bFlags & F_LDT)
			movzx ecx, wldt
            and cl,0F8h
            add ecx, dword ptr fgdt+2
            mov ah, @flat:[ecx+7]
            mov al, @flat:[ecx+4]
            shl eax, 16
            mov ax, @flat:[ecx+2]
            mov dwldtbase, eax
            .if (eax < 0FF800000h)
                jmp error8
            .endif
        .endif
            
        xor al,al
        mov ah, not 2
        .if (cs:bFlags & F_SYSTEM)
        	mov ah, not 4
        .endif
        .if (!bSet)
        	xor ah,-1
        .endif

		.if (cs:bFlags & F_LOWDOS)
			mov edi, dwPageTab0
			mov edx, 01000h shr 12
	        mov ecx, (10000h - 1000h) shr 12
	        .while (ecx)
            	.if (bSet)
		   	   		or al, @flat:[edi+edx*4]
        			and @flat:[edi+edx*4], ah
                .else
                	or @flat:[edi+edx*4], ah
                .endif
	            inc edx
    	        dec ecx
	        .endw
        .endif

		.if (cs:bFlags & F_HIGHDOS)
			mov edi, dwPageTab0
	        mov edx, 0C0000h shr 12
    	    mov ecx, (110000h - 0C0000h) shr 12
	        .while (ecx)
            	.if (bSet)
	    	    	or al, @flat:[edi+edx*4]
    	    		and @flat:[edi+edx*4], ah
                .else
                	or @flat:[edi+edx*4], ah
                .endif
	            inc edx
    	        dec ecx
	        .endw
        .endif
        
		.if (cs:bFlags & F_IDT)

			mov edi, dwPageTabS
            mov  edx, dword ptr fidt+2
            and dx, 0F000h
            sub edx, 0FF800000h
            shr edx, 12
    	    mov ecx, 1
	        .while (ecx)
            	.if (bSet)
	    	    	or al, @flat:[edi+edx*4]
    	    		and byte ptr @flat:[edi+edx*4], ah
                .else
                	or byte ptr @flat:[edi+edx*4], ah
                .endif
	            inc edx
    	        dec ecx
	        .endw
        .endif
        
		.if (cs:bFlags & F_GDT)

			mov edi, dwPageTabS
            mov  edx, dword ptr fgdt+2
            and dx, 0F000h
            sub edx, 0FF800000h
            shr edx, 12
    	    mov ecx, 1
	        .while (ecx)
            	.if (bSet)
	    	    	or al, @flat:[edi+edx*4]
    	    		and byte ptr @flat:[edi+edx*4], ah
                .else
                	or byte ptr @flat:[edi+edx*4], ah
                .endif
	            inc edx
    	        dec ecx
	        .endw
        .endif
        
		.if (cs:bFlags & F_LDT)

			mov edx, dwldtbase
			mov edi, dwPageTabS

            and dx, 0F000h
            sub edx, 0FF800000h
            shr edx, 12
    	    mov ecx, 10h
	        .while (ecx)
            	.if (bSet)
		   	   		or al, @flat:[edi+edx*4]
    	    		and byte ptr @flat:[edi+edx*4], ah
                .else
                	or byte ptr @flat:[edi+edx*4], ah
                .endif
	            inc edx
    	        dec ecx
	        .endw
        .endif
        
		.if (cs:bFlags & F_PAGETABS)
	        mov edi, dwPageDir
			mov edx, 0FFC00000h shr 22
	        mov ecx, 1
	        .while (ecx)
            	.if (bSet)
		   	   		or al, @flat:[edi+edx*4]
    	    		and byte ptr @flat:[edi+edx*4], ah 
                .else
                	or byte ptr @flat:[edi+edx*4], ah
                .endif
	            inc edx
    	        dec ecx
	        .endw
        .endif

		call freemaps
        
        clc
        ret
error3:
		mov eax, 3
		stc
        ret
error4:
		call freemaps
		mov eax, 4
		stc
        ret
error5:
		call freemaps
		mov eax, 5
		stc
        ret
error6:
		call freemaps
		mov eax, 6
		stc
        ret
error7:
		call freemaps
		mov eax, 7
		stc
        ret
error8:
		call freemaps
		mov eax, 8
		stc
        ret
freemaps:
		push eax

		mov eax, dwPageTabS
        .if (eax != -1)
        	push eax
            pop cx
            pop bx
	        mov ax,0801h
    	    int 31h
        .endif

		mov eax, dwPageTab0
        .if (eax != -1)
        	push eax
            pop cx
            pop bx
	        mov ax,0801h
    	    int 31h
        .endif

		mov eax, dwPageDir
        .if (eax != -1)
        	push eax
            pop cx
            pop bx
	        mov ax,0801h
    	    int 31h
        .endif
        
        pop eax
        retn

SetPTE	endp

;--- read the command line options
;--- return eax=1 if command line is valid

GetCmdLine proc uses ebx esi

		mov ah,51h
		int 21h
		push ds
		mov ds,ebx 
		mov esi, 0080h
		lodsb
		mov cl, al
		.while (cl)
			lodsb
			dec cl
			.if ((al == '/') || (al == '-'))
				.if (cl)
					lodsb
					dec cl
					or al,20h
					.if (al == 'h')
						or es:bFlags, F_HIGHDOS
					.elseif (al == 'd')
						or es:bFlags, F_LOWDOS
					.elseif (al == 'p')
						or es:bFlags, F_PAGETABS
					.elseif (al == 'g')
						or es:bFlags, F_GDT
					.elseif (al == 'i')
						or es:bFlags, F_IDT
					.elseif (al == 'l')
						or es:bFlags, F_LDT
					.elseif (al == 's')
						or es:bFlags, F_SYSTEM
                    .else
						or es:bUsage, 1
					.endif
				.endif
			.endif
		.endw
		pop ds
        mov al, bFlags
        and al, F_LOWDOS or F_HIGHDOS or F_PAGETABS or F_IDT or F_LDT or F_GDT
		.if ((bUsage) || (al == 0))
			jmp usage
		.endif
		mov eax,1
		ret
usage: 
		invoke WriteConsole, addr szUsage
		xor eax, eax
		ret
GetCmdLine endp 	   

main	proc c

local	dpmihost[128]:byte
		
		invoke GetCmdLine
		and eax, eax
		jz exit

;--- running on hdpmi?

		lea edi, dpmihost
		mov ax,0401h
        int 31h
        jc error1
        mov eax, [edi+2]
        cmp eax, "MPDH"
        jnz error1
        mov eax, [edi+6]
        cmp ax, "I"
        jnz error1

;--- protecting 1000-FFFF requires SHDPMIR to be installed

		.if (bFlags & F_LOWDOS)
	        mov ebx,"SHDP"
    	  	mov eax,"MI00"
	        int 2Fh
    	    .if ((eax == "SHDP") && (ebx == "MI00"))
	        	mov bShdpmir, 1
            .else
            	invoke printf, CStr(<"option -d requires SHDPMIR to be installed",10>)
                jmp exit
            .endif
        .endif

;--- protect now

		invoke SetPTE, 1
        jnc @F
        cmp eax, 3
        jz error3
        cmp eax, 4
        jz error4
        cmp eax, 5
        jz error5
        cmp eax, 6
        jz error6
        cmp eax, 7
        jz error7
        cmp eax, 8
        jz error8
@@:        

;--- display success

		xor ah, -1
        .if (al & ah)
        	mov esi, CStr("read-only")
            .if (bFlags & F_SYSTEM)
	        	mov esi, CStr("system")
            .endif
        	.if (bFlags & F_LOWDOS)
				invoke printf, CStr(<"PTEs for memory region 00001000-0000FFFF set to %s",10>), esi
            .endif
        	.if (bFlags & F_HIGHDOS)
				invoke printf, CStr(<"PTEs for memory region 000C0000-0010FFFF set to %s",10>), esi
            .endif
        	.if (bFlags & F_PAGETABS)
				invoke printf, CStr(<"PTE for page tables FFC00000-FFFFFFFF set to %s",10>), esi
            .endif
        	.if (bFlags & F_IDT)
				invoke printf, CStr(<"PTE for IDT set to read-only",10>)
            .endif
        	.if (bFlags & F_GDT)
				invoke printf, CStr(<"PTE for GDT set to read-only",10>)
            .endif
        	.if (bFlags & F_LDT)
				invoke printf, CStr(<"PTEs for LDT set to %s",10>), esi
            .endif
        .else
			invoke printf, CStr(<"all PTEs were set already",10>)
        .endif

exit:		 
		xor 	eax,eax
		ret
error1:        
		invoke printf, CStr(<"this tool works with HDPMI only",10>)
        jmp exit
error3:        
		invoke printf, CStr(<"cannot get page directory address",10>)
		jmp exit
error4:        
		invoke printf, CStr(<"cannot get page table 0 address",10>)
		jmp exit
error5:        
		invoke printf, CStr(<"cannot get page table FF8 address",10>)
		jmp exit
error6:        
       	invoke printf, CStr(<"option -i requires IDT in HDPMI system region",10>)
        jmp exit
error7:        
       	invoke printf, CStr(<"option -g requires GDT in HDPMI system region",10>)
        jmp exit
error8:        
      	invoke printf, CStr(<"option -l requires LDT in HDPMI system region",10>)
        jmp exit

main	endp

mainCRTStartup proc c

		call main
        mov ah,4Ch
        int 21h

mainCRTStartup endp
		
		END mainCRTStartup

