
# this will assemble all sources to be compatible with a 16-bit DPMI client,
# which has a 16-bit stack only. Win32 emulation for 16bit clients is 
# *not* supported by HX DOS extender, it is implemented just for convenience.
# it may work as long as code and data doesn't exceed 64 kB.

# to create enter "nmake /f dpmi16.mak"

# Please note: adjust paths in file "..\dirs" first!

# all object modules will be put into library dkrl3216.lib.
# to create a debug version use "nmake /f dpmi16.mak debug=1"
# and create a subdir DPMI16D first!

# for each proc, JWasm/Masm will create a prologue in format:
#
#   push ebp
#   movzx ebp, sp
#
# because stack cannot be 32-bit in this environment, but HIWORD of esp
# isnt necessarily cleared. 

# if MASM version >= 7.00 is used, option -omf has to be placed
# behind ml in ASM variable

!include <..\dirs>

!ifndef DEBUG
DEBUG=0
!endif

NAME=dkrl3216

!if $(DEBUG)
AOPTD=-D_DEBUG
OUTDIR=DPMI16D
!else
OUTDIR=DPMI16
AOPTD=
!endif


SRCMODS = \
!include modules.inc

OBJNAMES= $(SRCMODS:.ASM=.OBJ)
OBJMODS = $(OBJNAMES:.\=DPMI16\)

OTHERMODS=.\int21lfn.obj

!ifndef MASM
MASM=0
!endif

ASMOPT= -c -nologo -Cp -Sg -D_KERNEL32_=1 $(AOPTD) -I$(INC32DIR) -D?FLAT=0 -D?CLEARHIGHEBP=1 -Fl$* -Fo$*
!if $(MASM)
ASM=@ml.exe $(ASMOPT)
!else
ASM=@jwasm.exe $(ASMOPT)
!endif

LIBTOOLOMF=$(DMCDIR)\lib.exe

.SUFFIXES: .asm .obj

.asm{$(OUTDIR)}.obj:
	$(ASM) $<

ALL: $(OUTDIR) $(OUTDIR)\$(NAME).LIB

$(OUTDIR):
	@mkdir $(OUTDIR)
    
$(OUTDIR)\$(NAME).LIB: $(OBJMODS)
	@cd $(OUTDIR)
	if exist $(NAME).LIB del $(NAME).LIB
	$(LIB16BIN) $(NAME).LIB @<<
$(OBJNAMES:\.=+) $(OTHERMODS:\.=+)
<<
	@cd ..
!if $(DEBUG)==0
	copy $*.LIB $(LIBOMF)\*.*
!endif    

$(OBJMODS): dkrnl32.inc

clean:
	@del $(OUTDIR)\*.obj
	@del $(OUTDIR)\*.lib
	@del $(OUTDIR)\*.lst
