
# create OS/2 emulation DLL NLS.DLL

NAME  = NLS
LOPTS = /NOLOGO/NOPACKC/FAR/NON/NOD/NOE/MAP:FULL/A:16/ONERROR:NOEXE
MODS  = nls

!include <..\dirs>

LIBS  = $(HXINST)\lib16\kernel16.lib .\dosxxxs.lib

OUTDIR=RELEASE        

$(OUTDIR)\$(NAME).DLL: $(NAME).def $(NAME).mak $*.obj $(OUTDIR)\dosxxxs.lib
	@cd $(OUTDIR)
	link16.exe @<<
$(MODS),
$(NAME).DLL,
$(NAME).map,
$(LIBS),
..\$(NAME).def $(LOPTS);
<<
#	rc $(NAME).dll
#	c:\msvc\bin\implib -nowep $(NAME).lib ..\$(NAME).def
	@cd ..

$(OUTDIR)\$(NAME).obj: $(NAME).asm
	@jwasm.exe -c -nologo -Fl$* -Fo$* $(NAME).asm

clean:
	@del $(OUTDIR)\$(NAME).dll
