
# this will create DADVAPIS.LIB, an OMF library for Win32 emulation.

# to create enter "nmake /f omf.mak"

# Please note: paths in file "..\dirs" have to be adjusted first!

# to create a debug version use "nmake /f omf.mak debug=1"
# the debug modules will be located in directory TEXTD,
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

NAME=DADVAPIS

SRCMODS = \
!include modules.inc

OBJNAMES= $(SRCMODS:.ASM=.OBJ)
OBJMODS = $(OBJNAMES:.\=OMF\)

!ifndef MASM
MASM=0
!endif

ASMOPT= -c -nologo -Cp -Sg $(AOPTD) -D_ADVAPI32_=1 -I$(INC32DIR) -D?FLAT=1 -Fl$* -Fo$*
!if $(MASM)
ASM=@ml.exe $(ASMOPT) 
!else
ASM=@jwasm.exe $(ASMOPT)
!endif

.SUFFIXES: .asm .obj

.asm{$(OUTDIR)}.obj:
	$(ASM) $<

ALL: $(OUTDIR) $(OUTDIR)\$(NAME).lib

$(OUTDIR):
	@mkdir $(OUTDIR)
    
$(OUTDIR)\$(NAME).lib: $(OBJMODS)
	@cd $(OUTDIR)
	@if exist $(NAME).LIB del $(NAME).LIB
	@$(LIB16BIN) $(NAME).LIB @<<
$(OBJNAMES:.\=+)
<<
	@cd ..
!if $(DEBUG)==0
#	@copy $*.LIB $(LIBOMF)\*.* >NUL
!endif    

clean:
	@del $(OUTDIR)\*.obj
	@del $(OUTDIR)\*.lst
	@del $(OUTDIR)\*.lib

