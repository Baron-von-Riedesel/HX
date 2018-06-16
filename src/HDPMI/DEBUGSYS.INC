
;
;  Real mode Debugger services:
;

D386_RM_Int		equ 68h	; hooked by the debugger in real mode.

D386_Id			equ 0F386h ; debugger identification code

D386_MIN			equ 43h	; minimum INT 68 function code
D386_Identify		equ 43h	; returns debugger identification, if debugger
D386_Prepare_PMode	equ 44h	; partially prepare for protected mode operation
D386_Real_Mode_Init	equ 45h	; re-init fro real mode after entering pmode
D386_Set_Switches	equ 46h	; set debugging switches
D386_Execute_Cond	equ 47h	; execute conditional BP (/B option)
D386_Free_Segment	equ 48h	; undefine the real mode segment's symbols
D386_Set_Baudrate	equ 49h	; set com port baud rate
D386_Reinit			equ 4ah	; reinitialize debugger for protected mode
D386_Def_Deb_Segs	equ 4bh	; define debugger's segments
D386_Set_Com_Port	equ 4ch	; set com port number
D386_Link_Sym		equ 4dh	; link sym file map
D386_Unlink_Sym		equ 4eh	; unlink sym file maps
D386_Remove_Segs	equ 4fh	; remove any undefined segments from the
D386_Load_Segment	equ 50h	; defines the actual segment/selector for a
D386_Display_Char	equ 51h	; display a character to the debugging terminal
D386_Display_Str	equ 52h	; display a string to the debugging terminal
D386_IsVxDInstalled	equ 53h	; returns if debug VxD has been installed
D386_VxDInstall		equ 54h	; sets that the debug VxD installed/uninstalled
D386_RegisterDotCmd	equ 55h	; registers dot command
D386_DeRegisterDotCmd	equ 56h	; de-registers dot command
D386_Printf			equ 57h	; Printf
D386_Link_Sym_Phys	equ 58h	; link symbol file with physical address
D386_CheckMap		equ 59h	; DX:DI = pointer to module name
D386_SetAutoLoadSym	equ 5ah	; (BL) != 0, auto load symbols
D386_SetTeftiPort	equ 5bh	; (BX) = TEFTI port address
D386_ExecDebugCommand	equ 5ch	; execute debugger command script
D386_LoadCodeDataHigh	equ 5dh	; makes the debugger copy its code/data high
D386_SetWinVersion	equ 5eh	; sets Windows version number
D386_ScanChar		equ 5fh ; scan for character
D386_UnGetChar		equ 60h ; ungetchar scaned character, AL = char
D386_Stop			equ 61h	; stop at the CS:IP specified
D386_MAX			equ 61h	; maximum INT 68 function code

; D386_Load_Segment type equates:

ST_code_sel	equ 0		; code selector
ST_data_sel	equ 1		; data selector

ST_code_seg	equ 10h		; code segment
ST_data_seg	equ 11h		; data segment

ST_dual_code	equ 40h		; code segment and selector
ST_dual_data	equ 41h		; data segment and selector

ST_device_code	equ 80h		; device driver code segment
ST_device_data	equ 81h		; device driver data segment

; D386_Load_Segment device load parameters structure

D386_Device_Params STRUC
DD_logical_seg	dw  ?	; logical segment # from map
DD_actual_sel	dw  ?	; actual selector value
DD_base			dd  ?	; linear address offset for start of segment
DD_length		dd  ?	; actual length of segment
DD_name			df  ?	; 16:32 ptr to null terminated device name
DD_sym_name		df  ?	; 16:32 ptr to null terminated symbolic
DD_alias_sel	dw  ?	; alias selector value (0 = none)
D386_Device_Params ENDS

WDEB_INT2F_STARTING			equ	0	; first time starting
WDEB_INT2F_ENDING			equ	1	; first time ending
WDEB_INT2F_NESTED_STARTING	equ	2	; start on level of nesting
WDEB_INT2F_NESTED_ENDING	equ	3	; end one level of nesting

