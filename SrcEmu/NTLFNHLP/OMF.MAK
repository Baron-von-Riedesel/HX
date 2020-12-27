
# this will create a static OMF module, int21lfn.obj,
# which will then be copied to ..\DKRNL32\OMF
# the lib NTLFNHLP.LIB, which is created as well, is not used currently

# to create enter "nmake /f omf.mak"

# Please note: paths in file "..\dirs" have to be adjusted first!

# The MS OMF lib tool ist used here, renamed to LIB16.EXE!

# if MASM version >= 7.00 is used, option -omf has to be placed
# behind ml in ASM variable

!include <..\dirs>

!ifndef DEBUG
DEBUG=0
!endif

!if $(DEBUG)
AOPTD=-D_DEBUG
OUTDIR=OMFD
!else
AOPTD=
OUTDIR=OMF
!endif

NAME=NTLFNHLP

SRCMODS = \
!include modules.inc

OBJNAMES= $(SRCMODS:.ASM=.OBJ)
OBJMODS = $(OBJNAMES:.\=OMF\)

ASMOPT= -c -nologo -Cp -Sg $(AOPTD) -I$(INC32DIR) -D?FLAT=1 -Fl$* -Fo$*

.SUFFIXES: .asm .obj

.asm{$(OUTDIR)}.obj:
	$(ASM) $(ASMOPT) $<

ALL: $(OUTDIR) $(OUTDIR)\$(NAME).lib

$(OUTDIR):
	@mkdir $(OUTDIR)

$(OUTDIR)\$(NAME).lib: $(OBJMODS)
	@cd $(OUTDIR)
	@$(LIB16BIN) $(NAME).lib @<<
$(OBJNAMES:.\=+)
<<
	@cd ..

clean:
	@del $(OUTDIR)\*.obj
	@del $(OUTDIR)\*.lib
	@del $(OUTDIR)\*.lst
