
# create OS/2 emulation dll MOUCALLS.DLL
# currently not implemented!

NAME  = MOUCALLS
LOPTS = /NOLOGO/NOPACKC/FAR/NON/NOD/NOE/MAP:FULL/A:16/ONERROR:NOEXE
MODS  = moucalls 

!include <..\dirs>

LIBS  = $(HXINST)\lib16\kernel16.lib .\dosxxxs.lib

OUTDIR=RELEASE        

$(OUTDIR)\$(NAME).dll: $(NAME).def $(NAME).mak $*.obj $(OUTDIR)\dosxxxs.lib
	@cd $(OUTDIR)
	@link16.exe @<<
$(LOPTS) $(MODS),
$(NAME).dll,
$(NAME).map,
$(LIBS),
..\$(NAME).def;
<<
#	rc $(NAME).dll
#	c:\msvc\bin\implib -nowep $(NAME).lib ..\$(NAME).def
	@cd ..

$(OUTDIR)\$(NAME).obj: $(NAME).asm
	@jwasm.exe -c -nologo -nologo -Fl$* -Fo$* $(NAME).asm

