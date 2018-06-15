        pushcontext listing
        .nolist
        .nocref

MAX_MODULE_NAME32 equ 255

ifdef _KERNEL32_
?INDCALL_ = 0
elseif ?INDCALL eq 0
?INDCALL_ = 0
else
?INDCALL_ = 1
endif

if ?INDCALL_ eq 0

CreateToolhelp32Snapshot proto near stdcall dwFlags:dword, th32ProcessID:dword
Heap32ListFirst          proto near stdcall HANDLE:dword,LPHEAPLIST32:dword
Heap32ListNext           proto near stdcall HANDLE:dword,LPHEAPLIST32:dword
Heap32First              proto near stdcall LPHEAPENTRY32:dword,th32ProcessID:dword,th32HeapID:dword
Heap32Next               proto near stdcall LPHEAPENTRY32:dword
Process32First           proto near stdcall HANDLE:dword,LPPROCESSENTRY32:dword
Process32Next            proto near stdcall HANDLE:dword,LPPROCESSENTRY32:dword
Thread32First            proto near stdcall hSnapshot:dword,LPTHREADENTRY32:dword
Thread32Next             proto near stdcall hSnapshot:dword,LPTHREADENTRY32:dword
Module32First            proto near stdcall HANDLE:dword,LPMODULEENTRY32:dword
Module32Next             proto near stdcall HANDLE:dword,LPMODULEENTRY32:dword

else

externdef stdcall _imp__CreateToolhelp32Snapshot@8  :pfunc@8
externdef stdcall _imp__Heap32ListFirst@8           :pfunc@8
externdef stdcall _imp__Heap32ListNext@8            :pfunc@8
externdef stdcall _imp__Heap32First@12              :pfunc@12
externdef stdcall _imp__Heap32Next@4                :pfunc@4
externdef stdcall _imp__Process32First@8            :pfunc@8
externdef stdcall _imp__Process32Next@8             :pfunc@8
externdef stdcall _imp__Thread32First@8             :pfunc@8
externdef stdcall _imp__Thread32Next@8              :pfunc@8
externdef stdcall _imp__Module32First@8             :pfunc@8
externdef stdcall _imp__Module32Next@8              :pfunc@8

CreateToolhelp32Snapshot equ <_imp__CreateToolhelp32Snapshot@8>
Heap32ListFirst          equ <_imp__Heap32ListFirst@8>
Heap32ListNext           equ <_imp__Heap32ListNext@8>
Heap32First              equ <_imp__Heap32First@12>
Heap32Next               equ <_imp__Heap32Next@4>
Process32First           equ <_imp__Process32First@8>
Process32Next            equ <_imp__Process32Next@8>
Thread32First            equ <_imp__Thread32First@8>
Thread32Next             equ <_imp__Thread32Next@8>
Module32First            equ <_imp__Module32First@8>
Module32Next             equ <_imp__Module32Next@8>

endif

;/
;/ The th32ProcessID argument is only used if TH32CS_SNAPHEAPLIST or
;/ TH32CS_SNAPMODULE is specified. th32ProcessID == 0 means the current
;/ process.
;/
;/ NOTE that all of the snapshots are global except for the heap and module
;/      lists which are process specific. To enumerate the heap or module
;/      state for all WIN32 processes call with TH32CS_SNAPALL and the
;/      current process. Then for each process in the TH32CS_SNAPPROCESS
;/      list that isn't the current process, do a call with just
;/      TH32CS_SNAPHEAPLIST and/or TH32CS_SNAPMODULE.

;/ dwFlags

TH32CS_SNAPHEAPLIST equ 00000001h
TH32CS_SNAPPROCESS  equ 00000002h
TH32CS_SNAPTHREAD   equ 00000004h
TH32CS_SNAPMODULE   equ 00000008h
TH32CS_SNAPALL      equ TH32CS_SNAPHEAPLIST or TH32CS_SNAPPROCESS or TH32CS_SNAPTHREAD or TH32CS_SNAPMODULE
TH32CS_INHERIT      equ 80000000h

