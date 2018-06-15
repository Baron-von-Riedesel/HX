
;--- VESA graphics mode

_640x400x256   = 100h
_640x480x256   = 101h
_800x600x16    = 102h
_800x600x256   = 103h
_1024x768x16   = 104h
_1024x768x256  = 105h
_1280x1024x16  = 106h
_1280x1024x256 = 107h
_80x60         = 108h  ;Text
_132x25        = 109h  ;Text
_132x43        = 10Ah  ;Text
_132x50        = 10Bh  ;Text
_132x60        = 10Ch  ;Text
_320x200x32K   = 10Dh
_320x200x64K   = 10Eh
_320x200x16M   = 10Fh
_640x480x32K   = 110h
_640x480x64K   = 111h
_640x480x16M   = 112h
_800x600x32K   = 113h
_800x600x64K   = 114h
_800x600x16M   = 115h
_1024x768x32K  = 116h
_1024x768x64K  = 117h
_1024x768x16M  = 118h
_1280x1024x32K = 119h
_1280x1024x64K = 11Ah
_1280x1024x16M = 11Bh

_USELFB		equ 4000h

VESAINFO struct
VESASignature db "VBE2"              ;0
VESAVersion   dw ?                   ;4
OEMStringPtr  dd ?                   ;6
Capabilities  dd ?                   ;10
VideoModePtr  dd ?                   ;14
TotalMemory   dw ?                   ;18
xxxx          dw ?                   ;20 since Version 2.0
OEMSoftwareRev dd ?                  ;22
OEMVendorNamePtr dd ?                ;26
OEMProductRevPtr dd ?                ;30
VIReserved    db 222 dup (?)         ;34
VIReserved2   db 256 dup (?)
VESAINFO ends

VESACAP_DAC8		equ 00001h	;DAC can be switched to 8 bit
VESACAP_NONVGA		equ 00002h
VESACAP_BLANKBIT	equ 00004h

SVGAINFO struct
ModeAttributes dw ?		;+00
WinAAttributes db ?		;+02
WinBAttributes db ?		;+03
WinGranularity dw ?		;+04
WinSize        dw ?		;+06
WinASegment    dw ?		;+08
WinBSegment    dw ?		;+0A
WinFuncPtr     dd ?		;+0C
BytesPerScanLine dw ?	;+10
;---------------------- rest is optional info (since Version 1.2)
XResolution    dw ?		;+12
YResolution    dw ?		;+14
XCharSize      db ?		;+16
YCharSize      db ?		;+17
NumberOfPlanes db ?		;+18
BitsPerPixel   db ?		;+19
NumberOfBanks  db ?		;+1A
MemoryModel    db ?		;+1B
BankSize       db ?		;+1C
NumberOfImagePages db ?
Reserved       db ?
RedMaskSize        db ?
RedFieldPosition   db ?
GreenMaskSize      db ?
GreenFieldPosition db ?
BlueMaskSize       db ?
BlueFieldPosition  db ?
RsvdMaskSize       db ?
RsvdFieldPosition  db ?
DirectColorModeInfo db ?
PhysBasePtr        dd ?         ;since Version 2.0
OffScreenMemOffset dd ?
OffScreenMemSize   dw ?
Reserved2          db 206 dup (?)
SVGAINFO ends

;--- ModeAttributes flags

VESAATTR_SUPPORTED		equ 001h	;supported by hardware
VESAATTR_OPT_INFO_AVAIL	equ 002h
VESAATTR_BIOS_OUTPUT	equ 004h
VESAATTR_IS_COLOR_MODE 	equ 008h
VESAATTR_IS_GFX_MODE 	equ 010h	;is a graphics mode
VESAATTR_NON_VGA_COMPAT	equ 020h
VESAATTR_NO_BANK_SWITCH	equ 040h
VESAATTR_LFB_SUPPORTED	equ 080h	;LFB supported
VESAATTR_DBLSCAN_SUPP	equ 100h

XGAINFO struct
Signature dd ?
Version   dw ?
OEMStringPtr  dd ?                   ;6
EnvironmentFlags dd ?
Adapters	dw ?
Reserved  db 240 dup (?)
XGAINFO ends

;--- some options to be set in vesa32.dll

VESA32OPTIONS struct
wSize			dw ?
bNoVSyncWait	db ?	;ignore vsync wait request in SetDisplayMode
bUsePMTable     db ?	;use vesa protected mode table in VESA 2.0+
bFlipStatus     db ?	;use get flip status in VESA 3.0+
bHandleDAC		db ?	;handle DAC I/O directly
				db ?	;reserved
				db ?	;reserved
VESA32OPTIONS ends

;--- prototypes for functions in VESA32.DLL

ifdef _VESA32_
?INDCALL_ = 0
elseif ?INDCALL eq 0
?INDCALL_ = 0
else
?INDCALL_ = 1
endif

if ?INDCALL_ eq 0