; PMINIT routine functions

PMINIT_INIT_IDT					equ	0	; (ES:EDI) = pointer to PM IDT
PMINIT_INIT_PAGING				equ	1	; (BX) = phys-linear selector 
PMINIT_ENABLE_DEBUG_QUERYS		equ	2	; enables dot commands, etc.
PMINIT_INIT_SPARE_PTE			equ	3	; (EBX) = lin addr of spare PTE
PMINIT_SET_ENTER_EXIT_VMM		equ	4	; (EBX) = Enter VMM routine addr
PMINIT_GET_SIZE_PHYS			equ	5	; get debugger size/phys addr
PMINIT_SET_BASE_SPARE_PTE		equ	6	; set debugger base/spare PTE
PMINIT_ENABLE_MEMORY_CONTEXT	equ	7	; enables mem context functions
PMINIT_MAX						equ	7

if 0
WdebVCPIInfo	  STRUCT
	fnVCPI	df	?	; VCPI protect mode server entry point
	rdsVCPI	dw	?	; Selector for VCPI server
	laVTP	dd	?	; linear address of data structure containing
	Port67	dw	?	; Qualitas magic port for emulating INT 67h
WdebVCPIInfo	  ENDS

VTP	struct
	zaCr3VTP	dd	0	; physical addr of page directory
	laGdtrVTP	dd	0	; linear addr in first meg of gdtr
	laIdtrVTP	dd	0	; linear addr in first meg of idtr
	selLdtVTP	dw	0	; selector of ldt
	selTrVTP	dw	0	; selector of tr
	ipVTP		dw	0	; 48-bit address of protect
	unusedVTP	dw	0	;   mode entry point to xfer to
	csVTP		dw	0	;
VTP	ends

VCPI_RM_CALLOUT_INT	equ	67h	; v86 mode call to VCPI server
VCPI_PROT_ENTRY		equ	0DE0CH
endif


;  Protected mode Debugger services:

Debug_Serv_Int	     equ 41h	; Interrupt that calls Deb386 to perform

DS_Out_Char		equ     0	; function to display the char in DL
DS_In_Char		equ     1	; function to read a char into AL
DS_Out_Str		equ     2	; function to display a NUL terminated string
DS_Is_Char		equ     3	; Non blocking In_Chr
DS_Out_Str16	equ    12h	; function to display a NUL terminated string
DS_ForcedGO16	equ    40h	; enter the debugger and perform the equivalent
DS_LinkMap		equ    45h	; DX:(E)DI = ptr to paragraph in front of map
DS_UnlinkMap	equ    46h	; DX:(E)DI = ptr to paragraph in front of map
DS_CheckMap		equ    47h	; DX:(E)DI = pointer to module name
DS_IsAutoLoadSym equ   48h	; returns AX != 0, auto load symbols
DS_DebLoaded	equ    4Fh	; check to see if the debugger is installed and
DS_DebPresent	equ   0F386h
DS_LoadSeg		equ    50h	; define a segment value for the
DS_LoadSeg_32	equ  0150h	; Define a 32-bit segment for Windows 32
DS_MoveSeg		equ    51h	; notify the debugger that a segment has moved
DS_FreeSeg		equ    52h	; notify the debugger that a segment has been
DS_FreeSeg_32	equ  0152h	; notify the debugger that a segment has been
DS_DGH			equ    56h	; register "dump global heap" handler
DS_DFL			equ    57h	; register "dump free list" handler
DS_DLL			equ    58h	; register "dump LRU list" handler
DS_StartTask	equ    59h	; notify debugger that a new task is starting
DS_Kernel_Vars	equ    5ah	; Used by the Windows kernel to tell the
DS_VCPI_Notify	equ    5bh	; notify debugger that DOS extender is
DS_ReleaseSeg	equ    5ch	; This does the same as a DS_FreeSeg, but
DS_User_Vars    equ    5dh	; DS:SI = pointer to an array of offsets:
DS_POSTLOAD		=	60h	; Used by the RegisterPTrace interface
DS_EXITCALL		=	62h	; Somebody will fill these in if we ever
DS_INT2			=	63h	; figure out what they are supposed to do.
DS_LOADDLL		=	64h
DS_DELMODULE	=	65h

