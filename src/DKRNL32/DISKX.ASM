
;--- implements GetDiskFreeSpaceExA, GetDiskFreeSpaceExW

	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:none
	option proc:private

	include winbase.inc
	include dkrnl32.inc
	include macros.inc
	include fat32.inc

	.DATA

	.CODE

;--- parameters pRool and lpTotalNumberOfFreeBytes may be NULL

GetDiskFreeSpaceExA proc public uses edi pRoot:ptr BYTE,
                               lpFreeBytesAvailable:ptr QWORD,
                               lpTotalNumberOfBytes:ptr QWORD,
                               lpTotalNumberOfFreeBytes:ptr QWORD
local	sectorscluster:dword
local	bytessector:dword
local	freecluster:dword
local	totalcluster:dword

	invoke GetDiskFreeSpaceA, pRoot, addr sectorscluster,
		addr bytessector, addr freecluster, addr totalcluster
	.if (eax)
		mov eax, sectorscluster
		mov ecx, bytessector
		mul ecx
		mov ecx, eax
		mov eax, freecluster
		mul ecx
		mov edi, lpFreeBytesAvailable
		mov [edi+0],eax
		mov [edi+4],edx
		mov edi, lpTotalNumberOfFreeBytes
		and edi, edi
		jz @F
		mov [edi+0],eax
		mov [edi+4],edx
@@:
		mov eax, totalcluster
		mul ecx
		mov edi, lpTotalNumberOfBytes
		mov [edi+0],eax
		mov [edi+4],edx
		@mov eax,1
	.endif
	ret
	align 4

GetDiskFreeSpaceExA endp

GetDiskFreeSpaceExW proc public pRoot:ptr WORD,
                               lpFreeBytesAvailable:ptr QWORD,
                               lpTotalNumberOfBytes:ptr QWORD,
                               lpTotalNumberOfFreeBytes:ptr QWORD

	mov eax, pRoot
	.if (eax)
		call ConvertWStr
	.endif
	invoke GetDiskFreeSpaceExA, eax, lpFreeBytesAvailable, lpTotalNumberOfBytes, lpTotalNumberOfFreeBytes
	ret
	align 4

GetDiskFreeSpaceExW endp

end

