
# nmake makefile, creates the version of HDPMI16.EXE with the
# host stack in extended memory. Since v3.18, this is the "standard".
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
OBJMODS = $(OBJNAMES:.\=STD16D\)
!else
OBJMODS = $(OBJNAMES:.\=STD16\)
!endif

LINK  = jwlink.exe
LOPT  = format DOS

LCMDS1=$(LOPT) file $(OUTSTD)\$(SRC).obj name $*.EXE op q, map=$*.MAP, stack=0 lib $(OUTSTD)\$(NAME).lib

AOPT= -nologo -c -Cp -Sg -D?32BIT=0 -D?HSINEXTMEM=1 $(AOPTD) -I$(INC32DIR) -Fl$* -Fo$*

!if $(MASM)
ASM = ml.exe
!else
ASM = jwasm.exe
!endif

NAME  = HDPMI16
SRC   = hdpmi

DEPS0 = hdpmi.inc external.inc version.inc

!if $(DEBUG)
OUTSTD=STD16D
!else
OUTSTD=STD16
!endif

.SUFFIXES: .asm .obj

.asm{$(OUTSTD)}.obj:
	@$(ASM) $(AOPT) $<

ALL: $(OUTSTD) $(OUTSTD)\$(NAME).EXE 

$(OBJMODS): $(DEPS0)

$(OUTSTD):
	@mkdir $(OUTSTD)

# create the standard version

$(OUTSTD)\$(NAME).EXE: $(OUTSTD)\$(SRC).obj $(OUTSTD)\$(NAME).lib $(NAME).mak 
	$(LINK) @<<
$(LCMDS1)
<<
	@..\..\BIN\SETMZHDR.EXE -q $*.EXE
!if $(DEBUG)==0
	@copy $*.EXE ..\..\Bin\*.* >NUL
!endif

$(OUTSTD)\$(NAME).lib: $(OBJMODS) $(NAME).mak
	@cd $(OUTSTD)
	@$(LIB16BIN) $(NAME).lib $(OBJNAMES:.\=+)
	@cd ..

clean:
	@del $(OUTSTD)\*.obj
	@del $(OUTSTD)\*.lib
	@del $(OUTSTD)\*.exe
	@del $(OUTSTD)\*.map
	@del $(OUTSTD)\*.lst
