
# this will create VERSIONS.LIB, an OMF library for emulation of version.

# to create enter "nmake /f omf.mak"

# Please note: paths in file "..\dirs" have to be adjusted first!

# to create a debug version use "nmake /f omf.mak debug=1"
# the debug modules will be located in directory TEXTD,
# which probably has to be created first!

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

NAME=VERSIONS

SRCMODS = \
!include modules.inc

OBJNAMES= $(SRCMODS:.ASM=.OBJ)
OBJMODS = $(OBJNAMES:.\=OMF\)

ASMOPT= -c -nologo -Cp -Sg $(AOPTD) -I$(INC32DIR) -D?FLAT=1 -Fl$* -Fo$*

.SUFFIXES: .asm .obj

.asm{$(OUTDIR)}.obj:
	@$(ASM) $(ASMOPT) $<

$(OUTDIR)\$(NAME).LIB: $(OBJMODS) $(OUTDIR)\version.obj
	@cd $(OUTDIR)
	@$(LIB16BIN) $(NAME).LIB @<<
$(OBJNAMES:.\=+)
<<
	@cd ..

clean:
	@del $(OUTDIR)\*.obj
	@del $(OUTDIR)\*.lib
	@del $(OUTDIR)\*.lst
