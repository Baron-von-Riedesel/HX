
# nmake makefile, creates a HDPMI32.EXE which has its host stack
# in extended memory. Since v3.18, this is the "standard" version.
# tools used:
#  - JWasm | Masm
#  - JWLib | WLib (Open Watcom) | MS OMF LIB (lib16.exe)
#  - JWLink v1.8x
#  - setmzhdr.exe, modifies exe so:
#      - dos will load the 16-bit part only
#      - stack size will be 200h

!include <..\dirs>

!ifndef DEBUG
DEBUG = 0
!endif

NAME = HDPMI32

SRCMODS = \
!include modules.inc
OBJNAMES = $(SRCMODS:.ASM=.OBJ)

!if $(DEBUG)
OBJMODS = $(OBJNAMES:.\=STD32D\)
AOPTD=-D_DEBUG
#AOPTD=-D_DEBUG -D?DOSOUTPUT=0 -DVIODIROUT=1
OUTD=STD32D
!else
OBJMODS = $(OBJNAMES:.\=STD32\)
OUTD=STD32
!endif

!ifdef MASM
ASM = ml.exe
!else
ASM = jwasm.exe
!endif
LINK  = jwlink.exe

AOPT   = -nologo -c -Cp -Sg -D?32BIT=1 $(AOPTD) -I$(INC32DIR) -Fl$* -Fo$*
LCMDS3 = format DOS file {$(OBJMODS)} name $*.EXE lib $(OUTD)\$(NAME).lib op q, map=$*.MAP, stack=0

SRC   = hdpmi

DEPS0 = hdpmi.inc external.inc version.inc $(NAME).mak

.SUFFIXES: .asm .obj

.asm{$(OUTD)}.obj:
	@$(ASM) $(AOPT) $<

ALL: $(OUTD) $(OUTD)\$(NAME).EXE 

$(OUTD):
	@mkdir $(OUTD)

$(OBJMODS): $(DEPS0)

$(OUTD)\$(NAME).EXE: $(OBJMODS) $(OUTD)\$(NAME).lib
	$(LINK) @<<
$(LCMDS3)
<<
	@..\..\BIN\SETMZHDR.EXE -q $*.EXE
!if $(DEBUG)==0
	@copy $*.EXE ..\..\BIN\*.* >NUL
!endif     

$(OUTD)\$(NAME).lib: $(OBJMODS)
	@cd $(OUTD)
	@$(LIB16BIN) $(NAME).lib $(OBJNAMES:.\=+)
	@jwlib -q -b $(NAME).lib -$(SRC).OBJ
	@cd ..

clean:
	@del $(OUTD)\*.obj
	@del $(OUTD)\*.lib
	@del $(OUTD)\*.exe
	@del $(OUTD)\*.lst
	@del $(OUTD)\*.map
