
# nmake makefile, creates a HDPMI16.EXE that is linked as a PE binary;
# This is the "standard" version since v3.18.
# tools used:
#  - JWasm | Masm
#  - JWLib | WLib (Open Watcom) | MS OMF LIB (lib16.exe)
#  - JWLink v1.9beta 14
#  - EditPE
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
OBJMODS = $(OBJNAMES:.\=STD16D\)
AOPTD=-D_DEBUG
#AOPTD=-D_DEBUG -D?DOSOUTPUT=0 -D?VIODIROUT=1 -D?SLOWDOWN=200
OUTD=STD16D
!else
OBJMODS = $(OBJNAMES:.\=STD16\)
OUTD=STD16
AOPTD=
!endif

ASM   = jwasm.exe
LINK  = jwlink.exe

AOPT   = -nologo -c -Cp -Sg -D?32BIT=0 $(AOPTD) -I$(INC32DIR) -Fl$* -Fo$* -D?PE

SRC   = hdpmi

DEPS0 = hdpmi.inc external.inc version.inc $(NAME).mak

.SUFFIXES: .asm .obj

.asm{$(OUTD)}.obj:
	@$(ASM) $(AOPT) $<

ALL: $(OUTD) $(OUTD)\$(NAME).EXE 

$(OUTD):
	@mkdir $(OUTD)

$(OBJMODS): $(DEPS0)

# the binary created by jwlink has to be adjusted
# 1. the 16-bit code (segment 3) must get VA 0
# 2. the 16-bit code must be extracted and written as a stub
# 3. the 16-bit code section must be removed from the PE binary
# 4. the .reloc section is removed
# 5. the stub must be attached to the PE binary

$(OUTD)\$(NAME).EXE: $(OUTD)\$(NAME).TMP
	@editpe a 3=0  $(OUTD)\$(NAME).TMP $(OUTD)\$(NAME).EXE
	@editpe x 3 /m $(OUTD)\$(NAME).EXE $(OUTD)\stub.bin
	@editpe d 3    $(OUTD)\$(NAME).EXE $(OUTD)\$(NAME).EXE
	@editpe d 3    $(OUTD)\$(NAME).EXE $(OUTD)\$(NAME).EXE
	@pestub -n     $(OUTD)\$(NAME).EXE $(OUTD)\stub.bin
!if $(DEBUG)==0
	@copy $*.EXE ..\..\BIN\*.* >NUL
!endif     

$(OUTD)\$(NAME).TMP: $(OUTD)\$(SRC).obj $(OUTD)\$(NAME).lib $(NAME).mak 
	@$(LINK) format win pe hx ru native f $(OUTD)\$(SRC) n $*.TMP lib $(OUTD)\$(NAME).lib op q, map=$*.MAP, stack=0, offset=0, align=0x100
#	link /subsystem:native $(OUTD)\$(SRC).obj $(OUTD)\$(NAME).lib /OUT:$*.TMP /MAP:$*.map /STACK:0,0 /BASE:0 /FILEALIGN:0x100

$(OUTD)\$(NAME).lib: $(OBJMODS) $(NAME).mak
	@cd $(OUTD)
	@$(LIB16BIN) $(NAME).lib $(OBJNAMES:.\=+)
	@cd ..

clean:
	@del $(OUTD)\*.obj
	@del $(OUTD)\*.lib
	@del $(OUTD)\*.exe
	@del $(OUTD)\*.lst
	@del $(OUTD)\*.map
