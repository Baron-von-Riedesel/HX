
	include objbase.inc

LPDIRECTDRAW		typedef ptr IDirectDraw
LPDIRECTDRAWSURFACE typedef ptr IDirectDrawSurface
LPDIRECTDRAWCLIPPER typedef ptr IDirectDrawClipper
LPDIRECTDRAWPALETTE typedef ptr IDirectDrawPalette

DirectDrawCreate	proto :ptr, :ptr dword, :LPUNKNOWN

DDSCL_FULLSCREEN		EQU	00000001h
DDSCL_ALLOWREBOOT		EQU	00000002h
DDSCL_NOWINDOWCHANGES	EQU	00000004h
DDSCL_NORMAL			EQU	00000008h
DDSCL_EXCLUSIVE			EQU	00000010h
DDSCL_ALLOWMODEX		EQU	00000040h
DDSCL_SETFOCUSWINDOW	EQU	00000080h
DDSCL_SETDEVICEWINDOW	EQU	00000100h
DDSCL_CREATEDEVICEWINDOW	EQU	00000200h
DDSCL_MULTITHREADED		EQU	00000400h
DDSCL_FPUSETUP			EQU	00000800h
DDSCL_FPUPRESERVE		EQU	00001000h

DDFXCAPS_BLTARITHSTRETCHY	EQU	00000020h
DDFXCAPS_BLTARITHSTRETCHYN	EQU	00000010h
DDFXCAPS_BLTMIRRORLEFTRIGHT	EQU	00000040h
DDFXCAPS_BLTMIRRORUPDOWN	EQU	00000080h
DDFXCAPS_BLTROTATION		EQU	00000100h
DDFXCAPS_BLTROTATION90		EQU	00000200h
DDFXCAPS_BLTSHRINKX			EQU	00000400h
DDFXCAPS_BLTSHRINKXN		EQU	00000800h
DDFXCAPS_BLTSHRINKY			EQU	00001000h
DDFXCAPS_BLTSHRINKYN		EQU	00002000h
DDFXCAPS_BLTSTRETCHX		EQU	00004000h
DDFXCAPS_BLTSTRETCHXN		EQU	00008000h
DDFXCAPS_BLTSTRETCHY		EQU	00010000h
DDFXCAPS_BLTSTRETCHYN		EQU	00020000h
DDFXCAPS_OVERLAYARITHSTRETCHY	EQU	00040000h
DDFXCAPS_OVERLAYARITHSTRETCHYN	EQU	00000008h
DDFXCAPS_OVERLAYSHRINKX		EQU	00080000h
DDFXCAPS_OVERLAYSHRINKXN	EQU	00100000h
DDFXCAPS_OVERLAYSHRINKY		EQU	00200000h
DDFXCAPS_OVERLAYSHRINKYN	EQU	00400000h
DDFXCAPS_OVERLAYSTRETCHX	EQU	00800000h
DDFXCAPS_OVERLAYSTRETCHXN	EQU	01000000h
DDFXCAPS_OVERLAYSTRETCHY	EQU	02000000h
DDFXCAPS_OVERLAYSTRETCHYN	EQU	04000000h
DDFXCAPS_OVERLAYMIRRORLEFTRIGHT	EQU	08000000h
DDFXCAPS_OVERLAYMIRRORUPDOWN	EQU	10000000h
DDFXCAPS_OVERLAYDEINTERLACE	EQU	20000000h
DDFXCAPS_BLTALPHA	EQU	00000001h
DDFXCAPS_BLTFILTER	EQU	<DDFXCAPS_BLTARITHSTRETCHY>
DDFXCAPS_OVERLAYALPHA	EQU	00000004h
DDFXCAPS_OVERLAYFILTER	EQU	<DDFXCAPS_OVERLAYARITHSTRETCHY>


DDPCAPS_4BIT		EQU	00000001h
DDPCAPS_8BITENTRIES	EQU	00000002h
DDPCAPS_8BIT		EQU	00000004h
DDPCAPS_INITIALIZE	EQU	00000000h
DDPCAPS_PRIMARYSURFACE	EQU	00000010h
DDPCAPS_PRIMARYSURFACELEFT	EQU	00000020h
DDPCAPS_ALLOW256	EQU	00000040h
DDPCAPS_VSYNC		EQU	00000080h
DDPCAPS_1BIT		EQU	00000100h
DDPCAPS_2BIT		EQU	00000200h
DDPCAPS_ALPHA		EQU	00000400h

DDGFS_CANFLIP		EQU	00000001h
DDGFS_ISFLIPDONE	EQU	00000002h

DDSCAPS struct
dwCaps    DD ?
DDSCAPS ends

DDSCAPS2	struct
dwCaps	DWORD	?
dwCaps2	DWORD	?
dwCaps3	DWORD	?
union
dwCaps4	DWORD	?
dwVolumeDepth	DWORD	?
ends
DDSCAPS2	ends

;* DIRECTDRAWSURFACE CAPABILITY FLAGS

