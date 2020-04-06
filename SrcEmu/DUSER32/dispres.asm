
;--- changing display resolution with USER32
;--- this will result in VESA32.DLL being loaded (for FLAT)
;--- or - for SMALL - link in a bunch of vesa32 code statically

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
		include vesa32.inc

?ALWAYSSETOLDMODE	equ 1

		.data

g_dwVMode	dd -1
g_dwVState	dd 0
g_dwVMem  	dd 0

		.code

_SaveVideoState proc
		invoke _GetVesaProcs
		and eax, eax
		jz exit
		invoke g_lpfnGetVesaStateBufferSize
		.if (eax)
			push eax
			invoke malloc, eax
			pop ecx
			.if (eax)
				mov g_dwVState, eax
				invoke g_lpfnSaveVesaVideoState, eax, ecx
			.endif
			invoke g_lpfnGetVesaMode
			mov g_dwVMode, eax
			invoke g_lpfnGetVesaMemoryBufferSize, eax
			push eax
			invoke malloc, eax
			pop ecx
			.if (eax)
				mov g_dwVMem, eax
				invoke g_lpfnSaveVesaVideoMemory, eax, ecx
				@strace	<"user32::savevideostate successful">
			.endif
		.endif
exit:
		ret
		align 4
_SaveVideoState endp                    

_LoadVideoState proc                    

		invoke _GetVesaProcs
		and eax, eax
		jz exit
		or ecx, -1
		xchg ecx, g_dwVMode
if ?ALWAYSSETOLDMODE
		or ch,80h						;preserve video memory
		invoke g_lpfnSetVesaMode, ecx
endif
		xor ecx, ecx
		xchg ecx, g_dwVState
		.if (ecx)
			push ecx
			invoke g_lpfnRestoreVesaVideoState, ecx
			pop ecx
			invoke free, ecx
		.endif
		xor ecx, ecx
		xchg ecx, g_dwVMem
		.if (ecx)
			push ecx
			invoke g_lpfnRestoreVesaVideoMemory, ecx
			pop ecx
			invoke free, ecx
			@strace	<"user32::loadvideostate successful">
		.endif
exit:
		ret
		align 4
_LoadVideoState endp                    

ClearScreenBkGnd proc uses esi lpDevMode:ptr DEVMODE

		invoke GetDC, 0
		mov esi, eax
		invoke GetStockObject, DKGRAY_BRUSH
		invoke SelectObject, esi, eax
		push eax
		mov edx, lpDevMode
		invoke PatBlt, esi, 0, 0, [edx].DEVMODEA.dmPelsWidth, [edx].DEVMODEA.dmPelsHeight, PATCOPY
		pop eax
		invoke SelectObject, esi, eax
		invoke ReleaseDC, 0, esi
exit:
		ret
		align 4
ClearScreenBkGnd endp

ChangeDisplaySettingsA proc public uses ebx esi lpDevMode:ptr DEVMODEA, dwFlags:DWORD

		invoke _GetVesaProcs
		mov ebx, lpDevMode
ifdef _DEBUG
		.if (ebx)
			@strace	<"ChangeDisplaySettingsA(", lpDevMode, "[", [ebx].DEVMODEA.dmFields, " ", [ebx].DEVMODEA.dmPelsWidth, "x", [ebx].DEVMODEA.dmPelsHeight, "x", [ebx].DEVMODEA.dmBitsPerPel, "], ", dwFlags,") enter">
		.else
			@strace	<"ChangeDisplaySettingsA(", lpDevMode, ", ", dwFlags, ") enter">
		.endif
endif
		and eax, eax
		jz error
		xor eax, eax
		.if ((!ebx) && (!dwFlags))
;--- its valid to call ChangeDisplaySettings(0,0)
;--- without having changed video mode at all
			.if (g_dwVMode != -1)
				invoke _LoadVideoState
				invoke _ClearDCCache
			.endif
			@mov eax, DISP_CHANGE_SUCCESSFUL
		.elseif (ebx)
			mov edx, [ebx].DEVMODEA.dmFields
			and edx, DM_PELSWIDTH or DM_PELSHEIGHT
			cmp edx, DM_PELSWIDTH or DM_PELSHEIGHT
			jnz error
			mov esi, [ebx].DEVMODEA.dmBitsPerPel
			.if (!([ebx].DEVMODEA.dmFields & DM_BITSPERPEL))
				invoke GetDC, 0
				push eax
				invoke GetDeviceCaps, eax, BITSPIXEL
				mov esi, eax
				pop eax
				invoke ReleaseDC, 0, eax
			.endif
			invoke g_lpfnSearchVesaMode, [ebx].DEVMODEA.dmPelsWidth, 
				[ebx].DEVMODEA.dmPelsHeight, esi
			.if (eax)
				push eax
				.if (g_dwVMode == -1)
					invoke _SaveVideoState
				.endif
				pop eax
				or ah,40h						;LFB modes only
				invoke g_lpfnSetVesaMode, eax
				and eax, eax
				jz error
				invoke _ClearDCCache
				invoke ClearScreenBkGnd, ebx
				mov edx, [ebx].DEVMODEA.dmPelsHeight
				shl edx, 16
				mov dx, word ptr [ebx].DEVMODEA.dmPelsWidth
				invoke SendMessage, HWND_BROADCAST, WM_DISPLAYCHANGE, esi, edx
				.if (g_hwndActive)
					invoke InvalidateRect, g_hwndActive, 0, 1
				.endif
				@mov eax, DISP_CHANGE_SUCCESSFUL
			.else
				mov eax, DISP_CHANGE_BADMODE
			.endif
		.else
