
# creates DOSX.EXE
# tools used:
# - JWasm
# - JWlink

!include <..\dirs>

OUTDIR=RELEASE

AOPTS= -c -nologo -Fo$* -Fl$* -Sg

LOPTS=$(XLOPTS)/ONE:NOE/NOE/MAP:FULL/NON/FAR/STACK:2048

ALL: $(OUTDIR) $(OUTDIR)\dosx.exe

$(OUTDIR):
	@mkdir $(OUTDIR)

$(OUTDIR)\DOSX.EXE: $*.obj makefile
	@jwlink format dos file $*.OBJ name $*.EXE op q,map=$*.MAP

$(OUTDIR)\dosx.obj: dosx.asm makefile
	@$(ASM) $(AOPTS) dosx.asm

clean:
	@if exist $(OUTDIR)\dosx.exe del $(OUTDIR)\dosx.exe
