
;--- DMA mode register bits
;--- 0-1: select channel (0-3)
DMA_MODE_CHN00	equ 00b
DMA_MODE_CHN01	equ 01b
DMA_MODE_CHN02  equ 10b
DMA_MODE_CHN03  equ 11b
;--- 2-3: 00 verify, 01 write, 02 read, 11 invalid
DMA_MODE_VERIFY	equ 0000b
DMA_MODE_WRITE	equ 0100b
DMA_MODE_READ	equ 1000b
;--- 4: 0 single-cycle, 1 auto-init
DMA_MODE_SINGLECYCLE	equ 00000b
DMA_MODE_AUTOINIT		equ 10000b
;--- 5: 0 address increment, 1 address decrement
DMA_MODE_INCREMENT	equ 000000b
DMA_MODE_DECREMENT	equ 100000b
;--- 6-7: 00 demand mode, 01 single mode, 10 block mode, 11 cascade mode
DMA_MODE_DEMAND		equ 00000000b
DMA_MODE_SINGLE		equ 01000000b
DMA_MODE_BLOCK 		equ 10000000b
DMA_MODE_CASCADE	equ 11000000b

DMA_MASK_DISABLE_CHN	equ 100b
DMA_MASK_ENABLE_CHN		equ 000b

DMASetVars macro channel
if channel ge 4
DMABase            EQU 0C0h        ;base for 16bit DMA
DMAWidth           EQU 2           ;1 for 8bit, 2 for 16bit 
DMAChnBase         EQU 4
else
DMABase            EQU 00h         ;base for 8bit DMA
DMAWidth           EQU 1           ;1 for 8bit, 2 for 16bit 
DMAChnBase         EQU 0
endif
	endm

DMABaseReg macro channel
	DMASetVars channel
	exitm <DMABase + (channel - DMAChnBase) * (2 * DMAWidth)>
	endm

DMACntReg macro channel
	DMASetVars channel
	exitm <DMABase + (channel - DMAChnBase) * (2 * DMAWidth) + DMAWidth>
	endm

DMAPageReg macro channel
local xx, yy
	DMASetVars channel
xx = channel - DMAChnBase
        if xx eq 0
          yy = 7
        endif
        if xx eq 1
          yy = 3
        endif
        if xx eq 2
          yy = 1
        endif
        if xx eq 3
          yy = 2
        endif
		exitm <80h + DMAChnBase * 2 + yy>
		endm
