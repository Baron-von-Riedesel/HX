
# nmake makefile, creates 2 HDPMI32.EXE versions:
#  - the "old" standard version with host stack in conventional memory.
#  - the "nolfn" version with LFN API translation disabled.
# tools used:
#  - JWasm | Masm
#  - JWLib | WLib (Open Watcom) | MS OMF LIB (lib16.exe)
#  - JWLink v1.8x
#  - extrsect.exe, converts stub binary to assembly include file 
#  - setmzhdr.exe, modifies exe so:
#       - dos will load the 16-bit part only
#       - stack size will be 200h
#  - shrmzhdr.exe, shrinks MZ header, used only if MS link is used.

# The current version of the HDPMI binary is a challenge for
# all linkers, because it requires full control over segment ordering
# and stack size.That's why most linkers will fail.
# if VALX or MS Link is to be used, adjust stack class in HDPMI.ASM!

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
!ifdef 386SWAT
AOPTD=$(AOPTD) -D?386SWAT=1
!endif
!endif

SRCMODS = \
!include modules.inc
OBJNAMES = $(SRCMODS:.ASM=.OBJ)
!if $(DEBUG)
#CP = 0	;what's that?
OBJMODS = $(OBJNAMES:.\=HSCM32D\)
!else
#CP = 1
OBJMODS = $(OBJNAMES:.\=HSCM32\)
!endif

!if $(DEBUG)
LINKER = 1
!else
LINKER = 1
!endif

# 1: JWLink:
# 2: MS link works , but header size is 200h bytes, that's why SHRMZHDR
#    is called after the link step.
# 3: digital mars OPTLINK won't work. it has problems with segment ordering.
# 4: qlink won't work, some relocation targets are wrong
# 5: VALX works, but make sure version is >= 3.7.1.4.

!if $(LINKER)==2
LINK  = link16.exe
LOPT  = /NOLOGO/MAP:FULL/NOI/NOE/NON/ONERROR:NOEXE $(LOPTD)
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

HSMODS=$(OUTHSEXT)\$(SRC).obj $(OUTHSEXT)\init.obj $(OUTHSEXT)\switch.obj $(OUTHSEXT)\i31swt.obj

# JWLink has a somewhat strange cmdline syntax
!if $(LINKER)==1
LCMDS1=$(LOPT) file $(OUTHSCM)\$(SRC).obj name $*.EXE op q, map=$*.MAP, stack=0 lib $(OUTHSCM)\$(NAME).lib
LCMDS2=$(LOPT) file {$(OUTHSCM)\$(SRC).obj $(OUTNOLFN)\INT21API.obj} name $*.EXE op q, map=$*.MAP, stack=0 lib $(OUTHSCM)\$(NAME).lib
!else
LCMDS1=$(LOPT) $(OUTHSCM)\$(SRC).obj, $*.EXE, $*.MAP, $(OUTHSCM)\$(NAME).lib;
LCMDS2=$(LOPT) $(OUTHSCM)\$(SRC).obj $(OUTNOLFN)\INT21API.obj, $*.EXE, $*.MAP, $(OUTHSCM)\$(NAME).lib;
!endif

AOPT= -nologo -c -Cp -Sg -D?32BIT=1 -D?HSINEXTMEM=0 $(AOPTD) -I$(INC32DIR) -Fl$* -Fo$*

!if $(MASM)
ASM = ml.exe
!else
ASM = jwasm.exe
!endif

NAME  = HDPMI32
SRC   = hdpmi

DEPS0 = hdpmi.inc external.inc version.inc

!if $(DEBUG)
OUTHSCM=HSCM32D
OUTNOLFN=NOLFN32D
!else
OUTHSCM=HSCM32
OUTNOLFN=NOLFN32
!endif

.SUFFIXES: .asm .obj

.asm{$(OUTHSCM)}.obj:
	@$(ASM) $(AOPT) $<

# the following versions are created:
# 1. HSCM32:  "old" standard version with host stack in conv. memory
# 2. NOLFN32: non-LFN version

TARGET1=$(OUTHSCM)\$(NAME).EXE 
TARGET2=$(OUTNOLFN)\$(NAME).EXE 

ALL: $(OUTHSCM) $(OUTNOLFN) $(TARGET1) $(TARGET2)

$(OUTHSCM):
	@mkdir $(OUTHSCM)

$(OUTNOLFN):
	@mkdir $(OUTNOLFN)

$(OBJMODS): $(DEPS0)

# create the standard version

$(OUTHSCM)\$(NAME).EXE: $(OUTHSCM)\$(SRC).obj $(OUTHSCM)\$(NAME).lib $(NAME)a.mak
	$(LINK) @<<
$(LCMDS1)
<<
!if $(LINKER)==2
	@..\..\BIN\SHRMZHDR.EXE -d $*.EXE
!endif
	@..\..\BIN\SETMZHDR.EXE -q $*.EXE
#!if $(DEBUG)==0
	@copy $*.EXE ..\..\UNSUPP\*.* >NUL
#!endif     

$(OUTHSCM)\$(NAME).lib: $(OBJMODS) $(NAME)a.mak
	@cd $(OUTHSCM)
	@$(LIB16BIN) $(NAME).lib $(OBJNAMES:.\=+)
	@jwlib -q $(NAME).lib -$(SRC).OBJ
	@cd ..

# create the "no LFN" version

$(OUTNOLFN)\$(NAME).EXE: $(OUTHSCM)\$(SRC).obj $(OUTNOLFN)\INT21API.obj $(OUTHSCM)\$(NAME).lib $(NAME)a.mak
	$(LINK) @<<
$(LCMDS2)
<<
!if $(LINKER)==2
	@..\..\BIN\SHRMZHDR.EXE -d $*.EXE
!endif    
	@..\..\BIN\SETMZHDR.EXE -q $*.EXE

$(OUTNOLFN)\INT21API.obj: INT21API.asm $(DEPS0)
	$(ASM) $(AOPT) -D?LFNSUPPORT=0 INT21API.asm

clean:
	@del $(OUTHSCM)\*.obj
	@del $(OUTHSCM)\*.lib
	@del $(OUTHSCM)\*.exe
	@del $(OUTHSCM)\*.lst
	@del $(OUTHSCM)\*.map
	@del $(OUTNOLFN)\*.obj
	@del $(OUTNOLFN)\*.exe
	@del $(OUTNOLFN)\*.lst
	@del $(OUTNOLFN)\*.map
