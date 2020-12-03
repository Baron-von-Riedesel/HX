
# creates DOSX.EXE
# tools used:
# - JWasm
# - WLink

!include <..\dirs>

OUTDIR=RELEASE

AOPTS= -c -nologo -Fo$* -Fl$* -Sg

!ifndef MASM
MASM=0
!endif

!if $(MASM)
ASM=@ml.exe $(AOPTS)
!else
ASM=@jwasm.exe $(AOPTS)
!endif

LOPTS=$(XLOPTS)/ONE:NOE/NOE/MAP:FULL/NON/FAR/STACK:2048

ALL: $(OUTDIR) $(OUTDIR)\dosx.exe

$(OUTDIR):
	@mkdir $(OUTDIR)

$(OUTDIR)\DOSX.EXE: $*.obj makefile
	@jwlink @<<
format dos
file $*.OBJ
name $*.EXE
op map=$*.MAP
<<

$(OUTDIR)\dosx.obj: dosx.asm makefile
	$(ASM) dosx.asm

