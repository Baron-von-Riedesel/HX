
# this will create GDI32S.LIB, an OMF library for Win32 emulation.

# to create enter "nmake /f omf.mak"

# Please note: paths in file "..\dirs" have to be adjusted first!

# to create a debug version use "nmake /f omf.mak debug=1"
# the debug modules will be located in directory OMFD,
# which probably has to be created first!

# tools:
# - JWasm
# - Wlib (Open Watcom)

# the prefered (and default) assembler to be used is JWasm.
# if MASM version >= 7.00 is used, option -omf has to be placed
# behind ml in ASM variable

!include <..\dirs>

MASM=0

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

NAME=DGDI32S

SRCMODS = \
!include modules.inc

OBJNAMES= $(SRCMODS:.ASM=.OBJ)
OBJMODS = $(OBJNAMES:.\=OMF\)

ASMOPT= -c -nologo -Cp -D_GDI32_=1 -Sg $(AOPTD) -I$(INC32DIR) -D?FLAT=1 -Fl$* -Fo$*
!if $(MASM)
ASM=@ml.exe $(ASMOPT)
!else
ASM=@jwasm.exe -zlc -zld $(ASMOPT)
!endif

.SUFFIXES: .asm .obj

.asm{$(OUTDIR)}.obj:
	$(ASM) $<

ALL: $(OUTDIR) $(OUTDIR)\$(NAME).LIB

$(OUTDIR):
	@mkdir $(OUTDIR)

$(OUTDIR)\$(NAME).LIB: $(OBJMODS)
	@cd $(OUTDIR)
	@$(LIB16BIN) $(NAME).LIB @<<
$(OBJNAMES:.\=+)
<<
	@cd ..
!if $(DEBUG)==0
#	@copy $*.LIB $(LIBOMF)\*.* >NUL
!endif    

clean:
	@del $(OUTDIR)\*.obj
	@del $(OUTDIR)\*.lib
	@del $(OUTDIR)\*.lst