DDSCAPS_3D                   equ 00000001h
DDSCAPS_ALPHA                equ 00000002h
DDSCAPS_BACKBUFFER           equ 00000004h
DDSCAPS_COMPLEX              equ 00000008h
DDSCAPS_FLIP                 equ 00000010h
DDSCAPS_FRONTBUFFER          equ 00000020h
DDSCAPS_OFFSCREENPLAIN       equ 00000040h
DDSCAPS_OVERLAY              equ 00000080h
DDSCAPS_PALETTE              equ 00000100h
DDSCAPS_PRIMARYSURFACE       equ 00000200h
DDSCAPS_PRIMARYSURFACELEFT   equ 00000400h
DDSCAPS_SYSTEMMEMORY         equ 00000800h
DDSCAPS_TEXTURE              equ 00001000h
DDSCAPS_VIDEOMEMORY          equ 00004000h
DDSCAPS_VISIBLE              equ 00008000h
DDSCAPS_WRITEONLY            equ 00010000h
DDSCAPS_ZBUFFER              equ 00020000h
DDSCAPS_OWNDC                equ 00040000h
DDSCAPS_LIVEVIDEO            equ 00080000h
DDSCAPS_HWCODEC              equ 00100000h
DDSCAPS_MODEX                equ 00200000h
DDSCAPS_MIPMAP               equ 00400000h
DDSCAPS_RESERVED2            equ 00800000h
DDSCAPS_ALLOCONLOAD          EQU 04000000h
DDSCAPS_VIDEOPORT            EQU 08000000h
DDSCAPS_LOCALVIDMEM          equ 10000000h
DDSCAPS_NONLOCALVIDMEM       EQU 20000000h
DDSCAPS_STANDARDVGAMODE      EQU 40000000h
DDSCAPS_OPTIMIZED            EQU 80000000h

DDCOLORKEY struct
dwColorSpaceLowValue  dd ?          ;/ low boundary of color space that is to
dwColorSpaceHighValue dd ?          ;/ high boundary of color space that is
DDCOLORKEY ends

PALETTEENTRY	struct
peRed	BYTE	?
peGreen	BYTE	?
peBlue	BYTE	?
peFlags	BYTE	?
PALETTEENTRY	ends

LPPALETTEENTRY typedef ptr PALETTEENTRY

DDPIXELFORMAT struct
dwSize            DD ?              ;/ size of structure
dwFlags           DD ?              ;/ pixel format flags
dwFourCC          DD ?              ;/ (FOURCC code)
dwRGBBitCount     DD ?              ;/ how many bits per pixel (BD_4,8,16,24,32)
dwRBitMask        DD ?              ;/ mask for red bit
dwGBitMask        DD ?              ;/ mask for green bits
dwBBitMask        DD ?              ;/ mask for blue bits
dwRGBAlphaBitMask DD ?              ;/ mask for alpha channel
DDPIXELFORMAT ends

;-- DDPIXELFORMAT dwFlags values

DDPF_ALPHAPIXELS		EQU	00000001h
DDPF_ALPHA				EQU	00000002h
DDPF_FOURCC				EQU	00000004h
DDPF_PALETTEINDEXED4	EQU	00000008h
DDPF_PALETTEINDEXEDTO8	EQU	00000010h
DDPF_PALETTEINDEXED8	EQU	00000020h
DDPF_RGB				EQU	00000040h
DDPF_COMPRESSED			EQU	00000080h
DDPF_RGBTOYUV			EQU	00000100h
DDPF_YUV				EQU	00000200h
DDPF_ZBUFFER			EQU	00000400h
DDPF_PALETTEINDEXED1	EQU	00000800h
DDPF_PALETTEINDEXED2	EQU	00001000h
DDPF_ZPIXELS			EQU	00002000h
DDPF_STENCILBUFFER		EQU	00004000h
DDPF_ALPHAPREMULT		EQU	00008000h
DDPF_LUMINANCE			EQU	00020000h
DDPF_BUMPLUMINANCE		EQU	00040000h
DDPF_BUMPDUDV			EQU	00080000h


DDSURFACEDESC struct
dwSize            DD ?              ;/ size of the DDSURFACEDESC structure
dwFlags           DD ?              ;/ determines what fields are valid
dwHeight          DD ?              ;/ height of surface to be created
dwWidth           DD ?              ;/ width of input surface
lPitch            DD ?              ;/ distance to start of next line (return value only)
dwBackBufferCount DD ?              ;/ number of back buffers requested
dwRefreshRate     DD ?              ;/ refresh rate (used when display mode is described)
dwAlphaBitDepth   DD ?              ;/ depth of alpha buffer requested
dwReserved        DD ?              ;/ reserved
lpSurface         DD ?              ;/ pointer to the associated surface memory
ddckCKDestOverlay DDCOLORKEY {?,?}  ;/ color key for destination overlay use
ddckCKDestBlt     DDCOLORKEY {?,?}  ;/ color key for destination blt use
ddckCKSrcOverlay  DDCOLORKEY {?,?}  ;/ color key for source overlay use
ddckCKSrcBlt      DDCOLORKEY {?,?}  ;/ color key for source blt use
ddpfPixelFormat   DDPIXELFORMAT {}  ;/ pixel format description of the surface
ddsCaps           DDSCAPS {}        ;/ direct draw surface capabilities
DDSURFACEDESC ends

DDSURFACEDESC2 struct				; for DDS 7
		DDSURFACEDESC <>
dwTextureStage DD ?					;        
DDSURFACEDESC2 ends

;--- DDSURFACEDESC.dwFlags values

DDSD_CAPS			EQU	00000001h
DDSD_HEIGHT			EQU	00000002h
DDSD_WIDTH			EQU	00000004h
DDSD_PITCH			EQU	00000008h
DDSD_BACKBUFFERCOUNT	EQU	00000020h
DDSD_ZBUFFERBITDEPTH	EQU	00000040h
DDSD_ALPHABITDEPTH	EQU	00000080h
DDSD_LPSURFACE		EQU	00000800h
DDSD_PIXELFORMAT	EQU	00001000h
DDSD_CKDESTOVERLAY	EQU	00002000h
DDSD_CKDESTBLT		EQU	00004000h
DDSD_CKSRCOVERLAY	EQU	00008000h
DDSD_CKSRCBLT		EQU	00010000h
DDSD_MIPMAPCOUNT	EQU	00020000h
DDSD_REFRESHRATE	EQU	00040000h
DDSD_LINEARSIZE		EQU	00080000h
DDSD_TEXTURESTAGE	EQU	00100000h
DDSD_FVF			EQU	00200000h
DDSD_SRCVBHANDLE	EQU	00400000h
DDSD_DEPTH			EQU	00800000h
DDSD_ALL			EQU	00fff9eeh


