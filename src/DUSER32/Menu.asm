
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
		include wincon.inc
		include macros.inc
		include duser32.inc

MENUITEM struct
pNext	dd ?
dwFlags	dd ?
dwID	dd ?
lpItem	dd ?	;text, handle, bitmap
MENUITEM ends

		.DATA

		public g_SysMenu
        
g_SysMenu MENUOBJ <USER_TYPE_HMENU,0>

		.code

CreateMenu proc public
		invoke malloc, sizeof MENUOBJ
		.if (eax)
			mov [eax].MENUOBJ.dwType, USER_TYPE_HMENU
			mov [eax].MENUOBJ.pItems, 0
		.endif
		@strace	<"CreateMenu()=", eax>
		ret
		align 4
CreateMenu endp

CreatePopupMenu proc public
		invoke CreateMenu
		@strace	<"CreatePopupMenu()=", eax>
		ret
		align 4
CreatePopupMenu endp

DestroyMenu proc public uses ebx hMenu:DWORD
		xor eax, eax
		mov ebx,hMenu
		.if (ebx && [ebx].MENUOBJ.dwType == USER_TYPE_HMENU)
			.while ([ebx].MENUOBJ.pItems)
				mov eax,[ebx].MENUOBJ.pItems
				mov eax,[eax].MENUITEM.pNext
				mov [ebx].MENUOBJ.pItems, eax
				invoke free, eax
			.endw
			invoke free, ebx
		.endif
		@strace	<"DestroyMenu(", hMenu, ")=", eax>
		ret
		align 4
DestroyMenu endp

_CreateMenuItem proc uses ebx esi dwFlags:dword, lpItem:ptr
		xor ebx, ebx
		invoke malloc, sizeof MENUITEM
		and eax, eax
		jz exit
		mov esi, eax
		mov ebx, lpItem
		mov eax, dwFlags
		mov [esi].MENUITEM.dwFlags, eax
		mov [esi].MENUITEM.pNext, 0
		.if (eax & MF_STRING)
			invoke lstrlen, ebx
			inc eax
			invoke malloc, eax
			and eax,eax
			jz error
			mov ebx, eax
			invoke lstrcpy, ebx, lpItem
		.endif
		mov [esi].MENUITEM.lpItem, ebx
		mov eax,esi
exit:  
		ret
error:
		invoke free, esi
		xor eax,eax
		jmp exit
		align 4
		
_CreateMenuItem endp

AppendMenuA proc public uses ebx hMenu:DWORD, uFlags:DWORD, uID:DWORD, lpNewItem:ptr

		xor eax, eax
		mov ebx,hMenu
		.if (ebx && [ebx].MENUOBJ.dwType == USER_TYPE_HMENU)
			invoke _CreateMenuItem, uFlags, lpNewItem
			and eax,eax
			jz @exit
			mov edx, uID
			mov [eax].MENUITEM.dwID, edx
			lea ecx,[ebx].MENUOBJ.pItems
			.while (dword ptr [ecx])
				mov ecx,[ecx].MENUITEM.pNext
			.endw
			mov [ecx].MENUITEM.pNext, eax
		.endif
@exit:		  
		@strace	<"AppendMenuA(", hMenu, ", ", uFlags, ", ", uID, ", ", lpNewItem, ")=", eax>
		ret
		align 4
AppendMenuA endp

AppendMenuW proc public hMenu:DWORD, uFlags:DWORD, uID:DWORD, lpNewItem:ptr

		mov eax, lpNewItem
		invoke AppendMenuA, hMenu, uFlags, uID, eax
		ret
		align 4
AppendMenuW endp

_FindItem proc uPosition:dword, uFlags:dword
		mov eax, uPosition
		mov edx, [ebx].MENUOBJ.pItems
		lea ecx, [ebx].MENUOBJ.pItems
		.if (uFlags & MF_BYPOSITION)
			.while (eax && edx)
				dec eax
				mov ecx, edx
				mov edx,[edx].MENUITEM.pNext
			.endw
			cmp uPosition,-1
			jz @F
			and eax,eax
			jnz error
@@:
		.else
			.while (edx)
				.break .if (eax == [edx].MENUITEM.dwID)
				mov ecx, edx
				mov edx,[edx].MENUITEM.pNext
			.endw
			and edx,edx
			jz error
		.endif
		mov eax, ecx
		ret
error:
		xor eax,eax
		ret
		align 4
_FindItem endp

;--- insert a menu item at specified position

InsertMenuA proc public uses ebx hMenu:DWORD, uPosition:dword, uFlags:DWORD, uIDNew:DWORD, lpNew:ptr
		xor eax, eax
		mov ebx,hMenu
		.if (ebx && [ebx].MENUOBJ.dwType == USER_TYPE_HMENU)
			invoke _FindItem, uPosition, uFlags
			and eax, eax
			jz exit
			push eax
			invoke _CreateMenuItem, uFlags, lpNew
			pop ecx
			and eax, eax
			jz exit
			mov edx, uIDNew
			mov [eax].MENUITEM.dwID, edx
			mov edx,[ecx].MENUITEM.pNext
			mov [ecx].MENUITEM.pNext, eax
			mov [eax].MENUITEM.pNext, edx
		.endif
exit:
		@strace	<"InsertMenuA(", hMenu, ", ", uPosition, ", ", uFlags, ", ", uIDNew, ", ", lpNew, ")=", eax>
		ret
		align 4
InsertMenuA endp

;--- delete a menu item

DeleteMenu proc public uses ebx hMenu:DWORD, uPosition:DWORD, uFlags:DWORD
		mov ebx, hMenu
		invoke _FindItem, uPosition, uFlags
		and eax, eax
		jz exit
		mov ecx,[eax].MENUITEM.pNext
		mov edx,[ecx].MENUITEM.pNext
		mov [eax].MENUITEM.pNext, edx
		invoke free, ecx
