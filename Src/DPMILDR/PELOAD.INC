
;*** support for PE-files ***
;*** 32-Bit DPMI clients only ***

_TEXT segment
LoadModule32	proto near stdcall
FreeModule32    proto near stdcall
CheckInt214B	proto near stdcall
UnloadPEModules	proto near stdcall
InitPELoader	proto near stdcall
DeinitPELoader	proto near stdcall
CallProc16		proto near stdcall
checkandreplace proto near
if ?DOS4G
Init4G	proto near stdcall
endif
_TEXT ends

_DATA	segment
externdef	wFlatDS:word
externdef 	dwSysDir:dword
if ?DOS4GMEM
externdef	w4GSel:word
endif
externdef szLF:BYTE
_DATA	ends