DDENUMRET_CANCEL	EQU	0
DDENUMRET_OK		EQU	1

DDEDM_REFRESHRATES		EQU	00000001h
DDEDM_STANDARDVGAMODES	EQU	00000002h

;--- DDCAPS for DX1 and DX2

DD_ROP_SPACE	EQU	( 256 / 32 )

DDCAPS_DX1	struct
dwSize			DWORD	?					;+0
dwCaps			DWORD	?
dwCaps2			DWORD	?
dwCKeyCaps		DWORD	?
dwFXCaps		DWORD	?					;+10h
dwFXAlphaCaps	DWORD	?
dwPalCaps		DWORD	?
dwSVCaps		DWORD	?
dwAlphaBltConstBitDepths		DWORD	?	;+20h
dwAlphaBltPixelBitDepths		DWORD	?
dwAlphaBltSurfaceBitDepths		DWORD	?
dwAlphaOverlayConstBitDepths	DWORD	?
dwAlphaOverlayPixelBitDepths	DWORD	?	;+30h
dwAlphaOverlaySurfaceBitDepths	DWORD	?
dwZBufferBitDepths		DWORD	?
dwVidMemTotal			DWORD	?
dwVidMemFree			DWORD	?			;+40h
dwMaxVisibleOverlays	DWORD	?
dwCurrVisibleOverlays	DWORD	?
dwNumFourCCCodes		DWORD	?
dwAlignBoundarySrc		DWORD	?			;+50h
dwAlignSizeSrc			DWORD	?
dwAlignBoundaryDest		DWORD	?
dwAlignSizeDest			DWORD	?
dwAlignStrideAlign		DWORD	?			;+60h
dwRops					DWORD DD_ROP_SPACE dup (?)
ddsCaps					DDSCAPS	<>			;+84h
dwMinOverlayStretch		DWORD	?			;+88h
dwMaxOverlayStretch		DWORD	?			;+8Ch
dwMinLiveVideoStretch	DWORD	?			;+90h
dwMaxLiveVideoStretch	DWORD	?
dwMinHwCodecStretch		DWORD	?
dwMaxHwCodecStretch		DWORD	?
dwReserved1				DWORD	?			;+0A0h
dwReserved2				DWORD	?
dwReserved3				DWORD	?
DDCAPS_DX1	ends

;--- DDCAPS for DX5 

DDCAPS_DX5	struct
		DDCAPS_DX1 <>
dwSVBCaps				DWORD	?
dwSVBCKeyCaps			DWORD	?
dwSVBFXCaps				DWORD	?
dwSVBRops				DWORD DD_ROP_SPACE dup (?)
dwVSBCaps				DWORD	?
dwVSBCKeyCaps			DWORD	?
dwVSBFXCaps				DWORD	?
dwVSBRops				DWORD DD_ROP_SPACE dup (?)
dwSSBCaps				DWORD	?
dwSSBCKeyCaps			DWORD	?
dwSSBFXCaps				DWORD	?
dwSSBRops				DWORD DD_ROP_SPACE dup (?)
dwMaxVideoPorts			DWORD	?
dwCurrVideoPorts		DWORD	?
dwSVBCaps2				DWORD	? ;end of DDCAPS_DX3
dwNLVBCaps				DWORD	?
dwNLVBCaps2				DWORD	?
dwNLVBCKeyCaps			DWORD	?
dwNLVBFXCaps			DWORD	?
dwNLVBRops				DWORD DD_ROP_SPACE dup (?)
DDCAPS_DX5	ends

DDCAPS_DX6	struct
dwSize	DWORD	?
dwCaps	DWORD	?
dwCaps2	DWORD	?
dwCKeyCaps	DWORD	?
dwFXCaps	DWORD	?
dwFXAlphaCaps	DWORD	?
dwPalCaps	DWORD	?
dwSVCaps	DWORD	?
dwAlphaBltConstBitDepths	DWORD	?
dwAlphaBltPixelBitDepths	DWORD	?
dwAlphaBltSurfaceBitDepths	DWORD	?
dwAlphaOverlayConstBitDepths	DWORD	?
dwAlphaOverlayPixelBitDepths	DWORD	?
dwAlphaOverlaySurfaceBitDepths	DWORD	?
dwZBufferBitDepths	DWORD	?
dwVidMemTotal	DWORD	?
dwVidMemFree	DWORD	?
dwMaxVisibleOverlays	DWORD	?
dwCurrVisibleOverlays	DWORD	?
dwNumFourCCCodes	DWORD	?
dwAlignBoundarySrc	DWORD	?
dwAlignSizeSrc	DWORD	?
dwAlignBoundaryDest	DWORD	?
dwAlignSizeDest	DWORD	?
dwAlignStrideAlign	DWORD	?
dwRops	DWORD DD_ROP_SPACE dup (?)
ddsOldCaps	DDSCAPS	<>
dwMinOverlayStretch	DWORD	?
dwMaxOverlayStretch	DWORD	?
dwMinLiveVideoStretch	DWORD	?
dwMaxLiveVideoStretch	DWORD	?
dwMinHwCodecStretch	DWORD	?
dwMaxHwCodecStretch	DWORD	?
dwReserved1	DWORD	?
dwReserved2	DWORD	?
dwReserved3	DWORD	?
dwSVBCaps	DWORD	?
dwSVBCKeyCaps	DWORD	?
dwSVBFXCaps	DWORD	?
dwSVBRops	DWORD DD_ROP_SPACE dup (?)
dwVSBCaps	DWORD	?
dwVSBCKeyCaps	DWORD	?
dwVSBFXCaps	DWORD	?
dwVSBRops	DWORD DD_ROP_SPACE dup (?)
dwSSBCaps	DWORD	?
dwSSBCKeyCaps	DWORD	?
dwSSBFXCaps	DWORD	?
dwSSBRops	DWORD DD_ROP_SPACE dup (?)
dwMaxVideoPorts	DWORD	?
dwCurrVideoPorts	DWORD	?
dwSVBCaps2	DWORD	?
dwNLVBCaps	DWORD	?
dwNLVBCaps2	DWORD	?
dwNLVBCKeyCaps	DWORD	?
dwNLVBFXCaps	DWORD	?
dwNLVBRops	DWORD DD_ROP_SPACE dup (?)
ddsCaps	DDSCAPS2	<>
DDCAPS_DX6	ends

