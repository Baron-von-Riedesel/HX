
# nmake makefile, creates a HDPMI32 which may work with WDeb386.
# however, currently it won't work.
# tools used:
#  - JWasm | Masm
#  - JWLib | WLib (Open Watcom) | MS OMF LIB (lib16.exe)
#  - JWLink v1.8x
#  - SetMZHdr.exe, modifies exe so:
#                  - dos will load the 16-bit part only
#                  - stack size will be 200h

!include <..\dirs>

!ifndef DEBUG
DEBUG = 0
!endif

SRCMODS = \
!include modules.inc
OBJNAMES = $(SRCMODS:.ASM=.OBJ)

!if $(DEBUG)
OUTSTD= WDEBD
OBJMODS = $(OBJNAMES:.\=WDEBD\)
AOPTD=-D_DEBUG
!else
OUTSTD= WDEB
OBJMODS = $(OBJNAMES:.\=WDEB\)
!endif

NAME  = HDPMI32
SRC   = hdpmi

DEPS0 = hdpmi.inc external.inc version.inc


.SUFFIXES: .asm .obj

.asm{$(OUTSTD)}.obj:
	@$(ASM) -nologo -c -Cp -Sg -D?32BIT=1 $(AOPTD) -I$(INC32DIR) -Fl$* -Fo$* -D?WDEB386=1 $<

TARGET1=$(OUTSTD)\$(NAME).EXE 

ALL: $(OUTSTD) $(TARGET1)

$(OUTSTD):
	@mkdir $(OUTSTD)

$(OBJMODS): $(DEPS0)

$(OUTSTD)\$(NAME).EXE: $(OUTSTD)\$(SRC).obj $(OUTSTD)\$(NAME).lib $(NAME)d.mak
	jwlink @<<
format DOS file $(OUTSTD)\$(SRC).obj name $*.EXE lib $(OUTSTD)\$(NAME).lib op q, map=$*.MAP, stack=0
<<
	@SetMZHdr.exe -q $*.EXE

$(OUTSTD)\$(NAME).lib: $(OBJMODS) $(NAME)d.mak
	@cd $(OUTSTD)
	@$(LIB16BIN) $(NAME).lib $(OBJNAMES:.\=+)
	@jwlib -q -b $(NAME).lib -$(SRC).OBJ
	@cd ..

clean:
	@del $(OUTSTD)\*.obj
	@del $(OUTSTD)\*.lib
	@del $(OUTSTD)\*.exe
	@del $(OUTSTD)\*.lst
	@del $(OUTSTD)\*.map
