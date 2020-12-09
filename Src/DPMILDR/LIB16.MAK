
# nmake makefile, creates LIB\Ldr16.lib

!include <..\dirs>

NAME = LDR16
ODIR = LIB16

ALL: $(ODIR)\$(NAME).LIB

$(ODIR):
	@mkdir $(ODIR)

$(ODIR)\$(NAME).lib: $(ODIR)\*.asm
	@cd $(ODIR)
	@$(ASM) -c -nologo -Fl -Sg *.asm
	@jwlib -q -b -n $(NAME).lib +hmemset.obj +lstrcat.obj +lstrcpy.obj +lstrlen.obj +profstrg.obj
	@cd ..

clean:
	@del $(ODIR)\$(NAME).lib
	@del $(ODIR)\*.obj
	@del $(ODIR)\*.lst
