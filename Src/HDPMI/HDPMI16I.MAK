
# nmake makefile, creates HDPMI16i.EXE, linked as a PE binary.
# This variant runs clients with IOPL=0.
# Since v3.22, it's aware of JLM jhdpmi.

# tools used:
#  - JWasm | Masm
#  - JWLib | WLib (Open Watcom) | MS OMF LIB (lib16.exe)
#  - JWLink v1.9beta 15 (NODOSSEG option needed)
#  - EditPE, PEStub
# EditPE is used to extract the 16-bit code section from the PE binary
# and then add it again, as a so-called "stub".

!include <..\dirs>

!ifndef DEBUG
DEBUG = 0
!endif

NAME = HDPMI16

SRCMODS = \
!include modules.inc
OBJNAMES = $(SRCMODS:.ASM=.OBJ)

!if $(DEBUG)
OBJMODS = $(OBJNAMES:.\=IOPL016D\)
#AOPTD=-D_DEBUG -D?DOSOUTPUT=0 -D?VIODIROUT=1 -D?SLOWDOWN=200
AOPTD=-D_DEBUG
OUTD=IOPL016D
!else
OBJMODS = $(OBJNAMES:.\=IOPL016\)
OUTD=IOPL016
AOPTD=
!endif

LINK  = jwlink.exe

# for 3.20, add "wdeb386" support ( for "deb386" )
# for 3.22, add "jhdpmi" support
#AOPT   = -nologo -c -Cp -Sg -D?32BIT=0 -D?PMIOPL=0 $(AOPTD) -I$(INC32DIR) -Fl$* -Fo$* -D?PE
AOPT   = -nologo -c -Cp -Sg -D?32BIT=0 -D?PMIOPL=0 $(AOPTD) -I$(INC32DIR) -Fl$* -Fo$* -D?PE -D?WDEB386=1 -D?JHDPMI=1

SRC   = hdpmi

DEPS0 = hdpmi.inc external.inc version.inc $(NAME)i.mak

.SUFFIXES: .asm .obj

.asm{$(OUTD)}.obj:
	@$(ASM) $(AOPT) $<

ALL: $(OUTD) $(OUTD)\$(NAME)i.EXE 

$(OUTD):
	@mkdir $(OUTD)

$(OBJMODS): $(DEPS0)

# the binary created by jwlink has to be adjusted
# 1. the 16-bit code (segment 3) must get VA 0
# 2. the 16-bit code must be extracted and written as a stub
# 3. the 16-bit code section must be removed from the PE binary
# 4. the .reloc section is removed
# 5. the stub must be attached to the PE binary

$(OUTD)\$(NAME)i.EXE: $(OUTD)\$(NAME).TMP
	@EditPE -q a 3=0  $(OUTD)\$(NAME).TMP $*.EXE
	@EditPE -q x 3 /m $*.EXE $(OUTD)\stub.bin
	@EditPE -q d 3    $*.EXE $*.EXE
	@EditPE -q d 3    $*.EXE $*.EXE
	@PEstub -q -n     $*.EXE $(OUTD)\stub.bin

$(OUTD)\$(NAME).TMP: $(OUTD)\$(SRC).obj $(OUTD)\$(NAME).lib $(NAME)i.mak 
	@$(LINK) format win pe hx ru native f $(OUTD)\$(SRC) n $*.TMP lib $(OUTD)\$(NAME).lib op q, map=$*.MAP, nodosseg, stack=0, offset=0, align=0x100
#	link /subsystem:native $(OUTD)\$(SRC).obj $(OUTD)\$(NAME).lib /OUT:$*.TMP /MAP:$*.map /STACK:0,0 /BASE:0 /FILEALIGN:0x100

$(OUTD)\$(NAME).lib: $(OBJMODS) $(NAME).mak
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
	@del $(OUTD)\*.tmp
	@del $(OUTD)\stub.bin
