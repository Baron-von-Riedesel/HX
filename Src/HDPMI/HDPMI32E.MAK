
# nmake makefile, creates an "enhanced" HDPMI32.EXE version
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

NAME  = HDPMI32

SRCMODS = \
!include modules.inc
OBJNAMES = $(SRCMODS:.ASM=.OBJ)
!if $(DEBUG)
OBJMODS = $(OBJNAMES:.\=ENH32D\)
!else
OBJMODS = $(OBJNAMES:.\=ENH32\)
!endif

LINK  = jwlink.exe

AOPT= -nologo -c -Cp -Sg -D?32BIT=1 -D?ENHANCED=1 $(AOPTD) -I$(INC32DIR) -Fl$* -Fo$*
LCMDS = format DOS file $(OUTD)\$(SRC).obj name $*.EXE lib $(OUTD)\$(NAME).lib op q, map=$*.MAP, stack=0

SRC   = hdpmi

DEPS0 = hdpmi.inc external.inc version.inc $(NAME)e.mak

!if $(DEBUG)
OUTD=ENH32D
!else
OUTD=ENH32
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
