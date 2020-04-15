
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

;--- SecurityDescriptor

InitializeSecurityDescriptor proc public pSecurityDescriptor:DWORD, dwRevision:dword

	@mov eax, 1
	@strace <"InitializeSecurityDescriptor(", pSecurityDescriptor, ", ", dwRevision, ")=", eax, " *** unsupp ***">
	ret
	align 4

InitializeSecurityDescriptor endp

GetSecurityDescriptorControl proc public pSecurityDescriptor:DWORD, pControl:DWORD, lpdwRevision:ptr DWORD

	xor eax, eax
	@strace <"GetSecurityDescriptorControl(", pSecurityDescriptor, ", ", pControl, ", ", lpdwRevision, ")=", eax, " *** unsupp ***">
	ret
	align 4

GetSecurityDescriptorControl endp

GetKernelObjectSecurity proc public handle:DWORD, RequestedInformation:DWORD, pSecurityDescriptor:DWORD, nLength:DWORD, pnLengthNeeded:DWORD

	xor eax, eax
	@strace <"GetKernelObjectSecurity(", handle, ", ", RequestedInformation, ", ", pSecurityDescriptor, ", ", nLength, ", ", pnLengthNeeded, ")=", eax, " *** unsupp ***">
	ret
	align 4

GetKernelObjectSecurity endp

SetKernelObjectSecurity proc public pSecurityDescriptor:DWORD, SecurityInformation:DWORD, SecurityDescriptor:DWORD

	xor eax, eax
	@strace <"SetKernelObjectSecurity(", pSecurityDescriptor, ", ", SecurityInformation, ", ", SecurityDescriptor, ")=", eax, " *** unsupp ***">
	ret
	align 4

SetKernelObjectSecurity endp

IsValidSecurityDescriptor proc public pSecurityDescriptor:DWORD

	xor eax, eax
	@strace <"IsValidSecurityDescriptor(", pSecurityDescriptor, ")=", eax, " *** unsupp ***">
	ret
	align 4

IsValidSecurityDescriptor endp

GetSecurityDescriptorDacl proc public pSecurityDescriptor:DWORD, lpbDaclPresent:DWORD, pDacl:DWORD, lpbDaclDefaulted:DWORD

	xor eax, eax
	@strace <"GetSecurityDescriptorDacl(", pSecurityDescriptor, ", ", lpbDaclPresent, ", ", pDacl, ", ", lpbDaclDefaulted, ")=", eax, " *** unsupp ***">
	ret
	align 4

GetSecurityDescriptorDacl endp

SetSecurityDescriptorDacl proc public pSecurityDescriptor:DWORD, bDaclPresent:DWORD, Dacl:DWORD, bDaclDefaulted:DWORD

	xor eax, eax
	@strace <"SetSecurityDescriptorDacl(", pSecurityDescriptor, ", ", bDaclPresent, ", ", Dacl, ", ",  bDaclDefaulted, ")=", eax, " *** unsupp ***">
	ret
	align 4

SetSecurityDescriptorDacl endp

GetSecurityDescriptorSacl proc public pSecurityDescriptor:DWORD, lpbSaclPresent:DWORD, pSacl:DWORD, pbSaclDefaulted:DWORD

	xor eax, eax
	@strace <"GetSecurityDescriptorSacl(", pSecurityDescriptor, ", ", lpbSaclPresent, ", ", pSacl, ", ", pbSaclDefaulted, ")=", eax, " *** unsupp ***">
	ret
	align 4

GetSecurityDescriptorSacl endp

GetSecurityDescriptorOwner proc public pSecurityDescriptor:DWORD, pOwner:DWORD, lpbOwnerDefaulted:DWORD

	xor eax, eax
	@strace <"GetSecurityDescriptorOwner(", pSecurityDescriptor, ", ", pOwner, ", ", lpbOwnerDefaulted, ")=", eax, " *** unsupp ***">
	ret
	align 4

GetSecurityDescriptorOwner endp

GetSecurityDescriptorGroup proc public pSecurityDescriptor:DWORD, pGroup:DWORD, lpbGroupDefaulted:DWORD

	xor eax, eax
	@strace <"GetSecurityDescriptorGroup(", pSecurityDescriptor, ", ", pGroup, ", ", lpbGroupDefaulted, ")=", eax, " *** unsupp ***">
	ret
	align 4

GetSecurityDescriptorGroup endp

GetSecurityDescriptorLength proc public pSecurityDescriptor:DWORD

	xor eax, eax
	@strace <"GetSecurityDescriptorLength(", pSecurityDescriptor, ")=", eax, " *** unsupp ***">
	ret
	align 4

GetSecurityDescriptorLength endp

