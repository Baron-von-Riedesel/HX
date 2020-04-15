
?USEWIN95REGAPI equ 0	;doesnt work!

PF16 typedef far16 ptr
PF32 typedef far32 ptr

if ?USEWIN95REGAPI
externdef	ddVmmEntry:PF32
externdef	bRegistry:BYTE
endif

ConvertWStr proto stdcall
ConvertAStr proto stdcall :DWORD
ConvertAStrN proto stdcall :DWORD, :DWORD, :DWORD
