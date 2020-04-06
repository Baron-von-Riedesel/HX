

; D386_Load_Segment type equates:

ST_code_sel		equ 0
ST_data_sel		equ 1
ST_code_seg		equ 10h
ST_data_seg		equ 11h
ST_dual_code	equ 40h
ST_dual_data	equ 41h

; D386_Load_Segment device load parameters structure

D386_Device_Params STRUC
DD_logical_seg	dw  ?
DD_actual_sel	dw  ?
DD_base			dd  ?
DD_length		dd  ?
DD_name			df  ?
DD_sym_name		df  ?
DD_alias_sel	dw  ?
D386_Device_Params ENDS

Debug_Serv_Int	     equ 41h

DS_Out_Char		equ	0
DS_In_Char		equ	1
DS_Out_Str		equ	2
DS_Is_Char		equ	3
DS_Out_Str16	equ 12h
DS_ForcedGO16	equ 40h
DS_IsAutoLoadSym equ 48h
DS_DebLoaded	equ 4Fh
DS_DebPresent	equ 0F386h
DS_LoadSeg		equ 50h
DS_LoadSeg_32	equ 0150h
DS_MoveSeg		equ 51h
DS_FreeSeg		equ 52h
DS_FreeSeg_32	equ 0152h
DS_DLL			equ 58h
DS_StartTask	equ 59h
DS_ReleaseSeg	equ 5ch
DS_User_Vars    equ 5dh
DS_POSTLOAD		=	60h
DS_EXITCALL		=	62h
DS_LOADDLL		=	64h	;
DS_DELMODULE	=	65h

DS_CondBP		equ 0F001h
DS_ForcedBP		equ 0F002h
DS_ForcedGO		equ 0F003h

