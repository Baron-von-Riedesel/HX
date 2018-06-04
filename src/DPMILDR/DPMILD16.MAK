
# nmake makefile which creates 
# - DPMILD16.EXE: stand-alone DPMI loader
# - DPMILD16.BIN: 14k stub which includes the DPMI loader
# - HDLD16.BIN:   48k stub which includes the DPMI loader and HDPMI
# tools used:
# - Assembler: JWasm
# - Linker:    JWlink

!ifndef DEBUG
DEBUG = 0
!endif

!if $(DEBUG)
OUTDIR = DEBUG16
!else
OUTDIR = REL16
!endif

!include <..\dirs>

NAME  = DPMILD16
LIBS  = LIB16\ldr16.lib

!ifndef MASM
MASM=0
!endif

AOPT = -c -Sg -Fl$* -Fo$* -nologo -D?32BIT=0 -D?DEBUG=$(DEBUG) -I..\..\Include

!if $(MASM)
ASM   = @ml.exe $(AOPT)
!else
ASM   = @jwasm.exe $(AOPT)
!endif

!if $(DEBUG)
ALL: $(OUTDIR)\$(NAME).EXE
!else
ALL: $(OUTDIR) STUB16 STUBX16 $(OUTDIR)\$(NAME).EXE STUB16\$(NAME).BIN STUBX16\HDLD16.BIN
!endif

$(OUTDIR):
	@mkdir $(OUTDIR)

STUB16:
	@mkdir STUB16

STUBX16:
	@mkdir STUBX16

# create $(OUTDIR)\DPMILD16.EXE

$(OUTDIR)\$(NAME).EXE: $(OUTDIR)\dpmildr.obj $(OUTDIR)\kernel16.obj LIB16\ldr16.lib $(NAME).mak 
	@$(LINK16BIN) format dos file {$(OUTDIR)\dpmildr.obj $(OUTDIR)\kernel16.obj} name $*.EXE op q, map=$*.map lib $(LIBS)
!if $(DEBUG)==0
	@copy $*.EXE ..\..\bin >NUL
!ifdef TOOLSDIR    
	@copy $*.EXE $(TOOLSDIR)\$(NAME).EXE >NUL
!endif    
!endif

$(OUTDIR)\dpmildr.obj: dpmildr.asm dpmildr.inc kernel16.inc version.inc trace.inc
	$(ASM) dpmildr.asm

$(OUTDIR)\kernel16.obj: kernel16.asm dpmildr.inc kernel16.inc version.inc trace.inc
	$(ASM) kernel16.asm

# create STUB16\DPMILD16.BIN

STUB16\$(NAME).BIN: STUB16\dpmildr.OBJ STUB16\kernel16.obj LIB16\ldr16.lib $(NAME).mak 
	@$(LINK16BIN) format dos file STUB16\dpmildr.obj, STUB16\kernel16.obj name $*.BIN 	op q, knoweas, map=$*.map lib $(LIBS)
	@copy $*.BIN ..\..\Bin\*.* >NUL
!ifdef TOOLSDIR
	@copy $*.BIN $(TOOLSDIR)\*.* >NUL
!endif

STUB16\dpmildr.obj: dpmildr.asm dpmildr.inc kernel16.inc version.inc trace.inc
	$(ASM) -D?STUB=1 dpmildr.asm

STUB16\kernel16.obj: kernel16.asm dpmildr.inc kernel16.inc version.inc trace.inc
	$(ASM) -D?STUB=1 kernel16.asm

# create STUBX16\HDLD16.BIN

STUBX16\HDLD16.BIN: STUBX16\dpmildr.OBJ $(OUTDIR)\kernel16.OBJ LIB16\ldr16.lib $(NAME).mak
#	link16 @<<
#	/KNOWEAS STUBX16\dpmildr.obj $(OUTDIR)\kernel16.obj, $*.BIN, $*.MAP, $(LIBS);
#<<
	@$(LINK16BIN) format dos file STUBX16\dpmildr.OBJ, $(OUTDIR)\kernel16.OBJ name $*.BIN op q, knoweas, map=$*.MAP lib $(LIBS)
	@copy $*.BIN ..\..\Bin\*.* >NUL
!ifdef TOOLSDIR
	@copy $*.BIN $(TOOLSDIR)\*.* >NUL
!endif

STUBX16\dpmildr.obj: dpmildr.asm dpmildr.inc peload.inc version.inc trace.inc ..\HDPMI\STUB16\HDPMI16.INC dpmild16.mak
	$(ASM) -D?STUB=1 -D?LOADDBGDLL=0 -D?SERVER=0 -D?HDPMI=1 dpmildr.asm

clean:
	@del $(OUTDIR)\*.exe
	@del $(OUTDIR)\*.obj
	@del $(OUTDIR)\*.lst
	@del $(OUTDIR)\*.map
	@del STUB16\*.bin
	@del STUB16\*.obj
	@del STUB16\*.lst
	@del STUB16\*.map
	@del STUBX16\*.bin
	@del STUBX16\*.obj
	@del STUBX16\*.lst
	@del STUBX16\*.map
