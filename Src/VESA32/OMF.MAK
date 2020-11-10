
# this will create VESA32S.LIB, an OMF library

# to create enter "nmake /f omf.mak"

# Please note: paths in file "..\dirs" have to be adjusted first!

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

NAME=VESA32S

SRCMODS = \
!include modules.inc

OBJNAMES= $(SRCMODS:.ASM=.OBJ)
OBJMODS = $(OBJNAMES:.\=OMF\)

!ifndef MASM
MASM=0
!endif

ASMOPT= -c -nologo -Cp -Sg $(AOPTD) -I$(INC32DIR) -D_VESA32_=1 -D?FLAT=1 -Fl$* -Fo$*
!if $(MASM)
ASM=@ml.exe $(ASMOPT)
!else
ASM=@jwasm.exe $(ASMOPT) 
!endif

.SUFFIXES: .asm .obj

.asm{$(OUTDIR)}.obj:
	$(ASM) $<

ALL: $(OUTDIR) $(OUTDIR)\$(NAME).LIB

$(OUTDIR):
	@mkdir $(OUTDIR)
    
$(OUTDIR)\$(NAME).LIB: $(OBJMODS)
	@cd $(OUTDIR)
	@(LIB16BIN) $(NAME).LIB @<<
$(OBJNAMES:.\=+)
<<
	@cd ..
!if $(DEBUG)==0
#	@copy $*.LIB $(LIBOMF)\*.* >NUL
!endif    

clean:
	@erase $(OUTDIR)\*.obj
	@erase $(OUTDIR)\*.lst
