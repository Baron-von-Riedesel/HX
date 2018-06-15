
;--- base definitions for COM

CLSCTX typedef DWORD
CLSCTX_INPROC_SERVER = 1h 
CLSCTX_INPROC_HANDLER = 2h 
CLSCTX_LOCAL_SERVER = 4h 
CLSCTX_INPROC_SERVER16 = 8h 
CLSCTX_REMOTE_SERVER = 10h 
CLSCTX_INPROC_HANDLER16 = 20h 
CLSCTX_INPROC_SERVERX86 = 40h 
CLSCTX_INPROC_HANDLERX86 = 80h 
CLSCTX_ESERVER_HANDLER = 100h 

COINIT_APARTMENTTHREADED	equ 02h
COINIT_MULTITHREADED		equ 00h
COINIT_DISABLE_OLE1DDE		equ 04h
COINIT_SPEED_OVER_MEMORY	equ 08h

ifndef GUID
GUID	STRUCT
    Data1 	dd ?
    Data2 	dw ?
    Data3 	dw ?
    Data4 	db 8 dup(?)
GUID ENDS
endif


REFGUID typedef ptr GUID

DEFINE_GUID macro name,l,w1,w2,b1,b2,b3,b4,b5,b6,b7,b8
;	exitm <name GUID { l , w1 , w2 , { b1 , b2 , b3 , b4 , b5 , b6 , b7 , b8 } } >
	exitm <externdef name:GUID>
	endm

externdef GUID_NULL:GUID

protoQueryInterface typedef proto stdcall :ptr,:ptr,:ptr ptr 
protoAddRef			typedef proto stdcall :ptr
protoRelease		typedef proto stdcall :ptr

lpQueryInterface 	typedef ptr protoQueryInterface
lpAddRef			typedef ptr protoAddRef
lpRelease			typedef ptr protoRelease

IUnknownVtbl struct
QueryInterface lpQueryInterface ?
AddRef         lpAddRef ?
Release        lpRelease ?
IUnknownVtbl ends

LPUNKNOWNVTBL	typedef ptr IUnknownVtbl

IUnknown struct
lpVtbl	LPUNKNOWNVTBL ?
IUnknown ends

LPUNKNOWN typedef ptr IUnknown

protoIClassFactory@CreateInstance	typedef proto stdcall :ptr, :DWORD, :ptr GUID, :ptr
protoIClassFactory@LockServer		typedef proto stdcall :ptr, :dword

lpIClassFactory@CreateInstance 	typedef ptr protoIClassFactory@CreateInstance
lpIClassFactory@LockServer		typedef ptr protoIClassFactory@LockServer

IClassFactoryVtbl struct
		IUnknownVtbl <>
CreateInstance	lpIClassFactory@CreateInstance ?
LockServer		lpIClassFactory@LockServer ?
IClassFactoryVtbl ends

LPCLASSFACTORYVTBL	typedef ptr IClassFactoryVtbl

IClassFactory struct
lpVtbl	LPCLASSFACTORYVTBL ?
IClassFactory ends

ifndef HRESULT
HRESULT			typedef DWORD
endif

ifndef FACILITY_CONTROL
FACILITY_CONTROL equ 0ah
endif

;;-------------------------------------------------------------------
;;--- macros inside:
;;--- MAKE_HRESULT()		: assembles a HRESULT
;;-------------------------------------------------------------------

MAKE_HRESULT	macro sev,fac,code
	exitm <sev * 80000000h + fac * 10000h + code>
	endm

CLSCTX_INPROC	EQU	( CLSCTX_INPROC_SERVER  or  CLSCTX_INPROC_HANDLER )
CLSCTX_ALL	EQU	( CLSCTX_INPROC_SERVER  or  CLSCTX_INPROC_HANDLER  or  CLSCTX_LOCAL_SERVER  or  CLSCTX_REMOTE_SERVER )
CLSCTX_SERVER	EQU	( CLSCTX_INPROC_SERVER  or  CLSCTX_LOCAL_SERVER  or  CLSCTX_REMOTE_SERVER )

REGCLS typedef DWORD
REGCLS_SINGLEUSE = 0 
REGCLS_MULTIPLEUSE = 1 
REGCLS_MULTI_SEPARATE = 2 
REGCLS_SUSPENDED = 4 
REGCLS_SURROGATE = 8 

MARSHALINTERFACE_MIN	EQU	500
CWCSTORAGENAME	EQU	32

STGM_DIRECT				EQU	00000000h
STGM_TRANSACTED			EQU	00010000h
STGM_SIMPLE				EQU	08000000h
STGM_READ				EQU	00000000h
STGM_WRITE				EQU	00000001h
STGM_READWRITE			EQU	00000002h
STGM_SHARE_DENY_NONE	EQU	00000040h
STGM_SHARE_DENY_READ	EQU	00000030h
STGM_SHARE_DENY_WRITE	EQU	00000020h
STGM_SHARE_EXCLUSIVE	EQU	00000010h
STGM_PRIORITY			EQU	00040000h
STGM_DELETEONRELEASE	EQU	04000000h
STGM_NOSCRATCH			EQU	00100000h
STGM_CREATE				EQU	00001000h
STGM_CONVERT			EQU	00020000h
STGM_FAILIFTHERE		EQU	00000000h
STGM_NOSNAPSHOT			EQU	00200000h

ASYNC_MODE_COMPATIBILITY	EQU	00000001h
ASYNC_MODE_DEFAULT			EQU	00000000h

STGTY_REPEAT			EQU	00000100h
STG_TOEND				EQU	0FFFFFFFFh
STG_LAYOUT_SEQUENTIAL	EQU	00000000h
STG_LAYOUT_INTERLEAVED	EQU	00000001h

STGFMT_STORAGE	EQU	0
STGFMT_NATIVE	EQU	1
STGFMT_FILE		EQU	3
STGFMT_ANY		EQU	4
STGFMT_DOCFILE	EQU	5
STGFMT_DOCUMENT	EQU	0

IsEqualGUID 	proto stdcall :REFGUID, :REFGUID
StringFromGUID2 proto stdcall :REFGUID, :ptr WORD, :DWORD

