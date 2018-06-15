
ifndef CStr

;--- CStr() define a string in .CONST
;--- or in .CONST$2 if .CONST is the current section

CStr macro text:VARARG
local sym
ifidni @CurSeg,<CONST>
CONST$2 segment dword public 'CONST'
else
CONST segment dword public 'CONST'
endif
  ifidni <text>,<"">
	sym db 0
  else
	sym db text,0
  endif
@CurSeg ends
	exitm <offset sym>
	endm

endif

ifndef L

;---- L() defines a wide string
;---- usage: StringName dw L(stringvalue)

L macro y:req
local x
x	textequ <>
	forc chr$,<y>
x	CatStr x,<'&chr$'>,<,>
	endm
x	CatStr x,<0>
	exitm <x>
	endm

endif

;--- CStrW defines a wide string in CONST (or CONST$2)
;--- returns a pointer to that string

CStrW macro y:req
local sym

ifidni @CurSeg,<CONST>
CONST$2 segment dword public 'CONST'
else
ifdef CONST
CONST segment
else
CONST segment dword public 'CONST'
endif
endif

	align 2
    
sym dw y

@CurSeg ends

	exitm <offset sym>
	endm


ifndef smalloc

;--- the smalloc + sfree macros are used to alloc space
;--- on the stack.
;--- usage: "smalloc register,numBytes" and "sfree"

smalloc macro reg:req,bytes:req	;alloc space on the stack (local only)
local ?bytes
?bytes = (bytes + 3) and 0fffffffch
	sub esp,?bytes
	mov reg,esp
	push ?bytes+4
	endm

sreload macro reg:req,index		;reload address of stack items
ifnb <index>
	mov reg,esp
	repeat index
	add reg,[reg]
	endm
	add reg,4
else
	lea reg,[esp+4]
endif
	endm

sfree macro
	add esp,[esp]
	endm

endif	;smalloc


;--- return: return a value in eax

ifndef return

return macro x
ifnb <x>
 if OPATTR(x) eq 4	;;constant?
  if x
	mov eax,x
  else
	xor eax,eax
  endif
 else
	mov eax,x
 endif
endif
	ret
	endm

endif	;return

;--- simple macro for a 3 byte move, used i.e.: @mov ecx, 3

@mov macro x, y
	push y
	pop x
	endm

vf macro pThis, interface, function
	mov edx, pThis
	ifb <interface>
	   mov edx,[edx].IUnknown.lpVtbl
	   exitm <[edx].IUnknownVtbl.&function, pThis>
	else
	   mov edx, [edx].&interface.lpVtbl
	   exitm <[edx].&interface&Vtbl.&function, pThis>
	endif
	endm

;--- simple string output if wsprintf is not available

@trace macro x
local y, defConst
ifdef _DEBUG
	defConst = 1
	for operand,<x>
		if (OPATTR(operand)) and 10010y
			defConst = 0
		endif
	endm
	pushad
	if defConst
		.const
		y	db x, 0
		.code
		ifndef OutputDebugStringA
			mov esi, offset y
			mov ax, 0002
			int 41h
		else
			invoke OutputDebugStringA, offset y
		endif
	else
		ifndef OutputDebugStringA
			mov esi, x
			mov ax, 0002
			int 41h
		else
			invoke OutputDebugStringA, x
		endif        
	endif
	popad
endif
	endm

;--- same for wide chars (OutputDebugStringW doesnt work for win9x)

@tracew macro x
ifdef _DEBUG
OutputDebugStringW proto stdcall :ptr WORD
	defConst = 1
	for operand,<x>
		if (OPATTR(operand)) and 10010y
			defConst = 0
		endif
	endm
	pushad
	if defConst
		.const
		y	dw L(x)
		.code
		invoke OutputDebugStringW, offset y
	else
		invoke OutputDebugStringW, x
	endif
	popad
endif
	endm

;--- simple number output if wsprintf is not available

@tracedw macro x
ifdef _DEBUG
__dw2aDebug proto stdcall
	pushad
	mov eax, x
	call __dw2aDebug
	popad
endif
	endm

;--- display a string with given size

@traceN macro x, cnt
ifdef _DEBUG
	pushad
	mov ebx, esp
	mov ecx, cnt
	sub esp, ecx
	push 0
	and esp,-4
	mov esi, x
	mov edi, esp
	rep movsb
	mov [edi],cl
	invoke OutputDebugString, esp
	mov esp,ebx
	popad
endif
	endm

;--- displays EIP + a string

@traceX macro x
ifdef _DEBUG
	@tracedw [ebp+4]
	@trace <": ">
	@trace <x>
endif    
	endm

;--- display items of different type in a line

@strace macro x
local _y_
ifdef _DEBUG
	for operand,<x>
		_y_ SubStr <operand>,1,1
		ifidn _y_,<&>
			@trace @SubStr(<operand>,2)
		else
			if (OPATTR(operand)) and 10010y
				@tracedw operand
			else
				@trace operand
			endif
		endif
	endm
	@trace <13,10>
endif
	endm

;---- disable/reenable interrupts

@noints macro
if 0
	pushfd
	cli
else
	push eax
	mov ax,0900h
	int 31h
	xchg eax,[esp]
endif
	endm

;--- restore previous state of VIF after being disabled by @noints

@restoreints macro
local nochange
if 0
	xchg eax, [esp]
	test ah,2
	jz nochange
	sti
else
	xchg eax, [esp]
	and al,al
	jz nochange
	int 31h
endif
nochange:
	pop eax
	endm