EnumVesaModes			proto stdcall pCallback:dword, dwParm:dword
GetVesaDisplayStart		proto stdcall
GetVesaFlipStatus   	proto stdcall
GetVesaInfo				proto stdcall :ptr VESAINFO
GetVesaMemoryBufferSize	proto stdcall dwMode:dword
GetVesaMode				proto stdcall
GetVesaModeInfo			proto stdcall dwVesaMode:dword, pSVGAINFO:ptr SVGAINFO
GetVesaPaletteEntries	proto stdcall dwStart:dword, dwCount:dword, pEntries:ptr
GetVesaStateBufferSize	proto stdcall
GetVesaVideoMemorySize  proto stdcall
RestoreVesaVideoMemory  proto stdcall pSaveBuffer:ptr
RestoreVesaVideoState	proto stdcall pSaveBuffer:ptr
SaveVesaVideoMemory  	proto stdcall pSaveBuffer:ptr, dwSize:DWORD
SaveVesaVideoState  	proto stdcall pSaveBuffer:ptr, dwSize:DWORD
SearchVesaMode			proto stdcall xres:dword, yres:dword, bitsperpixel:dword
SetCursorPaletteEntries proto stdcall dwScreenColor:dword, dwCursorColor:dword
SetMaxVideoResolution	proto stdcall XMax:dword, YMax:dword, FrequencyMax:dword
SetVesa32Options		proto stdcall pOptions:ptr VESA32OPTIONS
SetVesaDisplayStart		proto stdcall dwOffset:dword, dwPitch:dword, dwFlags:dword
SetVesaMode				proto stdcall dwVesaMode:dword
SetVesaPaletteEntries	proto stdcall dwStart:dword, dwCount:dword, pEntries:ptr
VesaMouseInit           proto stdcall
VesaMouseExit           proto stdcall

VesaInit proto stdcall	;init vesa (must be called if statically linked)
VesaExit proto stdcall	;exit vesa (must be called if statically linked)

else

;	.DATA
_DATA segment

externdef stdcall _imp__EnumVesaModes@8:pfunc@8
externdef stdcall _imp__GetVesaDisplayStart@0:pfunc@0
externdef stdcall _imp__GetVesaFlipStatus@0:pfunc@0
externdef stdcall _imp__GetVesaInfo@4:pfunc@4
externdef stdcall _imp__GetVesaMemoryBufferSize@4:pfunc@4
externdef stdcall _imp__GetVesaMode@0:pfunc@0
externdef stdcall _imp__GetVesaModeInfo@8:pfunc@8
externdef stdcall _imp__GetVesaPaletteEntries@12:pfunc@12
externdef stdcall _imp__GetVesaStateBufferSize@0:pfunc@0
externdef stdcall _imp__GetVesaVideoMemorySize@0:pfunc@0
externdef stdcall _imp__RestoreVesaVideoMemory@4:pfunc@4
externdef stdcall _imp__RestoreVesaVideoState@4:pfunc@4
externdef stdcall _imp__SaveVesaVideoMemory@8:pfunc@8
externdef stdcall _imp__SaveVesaVideoState@8:pfunc@8
externdef stdcall _imp__SearchVesaMode@12:pfunc@12
externdef stdcall _imp__SetCursorPaletteEntries@8:pfunc@8
externdef stdcall _imp__SetMaxVideoResolution@12:pfunc@12
externdef stdcall _imp__SetVesa32Options@4:pfunc@4
externdef stdcall _imp__SetVesaDisplayStart@12:pfunc@12
externdef stdcall _imp__SetVesaMode@4:pfunc@4
externdef stdcall _imp__SetVesaPaletteEntries@12:pfunc@12
externdef stdcall _imp__VesaMouseInit@0:pfunc@0
externdef stdcall _imp__VesaMouseExit@0:pfunc@0

_DATA ends

EnumVesaModes           equ <_imp__EnumVesaModes@8>
GetVesaDisplayStart     equ <_imp__GetVesaDisplayStart@0>
GetVesaFlipStatus       equ <_imp__GetVesaFlipStatus@0>
GetVesaInfo             equ <_imp__GetVesaInfo@4>
GetVesaMemoryBufferSize equ <_imp__GetVesaMemoryBufferSize@4>
GetVesaMode             equ <_imp__GetVesaMode@0>
GetVesaModeInfo         equ <_imp__GetVesaModeInfo@8>
GetVesaPaletteEntries   equ <_imp__GetVesaPaletteEntries@12>
GetVesaStateBufferSize  equ <_imp__GetVesaStateBufferSize@0>
GetVesaVideoMemorySize  equ <_imp__GetVesaVideoMemorySize@0>
RestoreVesaVideoMemory  equ <_imp__RestoreVesaVideoMemory@4>
RestoreVesaVideoState   equ <_imp__RestoreVesaVideoState@4>
SaveVesaVideoMemory     equ <_imp__SaveVesaVideoMemory@8>
SaveVesaVideoState      equ <_imp__SaveVesaVideoState@8>
SearchVesaMode          equ <_imp__SearchVesaMode@12>
SetCursorPaletteEntries equ <_imp__SetCursorPaletteEntries@8>
SetMaxVideoResolution   equ <_imp__SetMaxVideoResolution@12>
SetVesa32Options		equ <_imp__SetVesa32Options@4>
SetVesaDisplayStart     equ <_imp__SetVesaDisplayStart@12>
SetVesaMode             equ <_imp__SetVesaMode@4>
SetVesaPaletteEntries   equ <_imp__SetVesaPaletteEntries@12>
VesaMouseInit           equ <_imp__VesaMouseInit@0>
VesaMouseExit           equ <_imp__VesaMouseExit@0>

endif

