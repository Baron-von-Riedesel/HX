
#ifdef __cplusplus
extern "C" {
#endif

typedef struct _VESAINFO {
unsigned char VESASignature[4];
short VESAVersion;
char * OEMStringPtr;
unsigned long Capabilities;
short * VideoModePtr;
short TotalMemory;
short reserved;
unsigned long OEMSoftwareRev;
char * OEMVendorNamePtr;
char * OEMProductRevPtr;
unsigned char VIReserved[222];
unsigned char VIReserved2[256];
} VESAINFO;

typedef struct _SVGAINFO {
short ModeAttributes  ;
unsigned char WinAAttributes ;
unsigned char WinBAttributes ;
short WinGranularity ;
short WinSize        ;
short WinASegment    ;
short WinBSegment    ;
unsigned long WinFuncPtr ;
short BytesPerScanLine ;
//---------------------- rest is optional info (since Version 1.2)
short XResolution   ;
short YResolution   ;
unsigned char XCharSize  ;
unsigned char YCharSize  ;
unsigned char NumberOfPlanes ;
unsigned char BitsPerPixel ;
unsigned char NumberOfBanks ;
unsigned char MemoryModel   ;
unsigned char BankSize      ;
unsigned char NumberOfImagePages ;
unsigned char Reserved     ;
unsigned char RedMaskSize   ;
unsigned char RedFieldPosition  ;
unsigned char GreenMaskSize ;
unsigned char GreenFieldPosition ;
unsigned char BlueMaskSize  ;
unsigned char BlueFieldPosition ;
unsigned char RsvdMaskSize  ;
unsigned char RsvdFieldPosition ;
unsigned char DirectColorModeInfo ;
//--------------------- since Version 2.0
unsigned long PhysBasePtr ;
unsigned long OffScreenMemOffset ;
short OffScreenMemSize   ;
unsigned char Reserved2[206];
    } SVGAINFO;

typedef struct _VESAPALETTEENTRY {
    unsigned char bRed;
    unsigned char bGreen;
    unsigned char bBlue;
    unsigned char bAlpha;
} VESAPALETTEENTRY;

//--- ModeAttributes flags

#define VESAATTR_SUPPORTED		0x001	/* supported by hardware */
#define VESAATTR_OPT_INFO_AVAIL	0x002
#define VESAATTR_BIOS_OUTPUT	0x004
#define VESAATTR_IS_COLOR_MODE 	0x008
#define VESAATTR_IS_GFX_MODE 	0x010	/* is a graphics mode */
#define VESAATTR_NON_VGA_COMPAT	0x020
#define VESAATTR_NO_BANK_SWITCH	0x040
#define VESAATTR_LFB_SUPPORTED	0x080	/* LFB supported */
#define VESAATTR_DBLSCAN_SUPP	0x100

typedef int (__stdcall * VESAENUMCALLBACK)(int iMode, SVGAINFO * psvga, int parm);

int __stdcall EnumVesaModes(VESAENUMCALLBACK pCallback, int parm);
int __stdcall GetVesaInfo(VESAINFO *);
int __stdcall GetVesaMode(void);
int __stdcall GetVesaModeInfo(int,SVGAINFO *);
int __stdcall GetVesaStateBufferSize(void);
int __stdcall GetVesaMemoryBufferSize(int iMode);
int __stdcall GetVesaVideoMemorySize(void);
int __stdcall RestoreVesaVideoMemory(void *);
int __stdcall RestoreVesaVideoState(void *);
int __stdcall SaveVesaVideoMemory(void *, int iSize);
int __stdcall SaveVesaVideoState(void *, int iSize);
int __stdcall SearchVesaMode(int xdim, int ydim, int bpp);
int __stdcall SetCursorPaletteEntries(int iScreenClr, int iCursorClr);
int __stdcall SetVesaMode(int);
int __stdcall SetVesaPaletteEntries(int iStart, int iCnt, VESAPALETTEENTRY * pEntries);
int __stdcall VesaMouseInit(void);
int __stdcall VesaMouseExit(void);

int __stdcall VesaInit(void); /* if code is linked statically */
int __stdcall VesaExit(void); /* if code is linked statically */

#ifdef __cplusplus
};
#endif
