
	.286

	public DOSEXECPGM

DOSXXX segment word public 'CODE'

;--- DosExecPgm(lpObjNameBuf, wObjNameBufLen, wExecFlags, pszArgs, pszEnv, pRet, pszPgm);

;--  6 1E pszPgm
;-- 10 22 pRet
;-- 14 26 pszEnv
;-- 18 2A pszArgs
;-- 22 2E wExecFlags
;-- 24 30 wObjNameBufLen
;-- 26 32 lpObjNameBuf

DOSEXECPGM:
		push BP
		sub SP,018h
		mov BP,SP

;--- exec parameter block is local:
;--- bp+00: environment
;--- bp+02: cmdline
;--- bp+06: fcb1
;--- bp+0A: fcb2
;--- bp+0E: res (cs:ip)
;--- bp+12: res (ss:sp)

;--- bp+16: psp

		push ES
		push DI
		push DS
		push SI
		push BX
		push CX
		push DX
		mov AH,062h
		int 21h

		mov [BP+16h],BX

		mov word ptr [BP+6],05Ch	;fcb1
		mov [BP+8],BX
		mov word ptr [BP+0Ah],06Ch	;fcb2
		mov [BP+0Ch],BX

		xor AX,AX
		mov [BP+0],AX	   ;environment

		les DI,[BP+2Ah]
		mov cx,es
		and cx,cx
		jnz cmdlinegiven
		xor di,di
		jmp cmdline2
cmdlinegiven:
		mov CX,040h
		repne scasb
		mov SI,DI
		mov CX,0100h
		repne scasb
		sub DI,SI		;size of cmdline
cmdline2:
		mov CX,DI
		mov BX,CX
		add BX,2		;one byte for cmdline length
		and bl,not 1	;make sure SP remains even
		
		sub SP,BX		;make room for the cmdline
		mov AX,ES
		mov DS,AX
		mov AX,SS
		mov ES,AX
		mov DI,SP
		dec BX
		dec BX
		mov es:[DI],BL
		mov [bp+2],DI
		mov [bp+4],ES
		inc DI
		rep movsb		;copy cmdline to our stack copy
		lds DX,[BP+1Eh]
		mov AX,SS
		mov ES,AX
		mov BX,BP

		mov AX,04B00h
		int 21h
		jb @F
		mov ah,4Dh
		int 21h
		lds si,[bp+22h]
		mov ah,00
		mov [si+2],ax	;set codeResult field
		xor AX,AX
@@:
		lea sp,[bp-7*2]
		pop DX
		pop CX
		pop BX
		pop SI
		pop DS
		pop DI
		pop ES
		add SP,018h
		pop BP
		retf 018h

DOSXXX ends

		end

