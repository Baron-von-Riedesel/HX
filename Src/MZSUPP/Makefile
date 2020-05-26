
# NMAKE makefile to create library JMPPM32.LIB and
# object modules JMPPM32.OBJ, LOADSRVR.OBJ, DEFSTACK.OBJ
# tools used:
# - JWasm/Masm
# - WLib

!include <..\dirs>

# define directory for OMF libs/modules
#LIBOMF=..\..\lib

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

!ifndef MASM
MASM=0
!endif

ASMOPT= -c -nologo -Sg -Fl$* -Fo$*.OBJ -D?W32=0 -D?FLAT=0 $(ASMT) -I$(INC32DIR)
!if $(MASM)
ASM=@ml.exe
!else
ASM=@jwasm.exe
!endif

ALL: $(OUTDIR) $(STUBDIR) $(OUTDIR)\JMPPM32.LIB $(OUTDIR)\JMPPM32.OBJ $(OUTDIR)\defstack.obj \
	$(OUTDIR)\dmysrvr.obj $(OUTDIR)\dmymove.obj \
	$(STUBDIR)\loadsrvr.OBJ $(OUTDIR)\loadpe.obj

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
!if $(DEBUG)==0
	@copy $(OUTDIR)\JMPPM32.LIB $(LIBOMF)\*.* >NUL
!endif

$(OUTDIR)\getcmdl.obj: getcmdl.asm makefile
	$(ASM) $(ASMOPT) getcmdl.asm

$(OUTDIR)\getenv.obj: getenv.asm makefile
	$(ASM) $(ASMOPT) getenv.asm

$(OUTDIR)\loadsrvr.obj: loadsrvr.asm makefile
	$(ASM) $(ASMOPT) loadsrvr.asm

$(OUTDIR)\movehigh.obj: movehigh.asm makefile
	$(ASM) $(ASMOPT) movehigh.asm

$(OUTDIR)\stksize.obj: stksize.asm makefile
	$(ASM) $(ASMOPT) stksize.asm

$(OUTDIR)\loadext.obj: loadext.asm makefile
	$(ASM) $(ASMOPT) loadext.asm

$(OUTDIR)\loadpe.obj: loadpe.asm makefile
	$(ASM) $(ASMOPT) loadpe.asm

$(STUBDIR)\loadsrvr.obj: loadsrvr.asm ..\hdpmi\stub32\hdpmi32.inc makefile
	$(ASM) $(ASMOPT) -D?HDPMI=1 loadsrvr.asm
	@copy $*.obj $(LIBOMF)\*.* >NUL


$(OUTDIR)\JMPPM32.OBJ: jmppm32.asm makefile
	$(ASM) $(ASMOPT) jmppm32.asm
!if $(DEBUG)==0
	@copy $*.OBJ $(LIBOMF)\*.* >NUL
!endif

$(OUTDIR)\DEFSTACK.OBJ: defstack.asm makefile
	$(ASM) $(ASMOPT) defstack.asm
!if $(DEBUG)==0
	@copy $*.OBJ $(LIBOMF)\*.* >NUL
!endif

$(OUTDIR)\DMYSRVR.OBJ: dmysrvr.asm makefile
	$(ASM) $(ASMOPT) dmysrvr.asm
!if $(DEBUG)==0
	@copy $*.OBJ $(LIBOMF)\*.* >NUL
!endif

$(OUTDIR)\DMYMOVE.OBJ: dmymove.asm makefile
	$(ASM) $(ASMOPT) dmymove.asm
!if $(DEBUG)==0
	@copy $*.OBJ $(LIBOMF)\*.* >NUL
!endif

clean:
	@del $(OUTDIR)\*.obj
	@del $(OUTDIR)\*.lib
	@del $(OUTDIR)\*.lst
	@del $(STUBDIR)\*.obj
