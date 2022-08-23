

proto_PFNVDD_INB   typedef proto stdcall :WORD,:ptr BYTE
proto_PFNVDD_INW   typedef proto stdcall :WORD,:ptr WORD
proto_PFNVDD_INSB  typedef proto stdcall :WORD,:ptr BYTE,:WORD
proto_PFNVDD_INSW  typedef proto stdcall :WORD,:ptr WORD,:WORD
proto_PFNVDD_OUTB  typedef proto stdcall :WORD,:BYTE
proto_PFNVDD_OUTW  typedef proto stdcall :WORD,:WORD
proto_PFNVDD_OUTSB typedef proto stdcall :WORD,:ptr BYTE,:WORD
proto_PFNVDD_OUTSW typedef proto stdcall :WORD,:ptr WORD,:WORD

PFNVDD_INB   typedef ptr proto_PFNVDD_INB
PFNVDD_INW   typedef ptr proto_PFNVDD_INW
PFNVDD_INSB  typedef ptr proto_PFNVDD_INSB
PFNVDD_INSW  typedef ptr proto_PFNVDD_INSW
PFNVDD_OUTB  typedef ptr proto_PFNVDD_OUTB
PFNVDD_OUTW  typedef ptr proto_PFNVDD_OUTW
PFNVDD_OUTSB typedef ptr proto_PFNVDD_OUTSB
PFNVDD_OUTSW typedef ptr proto_PFNVDD_OUTSW

VDD_IO_HANDLERS struct 
inb_handler		PFNVDD_INB ?
inw_handler		PFNVDD_INW ?
insb_handler	PFNVDD_INSB ?
insw_handler	PFNVDD_INSW ?
outb_handler	PFNVDD_OUTB ?
outw_handler	PFNVDD_OUTW ?
outsb_handler	PFNVDD_OUTSB ?
outsw_handler	PFNVDD_OUTSW ?
VDD_IO_HANDLERS ends

VDD_IO_PORTRANGE struct 
First	WORD ?
Last	WORD ?
VDD_IO_PORTRANGE ends

VDDInstallIOHook   proto stdcall :HANDLE, :WORD, :ptr VDD_IO_PORTRANGE, :ptr VDD_IO_HANDLERS
VDDDeInstallIOHook proto stdcall :HANDLE, :WORD, :ptr VDD_IO_PORTRANGE
VDDReserveIrqLine  proto stdcall :HANDLE, :WORD
VDDReleaseIrqLine  proto stdcall :HANDLE, :WORD

VDD_DMA_INFO struct 
addr_	WORD ?
count	WORD ?
page_	WORD ?
status	BYTE ?
mode	BYTE ?
mask_	BYTE ?
VDD_DMA_INFO ends

VDD_DMA_ADDR	EQU 01h
VDD_DMA_COUNT	EQU 02h
VDD_DMA_PAGE	EQU 04h
VDD_DMA_STATUS	EQU 08h
VDD_DMA_ALL		EQU VDD_DMA_ADDR or VDD_DMA_COUNT or VDD_DMA_PAGE or VDD_DMA_STATUS

VDM_V86 equ 0
VDM_PM  equ 1

VDM_NO_ERROR                  equ 0
VDM_ERROR_INVALID_BUFFER_SIZE equ 1
VDM_ERROR_INVALID_FUNCTION    equ 2


VDDRequestDMA proto stdcall :HANDLE, :WORD, :ptr, :DWORD
VDDSetDMA     proto stdcall :HANDLE, :WORD, :WORD, :ptr VDD_DMA_INFO
VDDQueryDMA   proto stdcall :HANDLE, :WORD, :ptr VDD_DMA_INFO

proto_PVDD_MEMORY_HANDLER typedef proto stdcall :ptr,:DWORD
PVDD_MEMORY_HANDLER       typedef ptr proto_PVDD_MEMORY_HANDLER

VDDInstallMemoryHook   proto stdcall :HANDLE, :ptr, :DWORD, :PVDD_MEMORY_HANDLER
VDDDeInstallMemoryHook proto stdcall :HANDLE, :ptr, :DWORD
VDDAllocMem            proto stdcall :HANDLE, :ptr, :DWORD
VDDFreeMem             proto stdcall :HANDLE, :ptr, :DWORD
VDDIncludeMem          proto stdcall :HANDLE, :ptr, :DWORD
VDDTerminateVDM        proto stdcall

proto_PFNVDD_UCREATE    typedef proto stdcall :WORD
proto_PFNVDD_UTERMINATE typedef proto stdcall :WORD
proto_PFNVDD_UBLOCK     typedef proto stdcall
proto_PFNVDD_URESUME    typedef proto stdcall

PFNVDD_UCREATE    typedef ptr proto_PFNVDD_UCREATE
PFNVDD_UTERMINATE typedef ptr proto_PFNVDD_UTERMINATE
PFNVDD_UBLOCK     typedef ptr proto_PFNVDD_UBLOCK
PFNVDD_URESUME    typedef ptr proto_PFNVDD_URESUME

VDD_USER_HANDLERS struct 
hvdd			HANDLE ?
ucr_handler		PFNVDD_UCREATE ?
uterm_handler	PFNVDD_UTERMINATE ?
ublock_handler	PFNVDD_UBLOCK ?
uresume_handler	PFNVDD_URESUME ?
next			DWORD ?
VDD_USER_HANDLERS ends

VDDInstallUserHook   proto stdcall :HANDLE, :PFNVDD_UCREATE, :PFNVDD_UTERMINATE, :PFNVDD_UBLOCK, :PFNVDD_URESUME
VDDDeInstallUserHook proto stdcall :HANDLE

VDDTerminateUserHook proto stdcall :DWORD
VDDCreateUserHook    proto stdcall :DWORD
VDDBlockUserHook     proto stdcall
VDDResumeUserHook    proto stdcall

VDDSimulate16        proto stdcall 
VDDAllocateDosHandle proto stdcall :DWORD, :ptr ptr, :ptr ptr
VDDAssociateNtHandle proto stdcall :ptr, :HANDLE, :WORD
VDDReleaseDosHandle  proto stdcall :DWORD, :SWORD
VDDRetrieveNtHandle  proto stdcall :DWORD, :SWORD, :ptr ptr, :ptr ptr
VdmTraceEvent        proto stdcall :WORD, :WORD, :DWORD

;--- vdm info type - argument 1 of VdmParametersInfo() 
VDM_GET_TICK_COUNT           equ 0
VDM_GET_TIMER0_INITIAL_COUNT equ 1
VDM_GET_LAST_UPDATED_TIMER0_COUNT equ 2
VDM_LATCH_TIMER0_COUNT       equ 3
VDM_SET_NEXT_TIMER0_COUNT    equ 4

ifndef VdmMapFlat
VdmMapFlat        proto stdcall :DWORD, :DWORD, :DWORD
endif
VdmParametersInfo proto stdcall :DWORD, :ptr, :DWORD
VdmGetParametersInfoError proto stdcall
