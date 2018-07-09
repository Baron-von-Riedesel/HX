
# nmake makefile, creates various HDPMI16.EXE versions:
# - the (old) "standard" version with host stack in conv. memory
# - the "nolfn" version with LFN API translation support disabled
# - the "enhanced" version with some Win16 enhanced features enabled
#   attached to the client binary.
# tools:
# - JWasm | Masm
# - WLib (Open Watcom) | MS OMF lib (lib16.exe)
# - JWLink (modified WLink v1.8)

!include <..\dirs>

!ifndef DEBUG
DEBUG = 0
!endif

!ifndef MASM
MASM=0
!endif

!if $(DEBUG)
AOPTD=-Zi -D_DEBUG
LOPTD=/LI
!endif

SRCMODS = \
!include modules.inc
OBJNAMES = $(SRCMODS:.ASM=.OBJ)
!if $(DEBUG)
OBJMODS = $(OBJNAMES:.\=HSCM16D\)
!else
OBJMODS = $(OBJNAMES:.\=HSCM16\)
!endif

# if VALX is used, but make sure version is >= 3.7.1.4.
# MS link also works, but then it is recommended to activate the line
# containing SHRMZHDR.EXE to reduce size of binary.
# digital mars linker has problems with segment ordering

!if $(DEBUG)
LINKER = 1
!else
LINKER = 1
!endif

!if $(LINKER)==2
LINK  = link16.exe
LOPT  = /NOLOGO/FAR/MAP:FULL/NOE/NOI/NON/ONERROR:NOEXE $(LOPTD)
!elseif $(LINKER)==3
LINK  = $(DMCDIR)\link.exe
LOPT  = /NOLOGO/FAR/MAP:FULL/NOREO/NOI/NOE/NON/ONERROR:NOEXE $(LOPTD)
!elseif $(LINKER)==4
LINK  = c:\qlink\qlink.exe
LOPT  = /NOLOGO/FAR/MAP:FULL/NOI/NOE/NON/ONERROR:NOEXE $(LOPTD)
!elseif $(LINKER)==5
LINK  = valx.exe
LOPT  = /NCI /32 /MAP /DET:2
!else
LINK  = jwlink.exe
LOPT  = format DOS
!endif

!if $(LINKER)==1
LCMDS1=$(LOPT) file $(OUTSTD)\$(SRC).obj name $*.EXE op q, map=$*.MAP, stack=0 lib $(OUTSTD)\$(NAME).lib
LCMDS2=$(LOPT) file {$(OUTSTD)\$(SRC).obj $(OUTNOLFN)\INT21API.obj} name $*.EXE op q, map=$*.MAP, stack=0 lib $(OUTSTD)\$(NAME).lib
LCMDS3=$(LOPT) file {$(OUTENH)\$(SRC).obj $(OUTENH)\INT2FAPI.obj $(OUTENH)\INT31API.obj $(OUTENH)\vxd.obj} name $*.EXE op q, map=$*.MAP, stack=0 lib $(OUTSTD)\$(NAME).lib
!else
LCMDS1=$(LOPT) $(OUTSTD)\$(SRC).obj, $*.EXE, $*.MAP, $(OUTSTD)\$(NAME).lib;
LCMDS2=$(LOPT) $(OUTSTD)\$(SRC).obj $(OUTNOLFN)\INT21API.obj, $*.EXE, $*.MAP, $(OUTSTD)\$(NAME).lib;
LCMDS3=$(LOPT) $(OUTENH)\hdpmi.obj $(OUTENH)\INT2FAPI.obj $(OUTENH)\INT31API.obj $(OUTENH)\vxd.obj , $*.EXE, $*.MAP, $(OUTSTD)\$(NAME).lib;
!endif

AOPT= -nologo -c -Cp -Sg -D?32BIT=0 -D?HSINEXTMEM=0 $(AOPTD) -I$(INC32DIR) -Fl$* -Fo$*

!if $(MASM)
ASM=@ml.exe
!else
ASM=@jwasm.exe
!endif

NAME  = HDPMI16
SRC   = hdpmi

DEPS0 = hdpmi.inc external.inc version.inc

