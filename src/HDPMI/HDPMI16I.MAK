
# nmake makefile, creates HDPMI16.EXE that runs in IOPL0.
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
LOPTD=
!endif

SRCMODS = \
!include modules.inc
OBJNAMES = $(SRCMODS:.ASM=.OBJ)
!if $(DEBUG)
OBJMODS = $(OBJNAMES:.\=IOPL016D\)
!else
OBJMODS = $(OBJNAMES:.\=IOPL016\)
!endif

LINK  = jwlink.exe
LOPT  = format DOS

LCMDS1=$(LOPT) file $(OUTIOPL0)\$(SRC).obj name $*.EXE lib $(OUTIOPL0)\$(NAME).lib op q, map=$*.MAP, stack=0 
AOPT= -nologo -c -Cp -Sg -D?32BIT=0 -D?PMIOPL=00 $(AOPTD) -I$(INC32DIR) -Fl$* -Fo$*

!if $(MASM)
ASM=@ml.exe
!else
ASM=@jwasm.exe
!endif

NAME  = HDPMI16
SRC   = hdpmi

DEPS0 = hdpmi.inc external.inc version.inc

!if $(DEBUG)
OUTIOPL0=IOPL016D
!else
OUTIOPL0=IOPL016
!endif

.SUFFIXES: .asm .obj

.asm{$(OUTIOPL0)}.obj:
	$(ASM) $(AOPT) $<

ALL: $(OUTIOPL0) $(OUTIOPL0)\$(NAME).EXE

$(OBJMODS): $(DEPS0)

$(OUTIOPL0):
	@mkdir $(OUTIOPL0)

$(OUTIOPL0)\$(NAME).EXE: $(OUTIOPL0)\$(SRC).obj $(OUTIOPL0)\$(NAME).lib
	@$(LINK) @<<
$(LCMDS1)
<<
	@..\..\BIN\SETMZHDR.EXE -q $*.EXE

$(OUTIOPL0)\$(NAME).lib: $(OBJMODS) $(NAME)i.mak
	@cd $(OUTIOPL0)
	@$(LIB16BIN) $(NAME).lib $(OBJNAMES:.\=+)
	@jwlib -q $(NAME).lib -$(SRC).OBJ
	@cd ..

clean:
	@del $(OUTIOPL0)\*.obj
	@del $(OUTIOPL0)\*.exe
	@del $(OUTIOPL0)\*.lst
	@del $(OUTIOPL0)\*.map
