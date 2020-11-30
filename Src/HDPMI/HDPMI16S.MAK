
# nmake makefile, creates the "stub" HDPMI16.EXE version, which 
# may be used to create a stub that is attached to the client binary.
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
OBJMODS = $(OBJNAMES:.\=STUB16D\)
!else
OBJMODS = $(OBJNAMES:.\=STUB16\)
!endif

LINK  = jwlink.exe
LOPT  = format DOS

LCMDS = $(LOPT) file $(OUTSTUB)\$(SRC).obj name $*.BIN lib $(OUTSTUB)\$(NAME).lib op q, map=$*.MAP, stack=0x200

AOPT= -nologo -c -Cp -Sg -D?32BIT=0 -D?STUB=1 $(AOPTD) -I$(INC32DIR) -Fl$* -Fo$*

!if $(MASM)
ASM= ml.exe
!else
ASM= jwasm.exe
!endif

NAME  = HDPMI16
SRC   = hdpmi

DEPS0 = hdpmi.inc external.inc version.inc

!if $(DEBUG)
OUTSTUB=STUB16D
!else
OUTSTUB=STUB16
!endif

.SUFFIXES: .asm .obj

.asm{$(OUTSTUB)}.obj:
	@$(ASM) $(AOPT) $<

ALL: $(OUTSTUB) $(OUTSTUB)\$(NAME).INC

$(OUTSTUB):
	@mkdir $(OUTSTUB)

$(OBJMODS): $(DEPS0)

# create the stub version
# EXTRMZ: convert binary to asm include
# -i: create include

$(OUTSTUB)\$(NAME).INC: $*.BIN $(NAME)s.mak
	@ExtrMZ.EXE -q -i $*.BIN $*.INC

$(OUTSTUB)\$(NAME).BIN: $(OUTSTUB)\$(SRC).obj $(OUTSTUB)\$(NAME).lib $(NAME)s.mak
	$(LINK) @<<
$(LCMDS)
<<
	@SetMZHdr.exe -q $*.BIN

$(OUTSTUB)\$(NAME).lib: $(OBJMODS) $(NAME)s.mak
	@cd $(OUTSTUB)
	@$(LIB16BIN) $(NAME).lib $(OBJNAMES:.\=+)
	@jwlib -q -b $(NAME).lib -$(SRC).OBJ
	@cd ..

clean:
	@del $(OUTSTUB)\*.obj
	@del $(OUTSTUB)\*.lib
#	@del $(OUTSTUB)\*.bin
	@del $(OUTSTUB)\*.lst
	@del $(OUTSTUB)\*.map
#	@del $(OUTSTUB)\*.inc
