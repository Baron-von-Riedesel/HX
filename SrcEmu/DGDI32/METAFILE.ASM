
        .386
if ?FLAT
        .MODEL FLAT, stdcall
else
        .MODEL SMALL, stdcall
endif
		option casemap:none
        option proc:private

        include winbase.inc
        include wingdi.inc
        include dgdi32.inc
        include macros.inc

        .CODE

CreateMetaFileW proc public lpszFile:ptr BYTE
CreateMetaFileW endp

CreateMetaFileA proc public lpszFile:ptr BYTE

		xor eax, eax
		@strace <"CreateMetaFileA(", lpszFile, ")=", eax, " *** unsupp">
        ret
		align 4
CreateMetaFileA endp

CloseMetaFile proc public hdc:DWORD
		xor eax, eax
		@strace <"CloseMetaFile(", hdc, ")=", eax, " *** unsupp">
        ret
		align 4

CloseMetaFile endp

DeleteMetaFile proc public hmf:DWORD
		xor eax, eax
		@strace <"DeleteMetaFile(", hmf, ")=", eax, " *** unsupp">
        ret
		align 4

DeleteMetaFile endp

PlayMetaFile proc public hdc:DWORD, hmf:DWORD
		xor eax, eax
		@strace <"PlayMetaFile(", hdc, ", ", hmf, ")=", eax, " *** unsupp">
        ret
		align 4

PlayMetaFile endp

PlayMetaFileRecord proc public hdc:DWORD, lpHandletable:ptr, lpMetaRecord:ptr, nHandles:DWORD
		xor eax, eax
		@strace <"PlayMetaFileRecord(", hdc, ", ", lpHandletable, ", ", lpMetaRecord, ", ", nHandles, ")=", eax, " *** unsupp">
        ret
		align 4

PlayMetaFileRecord endp

CopyMetaFileW proc public hmfSrc:DWORD, lpszFile:ptr BYTE
CopyMetaFileW endp

CopyMetaFileA proc public hmfSrc:DWORD, lpszFile:ptr BYTE
		xor eax, eax
		@strace <"CopyMetaFileA(", hmfSrc, ", ", lpszFile, ")=", eax, " *** unsupp">
        ret
		align 4

CopyMetaFileA endp

GetMetaFileBitsEx proc public hmf:DWORD, nSize:DWORD, lpData:ptr
		xor eax, eax
		@strace <"GetMetaFileBitsEx(", hmf, ", ", nSize, ", ", lpData, ")=", eax, " *** unsupp">
        ret
		align 4

GetMetaFileBitsEx endp

SetMetaFileBitsEx proc public nSize:DWORD, lpData:ptr
		xor eax, eax
		@strace <"SetMetaFileBitsEx(", nSize, ", ", lpData, ")=", eax, " *** unsupp">
        ret
		align 4

SetMetaFileBitsEx endp

EnumMetaFile proc public hdc:DWORD, hmf:DWORD, lpFunc:ptr, lpParam:ptr
		xor eax, eax
		@strace <"EnumMetaFile(", hdc, ", ", hmf, ", ", lpFunc, ", ", lpParam, ")=", eax, " *** unsupp">
        ret
		align 4

EnumMetaFile endp

		end
