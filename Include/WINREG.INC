
ifndef _WINREG_
_WINREG_	EQU	<>

ifndef ACCESS_MASK
ACCESS_MASK typedef dword
endif

ifndef LPSECURITY_ATTRIBUTES
LPSECURITY_ATTRIBUTES typedef ptr
endif

REGSAM typedef ACCESS_MASK

ifndef HKEY
HKEY typedef ptr
endif

PHKEY typedef ptr HKEY

ifndef LPSTR
LPSTR typedef ptr BYTE
endif
ifndef BOOL
BOOL typedef sdword
endif
ifndef LPDWORD
LPDWORD typedef ptr DWORD
endif
ifndef PLONG
PLONG typedef ptr SDWORD
endif
ifndef LPBYTE
LPBYTE typedef ptr BYTE
endif
ifndef PFILETIME
PFILETIME typedef ptr FILETIME
endif

HKEY_CLASSES_ROOT	EQU	( 80000000h )
HKEY_CURRENT_USER	EQU	( 80000001h )
HKEY_LOCAL_MACHINE	EQU	( 80000002h )
HKEY_USERS			EQU	( 80000003h )
HKEY_PERFORMANCE_DATA	EQU	( 80000004h )
HKEY_CURRENT_CONFIG	EQU	( 80000005h )
HKEY_DYN_DATA		EQU	( 80000006h )

ifdef _ADVAPI32_
WINADVAPI equ <>
else
WINADVAPI equ <__declspec ( dllimport )>
endif

@DefProto macro apiqual:REQ, name:REQ, type_, namesuffix, parms, suffix
;;echo	defproto: apiqual
%ifidn <apiqual>,<__declspec ( dllimport )>
  proto_&name typedef proto type_  parms
  ifnb <suffix>
    externdef stdcall _imp__&name&@&suffix: ptr proto_&name
    name&namesuffix equ <_imp__&name&@&suffix>
  else
    externdef c _imp__&name: ptr proto_&name
    name&namesuffix equ <_imp__&name>
  endif
else
  name&namesuffix proto type_ parms
endif
		endm

