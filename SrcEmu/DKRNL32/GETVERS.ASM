
	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:none
	option proc:private

?MAJVER	equ 4h		;4=win NT/win9x, 5=2K/XP
?MINVER	equ 0h
?BUILD	equ 2222

	include winbase.inc
	include dkrnl32.inc
	include macros.inc

	.CODE

GetVersion proc public

if ?NT
	mov eax,?MAJVER
else
	mov eax,?MAJVER or 80000000h
endif
	@strace <"GetVersion()=", eax>
	ret
	align 4
GetVersion endp

GetVersionExA proc public pBuffer:ptr OSVERSIONINFO

	mov eax,pBuffer
	mov [eax].OSVERSIONINFO.dwMajorVersion,?MAJVER
	mov [eax].OSVERSIONINFO.dwMinorVersion,?MINVER
if ?NT
	mov [eax].OSVERSIONINFO.dwBuildNumber,?BUILD
	mov [eax].OSVERSIONINFO.dwPlatformId,VER_PLATFORM_WIN32_NT
else
	mov [eax].OSVERSIONINFO.dwBuildNumber,?BUILD + (?MAJVER shl 24) + (?MINVER shl 16)
	mov [eax].OSVERSIONINFO.dwPlatformId,VER_PLATFORM_WIN32_WINDOWS
endif
	mov [eax].OSVERSIONINFO.szCSDVersion, 0
	@strace <"GetVersionExA(", pBuffer, ")=", eax>
	ret
GetVersionExA endp

	end

