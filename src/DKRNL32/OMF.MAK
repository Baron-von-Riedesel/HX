
# this will create DKRNL32S.LIB with all modules in OMF format.

# support for segmented models has been abandoned since v3.2,
# this makefile will now create the FLAT version of all modules.

# to create enter "nmake /f omf.mak"

# Please note: paths in file "..\dirs" have to be adjusted first!

# to create a debug version use "nmake /f omf.mak debug=1"
# the debug modules will be located in directory OMFD,
# which probably has to be created first!

# tols used:
# - JWasm
# - Wlib   (Open Watcom)
# - Wlink  (Open Watcom)

# if MASM version >= 7.00 is used, option -omf has to be placed
# behind ml.exe in variable ASM.

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

NAME=DKRNL32S

SRCMODS = \
!include modules.inc

OTHERMODS=.\int21lfn.obj

OBJNAMES= $(SRCMODS:.ASM=.OBJ)
OBJMODS = $(OBJNAMES:.\=OMF\)

!ifndef MASM
MASM=0
!endif

ASMOPT= -c -nologo -Cp -Sg -D?FLAT=1 -D_KERNEL32_=1 -D?OMF=1 $(AOPTD) -I$(INC32DIR) -Fl$* -Fo$*
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

$(OUTDIR)\$(NAME).LIB: $(OBJMODS) $(OUTDIR)\int21lfn.obj
	@cd $(OUTDIR)
	@$(LIB16BIN) $(NAME).LIB @<<
$(OBJNAMES:\.=+) $(OTHERMODS:\.=+)
<<
	@cd ..
!if $(DEBUG)==0
#	@copy $*.LIB $(LIBOMF)\*.* >NUL
!endif    

$(OUTDIR)\int21lfn.obj:
	@copy ..\NTLFNHLP\OMF\int21lfn.obj $(OUTDIR)\*.*

$(OBJMODS): dkrnl32.inc

clean:
	@del $(OUTDIR)\*.obj
	@del $(OUTDIR)\*.lib
	@del $(OUTDIR)\*.lst
