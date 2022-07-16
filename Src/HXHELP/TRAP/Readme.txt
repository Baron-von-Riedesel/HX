
  1. Adjustments

  The only thing that has to be adjusted for HX is dosxlink.c:
  
  Location 1:

#elif defined(HX)
    #define EXTENDER_NAMES  "HXHELP.EXE\0"
    #define HELPNAME        "HXHELP.EXE"
#else

 Location 2:

#if defined(DOS4G) || defined(CAUSEWAY) || defined(HX)
    #define LINK_VECTOR     0x06

  2. create HX.TRP ( and HX16.TRP)

  The Makefile should be copied into a newly create directory
  bld\trap\lcl\dos\dosx\hx\dos.trp. Then run wmake
