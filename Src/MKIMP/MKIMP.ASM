
;*** helper tool to create small _imp_xxx stubs
;*** currently used to create IMPHLP.LIB

	.386
	.MODEL FLAT, stdcall
	option casemap:none
	option proc:private

	include winbase.inc

printf  proto c :ptr, :vararg
sprintf proto c :ptr, :ptr, :vararg
malloc  proto c :dword


CStr macro text:vararg
local xxx
	.const
xxx db text,0
	.code
	exitm <offset xxx>
	endm

	.data

hStdOut	DWORD ?
pszFile	dd 0
pszAsm	dd offset szJWasm
pszOpt	dd offset szJWasmOpt
pszCoff	dd offset szJWasmCoff
pszOmf	dd offset szJWasmOmf
pszOut	dd offset szDot

g_bVerbose db 1
g_bOmf	db 0
g_test	db 0

	.const

szDot	db ".",0
szMasm	db "ml.exe",0
szNasm	db "nasm.exe",0
szJWasm	db "jwasm.exe",0
szPasm	db "poasm.exe",0
szFasm	db "fasm.exe",0
szTasm	db "tasm32.exe",0

szJWasmOpt db " -c -q -D?IMP=%s -Fo %s template.asm",0
szJWasmCoff db " -coff -zlf -zls",0
szJWasmOmf db 0

szMasmOpt db " -c -nologo -D?IMP=%s -Fo %s template.asm",0
szMasmCoff db " -coff",0
szMasmOmf db 0

szNasmOpt db " -D?IMP=%s -o %s.obj template.nsm",0
szNasmCoff db " -f win32",0
szNasmOmf db " -f obj",0

szPasmOpt db " -nologo -D?IMP=%s -Fo %s template.asm",0
szFasmOpt db " -d ?IMP=%s template.fsm %s.obj",0
szTasmOpt db " -t -ml -d?IMP=%s template.asm, %s.obj;",0

	.data

szOpt2	db 128 dup (?)

	.CODE

getline proc uses esi edi pSrc:ptr, pDst:ptr, dwMax:dword
	mov esi, pSrc
	mov edi, pDst
	mov ecx, dwMax
	.while (ecx)
		mov al,[esi]
		.break .if (!al)
		inc esi
		.if ((al == 13) && (byte ptr [esi] == 10))
			mov al,[esi]
			inc esi
		.endif
		.if (al == 10)
			mov al,0
		.endif
		stosb
		dec ecx
		.break .if (al == 0)
	.endw
	.if (ecx)
		mov al,0
		stosb
	.endif
	mov eax, esi
	ret
	align 4
getline endp

getword proc uses esi edi pszLine, pszWord, dwMax:dword
	mov esi, pszLine
	mov edi, pszWord
	mov byte ptr [edi],0
	mov ecx, dwMax
	.while (ecx)
		mov al,[esi]
		.break .if (al == 0)
		inc esi
		.break .if (al == '"')
		.break .if (al == ' ')
		.break .if (al == 9)
		.break .if (al == ',')
		stosb
		dec ecx
	.endw
	.if (ecx)
		mov al,0
		stosb
	.endif
	mov eax, esi
	ret
	align 4
getword endp

run proc stdcall uses ebx pszExe:ptr, pszName:ptr BYTE

local	_si:STARTUPINFOA
local	pi:PROCESS_INFORMATION
local	cmdline[256]:byte
local	fullcmdline[512]:byte

	invoke sprintf, addr fullcmdline, CStr("%s\%s"), pszOut, pszName

	invoke sprintf, addr cmdline, pszOpt, pszName, addr fullcmdline

	.if (g_bVerbose)
		invoke printf, CStr("%s%s",10), pszExe, addr cmdline
;		invoke fflush, stdout
	.endif

	invoke ZeroMemory, addr _si, sizeof _si
	mov _si.cb, sizeof STARTUPINFOA
	.if (1)
		invoke lstrcpy, addr fullcmdline, pszExe
		invoke lstrcat, addr fullcmdline, addr cmdline
		.if g_test
			invoke printf, CStr("%s",lf), addr fullcmdline
			mov eax,1
			ret
		.else
			invoke CreateProcess, 0, addr fullcmdline, NULL, NULL, FALSE, 0, 0, NULL, addr _si, addr pi
		.endif
	.else
		invoke CreateProcess, pszExe, addr cmdline, NULL, NULL, FALSE, 0, 0, NULL, addr _si, addr pi
	.endif
	.if (eax)
		invoke WaitForSingleObject, pi.hProcess, INFINITE
		invoke CloseHandle, pi.hThread
		invoke CloseHandle, pi.hProcess
		mov eax,1
	.else
		invoke printf, CStr("can't run %s",10), pszExe
		xor eax,eax
	.endif
	ret
	align 4
run endp

CheckFormat proc uses ebx
	.if (pszCoff)
		mov ebx, offset szOpt2
		.if (g_bOmf)
			invoke sprintf, ebx, CStr("%s%s"), pszOmf, pszOpt
		.else
			invoke sprintf, ebx, CStr("%s%s"), pszCoff, pszOpt
		.endif
		mov pszOpt, ebx
	.endif
	ret
	align 4
CheckFormat endp

main proc c public argc:dword,argv:dword

