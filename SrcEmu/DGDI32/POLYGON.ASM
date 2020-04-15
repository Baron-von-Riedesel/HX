
;--- implement a polygon fill routine

;--- this routine has its roots in an open source XLib 
;--- graphics library from the early 1990s, written by Themie Goutas.
;--- it was originally written for 16-bit Turbo Assembler.

		.386
if ?FLAT    
    	.model flat, stdcall
else
	    .model small, stdcall
endif
		option casemap:none
        option proc:private

		.nolist
        .nocref
        include winbase.inc
        include wingdi.inc
        include dgdi32.inc
        include macros.inc
        .list
        .cref

?CLIPPINGX	equ 0

		.code

;
; fill a triangle with the current background color
;

_triangle  proc c uses ebx esi edi hdc:dword, v0:POINT, v1:POINT, v2:POINT

local diff01:POINT
local diff02:POINT
local diff12:POINT

local DP01:dword
local DP02:dword
local DP12:dword

local XA01:dword
local XA02:dword
local XA12:dword

local dwLineProc:dword
local rcclip:RECT

		mov		edi,hdc
if ?CLIPPINGX
	    mov     eax, [edi].DCOBJ.rcClipping.top
    	mov     edx, [edi].DCOBJ.rcClipping.bottom
	    mov		rcclip.top, eax
    	mov		rcclip.bottom, edx
endif
	    mov ecx, [edi].DCOBJ.dwBpp
        dec ecx
        shr ecx,3      ;1-8 -> 0, 9-16 -> 1, 17-24 -> 2, 25-32 -> 3
        cmp ecx,4
        jnb tri_done
        mov edx, [ecx*4+offset lineprocs]
	    mov dwLineProc, edx

		mov     eax,v0.x
		mov     ebx,v0.y
		mov     ecx,v1.x
		mov     edx,v1.y
if ?MAPPING
		mov esi, [edi].DCOBJ.ptWindowOrg.x
        sub eax, esi
        sub ecx, esi
        sub v2.x, esi
		mov esi, [edi].DCOBJ.ptViewportOrg.x
		add eax, esi
		add ecx, esi
        add v2.x, esi
        
		mov esi, [edi].DCOBJ.ptWindowOrg.y
        sub ebx, esi
        sub edx, esi
        sub v2.y, esi
		mov esi, [edi].DCOBJ.ptViewportOrg.y
		add ebx, esi
		add edx, esi
        add v2.y, esi
        
		mov	v0.x, eax
		mov	v0.y, ebx
		mov	v1.x, ecx
		mov	v1.y, edx
endif

		cmp     ebx,edx     ; Y0,Y1
		jl      tri_Y0lY1
		je      tri_Y0eY1
		xchg    eax,ecx     ; swap(v0, v1)
		xchg    ebx,edx
tri_Y0lY1:
		cmp     edx,v2.y    ; Y1,Y2
		jle     tri_sorted
		xchg    ecx,v2.x    ; swap(v1, v2)
		xchg    edx,v2.y
		cmp     ebx,edx     ; Y0,Y1
		jl      tri_sorted
		je      tri_bot
		xchg    eax,ecx     ; swap(v0, v1)
		xchg    ebx,edx
		jmp     tri_sorted
tri_Y0eY1:
		cmp     ebx,v2.y	; Y0,Y2
		jl      tri_bot
		je      tri_done
		xchg    eax,v2.x    ; swap(v0, v2)
		xchg    ebx,v2.y
		jmp     tri_sorted

tri_bot:
		cmp     eax,ecx     ; X0,X1
		jl      tri_bot_sorted
		je      tri_done
		xchg    eax,ecx     ; X0,X1

tri_bot_sorted:

if ?CLIPPINGX
		cmp     ebx,rcclip.bottom
		jg      tri_done
		mov     esi,v2.y
		cmp     esi,rcclip.top
		jl      tri_done
endif
		mov     v0.x,eax
		mov     v0.y,ebx
		mov     v1.x,ecx
		mov     v1.y,edx

		mov     ebx,v2.y
		mov     eax,v2.x
		sub     ebx,v0.y     ;   ebx = Y2 - Y0
		sub     eax,v0.x     ;   eax = X2 - X0
		mov     diff02.y,ebx ;  DY02 = Y2 - Y0
		mov     diff02.x,eax ;  DX02 = X2 - X0
		mov     ecx,eax      ;   ecx = DX02
		cdq                  ;edx:eax = DX02
		idiv    ebx          ;   eax = DX02 / DY02
		cmp     ecx,0
		jge     @F
		dec     eax          ;   eax = DX02 / DY02 - 1
