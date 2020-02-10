
# delete a module from libraries
# usage: nmake /f remove.mak pgm=xxx

S32LIB=dkrnl32s.lib

ALL:
   @cd RELEASE
   lib /OUT:$(S32LIB) /REMOVE:$(PGM).obj $(S32LIB)
   del $(PGM).*
   @cd ..
   @cd DEBUG
   lib /OUT:$(S32LIB) /REMOVE:$(PGM).obj $(S32LIB)
   del $(PGM).*
   @cd ..
   @cd OMF
   wlib $(LIBOMF)\$(S32LIB) -$(PGM)
   del $(PGM).*
   @cd ..
