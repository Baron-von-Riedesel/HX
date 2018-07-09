
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

SRCMODS = \
!include modules.inc
OBJNAMES = $(SRCMODS:.ASM=.OBJ)

!if $(DEBUG)
OBJMODS = $(OBJNAMES:.\=STD32D\)
AOPTD=-D_DEBUG
OUTSTD=STD32D
!else
OBJMODS = $(OBJNAMES:.\=STD32\)
OUTSTD=STD32
!endif

LINK  = jwlink.exe
LOPT  = format DOS

LCMDS3=$(LOPT) file {$(OBJMODS)} name $*.EXE op q, map=$*.MAP, stack=0 lib $(OUTSTD)\$(NAME).lib

AOPT= -nologo -c -Cp -Sg -D?32BIT=1 $(AOPTD) -I$(INC32DIR) -Fl$* -Fo$*
ASM = jwasm.exe

NAME  = HDPMI32
SRC   = hdpmi

DEPS0 = hdpmi.inc external.inc version.inc

.SUFFIXES: .asm .obj

.asm{$(OUTSTD)}.obj:
	@$(ASM) $(AOPT) $<

ALL: $(OUTSTD) $(OUTSTD)\$(NAME).EXE 

$(OUTSTD):
	@mkdir $(OUTSTD)

$(OBJMODS): $(DEPS0)

$(OUTSTD)\$(NAME).EXE: $(OBJMODS) $(OUTSTD)\$(NAME).lib
	$(LINK) @<<
$(LCMDS3)
<<
	@..\..\BIN\SETMZHDR.EXE -q $*.EXE
!if $(DEBUG)==0
	@copy $*.EXE ..\..\BIN\*.* >NUL
!endif     

$(OUTSTD)\$(NAME).lib: $(OBJMODS)
	@cd $(OUTSTD)
	@$(LIB16BIN) $(NAME).lib $(OBJNAMES:.\=+)
	@jwlib -q $(NAME).lib -$(SRC).OBJ
	@cd ..

clean:
	@del $(OUTSTD)\*.obj
	@del $(OUTSTD)\*.exe
	@del $(OUTSTD)\*.lst
	@del $(OUTSTD)\*.map
