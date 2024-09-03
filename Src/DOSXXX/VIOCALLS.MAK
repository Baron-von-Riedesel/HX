
# create OS/2 emulation dll VIOCALLS.DLL

NAME  = VIOCALLS
LOPTS = /NOLOGO/NOPACKC/FAR/NON/NOD/NOE/MAP:FULL/A:16/ONERROR:NOEXE
MODS  = viocalls.obj 

!include <..\dirs>

LIBS  = $(HXINST)\lib16\kernel16.lib .\dosxxxs.lib

OUTDIR=RELEASE

$(OUTDIR)\$(NAME).DLL: $(NAME).def $(NAME).mak $*.obj $(OUTDIR)\dosxxxs.lib
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

clean:
	@del $(OUTDIR)\$(NAME).dll
	@del $(OUTDIR)\$(NAME).map
