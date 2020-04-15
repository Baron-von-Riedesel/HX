
        .386
if ?FLAT
        .MODEL FLAT, stdcall
else
        .MODEL SMALL, stdcall
endif
		option casemap:none
        option proc:private

        include winbase.inc
        include macros.inc

        .CODE

RegisterEventSourceA proc public lpUNCServerName:ptr BYTE, lpSourceName:ptr BYTE
		xor eax, eax
		@strace <"RegisterEventSourceA(", lpUNCServerName, ", ", lpSourceName, ")=", eax, " *** unsupp ***">
		ret
        align 4
RegisterEventSourceA endp

RegisterEventSourceW proc public lpUNCServerName:ptr WORD, lpSourceName:ptr WORD
		xor eax, eax
		@strace <"RegisterEventSourceW(", lpUNCServerName, ", ", lpSourceName, ")=", eax, " *** unsupp ***">
		ret
        align 4
RegisterEventSourceW endp

DeregisterEventSource proc public hEventLog:DWORD
		xor eax, eax
		@strace <"DeregisterEventSource(", hEventLog, ")=", eax, " *** unsupp ***">
		ret
        align 4
DeregisterEventSource endp

ReportEventA proc public hEventLog:DWORD, wType:DWORD, wCategory:DWORD, dwEvtId:dword, lpUserSID:ptr, wNumString:Dword, dwDataSize:dword, lpStrings:ptr ptr, lpRawData:ptr
		xor eax, eax
		@strace <"ReportEventA(", hEventLog, ", ", wType, ", ", wCategory, ", ", dwEvtId, ", ", lpUserSID, ", ", wNumString, ", ", dwDataSize, ", ", lpStrings, ", ", lpRawData, ")=", eax, " *** unsupp ***">
		ret
        align 4
ReportEventA endp

ReportEventW proc public hEventLog:DWORD, wType:DWORD, wCategory:DWORD, dwEvtId:dword, lpUserSID:ptr, wNumString:Dword, dwDataSize:dword, lpStrings:ptr ptr, lpRawData:ptr
		xor eax, eax
		@strace <"ReportEventW(", hEventLog, ", ", wType, ", ", wCategory, ", ", dwEvtId, ", ", lpUserSID, ", ", wNumString, ", ", dwDataSize, ", ", lpStrings, ", ", lpRawData, ")=", eax, " *** unsupp ***">
		ret
        align 4
ReportEventW endp

		end
