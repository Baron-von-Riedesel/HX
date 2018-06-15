;******************************************************************************
;
; WNASPI32.INC - prepared by Alvise Valsecchi - oct 18, 2000
;
; This file is derived directly from wnaspi32.h supplied with Adaptec's ASPISDK,
; and has been adapted to be included into win32asm programs.
;
; Freeware to be used with hutch's MASM32.
;
;*****************************************************************************/
 
;*****************************************************************************
;       SCSI MISCELLANEOUS EQUATES
;*****************************************************************************
 
 SENSE_LEN                   EQU  14  ;Default sense buffer length
 SRB_DIR_SCSI                EQU  00H ;Direction determined by SCSI
 SRB_POSTING                 EQU  01H ;Enable ASPI posting
 SRB_ENABLE_RESIDUAL_COUNT   EQU  04H ;Enable residual byte count reporting
 SRB_DIR_IN                  EQU  08H ;Transfer from SCSI target to host
 SRB_DIR_OUT                 EQU  10H ;Transfer from host to SCSI target
 SRB_EVENT_NOTIFY            EQU  40H ;Enable ASPI event notification
 RESIDUAL_COUNT_SUPPORTED    EQU  02H ;Extended buffer flag
 MAX_SRB_TIMEOUT             EQU  108000 ;30 hour maximum timeout in s
 DEFAULT_SRB_TIMEOUT         EQU  108000 ;Max timeout by default
 
;*****************************************************************************
;       ASPI Command Definitions
;*****************************************************************************
 
SC_HA_INQUIRY                EQU  00H ;Host adapter inquiry
SC_GET_DEV_TYPE              EQU  01H ;Get device type
SC_EXEC_SCSI_CMD             EQU  02H ;Execute SCSI command
SC_ABORT_SRB                 EQU  03H ;Abort an SRB
SC_RESET_DEV                 EQU  04H ;SCSI bus device reset
SC_SET_HA_PARMS              EQU  05H ;Set HA parameters
SC_GET_DISK_INFO             EQU  06H ;Get Disk information
SC_RESCAN_SCSI_BUS           EQU  07H ;ReBuild SCSI device map
SC_GETSET_TIMEOUTS           EQU  08H ;Get/Set target timeouts
 
;*****************************************************************************
;       SRB Status
;*****************************************************************************
 
SS_PENDING                   EQU  00H ;SRB being processed
SS_COMP                      EQU  01H ;SRB completed without error
SS_ABORTED                   EQU  02H ;SRB aborted
SS_ABORT_FAIL                EQU  03H ;Unable to abort SRB
SS_ERR                       EQU  04H ;SRB completed with error
SS_INVALID_CMD               EQU  80H ;Invalid ASPI command
SS_INVALID_HA                EQU  81H ;Invalid host adapter number
SS_NO_DEVICE                 EQU  82H ;SCSI device not installed
SS_INVALID_SRB               EQU 0E0H ;Invalid parameter set in SRB
SS_OLD_MANAGER               EQU 0E1H ;ASPI manager doesn't support Windows
SS_BUFFER_ALIGN              EQU 0E1H ;Buffer not aligned (replaces OLD_MANAGER in Win32)
SS_ILLEGAL_MODE              EQU 0E2H ;Unsupported Windows mode
SS_NO_ASPI                   EQU 0E3H ;No ASPI managers resident
SS_FAILED_INIT               EQU 0E4H ;ASPI for windows failed init
SS_ASPI_IS_BUSY              EQU 0E5H ;No resources available to execute cmd
SS_BUFFER_TO_BIG             EQU 0E6H ;Buffer size to big to handle!
SS_MISMATCHED_COMPONENTS     EQU 0E7H ;The DLLs/EXEs of ASPI don't version check
SS_NO_ADAPTERS               EQU 0E8H ;No host adapters to manage
SS_INSUFFICIENT_RESOURCES    EQU 0E9H ;Couldn't allocate resources needed to init
SS_ASPI_IS_SHUTDOWN          EQU 0EAH ;Call came to ASPI after PROCESS_DETACH
SS_BAD_INSTALL               EQU 0EBH ;The DLL or other components are installed wrong
 
