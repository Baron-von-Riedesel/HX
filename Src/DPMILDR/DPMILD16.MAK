
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
ODIR1 = STD16D
ODIR2 = STUB16D
ODIR3 = STUBX16D
!else
ODIR1 = STD16
ODIR2 = STUB16
ODIR3 = STUBX16
!endif

!include <..\dirs>

NAME  = DPMILD16
LIBS  = LIB16\ldr16.lib
MODS1 = $(ODIR1)\dpmildr.obj $(ODIR1)\kernel16.obj
MODS2 = $(ODIR2)\dpmildr.obj $(ODIR2)\kernel16.obj
MODS3 = $(ODIR3)\dpmildr.obj $(ODIR3)\kernel16.obj
INCTR =
!if $(DEBUG)
MODS1  = $(MODS1) $(ODIR1)\trace.obj
MODS2  = $(MODS2) $(ODIR2)\trace.obj
MODS3  = $(MODS3) $(ODIR3)\trace.obj
INCTR  = trace.inc
!endif

!ifndef MASM
MASM=0
!endif

AOPT = -c -Sg -Fl$* -Fo$* -nologo -D?32BIT=0 -D?DEBUG=$(DEBUG) -I..\..\Include

!if $(MASM)
ASM   = @ml.exe $(AOPT)
!else
ASM   = @jwasm.exe $(AOPT)
!endif

ALL: $(ODIR1) $(ODIR2) $(ODIR3) $(ODIR1)\$(NAME).EXE $(ODIR2)\$(NAME).BIN $(ODIR3)\HDLD16.BIN

$(ODIR1):
	@mkdir $(ODIR1)

$(ODIR2):
	@mkdir $(ODIR2)

$(ODIR3):
	@mkdir $(ODIR3)

# create $(ODIR1)\DPMILD16.EXE

$(ODIR1)\$(NAME).EXE: $(MODS1) LIB16\ldr16.lib $(NAME).mak 
	@$(LINK16BIN) format dos file {$(MODS1)} name $*.EXE op q, map=$*.map lib $(LIBS)
!if $(DEBUG)==0
	@copy $*.EXE ..\..\bin >NUL
!ifdef TOOLSDIR    
	@copy $*.EXE $(TOOLSDIR)\$(NAME).EXE >NUL
!endif    
!endif

$(ODIR1)\dpmildr.obj: dpmildr.asm dpmildr.inc kernel16.inc version.inc $(INCTR)
	$(ASM) dpmildr.asm

$(ODIR1)\kernel16.obj: kernel16.asm dpmildr.inc kernel16.inc version.inc $(INCTR)
	$(ASM) kernel16.asm

$(ODIR1)\trace.obj: trace.asm dpmildr.inc trace.inc
	$(ASM) trace.asm

# create STUB16\DPMILD16.BIN

$(ODIR2)\$(NAME).BIN: $(MODS2) LIB16\ldr16.lib $(NAME).mak 
	@$(LINK16BIN) format dos file {$(MODS2)} name $*.BIN op q, knoweas, map=$*.map lib $(LIBS)
!if $(DEBUG)==0
	@copy $*.BIN ..\..\Bin\*.* >NUL
!ifdef TOOLSDIR
	@copy $*.BIN $(TOOLSDIR)\*.* >NUL
!endif
!endif

$(ODIR2)\dpmildr.obj: dpmildr.asm dpmildr.inc kernel16.inc version.inc $(INCTR)
	$(ASM) -D?STUB=1 dpmildr.asm

$(ODIR2)\kernel16.obj: kernel16.asm dpmildr.inc kernel16.inc version.inc $(INCTR)
	$(ASM) -D?STUB=1 kernel16.asm

$(ODIR2)\trace.obj: trace.asm dpmildr.inc trace.inc
	$(ASM) trace.asm

# create $(ODIR3)\HDLD16.BIN

$(ODIR3)\HDLD16.BIN: $(MODS3) LIB16\ldr16.lib $(NAME).mak
#	link16 @<<
#	/KNOWEAS $(MODS3), $*.BIN, $*.MAP, $(LIBS);
#<<
	@$(LINK16BIN) format dos file {$(MODS3)} name $*.BIN op q, knoweas, map=$*.MAP lib $(LIBS)
!if $(DEBUG)==0
	@copy $*.BIN ..\..\Bin\*.* >NUL
!ifdef TOOLSDIR
	@copy $*.BIN $(TOOLSDIR)\*.* >NUL
!endif
!endif

$(ODIR3)\dpmildr.obj: dpmildr.asm dpmildr.inc peload.inc version.inc ..\HDPMI\STUB16\HDPMI16.INC $(INCTR)
	$(ASM) -D?STUB=1 -D?LOADDBGDLL=0 -D?SERVER=0 -D?HDPMI=1 dpmildr.asm

$(ODIR3)\kernel16.obj: kernel16.asm dpmildr.inc kernel16.inc version.inc $(INCTR)
	$(ASM) -D?STUB=1 kernel16.asm

$(ODIR3)\trace.obj: trace.asm dpmildr.inc trace.inc
	$(ASM) trace.asm

clean:
	@del $(ODIR1)\*.exe
	@del $(ODIR1)\*.obj
	@del $(ODIR1)\*.lst
	@del $(ODIR1)\*.map
	@del $(ODIR2)\*.bin
	@del $(ODIR2)\*.obj
	@del $(ODIR2)\*.lst
	@del $(ODIR2)\*.map
	@del $(ODIR3)\*.bin
	@del $(ODIR3)\*.obj
	@del $(ODIR3)\*.lst
	@del $(ODIR3)\*.map
