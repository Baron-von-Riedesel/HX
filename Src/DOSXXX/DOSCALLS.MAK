
# create OS/2 emulation dll DOSCALLS.DLL
# uses MS OMF linker

NAME  = DOSCALLS
LOPTS = /NOLOGO/NOPACKC/FAR/NON/NOD/NOE/MAP:FULL/A:16/ONE:NOE
MODS  = doscalls dosrallc

!include <..\dirs>

LIBS  = $(HXINST)\lib16\kernel16.lib .\dosxxxs.lib

OUTDIR=RELEASE

$(OUTDIR)\$(NAME).DLL: $(NAME).def $(NAME).mak $*.obj $(OUTDIR)\dosrallc.obj $(OUTDIR)\dosxxxs.lib
	@cd $(OUTDIR)
	@link16.exe @<<
$(LOPTS) $(MODS),
$(NAME).DLL,
$(NAME).map,
$(LIBS),
..\$(NAME).def;
<<
#	rc $(NAME).dll
#	c:\msvc\bin\implib -nowep $(NAME).lib ..\$(NAME).def
    @cd ..

$(OUTDIR)\$(NAME).obj: $(NAME).asm
	@jwasm.exe -nologo -c -Fl$* -Fo$* $(NAME).asm

$(OUTDIR)\dosrallc.obj: dosrallc.asm
	@jwasm.exe -nologo -c -Fl$* -Fo$* dosrallc.asm

clean:
	@del $(OUTDIR)\$(NAME).dll
	@del $(OUTDIR)\$(NAME).map
