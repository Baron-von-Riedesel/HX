
# this will create DDDRAWS.LIB, an OMF library for Win32 emulation
# which is part of HX's MZ file format support.

# to create enter "nmake /f omf.mak"

# Please note: paths in file "..\dirs" have to be adjusted first!

# to create a debug version use "nmake /f omf.mak debug=1"
# the debug modules will be located in directory OMFD,
# which probably has to be created first!

# tools:
# - JWasm
# - Wlib (Open Watcom)

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

NAME=DDDRAWS

SRCMODS = \
!include modules.inc

OBJNAMES= $(SRCMODS:.ASM=.OBJ)
OBJMODS = $(OBJNAMES:.\=OMF\)

ASMOPT= -c -nologo -Cp -Sg $(AOPTD) -I$(INC32DIR) -D?FLAT=1 -Fl$* -Fo$*

.SUFFIXES: .asm .obj

.asm{$(OUTDIR)}.obj:
	@$(ASM) $(ASMOPT) $<

ALL: $(OUTDIR) $(OUTDIR)\$(NAME).LIB

$(OUTDIR):
	@mkdir $(OUTDIR)
    
$(OUTDIR)\$(NAME).LIB: $(OBJMODS)
	@cd $(OUTDIR)
	@wlib.exe -q -n $(NAME).LIB @<<
$(OBJNAMES:.\=+)
<<
	@cd ..

clean:
	@del $(OUTDIR)\*.obj
	@del $(OUTDIR)\*.lib
	@del $(OUTDIR)\*.lst
