
# NMAKE makefile to create library JMPPM32.LIB and
# object modules JMPPM32.OBJ, LOADSRVR.OBJ, DEFSTACK.OBJ
# tools used:
# - JWasm/Masm
# - WLib

!include <..\dirs>

!ifdef TRACE
ASMT=-D?TRACE=1
!else
ASMT=
!endif

!ifndef DEBUG
DEBUG=0
!endif

!if $(DEBUG)
OUTDIR=DEBUG
STUBDIR=STUB
!else
OUTDIR=RELEASE
STUBDIR=STUB
!endif

ASMOPT= -c -nologo -Sg -Fl$* -Fo$*.OBJ $(ASMT) -I$(INC32DIR)

ALL: $(OUTDIR) $(STUBDIR) $(OUTDIR)\JMPPM32.LIB $(OUTDIR)\JMPPM32.OBJ $(OUTDIR)\defstack.obj \
	$(OUTDIR)\dmysrvr.obj $(OUTDIR)\dmymove.obj \
	$(STUBDIR)\loadsrvr.OBJ $(OUTDIR)\loadpe.obj $(OUTDIR)\InitPM.obj

$(OUTDIR):
	@mkdir $(OUTDIR)

$(STUBDIR):
	@mkdir $(STUBDIR)

$(OUTDIR)\JMPPM32.LIB: $(OUTDIR)\getcmdl.obj $(OUTDIR)\getenv.obj \
					$(OUTDIR)\loadsrvr.obj $(OUTDIR)\movehigh.obj \
					$(OUTDIR)\stksize.obj $(OUTDIR)\loadext.obj \
                    $(OUTDIR)\loadpe.obj
	@cd $(OUTDIR)
	@$(LIB16BIN) JMPPM32.LIB @<<
+getcmdl.obj +getenv.obj +loadsrvr.obj +movehigh.obj +stksize.obj +loadext.obj +loadpe.obj
<<
	@cd ..

$(OUTDIR)\getcmdl.obj: getcmdl.asm makefile
	@$(ASM) $(ASMOPT) getcmdl.asm

$(OUTDIR)\getenv.obj: getenv.asm makefile
	@$(ASM) $(ASMOPT) getenv.asm

$(OUTDIR)\loadsrvr.obj: loadsrvr.asm makefile
	@$(ASM) $(ASMOPT) loadsrvr.asm

$(OUTDIR)\movehigh.obj: movehigh.asm makefile
	@$(ASM) $(ASMOPT) movehigh.asm

$(OUTDIR)\stksize.obj: stksize.asm makefile
	@$(ASM) $(ASMOPT) stksize.asm

$(OUTDIR)\loadext.obj: loadext.asm makefile
	@$(ASM) $(ASMOPT) loadext.asm

$(OUTDIR)\loadpe.obj: loadpe.asm makefile
	@$(ASM) $(ASMOPT) loadpe.asm

$(STUBDIR)\loadsrvr.obj: loadsrvr.asm ..\hdpmi\stub32\hdpmi32.inc makefile
	@$(ASM) $(ASMOPT) -D?HDPMI=1 loadsrvr.asm

$(OUTDIR)\JMPPM32.OBJ: jmppm32.asm makefile
	@$(ASM) $(ASMOPT) jmppm32.asm

$(OUTDIR)\DEFSTACK.OBJ: defstack.asm makefile
	@$(ASM) $(ASMOPT) defstack.asm

$(OUTDIR)\DMYSRVR.OBJ: dmysrvr.asm makefile
	@$(ASM) $(ASMOPT) dmysrvr.asm

$(OUTDIR)\DMYMOVE.OBJ: dmymove.asm makefile
	@$(ASM) $(ASMOPT) dmymove.asm

$(OUTDIR)\InitPM.OBJ: InitPM.asm makefile
	@$(ASM) $(ASMOPT) InitPM.asm

clean:
	@del $(OUTDIR)\*.obj
	@del $(OUTDIR)\*.lib
	@del $(OUTDIR)\*.lst
	@del $(STUBDIR)\*.obj
