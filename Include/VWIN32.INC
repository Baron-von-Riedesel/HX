
;*** this is required for DeviceIoControl

vseb_s  STRUC
vseb_resp       DD      ?
vseb_b3 DW      ?
vseb_b2 DW      ?
vseb_b1 DW      ?
vseb_pszCaption DD      ?
vseb_pszText    DD      ?
vseb_s  ENDS
KERNEL_APC_IGNORE_MC    EQU     00000001H
KERNEL_APC_STATIC       EQU     00000002H
KERNEL_APC_WAKE EQU     00000004H

DIOCParams      STRUC
Internal1       DD      ?
VMHandle        DD      ?
Internal2       DD      ?
dwIoControlCode DD      ?
lpvInBuffer     DD      ?
cbInBuffer      DD      ?
lpvOutBuffer    DD      ?
cbOutBuffer     DD      ?
lpcbBytesReturned       DD      ?
lpoOverlapped   DD      ?
hDevice DD      ?
tagProcess      DD      ?
DIOCParams      ENDS
VWIN32_DIOC_GETVERSION  EQU     <DIOC_GETVERSION>
VWIN32_DIOC_DOS_IOCTL   EQU     1
VWIN32_DIOC_DOS_INT25   EQU     2
VWIN32_DIOC_DOS_INT26   EQU     3
VWIN32_DIOC_DOS_INT13   EQU     4
VWIN32_DIOC_SIMCTRLC    EQU     5
VWIN32_DIOC_CLOSEHANDLE EQU     <DIOC_CLOSEHANDLE>
VWIN32_DIOC_DOS_DRIVEINFO EQU     6

DIOCRegs        STRUC
reg_EBX DD      ?
reg_EDX DD      ?
reg_ECX DD      ?
reg_EAX DD      ?
reg_EDI DD      ?
reg_ESI DD      ?
reg_Flags       DD      ?
DIOCRegs        ENDS

ifndef FILE_FLAG_OVERLAPPED

_OVERLAPPED     STRUC
O_Internal      DD      ?
O_InternalHigh  DD      ?
O_Offset        DD      ?
O_OffsetHigh    DD      ?
O_hEvent        DD      ?
_OVERLAPPED     ENDS
endif

