
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
	include macros.inc

	.CODE

InitCommonControls proc public
	mov eax,1
	@strace <"InitCommonControls()=", eax>
	ret
	align 4
InitCommonControls endp

CreatePropertySheetPage proc public lppsp:ptr
CreatePropertySheetPage endp

CreatePropertySheetPageA proc public lppsp:ptr
	xor eax, eax
	@strace <"CreatePropertySheetPageA(", lppsp, ")=", eax, " *** unsupp ***">
	ret
	align 4
CreatePropertySheetPageA endp

PropertySheet proc public pSheet:ptr
PropertySheet endp

PropertySheetA proc public pSheet:ptr
	mov eax,0
	@strace <"PropertySheetA(", pSheet, ")=", eax, " *** unsupp ***">
	ret
	align 4
PropertySheetA endp

CreateStatusWindowA proc public d1:dword, d2:dword, d3:dword, d4:dword
	xor eax, eax
	@strace <"CreateStatusWindowA(", d1, ", ", d2, ", ", d3, ", ", d4, ")=", eax, " *** unsupp ***">
	ret
	align 4
CreateStatusWindowA endp

GetEffectiveClientRect proc public hwnd:dword, pRect:ptr RECT, d3:dword
	invoke GetClientRect, hwnd, pRect
	@strace <"GetEffectiveClientRect(", hwnd, ", ", pRect, ", ", d3, ")=", eax>
	ret
	align 4
GetEffectiveClientRect endp

LBItemFromPt proc public hLB:dword, pt:POINT, bAutoScroll:dword
	xor eax, eax
	@strace <"LBItemFromPt(", hLB, ", ", pt, ", ", bAutoScroll, ")=", eax, " *** unsupp ***">
	ret
	align 4
LBItemFromPt endp

DrawInsert proc public hParent:dword, hLB:dword, nItem:dword
	xor eax, eax
	@strace <"DrawInsert(", hParent, ", ", hLB, ", ", nItem, ")=", eax, " *** unsupp ***">
	ret
	align 4
DrawInsert endp

	end