exit:
		@strace	<"DeleteMenu(", hMenu, ", ", uPosition, ", ", uFlags, ")=", eax>
		ret
		align 4
DeleteMenu endp

ModifyMenuA proc public hMenu:DWORD, uPosition:DWORD, uFlags:DWORD, uIDNew:DWORD, lpNewItem:ptr
		xor eax, eax
		@strace	<"ModifyMenuA(", hMenu, ", ", uPosition, ", ", uFlags, ", ", uIDNew, ", ", lpNewItem, ")=", eax, " *** unsupp ***">
		ret
		align 4
ModifyMenuA endp

LoadMenuA proc public hInstance:dword, lpszName:dword
		xor eax, eax
		@strace	<"LoadMenuA(", hInstance, ", ", lpszName, ")=", eax, " *** unsupp ***">
		ret
		align 4
LoadMenuA endp

EnableMenuItem proc public hMenu:dword, uIDEnableItem:dword, uEnable:DWORD
		xor eax, eax
		@strace	<"EnableMenuItem(", hMenu, ", ", uIDEnableItem, ", ", uEnable, ")=", eax, " *** unsupp ***">
		ret
		align 4
EnableMenuItem endp

CheckMenuItem proc public hMenu:dword, uIDItem:dword, bChecked:DWORD
		xor eax, eax
		@strace	<"CheckMenuItem(", hMenu, ", ", uIDItem, ", ", bChecked, ")=", eax, " *** unsupp ***">
		ret
		align 4
CheckMenuItem endp

GetSubMenu proc public hMenu:dword, nPos:dword
		xor eax, eax
		@strace	<"GetSubMenu(", hMenu, ", ", nPos, ")=", eax, " *** unsupp ***">
		ret
		align 4
GetSubMenu endp

RemoveMenu proc public hMenu:dword, uPosition:dword, uFlags:dword
		xor eax, eax
		@strace	<"RemoveMenu(", hMenu, ", ", uPosition, ", ", uFlags, ")=", eax, " *** unsupp ***">
		ret
		align 4
RemoveMenu endp

GetMenuItemID proc public hMenu:dword, nPos:dword
		xor eax, eax
		@strace	<"GetMenuItemID(", hMenu, ", ", nPos, ")=", eax, " *** unsupp ***">
		ret
		align 4
GetMenuItemID endp

GetMenuItemCount proc public hMenu:dword
		xor eax, eax
		@strace	<"GetMenuItemCount(", hMenu, ")=", eax, " *** unsupp ***">
		ret
		align 4
GetMenuItemCount endp

GetMenuState proc public hMenu:dword, uId:dword, uFlags:dword
		xor eax, eax
		@strace	<"GetMenuState(", hMenu, ", ", uId, ", ", uFlags, ")=", eax, " *** unsupp ***">
		ret
		align 4
GetMenuState endp

GetMenuStringA proc public hMenu:dword, uId:dword, lpString:ptr BYTE, uMax:DWORD, uFlags:DWORD
		xor eax, eax
		@strace	<"GetMenuString(", hMenu, ", ", uId, ", ", lpString, ", ", uMax, ", ", uFlags, ")=", eax, " *** unsupp ***">
		ret
		align 4
GetMenuStringA endp

SetMenuDefaultItem proc public hMenu:dword, uItem:dword, fByPos:dword
		xor eax, eax
		@strace	<"SetMenuDefaultItem(", hMenu, ", ", uItem, ", ", fByPos, ")=", eax, " *** unsupp ***">
		ret
		align 4
SetMenuDefaultItem endp

SetMenuItemBitmaps proc public hMenu:dword, uPosition:dword, uFlags:dword, hBitmapUnchecked:ptr, hBitmapChecked:ptr
		xor eax, eax
		@strace	<"SetMenuItemBitmaps(", hMenu, ", ", uPosition, ", ", uFlags, ", ", hBitmapUnchecked, ", ", hBitmapChecked, ")=", eax, " *** unsupp ***">
		ret
		align 4
SetMenuItemBitmaps endp

GetMenuCheckMarkDimensions proc public
		xor eax, eax
		@strace	<"GetMenuCheckMarkDimensions()=", eax, " *** unsupp ***">
		ret
		align 4
GetMenuCheckMarkDimensions endp

GetMenuItemInfoA proc public hMenu:dword, uItem:dword, fByPosition:dword, pInfo:ptr
		xor eax, eax
		@strace	<"GetMenuItemInfoA(", hMenu, ", ", uItem, ", ", fByPosition, ", ", pInfo, ")=", eax, " *** unsupp ***">
		ret
		align 4
GetMenuItemInfoA endp

SetMenuItemInfoA proc public hMenu:dword, uItem:dword, fByPosition:dword, pInfo:ptr MENUITEMINFO
		xor eax, eax
		@strace	<"GetMenuItemInfoA(", hMenu, ", ", uItem, ", ", fByPosition, ", ", pInfo, ")=", eax, " *** unsupp ***">
		ret
		align 4
SetMenuItemInfoA endp

TrackPopupMenu proc public hMenu:dword, uFlags:dword, x:dword, y:dword, nReserved:dword, hwnd:dword, prcRect:ptr RECT
		xor eax, eax
		@strace	<"TrackPopupMenu(", hMenu, ", ", uFlags, ", ", x, ", ", y, ", ", nReserved, ", ", hwnd, ", ", prcRect, ")=", eax, " *** unsupp ***">
		ret
		align 4
TrackPopupMenu endp

		end
        
