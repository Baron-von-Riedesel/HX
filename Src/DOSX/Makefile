
# creates DOSX.EXE
# tools used:
# - JWasm
# - JWlink

!include <..\dirs>

OUTDIR=RELEASE

AOPTS= -mz -c -nologo -Fo$* -Fl$* -Sg

LOPTS=$(XLOPTS)/ONE:NOE/NOE/MAP:FULL/NON/FAR/STACK:2048

ALL: $(OUTDIR) $(OUTDIR)\dosx.exe

$(OUTDIR):
	@mkdir $(OUTDIR)

$(OUTDIR)\dosx.exe: dosx.asm makefile
	@$(ASM) $(AOPTS) dosx.asm

clean:
	@if exist $(OUTDIR)\dosx.exe del $(OUTDIR)\dosx.exe
