
;--- dos/win16 ASPI SRB structures
;--- used by APIX.ASM

SRBHDR struct
SRB_Cmd		db ?
SRB_Status	db ?
SRB_HaId	db ?
SRB_Flags	db ?
SRB_Hdr_Rsvd dd ?	;+04
SRBHDR ends

;--- define the 16bit SRB structures

SRB_GDEVBlock16	struct
		SRBHDR <>
SRB_Target 		db ?	;+08 [IN] target
SRB_Lun    		db ?	;+09 [IN] logical unit 
SRB_DeviceType	db ?	;+10 [OUT] Target's peripheral device type
SRB_GDEVBlock16	ends

SRB_ExecSCSICmd16	struct
		SRBHDR <>
SRB_Target 		db ?	;+08 [IN] target
SRB_Lun    		db ?	;+09 [IN] logical unit 
SRB_BufLen		dd ?	;+10 [IN/OUT] data buffer length
SRB_SenseLen	db ?	;+14 [IN]
SRB_BufPointer	dd ?	;+15 [IN] data buffer
SRB_NextReq		dd ?	;+19 [IN]
SRB_CDBLen		db ?	;+23 [IN]
SRB_HaStat		db ?	;+24 [OUT] host adapter status
SRB_TargStat	db ?	;+25 [OUT] target status
SRB_PostProc	dd ?	;+26 [IN] address post routine
SRB_Rsvd1 		db 34 dup (?) ;+30
SRB_ExecSCSICmd16	ends

SRB_Abort16	struct
		SRBHDR <>
SRB_ToAbort		dd ?	;+08
SRB_Abort16	ends

SRB_BusDeviceReset16 struct
		SRBHDR <>
SRB_Target	BYTE	?
SRB_Lun		BYTE	?
SRB_Rsvd1	BYTE 14 dup (?)
SRB_HaStat	BYTE	?
SRB_TargStat BYTE	?
SRB_PostProc DWORD  ?
SRB_Rsvd2	BYTE 34 dup (?)
SRB_BusDeviceReset16 ends

SRB_GetDiskInfo16	struct
		SRBHDR <>
SRB_Target 		db ?	;+08 [IN] target
SRB_Lun    		db ?	;+09 [IN] logical unit 
SRB_DriveFlags       DB ?
SRB_Int13HDriveInfo  DB ?
SRB_Heads            DB ?
SRB_Sectors          DB ?
SRB_GetDiskInfo16	ends

SRB_GetSetTimeouts16	struct
		SRBHDR <>
SRB_Target 		db ?	;+08 [IN] target
SRB_Lun    		db ?	;+09 [IN] logical unit 
SRB_Timeout		dd ?
SRB_GetSetTimeouts16	ends

