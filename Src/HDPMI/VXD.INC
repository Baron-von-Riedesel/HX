
;--- for "enhanced" variants only

?SUPI2F16840001	equ 1	;std=1, support int 2f,ax=1684,bx=1 (vmm)
?SUPI2F16840009	equ 1	;std=1, support int 2f,ax=1684,bx=9 (reboot)
?SUPI2F16840017	equ 1	;std=1, support int 2f,ax=1684,bx=17 (shell)
?SUPI2F16840021	equ 1	;std=1, support int 2f,ax=1684,bx=21 (pagefile)
?SUPI2F1684002A	equ 0	;std=0, support int 2f,ax=1684,bx=2A (vwin32)
?SUPI2F16840442	equ 1	;std=1, support int 2f,ax=1684,bx=442 (vtdapi)

externdef _I2F1684_0001_:abs
externdef _I2F1684_0009_:abs
externdef _I2F1684_0017_:abs
externdef _I2F1684_0021_:abs
externdef _I2F1684_002A_:abs
externdef _I2F1684_0442_:abs

ifdef ?DEFINEVXDBP
if ?SUPI2F16840001
	@defx _vxd_0001, _I2F1684_0001_
endif
if ?SUPI2F16840009
	@defx _vxd_0009, _I2F1684_0009_
endif
if ?SUPI2F16840017
	@defx _vxd_0017, _I2F1684_0017_
endif
if ?SUPI2F16840021
	@defx _vxd_0021, _I2F1684_0021_
endif
if ?SUPI2F1684002A
	@defx _vxd_002A, _I2F1684_002A_
endif
if ?SUPI2F16840442
	@defx _vxd_0442, _I2F1684_0442_
endif
endif
