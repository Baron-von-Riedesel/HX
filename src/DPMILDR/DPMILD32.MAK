
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
OUTDIR = DEBUG32
ODIRST = STUB32D
!else
OUTDIR = REL32
ODIRST = STUB32
!endif

!ifdef SINGLEMAKE
LINK16BIN=jwlink
!else
!include <..\dirs>
!endif

!ifndef MASM
MASM=0
!endif

NAME  = DPMILD32

AOPT = -c -nologo -Sg -Fl$* -Fo$* -D?32BIT=1 -D?DEBUG=$(DEBUG) -I..\..\Include

!if $(MASM)
ASM   = @ml.exe $(AOPT)
!else
ASM   = @jwasm.exe $(AOPT)
!endif

DEPS      = $(OUTDIR)\dpmildr.obj $(OUTDIR)\kernel16.obj  $(OUTDIR)\peload.obj
#DEPSSTUB = $(ODIRST)\dpmildr.obj $(ODIRST)\kernel16.obj  $(ODIRST)\peload.obj
DEPSSTUB  = $(ODIRST)\dpmildr.obj                         $(ODIRST)\peload.obj
DEPSNOLFN = NOLFN32\dpmildr.obj   NOLFN32\kernel16.obj    NOLFN32\peload.obj
DEPSSTUBX = STUBX32\dpmildr.obj

!if $(DEBUG)
ALL: $(OUTDIR) $(ODIRST) $(OUTDIR)\$(NAME).EXE $(ODIRST)\$(NAME).BIN 
!else
ALL: $(OUTDIR) $(ODIRST) NOLFN32 STUBX32 $(OUTDIR)\$(NAME).EXE $(ODIRST)\$(NAME).BIN NOLFN32\$(NAME).EXE STUBX32\HDLD32.BIN
!endif

$(OUTDIR):
	@mkdir $(OUTDIR)

$(ODIRST):
	@mkdir $(ODIRST)

NOLFN32:
	@mkdir NOLFN32

STUBX32:
	@mkdir STUBX32

# create $(OUTDIR)\DPMILD32.EXE

$(OUTDIR)\$(NAME).EXE: $(DEPS) $(NAME).mak
	@$(LINK16BIN) format dos file {$(DEPS)} name $*.EXE op q, map=$*.MAP
!if $(DEBUG)==0
	@copy $*.EXE ..\..\Bin\*.* >NUL
!ifdef TOOLSDIR
	@copy $*.EXE $(TOOLSDIR)\*.* >NUL
!endif
!endif

$(OUTDIR)\dpmildr.OBJ: dpmildr.asm dpmildr.inc peload.inc kernel16.inc version.inc trace.inc
	$(ASM) dpmildr.asm

$(OUTDIR)\kernel16.OBJ: kernel16.asm dpmildr.inc peload.inc kernel16.inc version.inc trace.inc
	$(ASM) kernel16.asm

$(OUTDIR)\peload.OBJ: peload.asm dpmildr.inc peload.inc mzhdr32.inc
	$(ASM) peload.asm

# create NOLFN32\DPMILD32.EXE

NOLFN32\$(NAME).EXE: $(DEPSNOLFN) $(NAME).mak
	@$(LINK16BIN) format dos file {$(DEPSNOLFN)} name $*.EXE op q, map=$*.MAP
!if $(DEBUG)==0
	@copy $*.EXE ..\..\Unsupp\*.* >NUL
!endif

NOLFN32\dpmildr.obj: dpmildr.asm dpmildr.inc peload.inc kernel16.inc version.inc trace.inc
	$(ASM) -D?LFN=0 dpmildr.asm

NOLFN32\kernel16.OBJ: kernel16.asm dpmildr.inc peload.inc kernel16.inc version.inc trace.inc
	$(ASM) -D?LFN=0 kernel16.asm

NOLFN32\peload.obj: peload.asm dpmildr.inc peload.inc mzhdr32.inc
	$(ASM) -D?LFN=0 peload.asm

# create $(ODIRST)\DPMILD32.BIN

$(ODIRST)\$(NAME).BIN: $(DEPSSTUB) $(NAME).mak
	@$(LINK16BIN) format dos file { $(DEPSSTUB) } name $*.BIN op q, knoweas, map=$*.MAP
!if $(DEBUG)==0
	@copy $*.BIN ..\..\Bin\*.* >NUL
!ifdef TOOLSDIR
	@copy $*.BIN $(TOOLSDIR)\*.* >NUL
!endif
!endif

$(ODIRST)\dpmildr.obj: dpmildr.asm dpmildr.inc peload.inc version.inc trace.inc dpmild32.mak
	$(ASM) -D?STUB=1 -D?KERNEL16=0 -D?LOADDBGDLL=0 dpmildr.asm

#$(ODIRST)\kernel16.OBJ: kernel16.asm dpmildr.inc peload.inc kernel16.inc version.inc trace.inc
#	$(ASM) -D?STUB=1 kernel16.asm

$(ODIRST)\peload.obj: peload.asm dpmildr.inc peload.inc mzhdr32.inc dpmild32.mak
	$(ASM) -D?STUB=1 -D?KERNEL16=0 peload.asm

# create STUBX32\HDLD32.BIN

STUBX32\HDLD32.BIN: $(DEPSSTUBX) STUB32\peload.obj $(NAME).mak
	@$(LINK16BIN) format dos file $(DEPSSTUBX), STUB32\peload.obj name $*.BIN op q, map=$*.MAP, knoweas 
!if $(DEBUG)==0
	@copy $*.BIN ..\..\Bin\*.* >NUL
!ifdef TOOLSDIR
	@copy $*.BIN $(TOOLSDIR)\*.* >NUL
!endif
!endif

STUBX32\dpmildr.obj: dpmildr.asm dpmildr.inc peload.inc version.inc trace.inc ..\HDPMI\STUB32\HDPMI32.INC dpmild32.mak
	$(ASM) -D?STUB=1 -D?KERNEL16=0 -D?LOADDBGDLL=0 -D?SERVER=0 -D?HDPMI=1 -D?NEAPPS=0 dpmildr.asm

clean:
	@del $(OUTDIR)\*.exe
	@del $(OUTDIR)\*.obj
	@del $(OUTDIR)\*.lst
	@del $(OUTDIR)\*.map
	@del $(ODIRST)\*.bin
	@del $(ODIRST)\*.obj
	@del $(ODIRST)\*.lst
	@del $(ODIRST)\*.map
	@del NOLFN32\*.exe
	@del NOLFN32\*.obj
	@del NOLFN32\*.lst
	@del NOLFN32\*.map
	@del STUBX32\*.bin
	@del STUBX32\*.obj
	@del STUBX32\*.lst
	@del STUBX32\*.map

