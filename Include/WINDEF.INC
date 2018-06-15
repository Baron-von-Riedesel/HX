
ifndef _WINDEF_

_WINDEF_	EQU	<>

MAX_PATH	EQU	260

ifndef NULL
NULL	EQU	0
endif 

ifndef FALSE
FALSE	EQU	0
endif 

ifndef TRUE
TRUE	EQU	1
endif 

BOOL  typedef DWORD
FLOAT  typedef REAL4
PFLOAT  typedef ptr REAL4
PBOOL  typedef ptr BOOL
LPBOOL  typedef ptr BOOL
PBYTE  typedef ptr BYTE
LPBYTE  typedef ptr BYTE
PINT  typedef ptr DWORD
LPINT  typedef ptr DWORD
PWORD  typedef ptr WORD
LPWORD  typedef ptr WORD
LPLONG  typedef ptr SDWORD
PDWORD  typedef ptr DWORD
LPDWORD  typedef ptr DWORD
LPVOID  typedef ptr 
LPCVOID  typedef ptr 
UINT  typedef DWORD
PUINT  typedef ptr DWORD

ifndef NT_INCLUDED
	include winnt.inc
endif 

WPARAM  typedef DWORD
LPARAM  typedef SDWORD
LRESULT  typedef SDWORD

ATOM  typedef WORD

HFILE_ERROR	EQU	 -1

endif 
