
?VESAVDD	equ 0	;use VESAVDD.DLL on NT platforms
?USEPMPROCS	equ 1	;1=allow to use vesa protected mode table

_SetDisplayStartProc proto :dword

if ?USEPMPROCS
_SetPaletteProc proto :dword
endif

MouseSetDisplayStart proto

externdef g_Vesa32Options:VESA32OPTIONS
externdef g_vesainfo:VESAINFO
