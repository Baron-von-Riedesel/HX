
# nmake makefile which creates 
# - DPMILD32.EXE: stand-alone DPMI loader
# - DPMILD32.BIN: stub which includes the DPMI loader
# - HDLD32.BIN:   stub which includes the DPMI loader and HDPMI
# tools used:
# - Assembler: JWasm
# - Linker:    JWlink

!ifndef DEBUG
DEBUG = 0
!endif

!if $(DEBUG)
ODIR1 = STD32D
ODIR2 = STUB32D
ODIR3 = NOLFN32D
ODIR4 = STUBX32D
!else
ODIR1 = STD32
ODIR2 = STUB32
ODIR3 = NOLFN32
ODIR4 = STUBX32
!endif

!include <..\dirs>

NAME  = DPMILD32

AOPT = -c -nologo -Sg -Fl$* -Fo$* -D?32BIT=1 -D?DEBUG=$(DEBUG) -I..\..\Include

MODS1 = $(ODIR1)\dpmildr.obj $(ODIR1)\kernel16.obj  $(ODIR1)\peload.obj
MODS2 = $(ODIR2)\dpmildr.obj                        $(ODIR2)\peload.obj
MODS3 = $(ODIR3)\dpmildr.obj $(ODIR3)\kernel16.obj  $(ODIR3)\peload.obj
MODS4 = $(ODIR4)\dpmildr.obj                        $(ODIR4)\peload.obj
INCTR =

!IF $(DEBUG)
MODS1 = $(MODS1) $(ODIR1)\trace.obj
MODS2 = $(MODS2) $(ODIR2)\trace.obj
MODS3 = $(MODS3) $(ODIR3)\trace.obj
MODS4 = $(MODS4) $(ODIR4)\trace.obj
INCTR = trace.inc
!ENDIF

ALL: $(ODIR1) $(ODIR2) $(ODIR3) $(ODIR4) $(ODIR1)\$(NAME).EXE $(ODIR2)\$(NAME).BIN $(ODIR3)\$(NAME).EXE $(ODIR4)\HDLD32.BIN

$(ODIR1):
	@mkdir $(ODIR1)

$(ODIR2):
	@mkdir $(ODIR2)

$(ODIR3):
	@mkdir $(ODIR3)

$(ODIR4):
	@mkdir $(ODIR4)

# create $(ODIR1)\DPMILD32.EXE

$(ODIR1)\$(NAME).EXE: $(MODS1) $(NAME).mak
	@$(LINK16BIN) format dos file {$(MODS1)} name $*.EXE op q, map=$*.MAP

$(ODIR1)\dpmildr.OBJ: dpmildr.asm dpmildr.inc peload.inc kernel16.inc version.inc $(INCTR)
	@$(ASM) $(AOPT) dpmildr.asm

$(ODIR1)\kernel16.OBJ: kernel16.asm dpmildr.inc peload.inc kernel16.inc version.inc $(INCTR)
	@$(ASM) $(AOPT) kernel16.asm

$(ODIR1)\peload.OBJ: peload.asm dpmildr.inc peload.inc mzhdr32.inc $(INCTR)
	@$(ASM) $(AOPT) peload.asm

$(ODIR1)\trace.OBJ: trace.asm dpmildr.inc trace.inc
	@$(ASM) $(AOPT) trace.asm

# create $(ODIR2)\DPMILD32.BIN

$(ODIR2)\$(NAME).BIN: $(MODS2) $(NAME).mak
	@$(LINK16BIN) format dos file {$(MODS2)} name $*.BIN op q, knoweas, map=$*.MAP

$(ODIR2)\dpmildr.obj: dpmildr.asm dpmildr.inc peload.inc version.inc $(INCTR)
	@$(ASM) $(AOPT) -D?STUB=1 -D?KERNEL16=0 -D?LOADDBGDLL=0 dpmildr.asm

$(ODIR2)\peload.obj: peload.asm dpmildr.inc peload.inc mzhdr32.inc $(INCTR)
	@$(ASM) $(AOPT) -D?STUB=1 -D?KERNEL16=0 peload.asm

$(ODIR2)\trace.OBJ: trace.asm dpmildr.inc trace.inc
	@$(ASM) $(AOPT) trace.asm

# create $(ODIR3)\DPMILD32.EXE

$(ODIR3)\$(NAME).EXE: $(MODS3) $(NAME).mak
	@$(LINK16BIN) format dos file {$(MODS3)} name $*.EXE op q, map=$*.MAP

$(ODIR3)\dpmildr.obj: dpmildr.asm dpmildr.inc peload.inc kernel16.inc version.inc $(INCTR)
	@$(ASM) $(AOPT) -D?LFN=0 dpmildr.asm

$(ODIR3)\kernel16.OBJ: kernel16.asm dpmildr.inc peload.inc kernel16.inc version.inc $(INCTR)
	@$(ASM) $(AOPT) -D?LFN=0 kernel16.asm

$(ODIR3)\peload.obj: peload.asm dpmildr.inc peload.inc mzhdr32.inc $(INCTR)
	@$(ASM) $(AOPT) -D?LFN=0 peload.asm

$(ODIR3)\trace.OBJ: trace.asm dpmildr.inc trace.inc
	@$(ASM) $(AOPT) trace.asm

# create $(ODIR4)\HDLD32.BIN

$(ODIR4)\HDLD32.BIN: $(MODS4) $(NAME).mak
	@$(LINK16BIN) format dos file {$(MODS4)} name $*.BIN op q, map=$*.MAP, knoweas 

$(ODIR4)\dpmildr.obj: dpmildr.asm dpmildr.inc peload.inc version.inc ..\HDPMI\STUB32\HDPMI32.INC $(INCTR)
	@$(ASM) $(AOPT) -D?STUB=1 -D?KERNEL16=0 -D?LOADDBGDLL=0 -D?SERVER=0 -D?HDPMI=1 -D?NEAPPS=0 -I..\HDPMI\STUB32 dpmildr.asm

$(ODIR4)\peload.obj: peload.asm dpmildr.inc peload.inc mzhdr32.inc $(INCTR)
	@$(ASM) $(AOPT) -D?STUB=1 -D?KERNEL16=0 peload.asm

$(ODIR4)\trace.OBJ: trace.asm dpmildr.inc trace.inc
	@$(ASM) $(AOPT) trace.asm

clean:
	@del $(ODIR1)\*.exe
	@del $(ODIR1)\*.obj
	@del $(ODIR1)\*.lst
	@del $(ODIR1)\*.map
	@del $(ODIR2)\*.bin
	@del $(ODIR2)\*.obj
	@del $(ODIR2)\*.lst
	@del $(ODIR2)\*.map
	@del $(ODIR3)\*.exe
	@del $(ODIR3)\*.obj
	@del $(ODIR3)\*.lst
	@del $(ODIR3)\*.map
	@del $(ODIR4)\*.bin
	@del $(ODIR4)\*.obj
	@del $(ODIR4)\*.lst
	@del $(ODIR4)\*.map