GetSecurityInfo proc public handle:DWORD, ObjectType:DWORD, SecurityInfo:DWORD, ppsidOwner:ptr DWORD, ppsidGroup:ptr DWORD, ppDacl:ptr DWORD, ppSacl:ptr DWORD, ppSecurityDescriptor:ptr DWORD

	xor eax, eax
	@strace <"GetSecurityInfo(", handle, ", ", ObjectType, ", ", SecurityInfo, ", ", ppsidOwner, ", ", ppsidGroup, ", ", ppDacl, ", ", ppSacl, ", ", ppSecurityDescriptor, ")=", eax, " *** unsupp ***">
	ret
	align 4

GetSecurityInfo endp

GetFileSecurityA proc public lpFileName:DWORD, SecurityInformation:DWORD, pSecurityDescriptor:DWORD, nLength:DWORD, lpnLengthNeeded:DWORD

	xor eax, eax
	@strace <"GetFileSecurityA(", lpFileName, ", ", SecurityInformation, ", ", pSecurityDescriptor, ", ", nLength, ", ", lpnLengthNeeded, ")=", eax, " *** unsupp ***">
	ret
	align 4

GetFileSecurityA endp

GetFileSecurityW proc public lpFileName:DWORD, SecurityInformation:DWORD, pSecurityDescriptor:DWORD, nLength:DWORD, lpnLengthNeeded:DWORD

	xor eax, eax
	@strace <"GetFileSecurityW(", lpFileName, ", ", SecurityInformation, ", ", pSecurityDescriptor, ", ", nLength, ", ", lpnLengthNeeded, ")=", eax, " *** unsupp ***">
	ret
	align 4

GetFileSecurityW endp

SetFileSecurityA proc public lpFileName:DWORD, SecurityInformation:DWORD, pSecurityDescriptor:DWORD

	xor eax, eax
	@strace <"SetFileSecurityA(", lpFileName, ", ", SecurityInformation, ", ", pSecurityDescriptor, ")=", eax, " *** unsupp ***">
	ret
	align 4

SetFileSecurityA endp

SetFileSecurityW proc public lpFileName:DWORD, SecurityInformation:DWORD, pSecurityDescriptor:DWORD

	xor eax, eax
	@strace <"SetFileSecurityW(", lpFileName, ", ", SecurityInformation, ", ", pSecurityDescriptor, ")=", eax, " *** unsupp ***">
	ret
	align 4

SetFileSecurityW endp

;--- Token

OpenProcessToken proc public hProcess:DWORD, DesiredAccess:DWORD, TokenHandle:ptr DWORD

	xor eax, eax
	@strace <"OpenProcessToken", hProcess, ", ", DesiredAccess, ", ", TokenHandle, ")=", eax, " *** unsupp ***">
	ret
	align 4

OpenProcessToken endp

OpenThreadToken proc public hThread:DWORD, DesiredAccess:DWORD, OpenAsSelf:DWORD, TokenHandle:ptr DWORD

	xor eax, eax
	@strace <"OpenThreadToken", hThread, ", ", DesiredAccess, ", ", OpenAsSelf, ", ", TokenHandle, ")=", eax, " *** unsupp ***">
	ret
	align 4

OpenThreadToken endp

GetTokenInformation proc public TokenHandle:DWORD, TokenInformationClass:DWORD, TokenInformation:ptr, TokenInformationLength:DWORD, ReturnLength:ptr DWORD

	xor eax, eax
	@strace <"GetTokenInformation(", TokenHandle, ", ", TokenInformationClass, ", ", TokenInformation, ", ", TokenInformationLength, ", ", ReturnLength, ")=", eax, " *** unsupp ***">
	ret
	align 4

GetTokenInformation endp

SetThreadToken proc public Thread:DWORD, Token:DWORD

	xor eax, eax
	@strace <"SetThreadToken(", Thread, ", ", Token, ")=", eax, " *** unsupp ***">
	ret
	align 4

SetThreadToken endp

AdjustTokenPrivileges proc public hToken:DWORD, DisableAllPrivileges:DWORD, NewState:DWORD, BufferLength:DWORD, PreviousState:DWORD, ReturnLength:DWORD

	xor eax, eax
	@strace <"AdjustTokenPrivileges(", hToken, ", ", DisableAllPrivileges, ", ", NewState, ", ", BufferLength, ", ", PreviousState, ", ", ReturnLength, ")=", eax, " *** unsupp ***">
	ret
	align 4

AdjustTokenPrivileges endp

DuplicateToken proc public hToken:DWORD, ImpersonationLevel:DWORD, DuplicateTokenHandle:ptr DWORD

	xor eax, eax
	@strace <"DuplicateToken(", hToken, ", ", ImpersonationLevel, ", ", DuplicateTokenHandle, ")=", eax, " *** unsupp ***">
	ret
	align 4