DDCAPS_DX7	struct
dwSize	DWORD	?
dwCaps	DWORD	?
dwCaps2	DWORD	?
dwCKeyCaps	DWORD	?
dwFXCaps	DWORD	?
dwFXAlphaCaps	DWORD	?
dwPalCaps	DWORD	?
dwSVCaps	DWORD	?
dwAlphaBltConstBitDepths	DWORD	?
dwAlphaBltPixelBitDepths	DWORD	?
dwAlphaBltSurfaceBitDepths	DWORD	?
dwAlphaOverlayConstBitDepths	DWORD	?
dwAlphaOverlayPixelBitDepths	DWORD	?
dwAlphaOverlaySurfaceBitDepths	DWORD	?
dwZBufferBitDepths	DWORD	?
dwVidMemTotal	DWORD	?
dwVidMemFree	DWORD	?
dwMaxVisibleOverlays	DWORD	?
dwCurrVisibleOverlays	DWORD	?
dwNumFourCCCodes	DWORD	?
dwAlignBoundarySrc	DWORD	?
dwAlignSizeSrc	DWORD	?
dwAlignBoundaryDest	DWORD	?
dwAlignSizeDest	DWORD	?
dwAlignStrideAlign	DWORD	?
dwRops	DWORD DD_ROP_SPACE dup (?)
ddsOldCaps	DDSCAPS	<>
dwMinOverlayStretch	DWORD	?
dwMaxOverlayStretch	DWORD	?
dwMinLiveVideoStretch	DWORD	?
dwMaxLiveVideoStretch	DWORD	?
dwMinHwCodecStretch	DWORD	?
dwMaxHwCodecStretch	DWORD	?
dwReserved1	DWORD	?
dwReserved2	DWORD	?
dwReserved3	DWORD	?
dwSVBCaps	DWORD	?
dwSVBCKeyCaps	DWORD	?
dwSVBFXCaps	DWORD	?
dwSVBRops	DWORD DD_ROP_SPACE dup (?)
dwVSBCaps	DWORD	?
dwVSBCKeyCaps	DWORD	?
dwVSBFXCaps	DWORD	?
dwVSBRops	DWORD DD_ROP_SPACE dup (?)
dwSSBCaps	DWORD	?
dwSSBCKeyCaps	DWORD	?
dwSSBFXCaps	DWORD	?
dwSSBRops	DWORD DD_ROP_SPACE dup (?)
dwMaxVideoPorts	DWORD	?
dwCurrVideoPorts	DWORD	?
dwSVBCaps2	DWORD	?
dwNLVBCaps	DWORD	?
dwNLVBCaps2	DWORD	?
dwNLVBCKeyCaps	DWORD	?
dwNLVBFXCaps	DWORD	?
dwNLVBRops	DWORD DD_ROP_SPACE dup (?)
ddsCaps	DDSCAPS2	<>
DDCAPS_DX7	ends

;* DIRECTDRAW DRIVER CAPABILITY FLAGS

DDCAPS_3D                 equ   00000001h
DDCAPS_ALIGNBOUNDARYDEST  equ   00000002h
DDCAPS_ALIGNSIZEDEST      equ   00000004h
DDCAPS_ALIGNBOUNDARYSRC   equ   00000008h
DDCAPS_ALIGNSIZESRC       equ   00000010h
DDCAPS_ALIGNSTRIDE        equ   00000020h
DDCAPS_BLT                equ   00000040h
DDCAPS_BLTQUEUE           equ   00000080h
DDCAPS_BLTFOURCC          equ   00000100h
DDCAPS_BLTSTRETCH         equ   00000200h
DDCAPS_GDI                equ   00000400h
DDCAPS_OVERLAY            equ   00000800h
DDCAPS_OVERLAYCANTCLIP    equ   00001000h
DDCAPS_OVERLAYFOURCC      equ   00002000h
DDCAPS_OVERLAYSTRETCH     equ   00004000h
DDCAPS_PALETTE            equ   00008000h
DDCAPS_PALETTEVSYNC       equ   00010000h
DDCAPS_READSCANLINE       equ   00020000h
DDCAPS_STEREOVIEW         equ   00040000h
DDCAPS_VBI                equ   00080000h
DDCAPS_ZBLTS              equ   00100000h
DDCAPS_ZOVERLAYS          equ   00200000h
DDCAPS_COLORKEY           equ   00400000h
DDCAPS_ALPHA              equ   00800000h
DDCAPS_COLORKEYHWASSIST   equ   01000000h
DDCAPS_NOHARDWARE         equ   02000000h
DDCAPS_BLTCOLORFILL       equ   04000000h
DDCAPS_BANKSWITCHED       equ   08000000h
DDCAPS_BLTDEPTHFILL       equ   10000000h
DDCAPS_CANCLIP            equ   20000000h
DDCAPS_CANCLIPSTRETCHED   equ   40000000h
DDCAPS_CANBLTSYSMEM       equ   80000000h


