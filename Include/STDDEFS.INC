
ifndef STDDEFS_DEFINED

STDDEFS_DEFINED equ 1

ifndef @Model
  @Model equ 0
endif

if @Model eq 7
  ifndef ?FLAT
?FLAT = 1
  endif
  if ?FLAT eq 0
%out definition ?FLAT/.flat inconsistent
.err
  endif
endif

ifndef ?DPMI16
?DPMI16 = 0
endif

if ?FLAT
  @flat   textequ <ds>
  if ?DPMI16
    %out ?DPMI16 and ?FLAT cannot be used together
    .err
  endif
else
  @flat   textequ <gs>
endif

if ?FLAT
?INDCALL = 1
else
?INDCALL = 0
endif

if ?INDCALL
func@0  typedef proto stdcall
func@4  typedef proto stdcall a1:dword
func@8  typedef proto stdcall a1:dword,a2:dword
func@12 typedef proto stdcall a1:dword,a2:dword,a3:dword
func@16 typedef proto stdcall a1:dword,a2:dword,a3:dword,a4:dword
func@20 typedef proto stdcall a1:dword,a2:dword,a3:dword,a4:dword,a5:dword
func@24 typedef proto stdcall a1:dword,a2:dword,a3:dword,a4:dword,a5:dword,a6:dword
func@28 typedef proto stdcall a1:dword,a2:dword,a3:dword,a4:dword,a5:dword,a6:dword,a7:dword
func@32 typedef proto stdcall a1:dword,a2:dword,a3:dword,a4:dword,a5:dword,a6:dword,a7:dword,a8:dword
func@36 typedef proto stdcall a1:dword,a2:dword,a3:dword,a4:dword,a5:dword,a6:dword,a7:dword,a8:dword,a9:dword
func@40 typedef proto stdcall a1:dword,a2:dword,a3:dword,a4:dword,a5:dword,a6:dword,a7:dword,a8:dword,a9:dword,a10:dword
func@44 typedef proto stdcall a1:dword,a2:dword,a3:dword,a4:dword,a5:dword,a6:dword,a7:dword,a8:dword,a9:dword,a10:dword,a11:dword
func@48 typedef proto stdcall a1:dword,a2:dword,a3:dword,a4:dword,a5:dword,a6:dword,a7:dword,a8:dword,a9:dword,a10:dword,a11:dword,a12:dword
cfunc@8v typedef proto c a1:dword,a2:dword,a3:vararg

pfunc@0  typedef ptr func@0
pfunc@4  typedef ptr func@4
pfunc@8  typedef ptr func@8
pfunc@12 typedef ptr func@12
pfunc@16 typedef ptr func@16
pfunc@20 typedef ptr func@20
pfunc@24 typedef ptr func@24
pfunc@28 typedef ptr func@28
pfunc@32 typedef ptr func@32
pfunc@36 typedef ptr func@36
pfunc@40 typedef ptr func@40
pfunc@44 typedef ptr func@44
pfunc@48 typedef ptr func@48
cpfunc@8v typedef ptr cfunc@8v
endif

endif