DuplicateToken endp

DuplicateTokenEx proc public hToken:DWORD, dwDesiredAccess:DWORD, lpTokenAttributes:ptr, ImpersonationLevel:DWORD, TokenType:DWORD, phNewToken: ptr DWORD

	xor eax, eax
	@strace <"DuplicateTokenEx(", hToken, ", ", dwDesiredAccess, ", ", lpTokenAttributes, ", ", ImpersonationLevel, ", ", TokenType, ", ", phNewToken, ")=", eax, " *** unsupp ***">
	ret
	align 4

DuplicateTokenEx endp

;--- Acl (access control list)

InitializeAcl proc public pAcl:DWORD, nAclLength:DWORD, dwAclRevision:DWORD

	xor eax, eax
	@strace <"InitializeAcl(", pAcl, ", ", nAclLength, ", ", dwAclRevision, ")=", eax, " *** unsupp ***">
	ret
	align 4

InitializeAcl endp

IsValidAcl proc public pAcl:DWORD

	xor eax, eax
	@strace <"IsValidAcl(", pAcl, ")=", eax, " *** unsupp ***">
	ret
	align 4

IsValidAcl endp

SetEntriesInAclW proc public cCount:DWORD, pList:ptr, OldAcl:DWORD, NewAcl:ptr DWORD

	xor eax, eax
	@strace <"SetEntriesInAclW(", cCount, ", ", pList, ", ", OldAcl, ", ", NewAcl, ")=", eax, " *** unsupp ***">
	ret
	align 4

SetEntriesInAclW endp

;--- Ace (access control entry)

AddAccessAllowedAce proc public pAcl:DWORD, dwAceRevision:DWORD, AccessMask:DWORD, pSid:ptr

	xor eax, eax
	@strace <"AddAccessAllowedAce(", pAcl, ", ", dwAceRevision, ", ", AccessMask, ", ", pSid, ")=", eax, " *** unsupp ***">
	ret
	align 4

AddAccessAllowedAce endp

DeleteAce proc public pAcl:DWORD, dwAceIndex:DWORD

	xor eax, eax
	@strace <"DeleteAce(", pAcl, ", ", dwAceIndex, ")=", eax, " *** unsupp ***">
	ret
	align 4

DeleteAce endp

GetAce proc public pAcl:DWORD, dwAceIndex:DWORD, pAce:ptr 

	xor eax, eax
	@strace <"GetAce(", pAcl, ", ", dwAceIndex, ", ", pAce, ")=", eax, " *** unsupp ***">
	ret
	align 4

GetAce endp

;--- Sid (Security IDentifier)

AllocateAndInitializeSid proc public dw1:dword, dw2:dword, dw3:dword, 
			dw4:dword, dw5:dword, dw6:dword, dw7:dword, dw8:dword,
			dw9:dword, dw10:dword, dw11:dword

	xor eax, eax
	@strace <"AllocateAndInitializeSid(...)=", eax>
	ret
	align 4

AllocateAndInitializeSid endp

InitializeSid proc public pSid:ptr SID, pAuth:ptr SID_IDENTIFIER_AUTHORITY, nCnt:dword

	mov edx, pSid
	mov ecx, pAuth
	mov eax, dword ptr [ecx].SID_IDENTIFIER_AUTHORITY.Value+0
	mov dword ptr [edx].SID.IdentifierAuthority+0, eax
	mov ax, word ptr [ecx].SID_IDENTIFIER_AUTHORITY.Value+4
	mov word ptr [edx].SID.IdentifierAuthority+4, ax
	mov eax, nCnt
	mov [edx].SID.SubAuthorityCount, al
	mov eax, 1
	@strace <"InitializeSid(", pSid, ", ", pAuth, ", ", nCnt, ")=", eax, " *** unsupp ***">
	ret
	align 4

InitializeSid endp

IsValidSid proc public pSid:DWORD

	xor eax, eax
	@strace <"IsValidSid(", pSid, ")=", eax, " *** unsupp ***">
	ret
	align 4

IsValidSid endp

EqualSid proc public pSid1:ptr, pSid2:ptr

	xor eax, eax
	@strace <"EqualSid(", pSid1, ", ", pSid2, ")=", eax>
	ret
	align 4

EqualSid endp

GetLengthSid proc public pSid:ptr

	xor eax, eax
	@strace <"GetLengthSid(", pSid, ")=", eax>
	ret
	align 4

GetLengthSid endp

