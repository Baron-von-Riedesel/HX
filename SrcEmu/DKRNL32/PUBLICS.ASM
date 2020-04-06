
;--- almost certainly this was never used

	.386

if 0 

ifndef ?FLAT
?FLAT=0
endif

if ?FLAT
	.MODEL FLAT
else
	.MODEL SMALL
endif
	option casemap:none
	option proc:private

@defpub macro name_, stk
	public name_
	externdef _&name_&@&stk:near
name_:
	jmp _&name_&@&stk
	endm

	.CODE

 @defpub Beep, 8
 @defpub CloseHandle, 4
 @defpub CreateFileA, 28
 @defpub DeleteCriticalSection, 4
 @defpub DeleteFileA, 4
 @defpub DosDateTimeToFileTime, 12
 @defpub DuplicateHandle, 28
 @defpub EnterCriticalSection, 4
 @defpub ExitProcess, 4
 @defpub FileTimeToDosDateTime, 12
 @defpub FileTimeToLocalFileTime, 8
 @defpub GetCommandLineA, 0
 @defpub GetConsoleMode, 8
 @defpub GetCurrentProcess, 0
 @defpub GetEnvironmentStrings, 0
 @defpub GetEnvironmentStringsA, 0
 @defpub GetFileInformationByHandle, 8
 @defpub GetFileType, 4
 @defpub GetLastError, 0
 @defpub GetLocalTime, 4
 @defpub GetModuleFileNameA, 12
 @defpub GetModuleHandleA, 4
 @defpub GetStdHandle, 4
 @defpub GetSystemInfo, 4
 @defpub GetTickCount, 0
 @defpub GetVersionExA, 4
 @defpub InitializeCriticalSection, 4
 @defpub LeaveCriticalSection, 4
 @defpub LocalAlloc, 8
 @defpub LocalFileTimeToFileTime, 8
 @defpub LocalFree, 4
 @defpub LocalLock, 4
 @defpub LocalUnlock, 4
 @defpub LockFile, 20
 @defpub MoveFileA, 8
 @defpub ReadFile, 20
 @defpub RemoveDirectoryA, 4
 @defpub SetConsoleCtrlHandler, 8
 @defpub SetConsoleMode, 8
 @defpub SetEndOfFile, 4
 @defpub SetFileAttributesA, 8
 @defpub SetFilePointer, 16
 @defpub SetFileTime, 16
 @defpub SetLocalTime, 4
 @defpub Sleep, 4
 @defpub SystemTimeToFileTime, 8
 @defpub TlsAlloc, 0
 @defpub TlsFree, 4
 @defpub TlsGetValue, 4
 @defpub TlsSetValue, 8
 @defpub UnlockFile, 20
 @defpub VirtualAlloc, 16
 @defpub VirtualFree, 12
 @defpub VirtualQuery, 12
 @defpub WriteFile, 20
 
; @defpub MessageBoxA, 16

	public MessageBoxA

MessageBoxA:
	ret 16

endif

	end