;*****************************************************************************
;       Host Adapter Status
;*****************************************************************************
 
HASTAT_OK                    EQU  00H ;Host adapter did not detect an error
HASTAT_SEL_TO                EQU  11H ;Selection Timeout
HASTAT_DO_DU                 EQU  12H ;Data overrun data underrun
HASTAT_BUS_FREE              EQU  13H ;Unexpected bus free
HASTAT_PHASE_ERR             EQU  14H ;Target bus phase sequence failure
HASTAT_TIMEOUT               EQU  09H ;Timed out while SRB was waiting to beprocessed.
HASTAT_COMMAND_TIMEOUT       EQU  0BH ;Adapter timed out processing SRB.
HASTAT_MESSAGE_REJECT        EQU  0DH ;While processing SRB, the adapter received a MESSAGE
HASTAT_BUS_RESET             EQU  0EH ;A bus reset was detected.
HASTAT_PARITY_ERROR          EQU  0FH ;A parity error was detected.
HASTAT_REQUEST_SENSE_FAILED  EQU  10H ;The adapter failed in issuing

ifndef SRBHDR
SRBHDR struct
SRB_Cmd		db ?
SRB_Status	db ?
SRB_HaId	db ?
SRB_Flags	db ?
SRB_Hdr_Rsvd dd ?
SRBHDR ends
endif 

;*****************************************************************************
;           SRB - HOST ADAPTER INQUIRY - SC_HA_INQUIRY (0)
;*****************************************************************************
 
SRB_HAInquiry           STRUC
	SRBHDR <>
   HA_Count             DB ?          ;Number of host adapters present
   HA_SCSI_ID           DB ?          ;SCSI ID of host adapter
   HA_ManagerId         DB 16 DUP (?) ;String describing the manager
   HA_Identifier        DB 16 DUP (?) ;String describing the host adapter
   HA_Unique            DB 16 DUP (?) ;Host Adapter Unique parameters
   HA_Rsvd1             DW ?          ;Reserved, MUST = 0
SRB_HAInquiry           ENDS
 
;*****************************************************************************
;           SRB - GET DEVICE TYPE - SC_GET_DEV_TYPE (1)
;*****************************************************************************
 
SRB_GDEVBlock           STRUC
	SRBHDR <>
   SRB_Target           DB ?          ;Target's SCSI ID
   SRB_Lun              DB ?          ;Target's LUN number
   SRB_DeviceType       DB ?          ;Target's peripheral device type
   SRB_Rsvd1            DB ?          ;Reserved, MUST = 0
SRB_GDEVBlock           ENDS
 
;*****************************************************************************
;           SRB - EXECUTE SCSI COMMAND - SC_EXEC_SCSI_CMD (2)
;*****************************************************************************
 
SRB_ExecSCSICmd         STRUC
	SRBHDR <>
   SRB_Target           DB ?          ;+08 Target's SCSI ID
   SRB_Lun              DB ?          ;Target's LUN number
   SRB_Rsvd1            DW ?          ;Reserved for Alignment
   SRB_BufLen           DD ?          ;+12 Data Allocation Length
   SRB_BufPointer       DD ?          ;+16 Pointer to Data Buffer
   SRB_SenseLen         DB ?          ;+20 Sense Allocation Length
   SRB_CDBLen           DB ?          ;CDB Length
   SRB_HaStat           DB ?          ;Host Adapter Status
   SRB_TargStat         DB ?          ;Target Status
   SRB_PostProc         DD ?          ;+24 pointer to post routine
   SRB_Rsvd2            DB 20 DUP (?) ;+28 Reserved, MUST = 0
   CDBByte              DB 16 DUP (?) ;+48 SCSI CDB
   SenseArea            DB 16 DUP (?) ;+64 Request Sense buffer (16=SENSE_LEN+2)
SRB_ExecSCSICmd         ENDS
 
