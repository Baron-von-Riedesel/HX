
 1. About
 
 DOSXXX is an emulation of the 16-bit OS/2 API. It is used by HXDEV16
 to provide a 16-bit DOS extender for Open Watcom C/C++.
 
 The source modules are assembled and put into a OMF library, DOSXXXS.LIB.
 This library can then be used to link the emulation statically to an
 application. It is also used to create 16-bit NE dlls DOSCALLS.DLL, 
 NLS.DLL, VIOCALLS.DLL and KBDCALLS.DLL, which export the functions in the
 same way as OS/2 did. Thus it is possible to run valid 16-bit OS/2 binaries
 with HX's DPMILD16.

 
 2. Requirements
 
 The source usually is written for MASM, a 16-bit OMF linker is needed as
 well. Furthermore in DOSXXX.MAK a tool to create import libraries is
 required (IMPLIB). The makefiles are in NMAKE format.

 
 3. History

 04/2024:    DosCreateCSAlias added.
 
 01/17/2007: dosprocs.asm splitted into doshuge.asm and dosgetcp.asm.
             bugfix: implementation of DosGetCp() had wrong number of 
             parameters, it just returned with AX==0.
             time zone in DosGetTimeDate set to -1 (previously not set).
             bugfix: implementation of DosGetDBCSEv() might not have
             marked end of DBCS table with two zero bytes.
 
 12/14/2006: bugfix: some functions didn't preserve registers as expected
             (hint by ChowGuy).
             bugfix in DOSEXECPGM.
             bugfix: DOSSETSIGHANDLER reworked, didn't work previously.
             bugfix: DOSQCURDIR didn't work with a buffer size of 0.
             DOSSETVEC added (ChowGuy's contribution).
             DOSQFILEINFO, DOSSETFILEINFO, DOSDUPHANDLE added.
 
 09/18/2006: DOSGETDBCSEV returns 0, which is success,
             but didn't call anything

