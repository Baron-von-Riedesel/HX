
;--- Win64 PE

IMAGE_FILE_MACHINE_AMD64    EQU 8664h

IMAGE_OPTIONAL_HEADER64 struct 
Magic                       WORD    ?
MajorLinkerVersion          BYTE    ?
MinorLinkerVersion          BYTE    ?
SizeOfCode                  DWORD   ?
SizeOfInitializedData       DWORD   ?
SizeOfUninitializedData     DWORD   ?
AddressOfEntryPoint         DWORD   ?
BaseOfCode                  DWORD   ?
ImageBase                   QWORD   ?
SectionAlignment            DWORD   ?
FileAlignment               DWORD   ?
MajorOperatingSystemVersion WORD    ?
MinorOperatingSystemVersion WORD    ?
MajorImageVersion           WORD    ?
MinorImageVersion           WORD    ?
MajorSubsystemVersion       WORD    ?
MinorSubsystemVersion       WORD    ?
Win32VersionValue           DWORD   ?
SizeOfImage                 DWORD   ?
SizeOfHeaders               DWORD   ?
CheckSum                    DWORD   ?
Subsystem                   WORD    ?
DllCharacteristics          WORD    ?
SizeOfStackReserve          QWORD   ?
SizeOfStackCommit           QWORD   ?
SizeOfHeapReserve           QWORD   ?
SizeOfHeapCommit            QWORD   ?
LoaderFlags                 DWORD   ?
NumberOfRvaAndSizes         DWORD   ?
DataDirectory   IMAGE_DATA_DIRECTORY IMAGE_NUMBEROF_DIRECTORY_ENTRIES dup (<>)
IMAGE_OPTIONAL_HEADER64 ends

