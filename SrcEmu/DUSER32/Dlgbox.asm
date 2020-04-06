
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
		include wincon.inc
		include macros.inc
		include duser32.inc

		.DATA

		.code

DialogBoxParamA proc public hInstance:dword, lpTemplateName:dword, 
		hwndParent:HWND, lpDialogProc:dword, dwInitParm:dword

local	szText[80]:byte

		invoke wsprintf, addr szText, CStr("DialogBoxParam(%X) called"), lpTemplateName
		invoke MessageBox, hwndParent, addr szText, 0, MB_OK
		@strace	<"DialogBoxParamA(", hInstance, ", ", lpTemplateName, ", ", hwndParent, ", ", lpDialogProc, ", ", dwInitParm, ")=", eax, " *** unsupp">
		ret
		align 4
DialogBoxParamA endp

DialogBoxParamW proc public hInstance:dword, lpTemplateName:dword, 
		hwndParent:HWND, lpDialogProc:dword, dwInitParm:dword

		mov eax, lpTemplateName
		.if ( eax > 0ffffh)
			call ConvertWStr
		.endif
		invoke DialogBoxParamA, hInstance, eax, hwndParent, lpDialogProc, dwInitParm
		ret
		align 4
DialogBoxParamW endp

DialogBoxIndirectParamA proc public hInstance:dword, lpTemplate:ptr, 
		hwndParent:HWND, lpDialogProc:dword, dwInitParm:dword

local	szText[80]:byte

		invoke wsprintf, addr szText, CStr("DialogBoxIndirectParam(%X) called"), lpTemplate
		invoke MessageBox, hwndParent, addr szText, 0, MB_OK
		@strace	<"DialogBoxIndirectParamA(", hInstance, ", ", lpTemplate, ", ", hwndParent, ", ", lpDialogProc, ", ", dwInitParm, ")=", eax, " *** unsupp">
		ret
		align 4
DialogBoxIndirectParamA endp

EndDialog proc public hDlg:dword, dwRC:dword
		xor eax, eax
		@strace	<"EndDialog(", hDlg, ", ", dwRC, ")=", eax>
		ret
		align 4
EndDialog endp

CreateDialogParamA proc public hInstance:dword, lpTemplateName:dword, 
		hwndParent:HWND, lpDialogProc:dword, dwInitParm:dword

		xor eax, eax
		@strace	<"CreateDialogParamA(", hInstance, ", ", lpTemplateName, ", ", hwndParent, ", ", lpDialogProc, ", ", dwInitParm, ")=", eax, " *** unsupp ***">
		ret
		align 4
CreateDialogParamA endp

IsDialogMessageA proc public hDlg:dword, lpMsg:ptr MSG
		xor eax, eax
		@strace	<"IsDialogMessageA(", hDlg, ", ", lpMsg, ")=", eax, " *** unsupp ***">
		ret
		align 4
IsDialogMessageA endp

;--- dlg items

GetDlgItem proc public hDlg:dword, dwId:dword
		xor eax, eax
		@strace	<"GetDlgItem(", hDlg, ", ", dwId, ")=", eax, " *** unsupp ***">
		ret
		align 4
GetDlgItem endp

GetDlgCtrlID proc public hwndCtrl:dword
		xor eax, eax
		@strace	<"GetDlgCtrlID(", hwndCtrl, ")=", eax, " *** unsupp ***">
		ret
		align 4
GetDlgCtrlID endp

CheckDlgButton proc public hDlg:dword, dwId:dword, uCheck:dword
		xor eax, eax
		@strace	<"CheckDlgButton(", hDlg, ", ", dwId, ",", uCheck, ")=", eax, " *** unsupp">
		ret
		align 4
CheckDlgButton endp

IsDlgButtonChecked proc public hDlg:dword, dwId:dword
		xor eax, eax
		@strace	<"IsDlgButtonChecked(", hDlg, ", ", dwId, ")=", eax, " *** unsupp">
		ret
		align 4
IsDlgButtonChecked endp

GetDlgItemTextA proc public hDlg:dword, dwID:dword, pszText:ptr byte, nSize:DWORD
		invoke GetDlgItem, hDlg, dwID
		.if (eax)
			invoke GetWindowTextA, eax, pszText, nSize
		.endif
		@strace	<"GetDlgItemTextA(", hDlg, ", ", dwID, ", ", pszText, ", ", nSize, ")=", eax>
		ret
		align 4
GetDlgItemTextA endp

SetDlgItemTextA proc public hDlg:dword, dwID:dword, pszText:ptr byte
		invoke GetDlgItem, hDlg, dwID
		.if (eax)
			invoke SetWindowTextA, eax, pszText
		.endif
		@strace	<"SetDlgItemTextA(", hDlg, ", ", dwID, ", ", pszText, ")=", eax>
		ret
		align 4
SetDlgItemTextA endp

SetDlgItemTextW proc public hDlg:dword, dwID:dword, pszText:ptr byte
		mov eax, pszText
		invoke ConvertWStr
		invoke SetDlgItemTextA, hDlg, dwID, eax
		@strace	<"SetDlgItemTextW(", hDlg, ", ", dwID, ", ", pszText, ")=", eax>
		ret
		align 4
SetDlgItemTextW endp

GetDlgItemInt proc public hDlg:dword, dwID:dword, lpTranslated:ptr DWORD, bSigned:DWORD

local	szText[64]:byte

		invoke GetDlgItem, hDlg, dwID
		.if (eax)
			lea ecx, szText
			invoke GetWindowTextA, eax, ecx, sizeof szText
			mov ecx, lpTranslated
			jecxz @F
			mov dword ptr [ecx],0
@@: 		   
			xor eax, eax
		.endif
		@strace	<"GetDlgItemInt(", hDlg, ", ", dwID, ", ", lpTranslated, ", ", bSigned, ")=", eax>
		ret
		align 4
GetDlgItemInt endp

SetDlgItemInt proc public uses ebx hDlg:dword, dwID:dword, uValue:DWORD, bSigned:DWORD

local	szText[64]:byte

		invoke GetDlgItem, hDlg, dwID
		.if (eax)
			mov ebx, eax
			.if (bSigned)
				invoke wvsprintf, addr szText, CStr("%d"), uValue
			.else
				invoke wvsprintf, addr szText, CStr("%u"), uValue
			.endif
			invoke SetWindowTextA, ebx, addr szText
		.endif
		@strace	<"SetDlgItemInt(", hDlg, ", ", dwID, ", ", uValue, ", ", bSigned, ")=", eax>
		ret
		align 4
SetDlgItemInt endp

SendDlgItemMessageA proc public uses ebx hDlg:dword, dwID:dword, msg:DWORD, wParam:dword, lParam:dword

		invoke GetDlgItem, hDlg, dwID
		.if (eax)
			invoke SendMessage, eax, msg, wParam, lParam
		.endif
		@strace	<"SendDlgItemMessage(", hDlg, ", ", dwID, ", ", msg, ", ", wParam, ", ", lParam, ")=", eax>
		ret
		align 4
SendDlgItemMessageA endp

GetNextDlgTabItem proc public hDlg:dword, hCtl:dword, bPrevious:DWORD

		xor eax, eax
		@strace	<"GetNextDlgTabItem(", hDlg, ", ", hCtl, ", ", bPrevious, ")=", eax, " *** unsupp ***">
		ret
		align 4
GetNextDlgTabItem endp

GetDialogBaseUnits proc public

		mov eax, 00040004h
		@strace	<"GetDialogBaseUnits()=", eax>
		ret
		align 4
GetDialogBaseUnits endp

		end