@@:
		mov     XA02,eax     ;  XA02 = DX02 / DY02
		imul    ebx          ;   eax = XA02 * DY02
		sub     ecx,eax      ;   ecx = DX02 - XA02 * DY02
		mov     DP02,ecx     ;  DP02 = DX02 - XA02 * DY02

		mov     ebx,v2.y     ;   ebx = Y2
		mov     eax,v2.x     ;   eax = X2
		sub     ebx,v1.y     ;   ebx = Y2 - Y1
		sub     eax,v1.x     ;   eax = X2 - X1
		mov     diff12.y,ebx ;  DY02 = Y2 - Y1
		mov     diff12.x,eax ;  DX12 = X2 - X1
		mov     ecx,eax      ;   ecx = DX12
		cdq                  ;edx:eax = DX12
		idiv    ebx          ;   eax = DX12 / DY12
		cmp     ecx,0
		jge     @F
		dec     eax          ;   eax = DX12 / DY12 - 1
@@:
		mov     XA12,eax     ;  XA12 = DX12 / DY12
		imul    ebx          ;   eax = XA12 * DY12
		sub     ecx,eax      ;   ecx = DX12 - XA12 * DY12
		mov     DP12,ecx     ;  DP12 = DX12 - XA12 * DY12

		mov     eax,0        ; PL = 0
		mov     ebx,0        ; PS = 0
		mov     ecx,v0.y     ;  Y = Y0
		mov     esi,v0.x
		mov     edi,v1.x
		dec     edi
tri_bot_loop:
		inc     ecx          ; Y

		add     eax,DP02     ; PL,DP02
		jle     @F
		sub     eax,diff02.y ; PL,DY02
		inc     esi          ; XL
@@:
		add     esi,XA02     ; XL,XA02

		add     ebx,DP12     ; PS,DP12
		jle     @F
		sub     ebx,diff12.y ; PS,DY12
		inc     edi          ; XS
@@:
		add     edi,XA12     ; XS,XA12

		push    edi          ; XS
		push    esi          ; XL
		cmp     ecx,v2.y     ; Y,Y2
		jl      tri_bot_loop

		jmp     tri_draw_lines


tri_sorted:
if ?CLIPPINGX
		cmp     ebx,rcclip.bottom
		jg      tri_done
		mov     esi,v2.y
		cmp     esi,rcclip.top
		jl      tri_done
endif    
		mov     v0.x,eax
		mov     v0.y,ebx
		mov     v1.x,ecx
		mov     v1.y,edx

		mov     ebx,edx      ;   ebx <- Y1
		sub     ebx,v0.y     ;   ebx <- Y1 - Y0
		mov     diff01.y,ebx ;  DY01 <- Y1 - Y0
		mov     eax,v1.x
		sub     eax,v0.x
		mov     diff01.x,eax ;  DX01 <- X1 - X0
		mov     ecx,eax      ;   ecx <- DX01
		cdq                  ;edx:eax <- DX01
		idiv    ebx          ;   eax <- DX01 / DY01
		cmp     ecx,0        ;  DX01 ? 0
		jge     @F
		dec     eax          ;   eax <- DX01 / DY01 - 1
@@:
		mov     XA01,eax     ;  XA01 <- DX01 / DY01
		imul    ebx          ;   eax <- XA01 * DY01
		sub     ecx,eax      ;   ecx <- DX01 - XA01 * DY01
		mov     DP01,ecx     ;  DP01 <- DX01 - XA01 * DY01

		mov     ebx,v2.y
		sub     ebx,v0.y
		mov     diff02.y,ebx ;  DY02 <- Y2 - Y0
		mov     eax,v2.x
		sub     eax,v0.x
		mov     diff02.x,eax ;  DX02 <- X2 - X0
		mov     ecx,eax      ;   ecx <- DX02
		cdq                  ;edx:eax <- DX02
		idiv    ebx          ;   eax <- DX02 / DY02
		cmp     ecx,0
		jge     @F
		dec     eax          ;   eax <- DX02 / DY02 - 1
