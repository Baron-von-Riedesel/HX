
# nmake makefile, creates 2 HDPMI16.EXE versions:
# - the (old) "standard" version with host stack in conv. memory
# - the "nolfn" version with LFN API translation support disabled
# tools:
# - JWasm | Masm
# - WLib (Open Watcom) | MS OMF lib (lib16.exe)
# - JWLink (modified WLink v1.8)

!include <..\dirs>

!ifndef DEBUG
DEBUG = 0
!endif

!ifndef MASM
MASM=0
!endif

!if $(DEBUG)
AOPTD=-Zi -D_DEBUG
LOPTD=/LI
!endif

SRCMODS = \
!include modules.inc
OBJNAMES = $(SRCMODS:.ASM=.OBJ)
!if $(DEBUG)
OBJMODS = $(OBJNAMES:.\=HSCM16D\)
!else
OBJMODS = $(OBJNAMES:.\=HSCM16\)
!endif

# if VALX is used, but make sure version is >= 3.7.1.4.
# MS link also works, but then it is recommended to activate the line
# containing SHRMZHDR.EXE to reduce size of binary.
# digital mars linker has problems with segment ordering

!if $(DEBUG)
LINKER = 1
!else
LINKER = 1
!endif

!if $(LINKER)==2
LINK  = link16.exe
LOPT  = /NOLOGO/FAR/MAP:FULL/NOE/NOI/NON/ONERROR:NOEXE $(LOPTD)
!elseif $(LINKER)==3
LINK  = $(DMCDIR)\link.exe
LOPT  = /NOLOGO/FAR/MAP:FULL/NOREO/NOI/NOE/NON/ONERROR:NOEXE $(LOPTD)
!elseif $(LINKER)==4
LINK  = c:\qlink\qlink.exe
LOPT  = /NOLOGO/FAR/MAP:FULL/NOI/NOE/NON/ONERROR:NOEXE $(LOPTD)
!elseif $(LINKER)==5
LINK  = valx.exe
LOPT  = /NCI /32 /MAP /DET:2
!else
LINK  = jwlink.exe
LOPT  = format DOS
!endif

!if $(LINKER)==1
LCMDS1=$(LOPT) file $(OUTD)\$(SRC).obj name $*.EXE lib $(OUTD)\$(NAME).lib op q, map=$*.MAP, stack=0
LCMDS2=$(LOPT) file {$(OUTD)\$(SRC).obj $(OUTNOLFN)\INT21API.obj} name $*.EXE lib $(OUTD)\$(NAME).lib op q, map=$*.MAP, stack=0
!else
LCMDS1=$(LOPT) $(OUTD)\$(SRC).obj, $*.EXE, $*.MAP, $(OUTD)\$(NAME).lib;
LCMDS2=$(LOPT) $(OUTD)\$(SRC).obj $(OUTNOLFN)\INT21API.obj, $*.EXE, $*.MAP, $(OUTD)\$(NAME).lib;
!endif

AOPT= -nologo -c -Cp -Sg -D?32BIT=0 -D?HSINEXTMEM=0 $(AOPTD) -I$(INC32DIR) -Fl$* -Fo$*

!if $(MASM)
ASM=@ml.exe
!else
ASM=@jwasm.exe
!endif

NAME  = HDPMI16
SRC   = hdpmi

DEPS0 = hdpmi.inc external.inc version.inc

!if $(DEBUG)
OUTD=HSCM16D
OUTNOLFN=NOLFN16D
!else
OUTD=HSCM16
OUTNOLFN=NOLFN16
!endif

.SUFFIXES: .asm .obj

.asm{$(OUTD)}.obj:
	$(ASM) $(AOPT) $<

ALL: $(OUTD) $(OUTNOLFN) $(OUTD)\$(NAME).EXE $(OUTNOLFN)\$(NAME).EXE

$(OBJMODS): $(DEPS0)

$(OUTD):
	@mkdir $(OUTD)

$(OUTNOLFN):
	@mkdir $(OUTNOLFN)

# create the old "standard" version

$(OUTD)\$(NAME).EXE: $(OUTD)\$(SRC).obj $(OUTD)\$(NAME).lib $(NAME)a.mak $(OUTNOLFN)\int21api.obj 
	$(LINK) @<<
$(LCMDS1)
<<
!if $(LINKER)==2
	@..\..\BIN\SHRMZHDR.EXE $*.exe
!endif     
	@..\..\BIN\SETMZHDR.EXE -q $*.EXE

$(OUTD)\$(NAME).lib: $(OBJMODS) $(NAME)a.mak
	@cd $(OUTD)
	@$(LIB16BIN) $(NAME).lib $(OBJNAMES:.\=+)
	@cd ..

# create the "no LFN" version

$(OUTNOLFN)\$(NAME).EXE: $(OUTD)\$(SRC).obj $(OUTNOLFN)\INT21API.obj $(OUTD)\$(NAME).lib $(NAME)a.mak
	$(LINK) @<<
$(LCMDS2)
<<
!if $(LINKER)==2
	@..\..\BIN\SHRMZHDR.EXE -d $*.EXE
!endif    
	@..\..\BIN\SETMZHDR.EXE -q $*.EXE

$(OUTNOLFN)\INT21API.obj: INT21API.asm $(DEPS0)
	$(ASM) $(AOPT) -D?LFNSUPPORT=0 INT21API.asm

clean:
	@del $(OUTD)\*.obj
	@del $(OUTD)\*.lib
	@del $(OUTD)\*.exe
	@del $(OUTD)\*.map
	@del $(OUTD)\*.lst
	@del $(OUTNOLFN)\*.exe
	@del $(OUTNOLFN)\*.obj
	@del $(OUTNOLFN)\*.lst
	@del $(OUTNOLFN)\*.map
