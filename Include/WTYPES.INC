
ifndef __wtypes_h__
__wtypes_h__ equ <>

ifndef FALSE
FALSE	EQU	0
TRUE	EQU	1
endif 

UINT  typedef DWORD
BOOL  typedef DWORD
WPARAM  typedef DWORD
LPARAM  typedef SDWORD
LRESULT  typedef SDWORD
HANDLE  typedef ptr 
HMODULE  typedef ptr 
HINSTANCE  typedef ptr 
HRGN  typedef ptr 
HTASK  typedef ptr 
HKEY  typedef ptr 
HDESK  typedef ptr 
HMF  typedef ptr 
HEMF  typedef ptr 
HPEN  typedef ptr 
HRSRC  typedef ptr 
HSTR  typedef ptr 
HWINSTA  typedef ptr 
HKL  typedef ptr 
HGDIOBJ  typedef ptr 
HDWP  typedef HANDLE
HFILE  typedef DWORD
HDC		typedef ptr

endif
