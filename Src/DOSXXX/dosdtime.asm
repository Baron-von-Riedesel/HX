
		.286
        
		public	DOSGETDATETIME

DATETIME struct
bHour		db ?	;+0
bMinute		db ?
bSeconds	db ?
bcSecs		db ?
bDay		db ?	;+4
bMonth		db ?
wYear		dw ?
wZone		dw ?	;+8 time zone (minutes GMT, -1 == undefined)
bDayOfWeek  db ?	;+10
DATETIME ends

;--- DosGetDateTime(far16 ptr DATETIME)

DOSXXX	segment word public 'CODE'

DOSGETDATETIME:
		push	BP
		mov	BP,SP
		push	DS
		push	SI
		push	CX
		push	DX
		lds	SI,[BP+6]
		mov	AH,2Ch		;get time
		int	21h
		mov	[SI+0],CH
		mov	[SI+1],CL
		mov	[SI+2],DH
		mov	[SI+3],DL
		mov	AH,2Ah		;get date
		int	21h
		mov	[SI+4],DL
		mov	[SI+5],DH
		mov	[SI+6],CX
        mov word ptr [SI+8],-1	;no time zone set
		mov	[SI+0Ah],AL
		xor	AX,AX
		pop	DX
		pop	CX
		pop	SI
		pop	DS
		pop	BP
		retf 4
DOSXXX	ends

	end