@@:
		mov     XA02,eax     ;  XA02 <- DX02 / DY02
		imul    ebx          ;   eax <- XA02 * DY02
		sub     ecx,eax      ;   ecx <- DX02 - XA02 * DY02
		mov     DP02,ecx     ;  DP02 <- DX02 - XA02 * DY02

		mov     ebx,v2.y     ;   ebx <- Y2
		sub     ebx,v1.y     ;   ebx <- Y2 - Y1
		jle     tri_const_computed
		mov     diff12.y,ebx ;  DY12 <- Y2 - Y1
		mov     eax,v2.x     ;   eax <- X2
		sub     eax,v1.x     ;   eax <- X2 - X1
		mov     diff12.x,eax ;  DX12 <- X2 - X1
		mov     ecx,eax      ;   ecx <- DX12
		cdq                  ;edx:eax <- DX12
		idiv    ebx          ;   eax <- DX12 / DY12
		cmp     ecx,0
		jge     @F
		dec     eax          ;   eax <- DX12 / DY12 - 1
@@:
		mov     XA12,eax     ;  XA12 <- DX12 / DY12
		imul    ebx          ;   eax <- XA12 * DY12
		sub     ecx,eax      ;   ecx <- DX12 - XA12 * DY12
		mov     DP12,ecx     ;  DP12 <- DX12 - XA12 * DY12

tri_const_computed:
		mov     eax,diff01.x
		imul    diff02.y
		mov     ebx,eax
		mov     ecx,edx      ; DX01 * DY02 in ecx:ebx

		mov     eax,diff02.x
		imul    diff01.y     ; DX02 * DY01 in edx:eax
		cmp     ecx,edx
		jg      tri_pt1rt
		jl      tri_pt1lt
		cmp     ebx,eax
		ja      tri_pt1rt
		jb      tri_pt1lt
		jmp     tri_done

;
;--- Short sides are on the left
;

tri_pt1lt:
		mov     eax,0    ; PL <- 0
		mov     ebx,0    ; PS <- 0
		mov     ecx,v0.y ;  Y <- Y0
		mov     esi,v0.x
		mov     edi,esi
		dec     esi
tri_lt_loop:
		inc     ecx      ; Y

		add     eax,DP02 ; PL,DP02
		jle     @F
		sub     eax,diff02.y ; PL,DY02
		inc     esi      ; XL
@@:
		add     esi,XA02 ; XL,XA02

		add     ebx,DP01 ; PS,DP01
		jle     @F
		sub     ebx,diff01.y ; PS,DY01
		inc     edi      ; XS
@@:
		add     edi,XA01 ; XS,XA01

		push    esi      ; XL
		push    edi      ; XS
		cmp     ecx,v1.y ; Y,Y1
		jl      tri_lt_loop

		jmp     tri_lb_start
        
tri_lb_loop:
		inc     ecx      ; Y

		add     eax,DP02 ; PL,DP02
		jle     @F
		sub     eax,diff02.y ; PL,DY02
		inc     esi      ; XL
@@:
		add     esi,XA02 ; XL,XA02

		add     ebx,DP12 ; PS,DP12
		jle     @F
		sub     ebx,diff12.y ; PS,DY12
		inc     edi      ; XS
@@:
		add     edi,XA12 ; XS,XA12

		push    esi      ; XL
		push    edi      ; XS
tri_lb_start:
		cmp     ecx,v2.y ; Y,Y2
		jl      tri_lb_loop
		jmp     tri_draw_lines

;
;--- short sides are on the right
;

tri_pt1rt:
		mov     eax,0    ; PL <- 0
		mov     ebx,0    ; PS <- 0
		mov     ecx,v0.y ;  Y <- Y0
		mov     esi,v0.x
		mov     edi,esi
		dec     edi
tri_rt_loop:
		inc     ecx      ; Y

		add     eax,DP02 ; PL,DP02
		jle     @F
		sub     eax,diff02.y ; PL,DY02
		inc     esi      ; XL
@@:
		add     esi,XA02 ; XL,XA02

		add     ebx,DP01 ; PS,DP01
		jle     @F
		sub     ebx,diff01.y ; PS,DY01
		inc     edi      ; XS
@@:
		add     edi,XA01 ; XS,XA01

		push    edi      ; XS
		push    esi      ; XL
		cmp     ecx,v1.y ; Y,Y1
		jl      tri_rt_loop

		jmp     tri_rb_start
        
