
# creates DOSX.EXE
# tools used:
# - JWasm
# - JWlink

!include <..\dirs>

OUTDIR=RELEASE

AOPTS= -mz -c -nologo -Fo$* -Fl$* -Sg

#LOPTS=$(XLOPTS)/ONE:NOE/NOE/MAP:FULL/NON/FAR/STACK:2048

ALL: $(OUTDIR) $(OUTDIR)\DOSX.EXE $(OUTDIR)\WIN386.EXE

$(OUTDIR):
	@mkdir $(OUTDIR)

$(OUTDIR)\DOSX.EXE: DOSX.ASM Makefile
	@$(ASM) $(AOPTS) DOSX.ASM

$(OUTDIR)\WIN386.EXE: DOSX.ASM Makefile
	@$(ASM) $(AOPTS) -DENHANCED=1 DOSX.ASM

clean:
	@if exist $(OUTDIR)\dosx.exe del $(OUTDIR)\dosx.exe
	@if exist $(OUTDIR)\win386.exe del $(OUTDIR)\win386.exe