CopySid proc public nDestinationSidLength:DWORD, pDestinationSid:DWORD, pSourceSid:DWORD

	xor eax, eax
	@strace <"CopySid(", nDestinationSidLength, ", ", pDestinationSid, ", ", pSourceSid, ")=", eax>
	ret
	align 4

CopySid endp

FreeSid proc public pSid:ptr

	xor eax, eax
	@strace <"FreeSid(", pSid, ")=", eax>
	ret
	align 4

FreeSid endp

GetSidIdentifierAuthority proc public pSid:ptr

	xor eax, eax
	@strace <"GetSidIdentifierAuthority(", pSid, ")=", eax>
	ret
	align 4

GetSidIdentifierAuthority endp

GetSidSubAuthorityCount proc public pSid:ptr

	xor eax, eax
	@strace <"GetSidSubAuthorityCount(", pSid, ")=", eax>
	ret
	align 4

GetSidSubAuthorityCount endp

GetSidSubAuthority proc public pSid:ptr, nSubAuthority:DWORD

	xor eax, eax
	@strace <"GetSidSubAuthority(", pSid, ", ", nSubAuthority, ")=", eax>
	ret
	align 4

GetSidSubAuthority endp

LookupAccountSidA proc public lpSystemName:ptr BYTE, Sid:DWORD, Name_:ptr BYTE, cbName:ptr DWORD, DomainName:ptr BYTE, cbDomainName:ptr DWORD, peUse:ptr

	xor eax, eax
	@strace <"LookupAccountSidA(", lpSystemName, ", ", Sid, ", ", Name_, ", ", cbName, ", ", DomainName, ", ", cbDomainName, ", ", peUse, ")=", eax>
	ret
	align 4

LookupAccountSidA endp

LookupAccountSidW proc public lpSystemName:ptr WORD, Sid:DWORD, Name_:ptr WORD, cbName:ptr DWORD, DomainName:ptr WORD, cbDomainName:ptr DWORD, peUse:ptr

	xor eax, eax
	@strace <"LookupAccountSidW(", lpSystemName, ", ", Sid, ", ", Name_, ", ", cbName, ", ", DomainName, ", ", cbDomainName, ", ", peUse, ")=", eax>
	ret
	align 4

LookupAccountSidW endp

;--- div

LookupPrivilegeValueA proc public lpSystemName:DWORD, lpName:DWORD, lpLuid:DWORD

	xor eax, eax
	@strace <"LookupPrivilegeValueA *** unsupp ***">
	ret
	align 4

LookupPrivilegeValueA endp

MakeAbsoluteSD proc public pSelfRelativeSD:ptr, pAbsoluteSD:ptr, lpdwAbsoluteSDSize:ptr DWORD, pDacl:ptr, lpdwDacsSize:ptr DWORD, pSacl:ptr, lpdwSaclSize:ptr DWORD, pOwner:ptr, lpdwOwnerSize:ptr DWORD, pPrimaryGroup:ptr, lpdwPrimaryGroupSize:ptr DWORD

	xor eax, eax
	@strace <"MakeAbsoluteSD(", pSelfRelativeSD, ", ", pAbsoluteSD, ",...)=", eax>
	ret
	align 4

MakeAbsoluteSD endp

AllocateLocallyUniqueId proc public Luid:ptr

	xor eax, eax
	@strace <"AllocateLocallyUniqueId(", Luid, ")=", eax>
	ret
	align 4

AllocateLocallyUniqueId endp

LookupAccountNameA proc public lpSystemName:DWORD, lpAccountName:DWORD, Sid:ptr, cbSid:ptr DWORD, DomainName:ptr, cbDomainName:ptr DWORD, peUse:ptr

	xor eax, eax
	@strace <"LookupAccountNameA(", lpSystemName, ", ", lpAccountName, ", ", Sid, ", ", cbSid, ",...)=", eax>
	ret
	align 4
        
LookupAccountNameA endp

LookupAccountNameW proc public lpSystemName:DWORD, lpAccountName:DWORD, Sid:ptr, cbSid:ptr DWORD, DomainName:ptr, cbDomainName:ptr DWORD, peUse:ptr

	xor eax, eax
	@strace <"LookupAccountNameW(", lpSystemName, ", ", lpAccountName, ", ", Sid, ", ", cbSid, ",...)=", eax>
	ret
	align 4
        
LookupAccountNameW endp

ImpersonateLoggedOnUser proc public hToken:DWORD

	xor eax, eax
	@strace <"ImpersonateLoggedOnUser(", hToken, ")=", eax>
	ret
	align 4
        
ImpersonateLoggedOnUser endp

RevertToSelf proc public

	mov eax, 1
	@strace <"RevertToSelf()=", eax>
	ret
	align 4
        
RevertToSelf endp

	end