;// Use CloseHandle to destroy the snapshot

;/****** heap walking ***************************************************/

HEAPLIST32 struct
dwSize            DWORD ?   ;
th32ProcessID     DWORD ?   ;/ owning process
th32HeapID        DWORD ?   ;/ heap (in owning process's context!)
dwFlags           DWORD ?   ;
HEAPLIST32 ends

LPHEAPLIST32 typedef ptr HEAPLIST32

; dwFlags

HF32_DEFAULT      equ 1  ;// process's default heap
HF32_SHARED       equ 2  ;// is shared heap

;BOOL WINAPI Heap32ListFirst(HANDLE hSnapshot, LPHEAPLIST32 lphl);
;BOOL WINAPI Heap32ListNext(HANDLE hSnapshot, LPHEAPLIST32 lphl);

HEAPENTRY32 struct
dwSize            DWORD  ?;
hHandle           DWORD  ?; Handle of this heap block
dwAddress         DWORD  ?; Linear address of start of block
dwBlockSize       DWORD  ?; Size of block in bytes
dwFlags           DWORD  ?;
dwLockCount       DWORD  ?;
dwResvd           DWORD  ?;
th32ProcessID     DWORD  ?;  // owning process
th32HeapID        DWORD  ?;  // heap block is in
HEAPENTRY32 ends

LPHEAPENTRY32 typedef ptr HEAPENTRY32

;// dwFlags

LF32_FIXED    equ 00000001h
LF32_FREE     equ 00000002h
LF32_MOVEABLE equ 00000004h

;BOOL WINAPI Heap32First(LPHEAPENTRY32 lphe, DWORD th32ProcessID,
;                        DWORD th32HeapID);
;BOOL WINAPI Heap32Next(LPHEAPENTRY32 lphe);
;BOOL WINAPI Toolhelp32ReadProcessMemory(DWORD   th32ProcessID,
;                                       LPCVOID lpBaseAddress,
;                                       LPVOID  lpBuffer,
;                                       DWORD   cbRead,
;                                       LPDWORD lpNumberOfBytesRead);


;/***** Process walking *************************************************/

PROCESSENTRY32 struct
dwSize                  DWORD ?     ;
cntUsage                DWORD ?     ;
th32ProcessID           DWORD ?     ;/ this process
th32DefaultHeapID       DWORD ?     ;
th32ModuleID            DWORD ?     ;/ associated exe
cntThreads              DWORD ?     ;
th32ParentProcessID     DWORD ?     ;/ this process's parent process
pcPriClassBase          SDWORD ?    ;/ Base priority of process's threads
dwFlags                 DWORD ?     ;
szExeFile               SBYTE MAX_PATH DUP (?)
PROCESSENTRY32 ends

LPPROCESSENTRY32 typedef ptr PROCESSENTRY32

;/***** Thread walking **************************************************/

THREADENTRY32 struct
dwSize                DWORD ? ;
cntUsage              DWORD ? ;
th32ThreadID          DWORD ? ; // this thread
th32OwnerProcessID    DWORD ? ; // Process this thread is associated with
tpBasePri             DWORD ? ;
tpDeltaPri            DWORD ? ;
dwFlags               DWORD ? ;
THREADENTRY32 ends

;/***** Module walking *************************************************/

MODULEENTRY32 struct
dwSize            DWORD ?      ;
th32ModuleID      DWORD ?      ;// This module
th32ProcessID     DWORD ?      ;// owning process
GlblcntUsage      DWORD ?      ;// Global usage count on the module
ProccntUsage      DWORD ?      ;// Module usage count in th32ProcessID's context
modBaseAddr       DWORD ?      ;// Base address of module in th32ProcessID's context
modBaseSize       DWORD ?      ;// Size in bytes of module starting at modBaseAddr
hModule           DWORD ?      ;// The hModule of this module in th32ProcessID's context
szModule          SBYTE MAX_MODULE_NAME32 + 1 DUP (?)
szExePath         SBYTE MAX_PATH DUP (?)
MODULEENTRY32 ends

        popcontext listing