!if $(DEBUG)
OUTSTD=HSCM16D
OUTNOLFN=NOLFN16D
OUTENH=ENH16D
!else
OUTSTD=HSCM16
OUTNOLFN=NOLFN16
OUTENH=ENH16
!endif

.SUFFIXES: .asm .obj

.asm{$(OUTSTD)}.obj:
	$(ASM) $(AOPT) $<

ALL: $(OUTSTD) $(OUTNOLFN) $(OUTENH) $(OUTSTD)\$(NAME).EXE $(OUTNOLFN)\$(NAME).EXE $(OUTENH)\$(NAME).EXE

$(OBJMODS): $(DEPS0)

$(OUTSTD):
	@mkdir $(OUTSTD)

$(OUTNOLFN):
	@mkdir $(OUTNOLFN)

$(OUTENH):
	@mkdir $(OUTENH)

# create the standard version

$(OUTSTD)\$(NAME).EXE: $(OUTSTD)\$(SRC).obj $(OUTSTD)\$(NAME).lib $(NAME)a.mak $(OUTNOLFN)\int21api.obj 
	$(LINK) @<<
$(LCMDS1)
<<
!if $(LINKER)==2
	@..\..\BIN\SHRMZHDR.EXE $*.exe
!endif     
	@..\..\BIN\SETMZHDR.EXE -q $*.EXE
!if $(DEBUG)==0
#	@copy $*.EXE ..\..\Bin\*.* >NUL
!endif

$(OUTSTD)\$(NAME).lib: $(OBJMODS) $(NAME)a.mak
	@cd $(OUTSTD)
	@$(LIB16BIN) $(NAME).lib $(OBJNAMES:.\=+)
	@cd ..

# create the "no LFN" version

$(OUTNOLFN)\$(NAME).EXE: $(OUTSTD)\$(SRC).obj $(OUTNOLFN)\INT21API.obj $(OUTSTD)\$(NAME).lib $(NAME)a.mak
	$(LINK) @<<
$(LCMDS2)
<<
!if $(LINKER)==2
	@..\..\BIN\SHRMZHDR.EXE -d $*.EXE
!endif    
	@..\..\BIN\SETMZHDR.EXE -q $*.EXE

$(OUTNOLFN)\INT21API.obj: INT21API.asm $(DEPS0)
	$(ASM) $(AOPT) -D?LFNSUPPORT=0 INT21API.asm

# create the "windows enhanced mode" version

$(OUTENH)\$(NAME).exe: $(OUTENH)\hdpmi.obj $(OUTENH)\int2fapi.obj $(OUTENH)\int31api.obj $(OUTENH)\vxd.obj $(OUTSTD)\$(NAME).lib $(NAME)a.mak
	$(LINK) @<<
$(LCMDS3)
<<
!if $(LINKER)==2
	@..\..\BIN\SHRMZHDR.EXE $*.EXE
!endif
	@..\..\BIN\SETMZHDR.EXE -q $*.EXE
#!if $(DEBUG)==0    
#	@copy $*.EXE ..\..\Unsupp
#!endif     

$(OUTENH)\hdpmi.obj: hdpmi.asm $(DEPS0)
	$(ASM) $(AOPT) -D?ENHANCED=1 hdpmi.asm

$(OUTENH)\INT2FAPI.obj: INT2FAPI.asm $(DEPS0)
	$(ASM) $(AOPT) -D?ENHANCED=1 INT2FAPI.asm

$(OUTENH)\INT31API.obj: INT31API.asm $(DEPS0)
	$(ASM) $(AOPT) -D?ENHANCED=1 INT31API.asm

$(OUTENH)\vxd.obj: vxd.asm $(DEPS0)
	$(ASM) $(AOPT) -D?ENHANCED=1 vxd.asm

clean:
	@del $(OUTSTD)\*.obj
	@del $(OUTSTD)\*.lib
	@del $(OUTSTD)\*.exe
	@del $(OUTSTD)\*.map
	@del $(OUTSTD)\*.lst
	@del $(OUTNOLFN)\*.exe
	@del $(OUTNOLFN)\*.obj
	@del $(OUTNOLFN)\*.lst
	@del $(OUTNOLFN)\*.map
	@del $(OUTENH)\*.obj
	@del $(OUTENH)\*.exe
	@del $(OUTENH)\*.map
	@del $(OUTENH)\*.lst
