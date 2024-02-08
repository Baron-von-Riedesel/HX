
# NMAKE makefile to create HXGUIHLP.DLL
# tools used:
# - Masm/JWasm
# - WLink

!include <..\dirs>

NAME=HXGUIHLP

!ifndef DEBUG
DEBUG=0
!endif

!if $(DEBUG)
OUTDIR=DEBUG
AOPTD=-D_DEBUG -Zi 
!else
OUTDIR=RELEASE
AOPTD=
!endif

ASMOPT= -c -nologo -coff -Sg -Fl$* -Fo$* -D_ML -I$(INC32DIR) $(AOPTD)

LOPTS= /SUBSYSTEM:CONSOLE /DLL /MAP /NOLOGO /NOD /LIBPATH:$(LIBCOFF)

LIBS=dkrnl32.lib duser32.lib dgdi32.lib vesa32.lib

ALL: $(OUTDIR) $(OUTDIR)\$(NAME).DLL

$(OUTDIR):
	@mkdir $(OUTDIR)

$(OUTDIR)\$(NAME).DLL: $*.obj Makefile
!if $(MSLINK)
	@link $*.obj $(LOPTS) $(LIBS) /OUT:$*.DLL /DEF:$(NAME).DEF /MERGE:.CRT=.data
!else
	@$(LINKBIN) format win pe dll f $*.obj name $*.DLL libpath $(LIBCOFF) lib { $(LIBS) } op q, map=$*.MAP @$(NAME).rsp
!endif

$(OUTDIR)\$(NAME).obj: $(NAME).asm $(NAME).inc vsprintf.inc Makefile
	@$(ASM) $(ASMOPT) $(NAME).asm

clean:
	@del $(OUTDIR)\*.obj
	@del $(OUTDIR)\*.dll
#	@del $(OUTDIR)\*.lib
	@del $(OUTDIR)\*.lst
	@del $(OUTDIR)\*.map
