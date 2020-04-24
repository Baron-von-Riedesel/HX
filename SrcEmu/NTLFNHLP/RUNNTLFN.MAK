
# makes a DPMI TSR which installs NTLFNHLP

NAME=RUNNTLFN
AS=jwasm.exe -c -Fo$* -I..\..\Include
LIBS=..\..\LibOMF
MODS=$(LIBS)\dmythunk
OUTDIR=TEXT

# Microsoft linker
LOPTS=/NOD/MAP/NOE/MAP:FULL/ONE:NOE
LINK=link16.exe

# Borland Linker
#LOPTS=/3 /m
#LINK=tlink

$(OUTDIR)\$(NAME).exe: $*.obj Makefile
	$(LINK) $(LOPTS) $(LIBS)\jmppm32 $* $(MODS),$*.EXE,$*,TEXT\NTLFNHLP $(LIBS)\jmppm32 $(LIBS)\duser32s;

$(OUTDIR)\$(NAME).obj: $(NAME).asm
	$(AS) $(NAME).asm

