
# this creates static library DOSXXXS.LIB
# and import library DOSXXX.LIB

NAME  = DOSXXX
SNAME = DOSXXXS

!include <..\dirs>

OUTDIR=RELEASE

ALL: $(OUTDIR)\$(NAME).LIB $(OUTDIR)\$(SNAME).LIB

AFLAGS= -nologo -c -Sg -I..\..\Include -Fl$* -Fo$*

.asm{$(OUTDIR)}.obj:
	$(ASM) $(AFLAGS) $<

# create the import library DOSXXX.LIB

$(OUTDIR)\$(NAME).LIB: doscalls.def viocalls.def kbdcalls.def nls.def $(OUTDIR)\$(SNAME).LIB
	@cd $(OUTDIR)
#	@$(IMPLIBBIN) /nowep $(NAME).lib ..\doscalls.def ..\viocalls.def ..\kbdcalls.def ..\nls.def
	@$(LIB16BIN) -io -o$(NAME).lib $(SNAME).lib 
	@cd ..

# create the static library DOSXXXS.LIB

DOSMODS = \
!include doscalls.mod
DOSOBJNAMES = $(DOSMODS:.ASM=.OBJ)
DOSOBJMODS = $(DOSOBJNAMES:.\=RELEASE\)

VIOMODS = \
!include viocalls.mod
VIOOBJNAMES = $(VIOMODS:.ASM=.OBJ)
VIOOBJMODS = $(VIOOBJNAMES:.\=RELEASE\)

KBDMODS = .\kbdgstat.ASM .\kbdchrin.ASM .\kbdpeek.ASM
KBDOBJNAMES = $(KBDMODS:.ASM=.OBJ)
KBDOBJMODS = $(KBDOBJNAMES:.\=RELEASE\)

MODS4 = .\csalias.ASM .\gblreal.ASM
MODS4OBJNAMES = $(MODS4:.ASM=.OBJ)
MODS4OBJMODS = $(MODS4OBJNAMES:.\=RELEASE\)


$(OUTDIR)\$(SNAME).LIB: DOSXXX.MAK doscalls.mod $(DOSOBJMODS) $(VIOOBJMODS) $(KBDOBJMODS) $(MODS4OBJMODS)
	@cd $(OUTDIR)
	@$(LIB16BIN) @<<
$(SNAME).LIB $(DOSOBJNAMES:.\=+) $(VIOOBJNAMES:.\=+) $(KBDOBJNAMES:.\=+) $(MODS4OBJNAMES:.\=+)
<<
	@cd ..

install:
	@copy $(OUTDIR)\$(NAME).LIB $(HXINST)\Lib16\*.*
	@copy $(OUTDIR)\$(SNAME).LIB $(HXINST)\Lib16\*.*

clean:
	@del $(OUTDIR)\$(NAME).LIB
	@del $(OUTDIR)\$(SNAME).LIB
	@del $(OUTDIR)\*.obj
	@del $(OUTDIR)\*.lst

