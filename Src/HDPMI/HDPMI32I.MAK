
# nmake makefile, creates a version of HDPMI32.EXE where clients run with IOPL=0.
# tools used:
#  - JWasm | Masm
#  - JWLib | WLib (Open Watcom) | MS OMF LIB (lib16.exe)
#  - JWLink v1.8x
#  - SetMZHdr.exe, modifies exe so:
#      - dos will load the 16-bit part only
#      - stack size will be 200h

!include <..\dirs>

!ifndef DEBUG
DEBUG = 0
!endif

!if $(DEBUG)
AOPTD=-Zi -D_DEBUG
LOPTD=
!endif

SRCMODS = \
!include modules.inc
OBJNAMES = $(SRCMODS:.ASM=.OBJ)
!if $(DEBUG)
OBJMODS = $(OBJNAMES:.\=IOPL032D\)
!else
OBJMODS = $(OBJNAMES:.\=IOPL032\)
!endif

LINK = jwlink.exe
LOPT = format DOS

LCMDS = $(LOPT) file $(OUTIOPL0)\$(SRC).obj name $*.EXE lib $(OUTIOPL0)\$(NAME).lib op q, map=$*.MAP, stack=0 

AOPT= -nologo -c -Cp -Sg -D?32BIT=1 -D?PMIOPL=0 $(AOPTD) -I$(INC32DIR) -Fl$* -Fo$*

NAME  = HDPMI32
SRC   = hdpmi

DEPS0 = hdpmi.inc external.inc version.inc

!if $(DEBUG)
OUTIOPL0=IOPL032D
!else
OUTIOPL0=IOPL032
!endif

.SUFFIXES: .asm .obj

.asm{$(OUTIOPL0)}.obj:
	@$(ASM) $(AOPT) $<

ALL: $(OUTIOPL0) $(OUTIOPL0)\$(NAME)i.EXE

$(OBJMODS): $(DEPS0)

$(OUTIOPL0):
	@mkdir $(OUTIOPL0)

$(OUTIOPL0)\$(NAME)i.EXE: $(OUTIOPL0)\$(SRC).obj $(OUTIOPL0)\$(NAME).lib
	$(LINK) @<<
$(LCMDS)
<<
	@SetMZHdr.exe -q $*.EXE

$(OUTIOPL0)\$(NAME).lib: $(OBJMODS) $(NAME)i.mak
	@cd $(OUTIOPL0)
	@$(LIB16BIN) $(NAME).lib $(OBJNAMES:.\=+)
	@jwlib -q -b $(NAME).lib -$(SRC).OBJ
	@cd ..

clean:
	@del $(OUTIOPL0)\*.obj
	@del $(OUTIOPL0)\*.lib
	@del $(OUTIOPL0)\*.exe
	@del $(OUTIOPL0)\*.lst
	@del $(OUTIOPL0)\*.map
