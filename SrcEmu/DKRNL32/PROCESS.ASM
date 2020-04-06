
;--- implements CreateProcessA, GetExitCodeProcess

	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:none
	option proc:private

	include winbase.inc
	include wincon.inc
	include dkrnl32.inc
	include macros.inc

_initializethread proto stdcall

;;_DEBUG	equ 1
?SHORTNAME	equ 1	;convert path to a short name
?SAVECURDIR	equ 1	;save/restore current directory
?FTDIRECT	equ 1	;std=?, 1=access file table in psp directly
?SAVEFS		equ 1	;save/restore FS register

if ?NONULLHDL
?CONINPHANDLE equ 10000h
else
?CONINPHANDLE equ 0
endif

EXECPM	struct
cmdline dq ?
fcb1	dq ?
fcb2	dq ?
EXECPM	ends

	.CONST

;g_szCmdLine	db "CMDLINE="
;LCMDLSIZE equ $ - g_szCmdLine

	.CODE

;--- constellations:
;--- 1. pszAppName=NULL, pszCmdLine=program to execute + arguments in
;--- 2. pszAppName=program to execute, pszCmdLine=arguments
;--- 3. pszAppName=program to execute, pszCmdLine=NULL

CreateProcessA proc public uses ebx esi edi pszAppName:ptr byte,
		pszCmdLine:ptr byte, pProcessAttribs:dword,
		pThreadAttribs:dword, bInheritHandles:dword,
		dwCreationFlags:dword, pEnvironment:ptr,
		lpCurrentDirectory:ptr byte, pStartupInfo:ptr STARTUPINFOA,
		pProcessInfo:ptr PROCESS_INFORMATION

local	bRC:byte
local	dwLengthCmdLine:DWORD
local	dwLengthEnviron:DWORD
local	hSaveHdls[3]:DWORD
local	pszNewCmd:DWORD
local	pszNewApp:DWORD
local	pNewEnv:DWORD
local	wDosSel:WORD			;dos memory selector for new process env.
local	wOldEnv:WORD
local	dwPSP:DWORD
local	dwEsp:dword
local	execparm:EXECPM
local	fcb[20h]:byte
local	oldmodlist:dword
local	lpFilePart:ptr BYTE
local	hProcess:DWORD
local	conmode:DWORD
local	cmdline[80h]:byte
local	szAppName[MAX_PATH]:byte
local	szFirstToken[MAX_PATH]:byte
if ?SAVECURDIR
local	szCurrentDirectory[MAX_PATH]:byte
endif

ifdef _DEBUG
	mov ecx, pszAppName
	.if (!ecx)
		mov ecx, CStr("NULL")
	.endif
	mov edx, pszCmdLine
	.if (!edx)
		mov edx, CStr("NULL")
	.endif
	@strace <"CreateProcess(", &ecx, ", ", &edx, ") enter">
	mov ecx, lpCurrentDirectory
	.if (!ecx)
		mov ecx, CStr("NULL")
	.endif
	@strace <"bInheritHandles=", bInheritHandles, ", dwCreationFlags=", dwCreationFlags, ", pEnvironment=", pEnvironment, ", lpCurrentDir=", &ecx>
	sub esp, sizeof MEMORYSTATUS
	push esp
	call GlobalMemoryStatus
	add esp, sizeof MEMORYSTATUS
endif
if ?SAVECURDIR
	invoke GetCurrentDirectory, sizeof szCurrentDirectory, addr szCurrentDirectory
endif
	mov ah, 51h
	int 21h
	mov ax,6
	int 31h
	push cx
	push dx
	pop ebx
	mov dwPSP, ebx		;linear address of current PSP

	xor eax,eax
	mov pNewEnv, eax
	mov wDosSel, ax

;-------- get first token from pszCmdLine

	mov esi,pszCmdLine
	mov pszNewCmd, esi		;initialize pszNewCmd
	lea edi, szFirstToken
	.if (esi)
		mov ecx, sizeof szFirstToken - 1
		mov ah, 0
		.while (ecx)
			lodsb
			.if (ah)
				.break .if (al == '"')
				stosb
			.elseif (al == '"')
				inc ah
			.elseif (al > ' ')
				stosb
			.else
				dec esi
				.break
			.endif
			dec ecx
		.endw
	.endif
	mov al, 00
	stosb