tri_rb_loop:
		inc     ecx      ; Y

		add     eax,DP02 ; PL,DP02
		jle     @F
		sub     eax,diff02.y ; PL,DY02
		inc     esi      ; XL
@@:
		add     esi,XA02 ; XL,XA02

		add     ebx,DP12 ; PS,DP12
		jle     @F
		sub     ebx,diff12.y ; PS,DY12
		inc     edi      ; XS
@@:
		add     edi,XA12 ; XS,XA12

		push    edi      ; XS
		push    esi      ; XL
tri_rb_start:
		cmp     ecx,v2.y ; Y,Y2
		jl      tri_rb_loop

;
;--- Draw the horizontal lines
;

tri_draw_lines:

	    mov ebx, hdc
nextline:
		pop     eax
		pop     ecx
		cmp     eax,ecx
		jg      @F
	    sub     ecx, eax
    	mov 	edi, [ebx].DCOBJ.pBMBits
    	mul 	[ebx].DCOBJ.dwBpp
	    shr 	eax, 3
        add 	edi, eax
	    mov 	eax, v2.y
	    mul 	[ebx].DCOBJ.lPitch
    	add 	edi, eax
		inc     ecx
	    mov		eax, [ebx].DCOBJ._BrushColor
    	call  	dwLineProc
@@:
		dec     v2.y
		dec     diff02.y
		jnz     nextline
tri_done:
		ret
		align 4
lineprocs label dword
		dd line8bpp, line16bpp, line24bpp, line32bpp
line8bpp:
		rep stosb
    	retn
	    align 4
line16bpp:
		rep stosw
	    retn
	    align 4
line24bpp:
		jecxz line24_done
		mov edx, eax
	    shr edx, 16
@@:    
		mov [edi+0],ax
    	mov [edi+2],dl
	    add edi,3
    	dec ecx
	    jnz @B
line24_done:    
	    retn
	    align 4
line32bpp:
		rep stosd
		retn
	    align 4
    
_triangle  endp

;
; void _FillPolygon( hdc, POINT *, int num_vertices)
;
; Note: This is just a quick hack of a generalized polygon routine.
;   The way it works is by splitting up polygons into triangles and
;   drawing each individual triangle.
;
; Obviously this is not as fast as it could be, but for polygons of
; 4 vertices it should perform quite respectably.
;
; Warning: Only works for convex polygons (convex polygons are such
;  that if you draw a line from any two vertices, every point on that
;  line will be within the polygon)
;

_FillPolygon proc public uses esi edi hdc:dword, vertices:ptr POINT, numvertices:dword

LOCAL pt:POINT
local tri_count:dword
	   
		mov   ecx,numvertices
		sub   ecx,3
        jc    done
		mov   tri_count,ecx 	; Number of triangles to draw

		invoke HideMouse

		sub   esp,3*sizeof POINT	;make room for 3 vertices
        
		mov   edi,vertices		; EDI -> Vertices
		mov   esi,esp
		mov   eax,[edi].POINT.x
		mov   edx,[edi].POINT.y
		mov   pt.x,eax
		mov   pt.y,edx

;--- Set up permanent parameter stack frame for
;--- triangle parameters

		push  hdc

nextitem:
		add   edi,sizeof POINT
		mov   eax, [edi+0*sizeof POINT].POINT.x  ; Vertex 2
		mov   edx, [edi+0*sizeof POINT].POINT.y
		mov   [esi+0*sizeof POINT].POINT.x, eax
		mov   [esi+0*sizeof POINT].POINT.y, edx

		mov   eax, [edi+1*sizeof POINT].POINT.x  ; Vertex 1
		mov   edx, [edi+1*sizeof POINT].POINT.y
		mov   [esi+1*sizeof POINT].POINT.x, eax
		mov   [esi+1*sizeof POINT].POINT.y, edx

		mov   eax,pt.x							; Vertex 0: The first vertex is
		mov   edx,pt.y
		mov   [esi+2*sizeof POINT].POINT.x,eax	 ; part of every triangle
		mov   [esi+2*sizeof POINT].POINT.y,edx

		call  _triangle
		dec   tri_count
		jns   nextitem

		add   esp,3*sizeof POINT + 4

        invoke ShowMouse
done:
		ret
_FillPolygon endp

	end
