
# nmake makefile, creates an "enhanced" HDPMI16.EXE version
# with some Win16 enhanced features enabled.
# tools:
# - JWasm | Masm
# - WLib (Open Watcom) | MS OMF lib (lib16.exe)
# - JWLink (modified WLink v1.8)

!include <..\dirs>

!ifndef DEBUG
DEBUG = 0
!endif

!if $(DEBUG)
AOPTD=-Zi -D_DEBUG
LOPTD=/LI
!endif

NAME  = HDPMI16

SRCMODS = \
!include modules.inc
OBJNAMES = $(SRCMODS:.ASM=.OBJ)
!if $(DEBUG)
OBJMODS = $(OBJNAMES:.\=ENH16D\)
!else
OBJMODS = $(OBJNAMES:.\=ENH16\)
!endif

LINK  = jwlink.exe

AOPT= -nologo -c -Cp -Sg -D?32BIT=0 -D?ENHANCED=1 $(AOPTD) -I$(INC32DIR) -Fl$* -Fo$*
LCMDS = format DOS file $(OUTD)\$(SRC).obj name $*.EXE lib $(OUTD)\$(NAME).lib op q, map=$*.MAP, stack=0

SRC   = hdpmi

DEPS0 = hdpmi.inc external.inc version.inc $(NAME)e.mak

!if $(DEBUG)
OUTD=ENH16D
!else
OUTD=ENH16
!endif

.SUFFIXES: .asm .obj

.asm{$(OUTD)}.obj:
	@$(ASM) $(AOPT) $<

ALL: $(OUTD) $(OUTD)\$(NAME).EXE

$(OBJMODS): $(DEPS0)

$(OUTD):
	@mkdir $(OUTD)

$(OUTD)\$(NAME).EXE: $(OUTD)\$(SRC).obj $(OUTD)\$(NAME).lib $(NAME)e.mak
	$(LINK) @<<
$(LCMDS)
<<
	@SetMZHdr.exe -q $*.EXE

$(OUTD)\$(NAME).lib: $(OBJMODS) $(NAME)e.mak
	@cd $(OUTD)
	@$(LIB16BIN) $(NAME).lib $(OBJNAMES:.\=+)
	@cd ..

clean:
	@del $(OUTD)\*.obj
	@del $(OUTD)\*.lib
	@del $(OUTD)\*.exe
	@del $(OUTD)\*.map
	@del $(OUTD)\*.lst
