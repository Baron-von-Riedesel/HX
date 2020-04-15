
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

CreateEnhMetaFileW proc public hdcRef:DWORD, lpFilename:ptr BYTE, lpRect:ptr RECT, lpDescription:ptr BYTE
CreateEnhMetaFileW endp

CreateEnhMetaFileA proc public hdcRef:DWORD, lpFilename:ptr BYTE, lpRect:ptr RECT, lpDescription:ptr BYTE

		xor eax, eax
		@strace <"CreateEnhMetaFileA(", hdcRef, ", ", lpFilename, ", ", lpRect, ", ", lpDescription, ")=", eax, " *** unsupp">
        ret
		align 4
CreateEnhMetaFileA endp

CloseEnhMetaFile proc public hdc:DWORD
		xor eax, eax
		@strace <"CloseEnhMetaFile(", hdc, ")=", eax, " *** unsupp">
        ret
		align 4

CloseEnhMetaFile endp

DeleteEnhMetaFile proc public hemf:DWORD
		xor eax, eax
		@strace <"DeleteEnhMetaFile(", hemf, ")=", eax, " *** unsupp">
        ret
		align 4

DeleteEnhMetaFile endp

PlayEnhMetaFile proc public hdc:DWORD, hemf:DWORD, lpRect:ptr RECT
		xor eax, eax
		@strace <"PlayEnhMetaFile(", hdc, ", ", hemf, ", ", lpRect, ")=", eax, " *** unsupp">
        ret
		align 4

PlayEnhMetaFile endp

PlayEnhMetaFileRecord proc public hdc:DWORD, lpHandletable:ptr, lpEnhMetaRecord:ptr, nHandles:DWORD
		xor eax, eax
		@strace <"PlayEnhMetaFileRecord(", hdc, ", ", lpHandletable, ", ", lpEnhMetaRecord, ", ", nHandles, ")=", eax, " *** unsupp">
        ret
		align 4

PlayEnhMetaFileRecord endp

CopyEnhMetaFileW proc public hemfSrc:DWORD, lpszFile:ptr BYTE
CopyEnhMetaFileW endp

CopyEnhMetaFileA proc public hemfSrc:DWORD, lpszFile:ptr BYTE
		xor eax, eax
		@strace <"CopyEnhMetaFileA(", hemfSrc, ", ", lpszFile, ")=", eax, " *** unsupp">
        ret
		align 4

CopyEnhMetaFileA endp

GetEnhMetaFileBits proc public hemf:DWORD, cbBuffer:DWORD, lpBuffer:ptr
		xor eax, eax
		@strace <"GetEnhMetaFileBits(", hemf, ", ", cbBuffer, ", ", lpBuffer, ")=", eax, " *** unsupp">
        ret
		align 4

GetEnhMetaFileBits endp

SetEnhMetaFileBits proc public cbBuffer:DWORD, lpBuffer:ptr
		xor eax, eax
		@strace <"SetEnhMetaFileBits(", cbBuffer, ", ", lpBuffer, ")=", eax, " *** unsupp">
        ret
		align 4

SetEnhMetaFileBits endp

GetEnhMetaFileHeader proc public hemf:DWORD, cbBuffer:DWORD, lpemh:ptr
		xor eax, eax
		@strace <"GetEnhMetaFileHeader(", hemf, ", ", cbBuffer, ", ", lpemh, ")=", eax, " *** unsupp">
        ret
		align 4

GetEnhMetaFileHeader endp

GetEnhMetaFilePaletteEntries proc public hemf:DWORD, cEntries:DWORD, lppe:ptr
		xor eax, eax
		@strace <"GetEnhMetaFilePaletteEntries(", hemf, ", ", cEntries, ", ", lppe, ")=", eax, " *** unsupp">
        ret
		align 4

GetEnhMetaFilePaletteEntries endp

EnumEnhMetaFile proc public hdc:DWORD, hemf:DWORD, lpFunc:ptr, lpData:ptr, lpRect:ptr RECT
		xor eax, eax
		@strace <"EnumEnhMetaFile(", hdc, ", ", hemf, ", ", lpFunc, ", ", lpData, ", ", lpRect, ")=", eax, " *** unsupp">
        ret
		align 4

EnumEnhMetaFile endp

GetWinMetaFileBits proc public hemf:DWORD, cbBuffer:DWORD, lpBuffer:ptr, fnMapMode:DWORD, hdcRef:DWORD
		xor eax, eax
		@strace <"GetWinMetaFileBits(", hemf, ", ", cbBuffer, ", ", lpBuffer, ", ", fnMapMode, ", ", hdcRef, ")=", eax, " *** unsupp">
        ret
		align 4

GetWinMetaFileBits endp

SetWinMetaFileBits proc public cbBuffer:DWORD, lpBuffer:ptr, hdcRef:DWORD, lpmfp:ptr
		xor eax, eax
		@strace <"SetWinMetaFileBits(", cbBuffer, ", ", lpBuffer, ", ", hdcRef, ", ", lpmfp, ")=", eax, " *** unsupp">
        ret
		align 4

SetWinMetaFileBits endp

		end