;*****************************************************************************
;           SRB - ABORT AN SRB - SC_ABORT_SRB (3)
;*****************************************************************************
 
SRB_Abort               STRUC
	SRBHDR <>
   SRB_ToAbort          DD ?          ;Pointer to SRB to abort
SRB_Abort               ENDS
 
;*****************************************************************************
;           SRB - BUS DEVICE RESET - SC_RESET_DEV (4)
;*****************************************************************************
 
SRB_BusDeviceReset      STRUC
	SRBHDR <>
   SRB_Target           DB ?          ;Target's SCSI ID
   SRB_Lun              DB ?          ;Target's LUN number
   SRB_Rsvd1            DB 12 DUP (?) ;Reserved for Alignment
   SRB_HaStat           DB ?          ;Host Adapter Status
   SRB_TargStat         DB ?          ;Target Status
   SRB_PostProc         DD ?          ;Pointer to Post routine
   SRB_Rsvd2            DB 36 DUP (?) ;Reserved, MUST = 0
SRB_BusDeviceReset      ENDS
 
;*****************************************************************************
;           SRB - GET DISK INFORMATION - SC_GET_DISK_INFO
;*****************************************************************************
 
SRB_GetDiskInfo         STRUC
	SRBHDR <>
   SRB_Target           DB ?          ;Target's SCSI ID
   SRB_Lun              DB ?          ;Target's LUN number
   SRB_DriveFlags       DB ?          ;Driver flags
   SRB_Int13HDriveInfo  DB ?          ;Host Adapter Status
   SRB_Heads            DB ?          ;Preferred number of heads translation
   SRB_Sectors          DB ?          ;Preferred number of sectors translation
   SRB_Rsvd1            DB 10 DUP (?) ;Reserved, MUST = 0
SRB_GetDiskInfo         ENDS
 
;*****************************************************************************
;            SRB - RESCAN SCSI BUS(ES) ON SCSIPORT
;*****************************************************************************
 
SRB_RescanPort          STRUC
	SRBHDR <>
SRB_RescanPort          ENDS
 
;*****************************************************************************
;           SRB - GET/SET TARGET TIMEOUTS
;*****************************************************************************
 
SRB_GetSetTimeouts      STRUC
	SRBHDR <>
   SRB_Target           DB ?          ;Target's SCSI ID
   SRB_Lun              DB ?          ;Target's LUN number
   SRB_Timeout          DD ?          ;Timeout in half seconds
SRB_GetSetTimeouts      ENDS
 
;*****************************************************************************
;           ASPIBUFF - Structure For Controllng I/O Buffers
;*****************************************************************************
 
ASPI32BUFF              STRUC
   AB_BufPointer        DD ?          ;Pointer to first byte of the ASPI allocated buffer
   AB_BufLen            DD ?          ;Length in bytes of the buffer
   AB_ZeroFill          DD ?          ;Flag set to 1 if buffer should be zeroed
   AB_Reserved          DD ?          ;Reserved
ASPI32BUFF              ENDS
 
;*****************************************************************************
;           PROTOTYPES - User Callable ASPI for Win32 Functions
; All these functions return a doubleword in EAX
;*****************************************************************************
 
GetASPI32SupportInfo   PROTO STDCALL
;EAX on return ---> bits:      value:
;                   31-16      set to zero
;                   15- 8      status code byte
;                    7- 0      host adapter count byte
 
SendASPI32Command      PROTO STDCALL, :DWORD
;EAX on return from asynchronous SRBs ---> SS_PENDING
;EAX on return from synchronous SRBs
;              ---> bits:      value:
;                   31- 8      ignored
;                    7- 0      same as SRB_Status in SRB_Header
 
GetASPI32Buffer        PROTO STDCALL, :DWORD
;EAX on return ---> TRUE/FALSE
 
FreeASPI32Buffer       PROTO STDCALL, :DWORD
;EAX on return ---> TRUE/FALSE
 
TranslateASPI32Address PROTO STDCALL, :DWORD , :DWORD
;EAX on return ---> TRUE/FALSE
 
 