DDWAITVB_BLOCKBEGIN			EQU	00000001h
DDWAITVB_BLOCKBEGINEVENT	EQU	00000002h
DDWAITVB_BLOCKEND			EQU	00000004h

DDBLT_ALPHADEST					EQU	00000001h
DDBLT_ALPHADESTCONSTOVERRIDE	EQU	00000002h
DDBLT_ALPHADESTNEG				EQU	00000004h
DDBLT_ALPHADESTSURFACEOVERRIDE	EQU	00000008h
DDBLT_ALPHAEDGEBLEND			EQU	00000010h
DDBLT_ALPHASRC					EQU	00000020h
DDBLT_ALPHASRCCONSTOVERRIDE		EQU	00000040h
DDBLT_ALPHASRCNEG				EQU	00000080h
DDBLT_ALPHASRCSURFACEOVERRIDE	EQU	00000100h
DDBLT_ASYNC						EQU	00000200h
DDBLT_COLORFILL					EQU	00000400h
DDBLT_DDFX						EQU	00000800h
DDBLT_DDROPS					EQU	00001000h
DDBLT_KEYDEST					EQU	00002000h
DDBLT_KEYDESTOVERRIDE			EQU	00004000h
DDBLT_KEYSRC					EQU	00008000h
DDBLT_KEYSRCOVERRIDE			EQU	00010000h
DDBLT_ROP						EQU	00020000h
DDBLT_ROTATIONANGLE				EQU	00040000h
DDBLT_ZBUFFER					EQU	00080000h
DDBLT_ZBUFFERDESTCONSTOVERRIDE	EQU	00100000h
DDBLT_ZBUFFERDESTOVERRIDE		EQU	00200000h
DDBLT_ZBUFFERSRCCONSTOVERRIDE	EQU	00400000h
DDBLT_ZBUFFERSRCOVERRIDE		EQU	00800000h
DDBLT_WAIT						EQU	01000000h
DDBLT_DEPTHFILL					EQU	02000000h
DDBLT_DONOTWAIT					EQU	08000000h
DDBLT_PRESENTATION				EQU	10000000h
DDBLT_LAST_PRESENTATION			EQU	20000000h

DDBLTFX	struct
dwSize						DWORD	?
dwDDFX						DWORD	?
dwROP						DWORD	?
dwDDROP						DWORD	?
dwRotationAngle				DWORD	?
dwZBufferOpCode				DWORD	?
dwZBufferLow				DWORD	?
dwZBufferHigh				DWORD	?
dwZBufferBaseDest			DWORD	?
dwZDestConstBitDepth		DWORD	?
union
dwZDestConst				DWORD	?
lpDDSZBufferDest			LPDIRECTDRAWSURFACE	?
ends
dwZSrcConstBitDepth			DWORD	?
union
dwZSrcConst					DWORD	?
lpDDSZBufferSrc				LPDIRECTDRAWSURFACE	?
ends
dwAlphaEdgeBlendBitDepth	DWORD	?
dwAlphaEdgeBlend			DWORD	?
dwReserved					DWORD	?
dwAlphaDestConstBitDepth	DWORD	?
union
dwAlphaDestConst			DWORD	?
lpDDSAlphaDest				LPDIRECTDRAWSURFACE	?
ends
dwAlphaSrcConstBitDepth		DWORD	?
union
dwAlphaSrcConst				DWORD	?
lpDDSAlphaSrc				LPDIRECTDRAWSURFACE	?
ends
union
dwFillColor					DWORD	?
dwFillDepth					DWORD	?
dwFillPixel					DWORD	?
lpDDSPattern				LPDIRECTDRAWSURFACE	?
ends
ddckDestColorkey			DDCOLORKEY	<>
ddckSrcColorkey				DDCOLORKEY	<>
DDBLTFX	ends

LPDDBLTFX  typedef ptr DDBLTFX

DDFLIP_WAIT			EQU	00000001h
DDFLIP_EVEN			EQU	00000002h
DDFLIP_ODD			EQU	00000004h
DDFLIP_NOVSYNC		EQU	00000008h
DDFLIP_INTERVAL2	EQU	02000000h
DDFLIP_INTERVAL3	EQU	03000000h
DDFLIP_INTERVAL4	EQU	04000000h
DDFLIP_STEREO		EQU	00000010h
DDFLIP_DONOTWAIT	EQU	00000020h

MAX_DDDEVICEID_STRING	EQU	512

DDDEVICEIDENTIFIER	struct
szDriver		BYTE MAX_DDDEVICEID_STRING dup (?)
szDescription	BYTE MAX_DDDEVICEID_STRING dup (?)
liDriverVersion	QWORD	?
dwVendorId		DWORD	?
dwDeviceId		DWORD	?
dwSubSysId		DWORD	?
dwRevision		DWORD	?
guidDeviceIdentifier	GUID	<>
DDDEVICEIDENTIFIER	ends

LPDDDEVICEIDENTIFIER typedef ptr DDDEVICEIDENTIFIER