DS_NEWTASK		=	0BH
DS_FLUSHTASK	=	0CH
DS_SWITCHOUT	=	0DH
DS_SWITCHIN		=	0EH

DS_IntRings		equ    20h	; function to tell debugger which INT 1's & 3's
DS_IncludeSegs	equ    21h	; function to tell debugger to go ahead and
MaxDebugSegs 	= 20

DS_CondBP		equ 0F001h	; conditional break pt, if the command line
DS_ForcedBP		equ 0F002h	; break pt, which accomplishes the same thing
DS_ForcedGO		equ 0F003h	; enter the debugger and perform the equivalent
DS_HardINT1		equ 0F004h	; check to see if INT 1 hooked for all rings
DS_Out_Symbol	equ    0Fh	; find the symbol nearest to the address in
DS_Disasm_Ins	equ    10h	; function to disassemble the instruction

DS_JumpTableStart       equ 70h
DS_RegisterDotCommand   equ 70h
DS_RegisterDotCommand16 equ 71h
DS_DeRegisterDotCommand equ 72h
DS_Printf	            equ	73h
DS_Printf16             equ 74h
DS_GetRegisterSet       equ 75h
DS_SetAlternateRegisterSet equ 76h
DS_GetCommandLineChar   equ 77h
DS_EvaluateExpression   equ 78h
DS_VerifyMemory	        equ 79h
DS_PrintRegisters       equ 7ah
DS_PrintStackDump       equ 7bh
DS_SetThreadID	        equ 7ch
DS_ExecDebugCommand     equ 7dh
DS_GetDebuggerInfo      equ 7eh
DS_CheckFault           equ 7fh	
DS_SetBreak             equ 80h	
DS_RedirectExec         equ 81h	
DS_PassOnDebugCommand   equ 82h	
DS_TrapFault            equ 83h	
DS_SetStackTraceCallBack equ 84h
DS_RemoveSegs           equ 85h	
DS_DefineDebugSegs      equ 86h	
DS_SetBaudRate          equ 87h
DS_SetComPort           equ 88h	
DS_ChangeTaskNum        equ 89h	
DS_ExitCleanup          equ 8ah	
DS_InstallVGAHandler    equ 8bh
DS_GetComBase	        equ	8ch
DS_GetSymbol            equ 8dh	
DS_CopyMem              equ 8eh	
DS_JumpTableEnd         equ 8eh

SaveRegs_Struc	struc
	Debug_EAX		dd	?
	Debug_EBX		dd	?
	Debug_ECX		dd	?
	Debug_EDX		dd	?
	Debug_ESP		dd	?
	Debug_EBP		dd	?
	Debug_ESI		dd	?
	Debug_EDI		dd	?
	Debug_ES		dw	?
	Debug_SS		dw	?
	Debug_DS		dw	?
	Debug_FS		dw	?
	Debug_GS		dw	?
	Debug_EIP		dd	?
	Debug_CS		dw	?
				dd	?
	Debug_EFlags		dd	?
	Debug_CR0		dd	?
	Debug_GDT		dq	?
	Debug_IDT		dq	?
	Debug_LDT		dw	?
	Debug_TR		dw	?
	Debug_CR2		dd	?
	Debug_CR3		dd	?
	Debug_DR0		dd	?
	Debug_DR1		dd	?
	Debug_DR2		dd	?
	Debug_DR3		dd	?
	Debug_DR6		dd	?
	Debug_DR7		dd	?
	Debug_DR7_2		dd	?
	Debug_TR6		dd	?
	Debug_TR7		dd	?
	Debug_TrapNumber	dw	-1	; -1 means no trap number
	Debug_ErrorCode		dw	0	; 0 means no error code