;------- if no appname is supplied, use first token as appname
;------- else extend appname to full path (no PATH scan in this case

	mov ecx, pszAppName
	.if (!ecx)
		mov pszNewCmd, esi	;command line now without first token
		lea eax, szFirstToken
		mov pszNewApp, eax
	.else
		invoke GetFullPathNameA, ecx, sizeof szAppName, addr szAppName, addr lpFilePart
if ?SHORTNAME
		invoke GetShortPathNameA, addr szAppName, addr szAppName, sizeof szAppName
endif
		lea eax, szAppName
		mov pszNewApp, eax

		mov pszNewCmd, esi	;skip first token here as well

	.endif

;------- pszNewApp is now first token of cmdline or full path
;------- pszCmdLine may be NULL

;--- we will call a dos app which has command line limitation of
;--- 126 bytes. if commandline exceeds this limit, alloc a new
;--- environment and set CMDLINE variable as well as path to executable

	.if (pszNewCmd)
		invoke lstrlen, pszNewCmd
	.else
		xor eax, eax
	.endif

	.if ((eax <= 7Eh) && (!pEnvironment) && (!pszAppName))
		jmp step2
	.endif

	@trace <"Length commandline=">
	@tracedw eax
	@trace <13,10>

;--- get environment if not specified

	.if (!pEnvironment)
		mov ah, 51h
		int 21h
		push es
		mov es, ebx
		mov bx, es:[2ch]
		pop es
		mov ax, 6
		int 31h
		jc noenviron
		push cx
		push dx
		pop eax
ife ?FLAT
		invoke __lin2based
endif
		mov pEnvironment, eax
	.endif

noenviron:

;--------- create a temporary buffer for environment

	invoke LocalAlloc, LMEM_FIXED, 8000h
	and eax, eax
	jz step2
	mov pNewEnv, eax
	mov edi, eax

;--------- copy all strings except CMDLINE=

	mov esi, pEnvironment
	and esi, esi
	jz noenviron2
	.while (byte ptr [esi])
		mov eax, [esi+0]
		mov ecx, [esi+4]
;;		invoke CompareStringA, 0, 0, addr g_szCmdLine, 8, esi, 8
;;		.if (eax != CSTR_EQUAL)
		.if ((eax != "LDMC") || (ecx != "=ENI"))
@@:
			lodsb
			stosb
			and al, al
			jnz @B
		.else
@@:
			lodsb
			and al, al
			jnz @B
		.endif
	.endw
noenviron2:

;--------- now create new CMDLINE= variable

	@trace <"create new CMDLINE variable=">

	mov eax, "LDMC"
	stosd
	mov eax, "=ENI"
	stosd
if 0
	mov esi, pszNewApp
@@:
	lodsb
	stosb
	and al, al
	jnz @B
	dec edi
endif
;;	mov esi, pszNewCmd
	mov esi, pszCmdLine
	.if (esi)
		@trace esi
@@:
		lodsb
		stosb
		and al, al
		jnz @B
		dec edi
	.endif
	@trace <13,10>
	xor eax,eax
	stosw
	inc ax
	stosw
	mov esi, pszNewApp
@@:
	lodsb
	stosb
	and al, al
	jnz @B

	sub edi, pNewEnv
	mov dwLengthEnviron, edi

;--------- now alloc DOS memory for new environment block
;--------- and get a zero based flat pointer to it in EDI

	mov ebx, edi
	mov al, bl
	shr ebx, 4
	test al, 0Fh
	jz @F
	inc ebx
@@:
	mov ax, 100h
	int 31h
	jc step2
	mov wDosSel, dx
	movzx edi, ax
	shl edi, 4
ife ?FLAT
	mov eax, edi
	invoke __lin2based
	mov edi, eax
endif

;---------- copy environment into dos space and free temp buffer

	invoke CopyMemory, edi, pNewEnv, dwLengthEnviron

;---------- finally we have an environment for new process
;---------- how to set it?
;---------- currently we set it temporarily as our own and restore it later

	mov ebx, dwPSP
	or byte ptr @flat:[ebx+4Fh],1		;force called app to use CMDLINE
	mov ax, wDosSel
	xchg ax, @flat:[ebx+2Ch]
	mov wOldEnv, ax

step2:
	.if (pNewEnv)
		invoke LocalFree, pNewEnv
	.endif

;---------- now transfer cmdline to dos cmd tail format

	mov esi,pszNewCmd
	.if (!esi)
		mov esi, CStr("")
	.endif

	@trace <"commandline=">
	@trace esi
	@trace <13,10>

	lea edi,cmdline+1
	mov ecx, sizeof cmdline-1
@@:
	lodsb
	stosb
	and al,al
	loopnz @B
	.if (ecx)
		dec edi
		mov byte ptr [edi],0Dh
	.endif
	mov eax,edi
	lea ecx, cmdline+1
	sub eax, ecx
	mov [ecx-1],al

	@trace <"length dos command tail=">
	@tracedw eax
	@trace <13,10>

;---- check the STARTUPINFO parameter if std handles should be set
;---- for the child
	.if (bInheritHandles)
		mov esi, pStartupInfo
		.if (esi && ([esi].STARTUPINFOA.dwFlags & STARTF_USESTDHANDLES))
;---- setting the child's handles can only be done by setting the
;---- handles directly in our PSP.
if ?FTDIRECT
			mov ebx, dwPSP
			movzx eax, word ptr @flat:[ebx+36h]
			shl eax,4
			movzx ebx,word ptr @flat:[ebx+34h]
			add ebx,eax

			xor ecx, ecx
			mov edx, [esi].STARTUPINFOA.hStdInput
			call sethandle
			mov hSaveHdls[0*4], eax

			inc ecx
			mov edx, [esi].STARTUPINFOA.hStdOutput
			call sethandle
			mov hSaveHdls[1*4], eax

			inc ecx
			mov edx, [esi].STARTUPINFOA.hStdError
			call sethandle
			mov hSaveHdls[2*4], eax
else
			invoke GetStdHandle, STD_INPUT_HANDLE
			mov hSaveHdls[0*4], eax
			invoke GetStdHandle, STD_OUTPUT_HANDLE
			mov hSaveHdls[1*4], eax
			invoke GetStdHandle, STD_ERROR_HANDLE
			mov hSaveHdls[2*4], eax
			invoke SetStdHandle, STD_INPUT_HANDLE, [esi].STARTUPINFOA.hStdInput
			invoke SetStdHandle, STD_OUTPUT_HANDLE, [esi].STARTUPINFOA.hStdOutput
			invoke SetStdHandle, STD_ERROR_HANDLE, [esi].STARTUPINFOA.hStdError
endif
		.endif
	.else
		mov dwEsp, esp
		mov ebx, dwPSP
		movzx ecx, word ptr @flat:[ebx+32h]
		movzx eax, word ptr @flat:[ebx+36h]
		shl eax,4
		movzx ebx,word ptr @flat:[ebx+34h]
		add ebx,eax
		sub esp, ecx
		shr ecx, 2
		.while (ecx)
			dec ecx
			mov eax, @flat:[ebx+ecx*4]
			mov [esp+ecx*4],eax
			.if (!ecx)
				mov eax, 00010101h
			.elseif (ecx == 1)
				mov eax, 0FFFFFF02h
			.else
				or eax, -1
			.endif
			mov @flat:[ebx+ecx*4], eax
		.endw
	.endif


	lea ebx,execparm
	lea eax,cmdline
	mov dword ptr [ebx.EXECPM.cmdline+0],eax
	mov dword ptr [ebx.EXECPM.cmdline+4],ds
	lea eax,fcb
	mov byte ptr [eax],0
	mov ecx,20202020h
	mov [eax+1],ecx
	mov [eax+5],ecx
	mov [eax+9],ecx
	mov dword ptr [ebx.EXECPM.fcb1+0],eax
	mov dword ptr [ebx.EXECPM.fcb1+4],ds
	mov dword ptr [ebx.EXECPM.fcb2+0],eax
	mov dword ptr [ebx.EXECPM.fcb2+4],ds

if ?FLAT

;--- this is some DPMILD32 specific code
;--- it resets module list of the PE loader so
;--- the new process gets its own instances of dlls.
;--- if there's no DPMILD32, this code is caught by some code in INIT.ASM

	xor edx,edx
	mov ax,4B92h
	int 21h
	mov oldmodlist,eax
endif

	invoke GetConsoleMode, ?CONINPHANDLE, addr conmode
	mov eax, conmode
	and eax, not ENABLE_MOUSE_INPUT
	invoke SetConsoleMode, ?CONINPHANDLE, eax

	invoke _RestoreRTCTimer

	test byte ptr g_dwFlags,DKF_NODISABLE
	jnz @F
	dec g_bIsActive			;this should deactivate any IRQ handlers
							;of this instance of DKRNL32.DLL
@@:                                    

	@strace	<"------------- calling int 21h, ax=4b00h ------------">
ifdef _DEBUG
	invoke _FlushLogFile
endif
if ?SAVEFS
	push fs
endif

	mov edx,pszNewApp
	mov ax,4B00h
	int 21h
if ?SAVEFS
	pop fs
endif
	mov bRC,0
	jnc @F
	movzx eax,ax
	invoke SetLastError, eax
	mov bRC,1
@@:
	.if (!bInheritHandles)
		mov ebx, dwPSP
		movzx ecx, word ptr @flat:[ebx+32h]
		movzx eax, word ptr @flat:[ebx+36h]
		shl eax,4
		movzx ebx,word ptr @flat:[ebx+34h]
		add ebx,eax
		shr ecx, 2
		.while (ecx)
			dec ecx
			mov eax, [esp+ecx*4]
			mov @flat:[ebx+ecx*4], eax
		.endw
		mov esp, dwEsp
	.endif

	test byte ptr g_dwFlags,DKF_NODISABLE
	jnz @F
	inc g_bIsActive
@@:
	invoke _SetRTCTimer

	invoke SetConsoleMode, ?CONINPHANDLE, conmode

ifdef _DEBUG
	@trace <0>				;tell dbg log to set file ptr to EOF
	mov edx, CStr("NC")
	test bRC,1
	jz @F
	mov edx, CStr("C")
@@:
	@strace <"------------- int 21h, ax=4b00h returned with ", &edx, ", eax=", eax, "------------">
endif

if ?FLAT
;--- this is some DPMILD32 specific code
;--- restore the module list.
;--- if there's no DPMILD32, this code is caught by some code in INIT.ASM
	mov edx,oldmodlist
	mov ax,4B92h
	int 21h
endif

	.if (bInheritHandles)
		mov esi, pStartupInfo
		.if (esi && ([esi].STARTUPINFOA.dwFlags & STARTF_USESTDHANDLES))
if ?FTDIRECT
			mov ebx, dwPSP
			movzx eax, word ptr @flat:[ebx+36h]
			shl eax,4
			movzx ebx,word ptr @flat:[ebx+34h]
			add ebx,eax
			mov eax, hSaveHdls[0*4]
			mov byte ptr @flat:[ebx+0],al
			mov eax, hSaveHdls[1*4]
			mov byte ptr @flat:[ebx+1],al
			mov eax, hSaveHdls[2*4]
			mov byte ptr @flat:[ebx+2],al
else
			invoke SetStdHandle, STD_INPUT_HANDLE, hSaveHdls[0*4]
			invoke SetStdHandle, STD_OUTPUT_HANDLE, hSaveHdls[1*4]
			invoke SetStdHandle, STD_ERROR_HANDLE, hSaveHdls[2*4]
endif
		.endif
	.endif

;--------------- restore environment

	.if (wDosSel)
		mov ebx, dwPSP
		mov dx, wOldEnv
		xchg dx, @flat:[ebx+2ch]

;--------------- and free dos memory

		mov dx, wDosSel
		mov ax, 101h
		int 31h
	.endif

if ?SAVECURDIR
	invoke SetCurrentDirectory, addr szCurrentDirectory
endif

	test bRC, 1
	jnz error

	xor edi, edi
	invoke KernelHeapAlloc, sizeof PROCESS
	.if (eax)
		mov esi, eax
		mov [esi].SYNCOBJECT.dwType, SYNCTYPE_PROCESS
		mov [esi].PROCESS.wFlags, PF_TERMINATED
		invoke KernelHeapAlloc, sizeof THREAD
		.if (eax)
			invoke _initializethread
			mov edi, eax
			mov [esi].PROCESS.hThread, edi
			mov [edi].THREAD.flags, TF_TERMINATED
			mov ah,4dh
			int 21h
			movzx eax,ax
			mov [edi].THREAD.dwExitCode, eax
		.endif
		mov eax, esi
	.endif

	mov ebx,pProcessInfo
	.if (ebx)
		mov [ebx].PROCESS_INFORMATION.hProcess, eax
		mov [ebx].PROCESS_INFORMATION.hThread, edi
		mov [ebx].PROCESS_INFORMATION.dwProcessId, eax
		mov [ebx].PROCESS_INFORMATION.dwThreadId,edi
	.endif
	@mov eax,1
exit:
	@strace <"CreateProcessA()=", eax>
	ret
error:
	xor eax,eax
	jmp exit

sethandle:
	mov al, byte ptr @flat:[ebx+ecx]
	.if (edx != -1)
		.if (edx > 10000h)
			.if ([edx].SYNCOBJECT.dwType == SYNCTYPE_PIPE)
				mov edx, [edx].PIPE.dwfh
			.endif
		.endif
		movzx edx,dx
		mov ah, byte ptr @flat:[ebx+edx]
	.else
		mov ah,-1
	.endif
	mov @flat:[ebx+ecx],ah
	movzx eax,al
	retn
	align 4

CreateProcessA endp

GetExitCodeProcess proc public hProcess:dword,pRC:dword

	mov eax, hProcess
	mov eax, [eax].PROCESS.hThread
	mov eax, [eax].THREAD.dwExitCode
	mov edx, pRC
	mov [edx], eax
	mov al,1
	@strace <"GetExitCodeProcess(", hProcess, ", ", pRC, ")=", eax>
	ret
	align 4
GetExitCodeProcess endp

	end
