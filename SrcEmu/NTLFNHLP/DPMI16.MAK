
# this will assemble all sources to be compatible with a 16-bit DPMI client,
# which has a 16-bit stack only. Win32 emulation for 16bit clients is 
# *not* supported by HX DOS extender, it is implemented just for conveniance.
# it may work as long as code and data doesn't exceed 64 kB.

# to create enter "nmake /f dpmi16.mak"

!include <..\dirs>

!ifndef DEBUG
DEBUG=0
!endif

NAME=ntlfnh16

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

!ifndef MASM
MASM=0
!endif

ASMOPT= -c -nologo -Cp -Sg -D_KERNEL32_=1 $(AOPTD) -I$(INC32DIR) -D?FLAT=0 -D?CLEARHIGHEBP=1 -Fl$* -Fo$*
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
	@del $(NAME).lib
	$(LIB16BIN) $(NAME).lib @<<
$(OBJNAMES:.\=+)
<<
	@cd ..
!if $(DEBUG)==0
#	copy $*.lib $(LIBOMF)\*.*
	copy $(OUTDIR)\*.obj ..\DKRNL32\DPMI16\*.*
!endif