local	dwRC:dword
local	dwSize:dword
local	dwRead:dword
local	pMem:dword
local	szDir[MAX_PATH]:byte
local	szLine[128]:byte
local	szOut[128]:byte
local	szName[96]:byte
local	szGuid[64]:byte

	invoke GetStdHandle, STD_OUTPUT_HANDLE
	mov hStdOut, eax

	mov dwRC, 1
	mov ecx, argc
	mov esi, [argv]
	cmp ecx, 2
	jb error1
	add esi, 4

	.while (ecx > 1)
		lodsd
		mov ebx, eax
		mov al,[ebx]
		.if (al == '-') || (al == '/')
			mov al,[ebx+1]
			mov ah,[ebx+2]
			or al,20h
			.if (ax == 'n')
				mov pszAsm, offset szNasm
				mov pszOpt, offset szNasmOpt
				mov pszCoff, offset szNasmCoff
				mov pszOmf, offset szNasmOmf
			.elseif (ax == 'p')
				mov pszAsm, offset szPasm
				mov pszOpt, offset szPasmOpt
				mov pszCoff, 0
				mov pszOmf, 0
			.elseif (ax == 'j')
				mov pszAsm, offset szJWasm
				mov pszOpt, offset szJWasmOpt
				mov pszCoff, offset szJWasmCoff
				mov pszOmf, offset szJWasmOmf
			.elseif (ax == 'f')
				mov pszAsm, offset szFasm
				mov pszOpt, offset szFasmOpt
				mov pszCoff, 0
				mov pszOmf, 0
			.elseif (ax == 't')
				mov pszAsm, offset szTasm
				mov pszOpt, offset szTasmOpt
				mov pszCoff, 0
				mov pszOmf, 0
			.elseif (ax == 'm')
				mov pszAsm, offset szMasm
				mov pszOpt, offset szMasmOpt
				mov pszCoff, offset szMasmCoff
				mov pszOmf, offset szMasmOmf
			.elseif (ax == 'q')
				mov g_bVerbose, 0
			.elseif (ax == 'd')
				mov g_test,1
			.elseif (ax == 'o')
				.if (ecx > 2)
					dec ecx
					lodsd
					mov [pszOut], eax
				.endif
			.elseif (al == 'o')
				or ah,20h
				.if (ax == "mo")
					mov ax,[ebx+3]
					or al,20h
					.if (ax == 'f')
						mov g_bOmf,1
					.else
						jmp error1
					.endif
				.else
					jmp error1
				.endif
			.else
				jmp error1
			.endif
		.else
			mov pszFile, ebx
		.endif
		dec ecx
	.endw

	mov ebx, pszFile
	.if (!ebx)
		jmp error1
	.endif

	invoke CheckFormat

	invoke _lopen, ebx, 0
	.if (eax == -1)
		jmp error2
	.endif
	mov ebx, eax

;--- search ML.EXE/POASM.EXE/JWASM.EXE/NASM.EXE in PATH

	invoke SearchPath, NULL, pszAsm, NULL, sizeof szDir, addr szDir, NULL
	.if (!eax)
		invoke printf, CStr("mkimp: %s not found",10), pszAsm
		jmp @exit
	.else
		.if (g_bVerbose)
			invoke printf, CStr("mkimp: %s found, full path=%s",10), pszAsm, addr szDir
		.endif
	.endif

	invoke GetFileSize, ebx, NULL
	mov dwSize, eax
	inc eax
	invoke malloc, eax
	and eax, eax
	jz error3
	mov pMem, eax
	invoke ReadFile, ebx, pMem, dwSize, addr dwRead, 0
	and eax, eax
	jz error4
	invoke CloseHandle, ebx
	mov esi, pMem
	mov eax, dwSize
	mov byte ptr [esi+eax],0

	.if (g_bVerbose)
		invoke printf, CStr("mkimp: processing %s",10), pszFile
	.endif

	.while (1)
		.break .if (byte ptr [esi] == 0)
		invoke getline, esi, addr szLine, sizeof szLine

		mov esi, eax
		lea edi, szLine
		mov al, [edi]
		.while ((al == ' ') || (al == 9))
			inc edi
			mov al,[edi]
		.endw
		.if (al == '"')
			inc edi
			invoke getword, edi, addr szName, sizeof szName
			.if (szName)
				invoke run, addr szDir, addr szName
				.break .if (eax==0)
			.endif
		.endif
	.endw
	.if (g_bVerbose)
		invoke printf, CStr("mkimp: done",10)
	.endif
	mov dwRC, 0
@exit:
	mov eax,dwRC
	ret

error1:
	invoke printf, CStr("mkimp v1.1",10)
	invoke printf, CStr("this tool's purpose is to create helper libs for static Win32 libs.",10)
	invoke printf, CStr("  usage: mkimp [options] imp_definition_file",10)
	invoke printf, CStr("  options:",10)
	invoke printf, CStr("  -f: use FASM,  template.fsm",10)
	invoke printf, CStr("  -j: use JWASM, template.asm (default)",10)
	invoke printf, CStr("  -m: use MASM,  template.asm",10)
	invoke printf, CStr("  -n: use NASM,  template.nsm",10)
	invoke printf, CStr("  -p: use PoASM, template.asm",10)
	invoke printf, CStr("  -t: use TASM,  template.asm",10)
	invoke printf, CStr("  -o name: name of directory to store object modules",10)
	invoke printf, CStr("  -q: quiet",10)
	invoke printf, CStr("  -d: display generated cmdlines only",10)
	invoke printf, CStr("  -omf: output in OMF format",10)
	jmp @exit
error2:
	invoke printf, CStr("file %s open error",10), ebx
	jmp @exit
error3:
	invoke printf, CStr("out of memory",10)
	jmp @exit
error4:
	invoke printf, CStr("read error",10)
	jmp @exit

main endp

	END

