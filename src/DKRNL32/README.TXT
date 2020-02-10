
 1. About
 
 This is the source code for DKRNL32.DLL, an emulation
 of KERNEL32.DLL for DPMI clients. It will only work in conjunction
 with DPMILD32.EXE, since it relies on the PE loading mechanisms
 implemented there.
 
 What is supported:
 
 - File Functions
 - Console Functions
 - Heap Functions
 - Dynamic Linking
 - File Mapping Functions
 - LFN (DPMI host must supply API translation - except for NT platforms)
 - Threads and Synchronization (doesn't work on NT platforms)
 - Structured Exception Handling (SEH)
 - Virtual Memory (fully supported if DPMI host has V1.0 memory functions)
 - Time Zones (environment variable TZ must be set)
 
 What is not supported:
 
 - Debugging API
 - Multiple Processes running concurrently


 2. Creating the Binary
 
 To create the binary launch nmake.
 To create a debug version enter "nmake debug=1". This version
 will display lots of messages to the console. By setting environment
 variable DKRNLLOG=<filename> output can be redirected to a file.

 Please read comments in MAKEFILE first, in case some adjustments have
 to be made.

 If you want to add a new source module, do these steps

 1. enter a new line in MODULES.INC with the name of your new module
 2. enter the names of the new functions to be exported in KERNEL32.DEF
 3. launch nmake


 3. Source Module Description

 The following is a description of the source files, but may not always
 be totally up to date.


Win32 API emulated:

Module       Type      Functions
-------------------------------------------------
ALLCCONS.ASM CONSOLE   AllocConsole
                       FreeConsole
APIX.ASM     DEVICE    implements APIX device
ATOMS.ASM    ATOM      AddAtomA
                       DeleteAtom
                       GetAtomNameA
                       FindAtomA
ATTRIBS.ASM  FILE      GetFileAttributesA
                       GetFileAttributesExA
                       GetFileAttributesW
                       SetFileAttributesA
                       SetFileAttributesW
BACKUP.ASM   FILE      BackupRead
                       BackupSeek
BEEP.ASM     HELP      Beep
CANCELIO.ASM FILE      CancelIo
CLOSEHDL.ASM FILE      CloseHandle
CMPSTR.ASM   HELP      CompareStringA
                       CompareStringW
CONATTR.ASM  CONSOLE   ReadConsoleOutputAttribute
                       WriteConsoleOutputAttribute
CONTITLE.ASM CONSOLE   GetConsoleTitleA
COPYFILE.ASM FILE      CopyFileA
                       CopyFileW
CREATFIL.ASM FILE      CreateFileA
                       CreateFileW
CRITSECT.ASM THREAD    EnterCriticalSection
                       LeaveCriticalSection
                       InitializeCriticalSection
                       InitializeCriticalSectionAndSpinCount
                       DeleteCriticalSection
CSRPROCS.ASM CONSOLE   SetConsoleCursorPosition
                       SetConsoleCursorInfo
                       GetConsoleCursorInfo
DBGBREAK.ASM DEBUG     DebugBreak
DBGSUPP.ASM  DEBUG     WaitForDebugEvent
                       ContinueDebugEvent
                       GetThreadContext
                       SetThreadContext
                       GetThreadSelectorEntry
                       DebugActiveProcess
DELFILE.ASM  FILE      DeleteFileA
                       DeleteFileW
DEVICEIO.ASM           DeviceIoControl
DIRECT.ASM   DIR       CreateDirectoryA
                       CreateDirectoryW
                       RemoveDirectoryA
                       RemoveDirectoryW
DISK.ASM     DASD      GetDiskFreeSpaceA
                       GetDiskFreeSpaceExA
DISTHRLC.ASM THREAD    DisableThreadLibraryCalls
DOSDATE.ASM  TIME      DosDateTimeToFileTime
                       FileTimeToDosDateTime
DUPLICAT.ASM FILE      DuplicateHandle
EVENT.ASM    THREAD    CreateEventA
                       OpenEventA
                       SetEvent
                       ResetEvent
EXCEPT.ASM   EXCEPTION RaiseException
                       SetUnhandledExceptionFilter
                       UnhandledExceptionFilter
                       InitException (set DPMI exception handlers)
                       ExitException (reset DPMI exception handlers)
EXITPROC.ASM PROCESS   ExitProcess
EXPENVS.ASM  PROCESS   ExpandEnvironmentStringsA
                       ExpandEnvironmentStringsW
FATEXIT.ASM  PROCESS   FatalAppExitA
FILEAPIS.ASM           SetFileApiToOEM
                       SetFileApiToANSI
                       AreFileApisANSI
FILEMAPP.ASM FILE      CreateFileMappingA
                       MapViewOfFileEx
                       MapViewOfFile
                       UnmapViewOfFile
                       FlushViewOfFile
FILETIME.ASM TIME      FileTimeToSystemTime
                       SystemTimeToFileTime
                       FileTimeToLocalFileTime
                       LocalFileTimeToFileTime
FILLCONS.ASM CONSOLE   FillConsoleOutputAttribute
                       FillConsoleOutputCharacterA
FILLMEM.ASM  MEM       RtlFillMemory
                       RtlZeroMemory
                       RtlMoveMemory
FINDRES      RESOURCE  FindResourceA
                       FindResourceExA
                       FindResourceW
                       LoadResource
                       SizeOfResource
FLUSHFB.ASM  FILE      FlushFileBuffers
FNDFILE.ASM  FILE      FindFirstFileA
                       FindNextFileA
                       FindClose
FNDFILEW.ASM FILE      FindFirstFileW
                       FindNextFileW
FORMMSG.ASM  DIV       FormatMessage
FULLPATH.ASM FILE      GetFullPathNameA
FULPATHW.ASM FILE      GetFullPathNameW
GETACP.ASM   HELP      GetACP
                       GetOEMCP
                       GetConsoleCP
                       GetConsoleOutputCP
                       SetConsoleCP
                       SetConsoleOutputCP
GETCFSIZ.ASM FILE      GetCompressedFileSizeA
GETCMDL.ASM  MODUL     GetCommandLineA
GETCMDLW.ASM MODUL     GetCommandLineW
GETCPINF.ASM DIV       GetCPInfo
GETCPROC.ASM PROCESS   GetCurrentProcess
                       GetCurrentProcessId
GETCTHRD.ASM THREAD    GetCurrentThread
GETCURD.ASM  DIR       GetCurrentDirectoryA
                       GetCurrentDirectoryW
GETDATE.ASM  TIME      GetDateFormatA
                       GetTimeFormatA
GETDRVTP.ASM DASD      GetDriveTypeA
                       GetDriveTypeW
                       GetLogicalDrives
GETENVAR.ASM MODUL     GetEnvironmentVariableA
GETENVS.ASM  MODUL     GetEnvironmentStringsA
                       FreeEnvironmentStringsA
GETENVSW.ASM MODUL     GetEnvironmentStringsW
                       FreeEnvironmentStringsW
GETFINFO.ASM FILE      GetFileInformationByHandle
GETFSIZE.ASM FILE      GetFileSize
                       GetCompressedFileSize
                       GetFileInformationByHandle
GETFTIME.ASM FILE      GetFileTime
GETFTYPE.ASM FILE      GetFileType
GETLERR.ASM            GetLastError (single thread)
                       SetLastError (single thread)
GETLOCAL.ASM DIV       GetLocaleInfoA
                       GetLocaleInfoW
                       GetStringTypeA
                       GetStringTypeW
                       IsValidLocale
                       EnumSystemLocales
GETMODFN.ASM MODUL     GetModuleFileNameA
                       GetModuleFileNameW
GETMODH.ASM  MODUL     GetModuleHandleA
GETPHEAP.ASM PROCESS   GetProcessHeap
GETSPATH.ASM FILE      GetShortPathNameA                       
                       GetShortPathNameW  
GETSTART.ASM PROCESS   GetStartupInfoA
GETSYINF.ASM CONSOLE   GetSystemInfo
GETTMPNM.ASM FILE      GetTempFileNameA
                       GetTempFileNameW
GETTICKC.ASM HELP      GetTickCount
GETVERS.ASM  PROCESS   GetVersion
                       GetVersionExA
GETVOLUM.ASM FILE      GetVolumeInformationA                      
GETWIND.ASM  SYSTEM    GetWindowsDirectoryA
                       GetWindowsDirectoryW
GMEMSTAT.ASM MEM       GlobalMemoryStatus
GSTDHDL.ASM  CONSOLE   GetStdHandle
                       SetStdHandle
GTSCRBFI.ASM CONSOLE   GetConsoleScreenBufferInfo
HALLOC.ASM   MEM       HeapAlloc
                       HeapFree
                       HeapReAlloc
                       HeapLock
                       HeapUnlock
                       HeapWalk
                       HeapCompact
                       HeapSize
HCREATE.ASM  MEM       HeapCreate
                       HeapDestroy
HEAPVAL.ASM  MEM       HeapValidate
ISBADPTR.ASM MEM       IsBadReadPtr
                       IsBadWritePtr
                       IsBadCodePtr
LCLALLOC.ASM MEM       LocalAlloc
                       GlobalAlloc
                       LocalFree
                       GlobalFree
LCLOSE.ASM   FILE      _lclose
LCMAPSTR.ASM HELP      LCMapStringA
                       LCMapStringW
                       GetUserDefaultLCID
                       GetSystemDefaultLCID
                       GetThreadLocale
LLSEEK.ASM   FILE      _llseek
                       SetFilePointer
LOADLIB.ASM  MODUL     LoadLibraryA
                       FreeLibrary
                       GetProcAddress
LOADLIBX.ASM MODUL     LoadLibraryExA
LOADLIBW.ASM MODUL     LoadLibraryW
                       LoadLibraryExW
LOCK.ASM     THREAD    InterLockedIncrement
                       InterLockedDecrement
                       InterLockedExchange
LOCKFILE.ASM FILE      LockFile
                       UnlockFile
LOPEN.ASM    FILE      _lcreat
                       _lopen
LREAD.ASM    FILE      _lread
                       _lwrite
LSTRCAT.ASM  STRING    lstrcat
                       lstrcatA
LSTRCMP.ASM  STRING    lstrcmp
                       lstrcmpA
LSTRCMPI.ASM STRING    lstrcmpi
                       lstrcmpiA
LSTRCPY.ASM  STRING    lstrcpy
                       lstrcpyA
LSTRCPYN.ASM STRING    lstrcpyn
                       lstrcpynA
LSTRLEN.ASM  STRING    lstrlen
                       lstrlenA
                       lstrlenW
MOUSE.ASM    CONSOLE   GetNumberOfConsoleMouseButtons                       
MOVEFILE.ASM FILE      MoveFileA
                       MoveFileW
MUTEX.ASM    THREAD    CreateMutex
                       ReleaseMutex
OUTDBGST.ASM DEBUG     OutputDebugStringA
PEEKCON.ASM  CON       PeekConsoleInputA
                       ReadConsoleInputA
                       ReadConsoleInputW
                       GetNumberOfConsoleInputEvents
                       FlushConsoleInputBuffer
PIPES.ASM    FILE      CreatePipe
                       PeekNamedPipe
PRIVPROF.ASM PROCESS   GetPrivateProfileString
                       WritePrivateProfileString
PROCESS.ASM  PROCESS   CreateProcessA
                       GetExitCodeProcess
PROCESSW.ASM PROCESS   CreateProcessW
PROCWSS.ASM  PROCESS   SetProcessWorkingSetSize
QPERFCNT.ASM DIV       QueryPerformanceCounter
READCONS.ASM CONSOLE   ReadConsoleA
                       ReadConsoleW
READFILE.ASM FILE      ReadFile
                       WriteFile
READPMEM.ASM PROCESS   ReadProcessMemory
                       WriteProcessMemory
RTLUNWIN.ASM HELP      RtlUnwind
SCRLCONS.ASM CONSOLE   ScrollConsoleScreenBuffer
SEMAPHOR.ASM THREAD    CreateSemaphoreA
                       WaitForSingleObject
                       ReleaseSemaphore
SETCMODE.ASM CONSOLE   SetConsoleMode
                       GetConsoleMode
SETCTRLH.ASM CONSOLE   SetConsoleCtrlHandler
                       GenerateConsoleCtrlEvent
SETCURD.ASM  DIR       SetCurrentDirectoryA
                       SetCurrentDirectoryW
SETCWNDI.ASM CONSOLE   SetConsoleWindowInfo
                       GetLargestConsoleWindowSize
SETEOF.ASM   FILE      SetEndOfFile
SETERRM.ASM  PROCESS   SetErrorMode
SETFTIME.ASM FILE      SetFileTime
SETHDLCT.ASM FILE      SetHandleCount
SLEEP.ASM    THREAD    Sleep
SRCHPATH.ASM FILE      SearchPathA
                       SearchPathW
TEMPPATH.ASM FILE      GetTempPathA
                       GetTempPathW
TERMPROC.ASM PROCESS   TerminateProcess
                       OpenProcess
                       SetPriorityClass
THREAD.ASM   THREAD    CreateThread
                       GetCurrentThread (multi thread)
                       GetCurrentThreadId
                       SetThreadPriority
                       SuspendThread
                       ResumeThread
                       TerminateThread
                       ExitThread
                       GetExitCodeThread
                       GetLastError (multi thread)
                       SetLastError (multi thread)
TIME.ASM     TIME      GetLocalTime
                       SetLocalTime
                       GetSystemTime
                       GetSystemTimeAsFileTime
TOOLHELP.ASM MODULE    Thread32First
                       Thread32Next
                       CreateToolhelp32Snapshot
                       Module32First
                       Module32Next
                       Heap32ListFirst
                       Heap32ListNext
                       Heap32First
                       Heap32Next
                       Process32First
                       Process32Next
VALLOC.ASM   MEM       VirtualAlloc
                       VirtualFree
                       VirtualLock
                       VirtualUnlock
VIRTUAL.ASM  MEM       VirtualProtect (may work if DPMI host is v1.0)
VQUERY.ASM   MEM       VirtualQuery
                       VirtualQueryEx
VWIN32.ASM   DEVICE    implements VWIN32 device
WAITMULT.ASM THREAD    WaitForMultipleObjects
WC2MB.ASM    HELP      WideCharToMultiByte
                       MultiByteToWideChar
                       IsValidCodePage
                       IsDBCSLeadByte
                       IsDBCSLeadByteEx
WRITCONS.ASM CONSOLE   WriteConsoleA
                       WriteConsoleW
WRCONOUT.ASM CONSOLE   WriteConsoleOutputA
                       ReadConsoleOutputA
WRCONOCH.ASM CONSOLE   WriteConsoleOutputCharacterA/W
                       ReadConsoleOutputCharacterA/W


other modules:

CHECKOS.ASM            if platform is NT installs a Int 21h hook
CONFLGS.ASM  FILE      console flags (global)
CONWSTR.ASM            ascii -> wide, wide -> ascii
CSALIAS.ASM            alias for CS (used by interrupt routines)
DOSMEM.ASM             dos memory allocation helpers
GROWSEG.ASM            helper for HeapAlloc
SEARCHSG.ASM           helper for HeapAlloc
BOOST.ASM              helper for threads
GETSCRPT.ASM           getscreenptr get physical screen start address