DD_OK                              equ 0
DDERR_OUTOFMEMORY                  equ  8007000Eh
DDERR_ALREADYINITIALIZED           equ  88760000h + 5
DDERR_CANNOTATTACHSURFACE          equ  88760000h + 10
DDERR_CANNOTDETACHSURFACE          equ  88760000h + 20
DDERR_CURRENTLYNOTAVAIL            equ  88760000h + 40
DDERR_EXCEPTION                    equ  88760000h + 55
DDERR_HEIGHTALIGN                  equ  88760000h + 90
DDERR_INCOMPATIBLEPRIMARY          equ  88760000h + 95
DDERR_INVALIDCAPS                  equ  88760000h + 100
DDERR_INVALIDCLIPLIST              equ  88760000h + 110
DDERR_INVALIDMODE                  equ  88760000h + 120
DDERR_INVALIDOBJECT                equ  88760000h + 130
DDERR_INVALIDPIXELFORMAT           equ  88760000h + 145
DDERR_INVALIDRECT                  equ  88760000h + 150
DDERR_LOCKEDSURFACES               equ  88760000h + 160
DDERR_NO3D                         equ  88760000h + 170
DDERR_NOALPHAHW                    equ  88760000h + 180
DDERR_NOCLIPLIST                   equ  88760000h + 205
DDERR_NOCOLORCONVHW                equ  88760000h + 210
DDERR_NOCOOPERATIVELEVELSET        equ  88760000h + 212
DDERR_NOCOLORKEY                   equ  88760000h + 215
DDERR_NOCOLORKEYHW                 equ  88760000h + 220
DDERR_NODIRECTDRAWSUPPORT          equ  88760000h + 222
DDERR_NOEXCLUSIVEMODE              equ  88760000h + 225
DDERR_NOFLIPHW                     equ  88760000h + 230
DDERR_NOGDI                        equ  88760000h + 240
DDERR_NOMIRRORHW                   equ  88760000h + 250
DDERR_NOTFOUND                     equ  88760000h + 255
DDERR_NOOVERLAYHW                  equ  88760000h + 260
DDERR_NORASTEROPHW                 equ  88760000h + 280
DDERR_NOROTATIONHW                 equ  88760000h + 290
DDERR_NOSTRETCHHW                  equ  88760000h + 310
DDERR_NOT4BITCOLOR                 equ  88760000h + 316
DDERR_NOT4BITCOLORINDEX            equ  88760000h + 317
DDERR_NOT8BITCOLOR                 equ  88760000h + 320
DDERR_NOTEXTUREHW                  equ  88760000h + 330
DDERR_NOVSYNCHW                    equ  88760000h + 335
DDERR_NOZBUFFERHW                  equ  88760000h + 340
DDERR_NOZOVERLAYHW                 equ  88760000h + 350
DDERR_OUTOFCAPS                    equ  88760000h + 360
DDERR_OUTOFVIDEOMEMORY             equ  88760000h + 380
DDERR_OVERLAYCANTCLIP              equ  88760000h + 382
DDERR_OVERLAYCOLORKEYONLYONEACTIVE equ  88760000h + 384
DDERR_PALETTEBUSY                  equ  88760000h + 387
DDERR_COLORKEYNOTSET               equ  88760000h + 400
DDERR_SURFACEALREADYATTACHED       equ  88760000h + 410
DDERR_SURFACEALREADYDEPENDENT      equ  88760000h + 420
DDERR_SURFACEBUSY                  equ  88760000h + 430
DDERR_CANTLOCKSURFACE              equ  88760000h + 435
DDERR_SURFACEISOBSCURED            equ  88760000h + 440
DDERR_SURFACELOST                  equ  88760000h + 450
DDERR_SURFACENOTATTACHED           equ  88760000h + 460
DDERR_TOOBIGHEIGHT                 equ  88760000h + 470
DDERR_TOOBIGSIZE                   equ  88760000h + 480
DDERR_TOOBIGWIDTH                  equ  88760000h + 490
DDERR_UNSUPPORTEDFORMAT            equ  88760000h + 510
DDERR_UNSUPPORTEDMASK              equ  88760000h + 520
DDERR_VERTICALBLANKINPROGRESS      equ  88760000h + 537
DDERR_WASSTILLDRAWING              equ  88760000h + 540
DDERR_XALIGN                       equ  88760000h + 560
DDERR_INVALIDDIRECTDRAWGUID        equ  88760000h + 561
DDERR_DIRECTDRAWALREADYCREATED     equ  88760000h + 562
DDERR_NODIRECTDRAWHW               equ  88760000h + 563
DDERR_PRIMARYSURFACEALREADYEXISTS  equ  88760000h + 564
DDERR_NOEMULATION                  equ  88760000h + 565
DDERR_REGIONTOOSMALL               equ  88760000h + 566
DDERR_CLIPPERISUSINGHWND           equ  88760000h + 567
DDERR_NOCLIPPERATTACHED            equ  88760000h + 568
DDERR_NOHWND                       equ  88760000h + 569
DDERR_HWNDSUBCLASSED               equ  88760000h + 570
DDERR_HWNDALREADYSET               equ  88760000h + 571
DDERR_NOPALETTEATTACHED            equ  88760000h + 572
DDERR_NOPALETTEHW                  equ  88760000h + 573
DDERR_BLTFASTCANTCLIP              equ  88760000h + 574
DDERR_NOBLTHW                      equ  88760000h + 575
DDERR_NODDROPSHW                   equ  88760000h + 576
DDERR_OVERLAYNOTVISIBLE            equ  88760000h + 577
DDERR_NOOVERLAYDEST                equ  88760000h + 578
DDERR_INVALIDPOSITION              equ  88760000h + 579
DDERR_NOTAOVERLAYSURFACE           equ  88760000h + 580
DDERR_EXCLUSIVEMODEALREADYSET      equ  88760000h + 581
DDERR_NOTFLIPPABLE                 equ  88760000h + 582
DDERR_CANTDUPLICATE                equ  88760000h + 583
DDERR_NOTLOCKED                    equ  88760000h + 584
DDERR_CANTCREATEDC                 equ  88760000h + 585
DDERR_NODC                         equ  88760000h + 586
DDERR_WRONGMODE                    equ  88760000h + 587
DDERR_IMPLICITLYCREATED            equ  88760000h + 588
DDERR_NOTPALETTIZED                equ  88760000h + 589
DDERR_UNSUPPORTEDMODE              equ  88760000h + 590
DDERR_NOMIPMAPHW                   equ  88760000h + 591
DDERR_INVALIDSURFACETYPE           equ  88760000h + 592
DDERR_DCALREADYCREATED             equ  88760000h + 620
DDERR_CANTPAGELOCK                 equ  88760000h + 640
DDERR_CANTPAGEUNLOCK               equ  88760000h + 660
DDERR_NOTPAGELOCKED                equ  88760000h + 680

