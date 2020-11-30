
# nmake makefile, creates HDPMIST.EXE.
# tools used:
#  - JWasm | Masm
#  - JWLib | WLib (Open Watcom) | MS OMF LIB (lib16.exe)
#  - JWLink v1.9beta 15 (NODOSSEG option needed)
#  - EditPE
#  - PEStub
# EditPE is used to extract the 16-bit code section from the PE binary
# and then add it again, as a so-called "stub".

!include <..\dirs>

NAME = HDPMIST

SRCMODS = \
!include modules.inc
OBJNAMES = $(SRCMODS:.ASM=.OBJ)
OBJMODS = $(OBJNAMES:.\=HDPMIST\)

AOPTD= -D?DOSOUTPUT=1 -D?HDPMISTAT
OUTD=HDPMIST

ASM   = jwasm.exe
LINK  = jwlink.exe

AOPT   = -nologo -c -Cp -Sg -D?32BIT=1 $(AOPTD) -I$(INC32DIR) -Fl$* -Fo$* -D?PE

SRC   = hdpmi

DEPS0 = hdpmi.inc external.inc version.inc $(NAME).mak

.SUFFIXES: .asm .obj

.asm{$(OUTD)}.obj:
	@$(ASM) $(AOPT) $<

ALL: $(OUTD) $(OUTD)\$(NAME).EXE 

$(OUTD):
	@mkdir $(OUTD)

$(OBJMODS): $(DEPS0)

$(OUTD)\$(NAME).EXE: $(OUTD)\$(NAME).TMP
	@EditPE a 3=0  $(OUTD)\$(NAME).TMP $(OUTD)\$(NAME).EXE
	@EditPE x 3 /m $(OUTD)\$(NAME).EXE $(OUTD)\$(NAME).EXE

$(OUTD)\$(NAME).TMP: $(OUTD)\HDPMIST.obj $(OUTD)\$(SRC).obj $(OUTD)\$(NAME).lib $(NAME).mak 
	@$(LINK) format win pe hx ru native f $(OUTD)\$(SRC) n $*.TMP lib $(OUTD)\$(NAME).lib op q, map=$*.MAP, nodosseg, stack=0, offset=0, align=0x100

$(OUTD)\$(NAME).lib: $(OBJMODS) $(OUTD)\HDPMIST.obj
	@cd $(OUTD)
	@$(LIB16BIN) $(NAME).lib $(OBJNAMES:.\=+)
	@jwlib -q -b $(NAME).lib -$(SRC).OBJ -INIT.OBJ +HDPMIST.obj
	@cd ..

clean:
	@del $(OUTD)\*.obj
	@del $(OUTD)\*.lib
#	@del $(OUTD)\*.exe
	@del $(OUTD)\*.lst
	@del $(OUTD)\*.map
	@del $(OUTD)\*.tmp
	@del $(OUTD)\stub.bin
