
		.386
if ?FLAT
		.MODEL FLAT, stdcall
else
		.MODEL SMALL, stdcall
endif
		option casemap:none
		option proc:private

		include winbase.inc
		include winuser.inc
		include wingdi.inc
		include macros.inc
		include duser32.inc

		.code

PtInRect proc public lprc:ptr RECT, pt:POINT
		mov ecx, lprc
		mov edx, pt.x
		xor eax, eax
		.if ((edx >= [ecx].RECT.left) && (edx < [ecx].RECT.right))
			mov edx, pt.y
			.if ((edx >= [ecx].RECT.top) && (edx < [ecx].RECT.bottom))
				inc eax
			.endif
		.endif
ifdef _DEBUG
		@strace	<"PtInRect(", lprc, "[", [ecx].RECT.left, " ", [ecx].RECT.top, " ", [ecx].RECT.right, " ", [ecx].RECT.bottom,"],", pt.x, ",", pt.y,")=", eax>
endif
		ret
		align 4
PtInRect endp

SetRect proc public lprc:ptr RECT, lLeft:dword, lTop:dword, lRight:dword, lBottom:dword
		mov ecx, lprc
		mov eax, lLeft
		mov edx, lTop
		mov [ecx].RECT.left, eax
		mov [ecx].RECT.top, edx
		mov eax, lRight
		mov edx, lBottom
		mov [ecx].RECT.right, eax
		mov [ecx].RECT.bottom, edx
		@mov eax, 1
		ret
		align 4
SetRect endp

SetRectEmpty proc public lprc:ptr RECT
		mov eax, lprc
		xor ecx, ecx
		mov [eax].RECT.left, ecx
		mov [eax].RECT.top, ecx
		mov [eax].RECT.right, ecx
		mov [eax].RECT.bottom, ecx
		ret
		align 4
SetRectEmpty endp

IsRectEmpty proc public lprc:ptr RECT
		mov ecx, lprc
		mov eax, [ecx].RECT.left
		add eax, [ecx].RECT.top
		add eax, [ecx].RECT.right
		add eax, [ecx].RECT.bottom
		and eax, eax
		setz al
		movzx eax,al
		ret
		align 4
IsRectEmpty endp

EqualRect proc public uses esi edi lprc1:ptr RECT, lprc2:ptr RECT
		mov esi, lprc1
		mov edi, lprc2
		mov ecx, 4
		repz cmpsd
		setz al
		movzx eax,al
		ret
		align 4
EqualRect endp

CopyRect proc public lprc:ptr RECT, lprcsrc:ptr RECT

		invoke RtlMoveMemory, lprc, lprcsrc, sizeof RECT
		@mov eax,1
		ret
		align 4

CopyRect endp

OffsetRect proc public lprc:ptr RECT, dx_:sdword, dy:sdword

		mov ecx, lprc
		mov eax, dx_
		mov edx, dy
		add [ecx].RECT.left, eax
		add [ecx].RECT.top, edx
		add [ecx].RECT.right, eax
		add [ecx].RECT.bottom, edx
		@mov eax,1
		ret
		align 4

OffsetRect endp

InflateRect proc public lprc:ptr RECT, dx_:sdword, dy:sdword

		mov ecx, lprc
		mov eax, dx_
		mov edx, dy
		sub [ecx].RECT.left, eax
		sub [ecx].RECT.top, edx
		add [ecx].RECT.right, eax
		add [ecx].RECT.bottom, edx
		@mov eax,1
		ret
		align 4

InflateRect endp

UnionRect proc public uses esi edi lprcDest:ptr RECT, lprc1:ptr RECT, lprc2:ptr RECT

		mov edx, lprc2
		mov esi, lprc1
		mov edi, lprcDest
		mov ecx, [edx].RECT.left
		lodsd
		.if (SDWORD ptr eax > SDWORD ptr ecx)
			mov eax, ecx
		.endif
		stosd
		mov ecx, [edx].RECT.top
		lodsd
		.if (SDWORD ptr eax > SDWORD ptr ecx)
			mov eax, ecx
		.endif
		stosd
		mov ecx, [edx].RECT.right
		lodsd
		.if (SDWORD ptr eax < SDWORD ptr ecx)
			mov eax, ecx
		.endif
		cmp eax, [edi-8]
		jl isempty
		stosd
		mov ecx, [edx].RECT.bottom
		lodsd
		.if (SDWORD ptr eax < SDWORD ptr ecx)
			mov eax, ecx
		.endif
		cmp eax, [edi-8]
		jl isempty
		stosd
		@mov eax,1
exit:
		ret
isempty:
		invoke SetRectEmpty, lprcDest
		xor eax, eax
		jmp exit
		align 4

UnionRect endp

IntersectRect proc public uses esi edi lprcDest:ptr RECT, lprc1:ptr RECT, lprc2:ptr RECT

		mov edx, lprc2
		mov esi, lprc1
		mov edi, lprcDest
		mov ecx, [edx].RECT.left
		lodsd
		.if (SDWORD ptr eax < SDWORD ptr ecx)
			mov eax, ecx
		.endif
		stosd
		mov ecx, [edx].RECT.top
		lodsd
		.if (SDWORD ptr eax < SDWORD ptr ecx)
			mov eax, ecx
		.endif
		stosd
		mov ecx, [edx].RECT.right
		lodsd
		.if (SDWORD ptr eax > SDWORD ptr ecx)
			mov eax, ecx
		.endif
		cmp eax, [edi-8]
		jl isempty
		stosd
		mov ecx, [edx].RECT.bottom
		lodsd
		.if (SDWORD ptr eax > SDWORD ptr ecx)
			mov eax, ecx
		.endif
		cmp eax, [edi-8]
		jl isempty
		stosd
		@mov eax,1
exit:
		ret
isempty:
		invoke SetRectEmpty, lprcDest
		xor eax, eax
		jmp exit
		align 4

IntersectRect endp

InvertRect proc public hdc:dword, lprc:ptr RECT

		xor eax, eax
		ret
		align 4

InvertRect endp


		end
