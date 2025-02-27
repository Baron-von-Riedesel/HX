
# create clock.obj; that's a replacement for Watcom's clock()
# function, with a resolution of 1ms instead of 55ms.

!include <..\dirs>

OWDIR=\watcom

OUTOW20=rel_20
INPOW20=src_20

#ASMOPT= -c -nologo -Sg -Fl$* -Fo$* -D?FLAT=0
WASMOPT= -q -bt=DOS -ms -3r -fo=$*.OBJ 

ALL: $(OUTOW20) $(OUTOW20)\CLOCK.OBJ

#-------------------------------------------------------------------------

$(OUTOW20):
	@mkdir $(OUTOW20)

# jwasm options -Gr and -zf1 select Watcom calling convention

$(OUTOW20)\CLOCK.OBJ: $(INPOW20)\clock.asm
	@jwasm -q -Gr -zf1 -Fo$* -Fl$* $(INPOW20)\clock.asm

clean:
	@del $(OUTOW20)\clock.obj

install:
	copy $(OUTOW20)\clock.obj $(OWDIR)\lib386\DOS