;DDERR_GENERIC                           E_FAIL
DDERR_INVALIDPARAMS                equ  E_INVALIDARG
DDERR_UNSUPPORTED                  equ  80004001h  ;=E_NOTIMPL

;--- DirectDraw vtable structure

protoDDWaitForVerticalBlank typedef proto :DWORD, :DWORD, :DWORD
LPDDWAITFORVERTICALBLANK typedef ptr protoDDWaitForVerticalBlank

protoDDCreateSurface typedef proto :DWORD, :ptr DDSURFACEDESC, :ptr LPUNKNOWN, :LPUNKNOWN
LPDDCREATESURFACE typedef ptr protoDDCreateSurface

IDirectDrawVtbl struct
						IUnknownVtbl <>
pCompact                dd ? ;
CreateClipper           dd ? ; DWORD, LPDIRECTDRAWCLIPPER *, IUnknown *
CreatePalette_          dd ? ; DWORD, LPPALETTEENTRY, LPDIRECTDRAWPALETTE *, IUnknown *
CreateSurface           LPDDCREATESURFACE ? ; LPDDSURFACEDESC, LPDIRECTDRAWSURFACE *, IUnknown *
DuplicateSurface        dd ? ; LPDIRECTDRAWSURFACE, LPDIRECTDRAWSURFACE *
EnumDisplayModes        dd ? ; DWORD, LPDDSURFACEDESC, LPVOID, LPDDENUMMODESCALLBACK
EnumSurfaces            dd ? ; DWORD, LPDDSURFACEDESC, LPVOID,LPDDENUMSURFACESCALLBACK
pFlipToGDISurface       dd ? ;
pGetCaps                dd ? ; LPDDCAPS, LPDDCAPS
pGetDisplayMode         dd ? ; LPDDSURFACEDESC
pGetFourCCCodes         dd ? ; LPDWORD, LPDWORD
pGetGDISurface          dd ? ; LPDIRECTDRAWSURFACE FAR *
pGetMonitorFrequency    dd ? ; LPDWORD
pGetScanLine            dd ? ; LPDWORD
pGetVerticalBlankStatus dd ? ; LPBOOL
pInitialize             dd ? ; GUID FAR *
pRestoreDisplayMode     dd ? ;
pSetCooperativeLevel    dd ? ; HWND, DWORD
pSetDisplayMode         dd ? ; DWORD, DWORD,DWORD
WaitForVerticalBlank    LPDDWAITFORVERTICALBLANK ? ; DWORD, HANDLE
IDirectDrawVtbl ends

LPDIRECTDRAWVTBL typedef ptr IDirectDrawVtbl

IDirectDraw2Vtbl struct
	IDirectDrawVtbl <>
pGetAvailableVidMem	dd ?    
IDirectDraw2Vtbl ends

LPDIRECTDRAW2VTBL typedef ptr IDirectDraw2Vtbl

IDirectDraw struct
lpVtbl	LPDIRECTDRAWVTBL ?
IDirectDraw ends

IDirectDraw2 struct
lpVtbl	LPDIRECTDRAW2VTBL ?
IDirectDraw2 ends

protoDDSGetDC typedef proto :DWORD, :ptr DWORD
LPDDSGETDC typedef ptr protoDDSGetDC

protoDDSReleaseDC typedef proto :DWORD, :DWORD
LPDDSRELEASEDC typedef ptr protoDDSReleaseDC

protoDDSLock typedef proto :DWORD, :DWORD, :ptr DDSURFACEDESC, :DWORD, :DWORD
LPDDSLOCK typedef ptr protoDDSLock

protoDDSUnlock typedef proto :DWORD, :DWORD
LPDDSUNLOCK typedef ptr protoDDSUnlock

protoDDSGetSurfaceDesc typedef proto :DWORD, :ptr DDSURFACEDESC
LPDDSGETSURFACEDESC typedef ptr protoDDSGetSurfaceDesc

IDirectDrawSurfaceVtbl struct
		IUnknownVtbl <>
