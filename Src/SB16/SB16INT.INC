
?DOSEMUCHECK	equ 0	;account for dosemu's sb16 emulation to be limited
?SBMIDI			equ 1	;support SB Midi


;externdef g_hHeap:DWORD
externdef g_csalias:DWORD
ife ?FLAT
externdef g_flatsel:dword
endif

if ?DOSEMUCHECK
externdef g_bIsDosEmu:BYTE
endif

?SBPRO_WAVE_FORMATS	equ	0133h	;8 bit variations only, (44100 mono only)
?SB16_WAVE_FORMATS	equ 0FFFh	;all 11025, 22050 and 44100 variations