error:
			mov eax, DISP_CHANGE_FAILED
		.endif
exit:
		@strace <"ChangeDisplaySettingsA(", lpDevMode, ", ", dwFlags, ")=", eax>
		ret
		align 4
ChangeDisplaySettingsA endp

DISENUMHLP struct
dwCnt		dd ?
iModeIdx 	dd ?
lpDevmode	dd ?
DISENUMHLP ends

filldevmode:
		movzx eax,[ecx].SVGAINFO.BitsPerPixel
		mov [edx].DEVMODEA.dmBitsPerPel, eax
		movzx eax,[ecx].SVGAINFO.XResolution 
		mov [edx].DEVMODEA.dmPelsWidth, eax
		movzx eax,[ecx].SVGAINFO.YResolution 
		mov [edx].DEVMODEA.dmPelsHeight, eax
		mov [edx].DEVMODEA.dmFields,DM_BITSPERPEL or DM_PELSWIDTH or DM_PELSHEIGHT
		ret


mycb proc vmode:dword, psvga:ptr SVGAINFO, parmx:dword

		mov ecx, psvga
		mov dx, [ecx].SVGAINFO.ModeAttributes
		and dx, VESAATTR_IS_GFX_MODE or VESAATTR_LFB_SUPPORTED or VESAATTR_SUPPORTED
		cmp dx, VESAATTR_IS_GFX_MODE or VESAATTR_LFB_SUPPORTED or VESAATTR_SUPPORTED
		jnz ignoreitem
		mov ecx, parmx
		mov edx, [ecx].DISENUMHLP.dwCnt
		cmp edx, [ecx].DISENUMHLP.iModeIdx
		jnz skipitem
		mov edx, [ecx].DISENUMHLP.lpDevmode
		mov ecx, psvga
		call filldevmode
		@mov eax, 1
		ret
skipitem:
		inc [ecx].DISENUMHLP.dwCnt
ignoreitem:
		xor eax, eax
		ret
		align 4
mycb endp

EnumDisplaySettingsA proc public lpszDevName:DWORD, iModeNum:Dword, lpDevMode:ptr DEVMODEA

local	parms:DISENUMHLP
local	svi:SVGAINFO

		@strace <"EnumDisplaySettingsA(", lpszDevName, ", ", iModeNum, ", ", lpDevMode, ") enter">
		invoke _GetVesaProcs
		and eax, eax
		jz exit
		xor eax, eax
		mov ecx, iModeNum
		.if (ecx == ENUM_CURRENT_SETTINGS)
			invoke g_lpfnGetVesaMode
			lea ecx, svi
			invoke g_lpfnGetVesaModeInfo, eax, ecx
			.if (eax)
				mov edx,lpDevMode
				lea ecx, svi
				call filldevmode
				@mov eax,1
			.endif
		.elseif (ecx == ENUM_REGISTRY_SETTINGS)
		.else
			mov parms.iModeIdx,ecx
			xor ecx, ecx
			mov parms.dwCnt,ecx
			mov ecx, lpDevMode
			mov parms.lpDevmode,ecx
			invoke g_lpfnEnumVesaModes, offset mycb, addr parms
		.endif
exit:
		@strace	<"EnumDisplaySettingsA(", lpszDevName, ", ", iModeNum, ", ", lpDevMode, ")=", eax>
		ret
		align 4
EnumDisplaySettingsA endp

EnumDisplayDevicesA proc public uses ebx lpDevice:DWORD, iDevNum:Dword, lpDisplayDevice:ptr, dwFlags:DWORD

		xor eax, eax
		.if ( lpDevice == NULL && iDevNum == 0 )
			mov ebx, lpDisplayDevice
			invoke lstrcpy, addr [ebx].DISPLAY_DEVICEA.DeviceName, CStr("\\.\DISPLAY")
			invoke lstrcpy, addr [ebx].DISPLAY_DEVICEA.DeviceString, CStr("Display")
			mov [ebx].DISPLAY_DEVICEA.StateFlags, \
				DISPLAY_DEVICE_ATTACHED_TO_DESKTOP or DISPLAY_DEVICE_PRIMARY_DEVICE or DISPLAY_DEVICE_VGA_COMPATIBLE
			invoke wsprintfA, addr [ebx].DISPLAY_DEVICEA.DeviceID, CStr("%08X"), 1
			mov eax, 1
		.endif
		@strace <"EnumDisplayDevicesA(", lpDevice, ", ", iDevNum, ", ", lpDisplayDevice, ", ", dwFlags, ")=", eax>
		ret
		align 4

EnumDisplayDevicesA endp

		end
