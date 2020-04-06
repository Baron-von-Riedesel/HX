
# to create hxhelp16.exe enter: nmake -f hxhelp16.mak
# adjust path for Open Watcom first (OWPATH=\watcom).

# switch MAKEMZ must remain 0. Currently there is no support for 
# hxhelp.exe in MZ file format.

# the HX.TRP file is generated in HX.TRP subdirectory
# it expects \WATCOM\TRP_SRC tree to exist!
# since that source is protected by copyrights, it is not included here!

#########################################################################
# WARNING: jwlink must be at least v1.9 beta10! This ensures that
# - the only segment is marked as CODE, not DATA
# - the 32-bit segment flag is set
#########################################################################


!include <..\dirs>

!ifndef DEBUG
DEBUG=0
!endif

NAME=HXHELP16
OWPATH=$(OWDIR)
MAKEMZ=0

!if $(DEBUG)==0
OUTDIR=REL16
!else
OUTDIR=DEB16
!endif

!ifndef MASM
MASM=0
!endif

ASMOPT= -c -nologo -Sg -Fl$* -Fo$* -I..\..\Include -D?FLAT=0 -D?NE=1 -D?DEBUGLEVEL=$(DEBUG)
!if $(MASM)
ASM = ml.exe $(ASMOPT) 
!else
ASM = jwasm.exe $(ASMOPT)
!endif

ALL: $(OUTDIR) $(OUTDIR)\$(NAME).EXE

$(OUTDIR):
	@mkdir $(OUTDIR)

$(OUTDIR)\$(NAME).EXE: $(OUTDIR)\hxhelp16.obj $(OUTDIR)\privprof.obj HXHELP16.mak hxhelp16.def
	$(LINK16BIN) format win dpmi file $*.obj, $(OUTDIR)\privprof.obj name $*.EXE op q, map=$*.MAP, stub=..\..\BIN\DPMILD16.BIN, stack=0x800, protmode seg type code fixed seg type data fixed
	@copy $*.EXE $(OWPATH)\binw\HXHP16.EXE >NUL
	@copy $*.EXE ..\..\OWSUPP16\HXHP16.EXE >NUL

$(OUTDIR)\$(NAME).obj: hxhelp.asm hxhelp.inc version.inc rmdbghlp.inc HXHELP16.MAK
	@$(ASM) hxhelp.asm

$(OUTDIR)\privprof.obj: privprof.asm HXHELP16.MAK
    @$(ASM) privprof.asm

clean:
	@del $(OUTDIR)\*.exe
	@del $(OUTDIR)\*.obj