@DefProto WINADVAPI, RegCloseKey, stdcall, , <:HKEY>, 4
@DefProto WINADVAPI, RegOverridePredefKey, stdcall, , <:HKEY, :HKEY>, 8
@DefProto WINADVAPI, RegConnectRegistryA, stdcall, , <:LPSTR, :HKEY, :PHKEY>, 12
@DefProto WINADVAPI, RegCreateKeyA, stdcall, , <:HKEY, :LPSTR, :PHKEY>, 12
@DefProto WINADVAPI, RegCreateKeyExA, stdcall, , <:HKEY, :LPSTR, :DWORD, :LPSTR, :DWORD, :REGSAM, :LPSECURITY_ATTRIBUTES, :PHKEY, :LPDWORD>, 36
@DefProto WINADVAPI, RegDeleteKeyA, stdcall, , <:HKEY, :LPSTR>, 8
@DefProto WINADVAPI, RegDeleteValueA, stdcall, , <:HKEY, :LPSTR>, 8
@DefProto WINADVAPI, RegEnumKeyA, stdcall, , <:HKEY, :DWORD, :LPSTR, :DWORD>, 16
@DefProto WINADVAPI, RegEnumKeyExA, stdcall, , <:HKEY, :DWORD, :LPSTR, :LPDWORD, :LPDWORD, :LPSTR, :LPDWORD, :PFILETIME>, 32
@DefProto WINADVAPI, RegEnumValueA, stdcall, , <:HKEY, :DWORD, :LPSTR, :LPDWORD, :LPDWORD, :LPDWORD, :LPBYTE, :LPDWORD>, 32
@DefProto WINADVAPI, RegFlushKey, stdcall, , <:HKEY>, 4
;@DefProto WINADVAPI, RegGetKeySecurity, stdcall, , <:HKEY, :SECURITY_INFORMATION, :PSECURITY_DESCRIPTOR, :LPDWORD>, 16
@DefProto WINADVAPI, RegLoadKeyA, stdcall, , <:HKEY, :LPSTR, :LPSTR>, 12
@DefProto WINADVAPI, RegNotifyChangeKeyValue, stdcall, , <:HKEY, :BOOL, :DWORD, :HANDLE, :BOOL>, 20
@DefProto WINADVAPI, RegOpenKeyA, stdcall, , <:HKEY, :LPSTR, :PHKEY>, 12
@DefProto WINADVAPI, RegOpenKeyExA, stdcall, , <:HKEY, :LPSTR, :DWORD, :REGSAM, :PHKEY>, 20
@DefProto WINADVAPI, RegQueryInfoKeyA, stdcall, , <:HKEY, :LPSTR, :LPDWORD, :LPDWORD, :LPDWORD, :LPDWORD, :LPDWORD, :LPDWORD, :LPDWORD, :LPDWORD, :LPDWORD, :PFILETIME>, 48
@DefProto WINADVAPI, RegQueryValueA, stdcall, , <:HKEY, :LPSTR, :LPSTR, :PLONG>, 16
;@DefProto WINADVAPI, RegQueryMultipleValuesA, stdcall, , <:HKEY, :PVALENTA, :DWORD, :LPSTR, :LPDWORD>, 20
@DefProto WINADVAPI, RegQueryValueExA, stdcall, , <:HKEY, :LPSTR, :LPDWORD, :LPDWORD, :LPBYTE, :LPDWORD>, 24
@DefProto WINADVAPI, RegReplaceKeyA, stdcall, , <:HKEY, :LPSTR, :LPSTR, :LPSTR>, 16
@DefProto WINADVAPI, RegRestoreKeyA, stdcall, , <:HKEY, :LPSTR, :DWORD>, 12
@DefProto WINADVAPI, RegSaveKeyA, stdcall, , <:HKEY, :LPSTR, :LPSECURITY_ATTRIBUTES>, 12
;@DefProto WINADVAPI, RegSetKeySecurity, stdcall, , <:HKEY, :SECURITY_INFORMATION, :PSECURITY_DESCRIPTOR>, 12
@DefProto WINADVAPI, RegSetValueA, stdcall, , <:HKEY, :LPSTR, :DWORD, :LPSTR, :DWORD>, 20
@DefProto WINADVAPI, RegSetValueExA, stdcall, , <:HKEY, :LPSTR, :DWORD, :DWORD, :ptr BYTE, :DWORD>, 24
@DefProto WINADVAPI, RegUnLoadKeyA, stdcall, , <:HKEY, :LPSTR>, 8
@DefProto WINADVAPI, InitiateSystemShutdownA, stdcall, , <:LPSTR, :LPSTR, :DWORD, :BOOL, :BOOL>, 20
@DefProto WINADVAPI, AbortSystemShutdownA, stdcall, , <:LPSTR>, 4

RegConnectRegistry	EQU	<RegConnectRegistryA>
RegCreateKey	EQU	<RegCreateKeyA>
RegCreateKeyEx	EQU	<RegCreateKeyExA>
RegDeleteKey	EQU	<RegDeleteKeyA>
RegDeleteValue	EQU	<RegDeleteValueA>
RegEnumKey		EQU	<RegEnumKeyA>
RegEnumKeyEx	EQU	<RegEnumKeyExA>
RegEnumValue	EQU	<RegEnumValueA>
RegLoadKey		EQU	<RegLoadKeyA>
RegOpenKey		EQU	<RegOpenKeyA>
RegOpenKeyEx	EQU	<RegOpenKeyExA>
RegQueryInfoKey	EQU	<RegQueryInfoKeyA>
RegQueryValue	EQU	<RegQueryValueA>
RegQueryMultipleValues	EQU	<RegQueryMultipleValuesA>
RegQueryValueEx	EQU	<RegQueryValueExA>
RegReplaceKey	EQU	<RegReplaceKeyA>
RegRestoreKey	EQU	<RegRestoreKeyA>
RegSaveKey		EQU	<RegSaveKeyA>
RegSetValue		EQU	<RegSetValueA>
RegSetValueEx	EQU	<RegSetValueExA>
RegUnLoadKey	EQU	<RegUnLoadKeyA>
InitiateSystemShutdown	EQU	<InitiateSystemShutdownA>
AbortSystemShutdown		EQU	<AbortSystemShutdownA>

endif
