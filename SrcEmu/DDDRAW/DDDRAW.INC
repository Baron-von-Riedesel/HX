
?USEMODE13	equ 0	;for testing purposes use mode 13h (320x200x256)
					;this mode should work with mouse drivers,
                    ;but will not supply backbuffers
?USEXMM		equ 1	;use XMM movntq for Blt if available

?VESADLL	equ 1	;1=use VESA32.DLL, 0=link vesa32 statically

?DD4		equ 1	;1=support IDirectDraw4
?DD7		equ 1	;1=support IDirectDraw7
?DDS4		equ ?DD4;1=support IDirectDrawSurface4
?DDS7		equ ?DD7;1=support IDirectDrawSurface7

?OVERLAYEMU	equ 0   ;1=emulate overlays (not yet functional)


externdef CLSID_IDirectDraw:byte
externdef IID_IUnknown:GUID
externdef IID_IClassFactory:GUID
externdef IID_IDirectDraw:GUID
externdef IID_IDirectDraw2:GUID
if ?DD4
externdef IID_IDirectDraw4:GUID
endif
if ?DD7
externdef IID_IDirectDraw7:GUID
endif
externdef IID_IDirectDrawSurface:GUID
externdef IID_IDirectDrawSurface2:GUID
if ?DD4
externdef IID_IDirectDrawSurface4:GUID
endif
if ?DD7
externdef IID_IDirectDrawSurface7:GUID
endif
externdef IID_IDirectDrawPalette:GUID
externdef IID_IDirectDrawClipper:GUID

Create@DDSurface proto :LPDIRECTDRAW, :ptr DDSURFACEDESC, :dword
Create@DDPalette proto :LPDIRECTDRAW, :DWORD, :LPPALETTEENTRY, :ptr DWORD
Create@DDClipper proto :LPDIRECTDRAW
AllocVideoMemory proto :ptr DDOBJ, :DWORD
GetVideoMemoryStart proto :ptr DDOBJ
GetCoopLevel proto :ptr DDOBJ
_SendMessage proto :ptr DDOBJ, :DWORD, :DWORD, :DWORD

protoGetDC     typedef proto :dword
LPFNGETDC      typedef ptr protoGetDC
protoReleaseDC typedef proto :dword, :dword
LPFNRELEASEDC  typedef ptr protoReleaseDC

externdef g_lpfnGetDC		:LPFNGETDC
externdef g_lpfnReleaseDC	:LPFNRELEASEDC