SaveRegs_Struc ends

DebInfoBuf	struc
	DIB_MajorVersion	db	0
	DIB_MinorVersion	db	0
	DIB_Revision		db	0
				db	0	; reserved
	DIB_DebugTrap16		dd	0	; send 16 bit trap to debugger
	DIB_DebugTrap32		df	0	; send 32 bit trap to debugger
	DIB_DebugBreak16	dd	0	; 16 bit break in debugger
	DIB_DebugBreak32	df	0	; 32 bit break in debugger
	DIB_DebugCtrlC16	dd	0	; 16 bit check for ctrl C
	DIB_DebugCtrlC32	df	0	; 32 bit check for ctrl C
DebInfoBuf	ends

BreakStruc	struc
	BS_BreakEIP		dd	0	; CS:EIP, SS:ESP to go to
	BS_BreakCS		dw	0	;  on a error or ctrlc break
	BS_BreakESP		dd	0
	BS_BreakSS		dw	0
BreakStruc	ends

RedirectExecStruc	struc
	RDE_fpbufDebugCommand	df	0	; debugger command script
	RDE_cbDebugCommand	dw	0	; debugger command script len
	RDE_fpszInput		df	0	; input stream pointer
	RDE_usFlags		dw	0	; reserved (must be 0)
	RDE_cbOutput		dd	0	; size of output buffer
	RDE_fpbufOutput		df	0	; output buffer pointer
RedirectExecStruc	ends

REPEAT_FOREVER_CHAR	equ	0feh		; send next character until
						;  end of debugger command

AddrS	struc					; for printf service
	AddrOff		dd	0
	AddrSeg		dw	0
	AddrType	db	0
	AddrSize	db	0
	AddrTask	dw	0
AddrS	ends

AddrTypeSize	equ	word ptr AddrType

EXPR_TYPE_SEG		equ	00000001b	; address type segment:offset
EXPR_TYPE_SEL		equ	00001001b	; address type selector:offset
EXPR_TYPE_LIN		equ	00000010b	; address type linear
EXPR_TYPE_PHY		equ	00001010b	; address type physical
EXPR_TYPE_LOG		equ	00001000b	; logical address (no sel yet)

DEBUG_FAULT_TYPE_V86		equ	00000001b
DEBUG_FAULT_TYPE_PM		equ	00000010b
DEBUG_FAULT_TYPE_RING0		equ	00000100b
DEBUG_FAULT_TYPE_FIRST		equ	00001000b
DEBUG_FAULT_TYPE_LAST		equ	00010000b

;
;   Interrupt and services that Win386 provides to the debugger
;

Win386_Query_Int      equ 22h	; interrupt for Win386 protected mode

Win386_Alive	      equ 0	; function 0, query Win386 installation
Win386_Q_Ack	      equ 0F386h	;	good response from func 43h, of
Win386_Query	      equ 1	; function 1, query Win386 state
Win386_PhysToLinr     equ 2	; function 2, have Win386 convert a
Win386_AddrValid      equ 3	; function 3, have Win386 check the
Win386_MapVM	      equ 4	; function 4, make sure that the VM's
Win386_UnmapVM	      equ 5	; function 5, map out the VM's low
Win386_GetDLAddr      equ 6	; function 6, return offset of dyna-link
Win386_GetVXDName     equ 7 ; function 7, determines whether an address
Win386_GetPDE         equ 8 ; function 8, get pde for a context
Win386_GetFrame       equ 9 ; function 9, get phys addr for not pres ptes
Win386_GetLDTAddress  equ 10    ; function 10,
Win386_GetThreadID    equ 11    ; function 11, AX = Current Thread ID
Win386_GetTSHandler   equ 12	; function 12, return offset of transfer-space
Win386_GetArplHandler equ 13	; function 12, return offset of ARPL fault
Max_Win386_Services   equ 13
