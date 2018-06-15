
VDM_V86	equ 0
VDM_PM	equ 1

ifdef __POASM__
 @Vdd macro name_, parms
 externdef stdcall _imp__ # name_ # @ # parms :pfunc@ # parms
 name_ textequ _imp__ # name_ # @ # parms
 endm
else
 @Vdd macro name_, parms
 externdef stdcall _imp__&name_&@&parms :pfunc@&parms
 name_ equ <_imp__&name_&@&parms>
 endm
endif 

 @Vdd VdmMapFlat ,12
 @Vdd getEAX, 0
 @Vdd getAX, 0 
 @Vdd getAL, 0 
 @Vdd getAH , 0 
 @Vdd getEBX , 0
 @Vdd getBX , 0 
 @Vdd getBL , 0 
 @Vdd getBH , 0 
 @Vdd getECX , 0
 @Vdd getCX , 0 
 @Vdd getCL , 0 
 @Vdd getCH , 0 
 @Vdd getEDX , 0
 @Vdd getDX , 0 
 @Vdd getDL , 0 
 @Vdd getDH , 0 
 @Vdd getESP , 0
 @Vdd getSP , 0 
 @Vdd getEBP , 0
 @Vdd getBP , 0 
 @Vdd getESI , 0
 @Vdd getSI , 0 
 @Vdd getEDI , 0
 @Vdd getDI , 0 
 @Vdd getEIP , 0
 @Vdd getIP , 0 
 @Vdd getCS , 0 
 @Vdd getSS , 0 
 @Vdd getDS , 0 
 @Vdd getES , 0 
 @Vdd getFS , 0 
 @Vdd getGS , 0 
 @Vdd getCF , 0 
 @Vdd getPF , 0 
 @Vdd getAF , 0 
 @Vdd getZF , 0 
 @Vdd getSF , 0 
 @Vdd getIF , 0 
 @Vdd getDF , 0 
 @Vdd getOF , 0 
 @Vdd getMSW , 0
 @Vdd setEAX, 4
 @Vdd setAX, 4 
 @Vdd setAH, 4 
 @Vdd setAL, 4 
 @Vdd setEBX, 4
 @Vdd setBX, 4 
 @Vdd setBH, 4 
 @Vdd setBL, 4 
 @Vdd setECX, 4
 @Vdd setCX, 4 
 @Vdd setCH, 4 
 @Vdd setCL, 4 
 @Vdd setEDX, 4
 @Vdd setDX, 4 
 @Vdd setDH, 4 
 @Vdd setDL, 4 
 @Vdd setESP, 4
 @Vdd setSP, 4 
 @Vdd setEBP, 4
 @Vdd setBP, 4 
 @Vdd setESI, 4
 @Vdd setSI, 4 
 @Vdd setEDI, 4
 @Vdd setDI, 4 
 @Vdd setEIP, 4
 @Vdd setIP, 4 
 @Vdd setCS, 4 
 @Vdd setSS, 4 
 @Vdd setDS, 4 
 @Vdd setES, 4 
 @Vdd setFS, 4 
 @Vdd setGS, 4 
 @Vdd setCF, 4 
 @Vdd setPF, 4 
 @Vdd setAF, 4 
 @Vdd setZF, 4 
 @Vdd setSF, 4 
 @Vdd setIF, 4 
 @Vdd setDF, 4 
 @Vdd setOF, 4 
 @Vdd setMSW, 4