pAddAttachedSurface      dd ?	;+0C LPDIRECTDRAWSURFACE
pAddOverlayDirtyRect     dd ?	;+10 LPRECT
pBlt                     dd ?	;+14 LPRECT,LPDIRECTDRAWSURFACE, LPRECT,DWORD, LPDDBLTFX
pBltBatch                dd ?	;+18 LPDDBLTBATCH, DWORD, DWORD
pBltFast                 dd ?   ;+1C DWORD,DWORD,LPDIRECTDRAWSURFACE, LPRECT,DWORD
pDeleteAttachedSurface   dd ?   ;+20 DWORD,LPDIRECTDRAWSURFACE
pEnumAttachedSurfaces    dd ?   ;+24 LPVOID,LPDDENUMSURFACESCALLBACK
pEnumOverlayZOrders      dd ?   ;+28 DWORD,LPVOID,LPDDENUMSURFACESCALLBACK
pFlip                    dd ?   ;+2C LPDIRECTDRAWSURFACE, DWORD
pGetAttachedSurface      dd ?   ;+30 LPDDSCAPS, LPDIRECTDRAWSURFACE FAR *
pGetBltStatus            dd ?   ;+34 DWORD
pGetCaps                 dd ?   ;+38 LPDDSCAPS
pGetClipper              dd ?   ;+3C LPDIRECTDRAWCLIPPER FAR*
pGetColorKey             dd ?   ;+40 DWORD, LPDDCOLORKEY
GetDC_                   LPDDSGETDC ?   ;+44 HDC FAR *
pGetFlipStatus           dd ?   ;+48 DWORD
pGetOverlayPosition      dd ?   ;+4C LPLONG, LPLONG
pGetPalette              dd ?   ;+50 LPDIRECTDRAWPALETTE FAR*
pGetPixelFormat          dd ?   ;+54 LPDDPIXELFORMAT
GetSurfaceDesc           LPDDSGETSURFACEDESC ?   ;+58 LPDDSURFACEDESC
pInitialize              dd ?   ;+5C LPDIRECTDRAW, LPDDSURFACEDESC
pIsLost                  dd ?   ;+60 
Lock_                    LPDDSLOCK ?   ;+64 LPRECT,LPDDSURFACEDESC,DWORD,HANDLE
ReleaseDC_               LPDDSRELEASEDC ?   ;+68 HDC
pRestore                 dd ?   ;+6C 
pSetClipper              dd ?   ;+70 LPDIRECTDRAWCLIPPER
pSetColorKey             dd ?   ;+74 DWORD, LPDDCOLORKEY
pSetOverlayPosition      dd ?   ;+78 LONG, LONG
pSetPalette              dd ?   ;+7C LPDIRECTDRAWPALETTE
Unlock                   LPDDSUNLOCK ?   ;+80 LPVOID
pUpdateOverlay           dd ?   ;+84 LPRECT, LPDIRECTDRAWSURFACE,LPRECT,DWORD, LPDDOVERLAYFX
pUpdateOverlayDisplay    dd ?   ;+88 DWORD
pUpdateOverlayZOrder     dd ?   ;+8C DWORD, LPDIRECTDRAWSURFACE
IDirectDrawSurfaceVtbl ends

LPDIRECTDRAWSURFACEVTBL typedef ptr IDirectDrawSurfaceVtbl

IDirectDrawSurface struct
lpVtbl	LPDIRECTDRAWSURFACEVTBL ?
IDirectDrawSurface ends

IDirectDrawSurface2Vtbl struct
		IDirectDrawSurfaceVtbl <>
pGetDDInterface			dd ?        
pPageLock      			dd ?        
pPageUnlock    			dd ?        
IDirectDrawSurface2Vtbl ends

LPDIRECTDRAWSURFACE2VTBL typedef ptr IDirectDrawSurface2Vtbl

IDirectDrawSurface2 struct
lpVtbl	LPDIRECTDRAWSURFACE2VTBL ?
IDirectDrawSurface2 ends

IDirectDrawSurface3Vtbl struct
		IDirectDrawSurface2Vtbl <>
pSetSurfaceDesc			dd ?        
IDirectDrawSurface3Vtbl ends

LPDIRECTDRAWSURFACE3VTBL typedef ptr IDirectDrawSurface3Vtbl

IDirectDrawSurface3 struct
lpVtbl	LPDIRECTDRAWSURFACE3VTBL ?
IDirectDrawSurface3 ends

;--- palette

protoDDPGetCaps typedef proto :DWORD, :ptr DWORD
LPDDPGETCAPS typedef ptr protoDDPGetCaps

IDirectDrawPaletteVtbl struct
		IUnknownVtbl <>
pGetCaps 	LPDDPGETCAPS ?	; :LPDWORD
pGetEntries	dd ?	; :DWORD, :DWORD, :DWORD, :LPPALETTEENTRY
pInitialize	dd ?	; :LPDIRECTDRAW, :DWORD, :LPPALETTEENTRY
pSetEntries	dd ?	; :DWORD, :DWORD, :DWORD, :LPPALETTEENTRY
IDirectDrawPaletteVtbl ends

LPDIRECTDRAWPALETTEVTBL typedef ptr IDirectDrawPaletteVtbl

IDirectDrawPalette struct
lpVtbl	LPDIRECTDRAWPALETTEVTBL ?
IDirectDrawPalette ends

;--- gamma control

IDirectDrawGammaControlVtbl struct
		IUnknownVtbl <>
pGetGammaRamp	dd ?        
pSetGammaRamp	dd ?        
IDirectDrawGammaControlVtbl ends

LPDIRECTDRAWGAMMACONTROLVTBL typedef ptr IDirectDrawGammaControlVtbl

IDirectDrawGammaControl struct
lpVtbl	LPDIRECTDRAWGAMMACONTROLVTBL ?
IDirectDrawGammaControl ends

