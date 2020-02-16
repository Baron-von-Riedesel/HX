
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

!ifndef MASM
MASM=0
!endif
MSLINK=0

ASMOPT= -c -nologo -coff -Sg -Fl$* -Fo$* -D_ML -I$(INC32DIR) $(AOPTD)
!if $(MASM)
ASM=ml.exe $(ASMOPT)
!else
ASM=jwasm.exe $(ASMOPT)
!endif

LOPTS= /SUBSYSTEM:CONSOLE /DLL /MAP /NOLOGO /NOD /LIBPATH:$(LIBCOFF)

LIBS=dkrnl32.lib duser32.lib dgdi32.lib libc32s.lib vesa32.lib

ALL: $(OUTDIR) $(OUTDIR)\$(NAME).DLL

$(OUTDIR):
	@mkdir $(OUTDIR)

$(OUTDIR)\$(NAME).DLL: $*.obj Makefile
!if $(MSLINK)
	@link $*.obj $(LOPTS) $(LIBS) /OUT:$*.DLL /DEF:$(NAME).DEF /MERGE:.CRT=.data
!else
	@$(LINKBIN) format win pe dll f $*.obj name $*.DLL libpath $(LIBCOFF) lib { $(LIBS) } op q, map=$*.MAP @$(NAME).rsp
!endif
!if $(DEBUG)==0
    @copy $*.DLL ..\..\Bin\$(NAME).* >NUL
!ifdef DLL32DIR
    @copy $*.DLL $(DLL32DIR)\$(NAME).* >NUL
!endif
!endif

$(OUTDIR)\$(NAME).obj: $(NAME).asm $(NAME).inc Makefile
	@$(ASM) $(NAME).asm

clean:
	@del $(OUTDIR)\*.obj
	@del $(OUTDIR)\*.dll
	@del $(OUTDIR)\*.lib
	@del $(OUTDIR)\*.lst
	@del $(OUTDIR)\*.map
	@del $(OUTDIR)\*.exp
