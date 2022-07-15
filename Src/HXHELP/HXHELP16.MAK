
# to create hxhelp16.exe enter: nmake -f hxhelp16.mak

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
#OWPATH=$(OWDIR)
MAKEMZ=0

!if $(DEBUG)==0
OUTDIR=REL16
!else
OUTDIR=DEB16
!endif

#ASMOPT= -c -nologo -Sg -Fl$* -Fo$* -I$(INC32DIR) -D?FLAT=0 -D?NE=1 -D?DEBUGLEVEL=$(DEBUG)
ASMOPT= -c -nologo -Sg -Fl$* -Fo$* -I$(INC32DIR) -D?V19=1 -D?FLAT=0 -D?NE=1 -D?DEBUGLEVEL=$(DEBUG)

ALL: $(OUTDIR) $(OUTDIR)\$(NAME).EXE

$(OUTDIR):
	@mkdir $(OUTDIR)

$(OUTDIR)\$(NAME).EXE: $(OUTDIR)\hxhelp16.obj $(OUTDIR)\privprof.obj HXHELP16.mak hxhelp16.def ..\DPMILDR\STUB16\DPMILD16.BIN
	@$(LINK16BIN) format win dpmi file $*.obj, $(OUTDIR)\privprof.obj name $*.EXE op q, map=$*.MAP @HXHELP16.LBC

$(OUTDIR)\$(NAME).obj: hxhelp.asm hxhelp.inc version.inc rmdbghlp.inc HXHELP16.MAK
	@$(ASM) $(ASMOPT) hxhelp.asm

$(OUTDIR)\privprof.obj: privprof.asm HXHELP16.MAK
    @$(ASM) $(ASMOPT) privprof.asm

clean:
	@del $(OUTDIR)\*.exe
	@del $(OUTDIR)\*.obj
