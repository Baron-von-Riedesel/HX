
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
OBJMODS = $(OBJNAMES:.\=HSEXT32D\)
AOPTD=-D_DEBUG
OUTHSEXT=HSEXT32D
!else
OBJMODS = $(OBJNAMES:.\=HSEXT32\)
OUTHSEXT=HSEXT32
!endif

LINK  = jwlink.exe
LOPT  = format DOS

LCMDS3=$(LOPT) file {$(OBJMODS)} name $*.EXE op q, map=$*.MAP, stack=0 lib $(OUTHSEXT)\$(NAME).lib

AOPT= -nologo -c -Cp -Sg -D?32BIT=1 -D?HSINEXTMEM=1 $(AOPTD) -I$(INC32DIR) -Fl$* -Fo$*
ASM=@jwasm.exe

NAME  = HDPMI32
SRC   = hdpmi

DEPS0 = hdpmi.inc external.inc version.inc

.SUFFIXES: .asm .obj

.asm{$(OUTHSEXT)}.obj:
	$(ASM) $(AOPT) $<

# the following versions are created:
# HSEXT32: version with host stack in extended memory [Hiword(ESP) != 0]
#          which requires very little DOS ram, but will not work with some
#          clients (DOS4G!)

TARGET3=$(OUTHSEXT)\$(NAME).EXE 

ALL: $(OUTHSEXT) $(TARGET3)

$(OUTHSEXT):
	@mkdir $(OUTHSEXT)

$(OBJMODS): $(DEPS0)

$(OUTHSEXT)\$(NAME).EXE: $(OBJMODS) $(OUTHSEXT)\$(NAME).lib
	@$(LINK) @<<
$(LCMDS3)
<<
	@..\..\BIN\SETMZHDR.EXE -q $*.EXE
!if $(DEBUG)==0
	@copy $*.EXE ..\..\BIN\*.* >NUL
!endif     

$(OUTHSEXT)\$(NAME).lib: $(OBJMODS)
	@cd $(OUTHSEXT)
	@$(LIB16BIN) $(NAME).lib $(OBJNAMES:.\=+)
	@jwlib -q $(NAME).lib -$(SRC).OBJ
	@cd ..

clean:
	@del $(OUTHSEXT)\*.obj
	@del $(OUTHSEXT)\*.exe
	@del $(OUTHSEXT)\*.lst
	@del $(OUTHSEXT)\*.map
