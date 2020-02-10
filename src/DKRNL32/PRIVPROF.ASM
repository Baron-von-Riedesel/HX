
;--- implements 
;--- GetPrivateProfileStringA
;--- WritePrivateProfileStringA
;--- GetPrivateProfileSectionA

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

	option dotname

QUOTED_KEYS	equ 1	;1 may be wrong, 0 is Windows standard

;--- file cache entry

FCENTRY struct
pCacheMem	dd 0	;pointer to memory block (starts with file name)
dwSize		dd 0	;size of memory block
bModified	db 0
FCENTRY ends

.BASE$XA SEGMENT dword public 'DATA'
	DD offset destructor
.BASE$XA ENDS

	.data

;--- critical section to protect global variable g_fc

g_cs		CRITICAL_SECTION <>        

;--- the file cache holds just 1 entry, which is the current profile file

g_fc		FCENTRY <>

g_bInit		db 0

	.CODE

ToLower proc
	cmp al,'A'
	jc @F
	cmp al,'Z'
	ja @F
	or al,20h
@@:
	ret
	align 4
ToLower endp

;--- cmp if 2 strings are equal
;--- used by searchsection and searchentry
;--- esi -> string1, null-terminated
;--- edi -> string2, not null-terminated

checkstrings proc uses esi

check_0:
	mov al,[edi]
	call ToLower
	mov ah,al
	lodsb
	cmp al,0
	jz @F
	inc edi
	call ToLower
	cmp al,ah
	jz check_0
@@:
	ret
	align 4
checkstrings endp

;--- compare 2 strings case-sensitive and 
;--- edi is terminated by a '"'

if QUOTED_KEYS

checkstrings2   proc uses esi

check_0:
	mov al,[edi]
	mov ah,al
	mov al,[esi]
	inc esi
	inc edi
	cmp al,ah
	jz check_0
	.if (ah == '"')
		mov ah, [edi]
	.else
		dec edi
	.endif
	dec esi
	mov al,[esi]
	ret
	align 4
checkstrings2   endp

endif

;--- go past next lf
;--- preserve ECX!

skipline proc
nextchar:
	mov al, [edi]
	cmp al, 10
	jz done
	cmp al, 0
	jz doneall
	inc edi
	jmp nextchar
done:
	inc edi
doneall:
	ret
	align 4
skipline endp

skipline2 proc
	.while (byte ptr [esi])
		lodsb
		.break .if (al == 10)
	.endw
	ret
	align 4
skipline2 endp

copykeyname proc

	mov ebx, ecx
	mov edx, edi
next:
	lodsb
	cmp al,'='
	jz iskey
	cmp al,13
	jz done
	cmp al, 0
	jz done2
	stosb
	dec ecx
	jnz next
done2:
	dec esi
done:
	mov edi, edx
	mov ecx, ebx
	jmp exit
iskey:
	mov al,0
	stosb
	dec ecx
exit:
	ret
	align 4

copykeyname endp

;--- copy all keys in a section to edi, max size ecx
;--- end is indicated by 2 00 bytes

getallkeys proc uses ebx

	jecxz done
	dec ecx       ;one byte needed for terminating 0
	.while (ecx )
		lodsb
		.continue .if ( al == ' ' || al == 9 )
		.break .if ( al == 0 || al == '[')
		.if (al == ';' || al == 13 || al == 10 )
		.else
			dec esi
			call copykeyname
		.endif
		call skipline2
	.endw
	mov al,0
	stosb
	dec edi
done:
	ret
	align 4

getallkeys  endp


copysectionname proc

next:
	lodsb
	cmp al,']'
	jz done
	cmp al,13
	jz done
	cmp al, 0
	jz done2
	stosb
	dec ecx
	jnz next
	dec edi
	inc ecx
	jmp done
done2:
	dec esi
done:
	mov al,0
	stosb
	dec ecx
	ret
	align 4

copysectionname endp

;--- copy all section names to edi, max size ecx
;--- end is indicated by 2 00 bytes

getallsections proc

	jecxz done
	dec ecx
	.while (ecx && byte ptr [esi])
		lodsb
		.if (al == '[')
			call copysectionname
		.endif
		call skipline2
	.endw
	mov al,0
	stosb
done:
	ret
	align 4

getallsections  endp

;--- esi -> name of section to search
;--- edi -> buffer where to search
;--- out: C if not found, 
;---        edi -> end of buffered text
;---        dl = -1 if a "subkey" has been found
;---      NC if found, edi -> next line

searchsection   proc

	mov ecx, edi
	mov dl,0
	.while (byte ptr [edi])
		.if (byte ptr [edi] == '[')
			mov ecx, edi
			inc edi
			call checkstrings
			cmp ax, ']' * 100h ; ah==']' && al==0?
			jz done
			cmp ax, '\' * 100h ; ah=='\' && al==0?
			jz @F
			mov dl,-1
@@:
		.endif
		call skipline
	.endw
error:
	stc
	ret
done:
	call skipline
	clc
	ret
	align 4

searchsection endp

;--- in: esi -> key to search
;--- in: edi -> file (points directly behind section name)
;--- out: C if not found, ECX->place for new key
;--- out: NC if found, EDI->'=', ECX->key start

searchentry proc

	mov ecx, edi
	.while (byte ptr [edi])
		mov al,[edi]
		.while (al == ' ' || al == 9 || al == 13 || al == 10 )
			inc edi
			mov al,[edi]
		.endw
		.break .if (al == '[')  ;another section starting?
		cmp al, ';'
		jz skip
		mov ecx, edi
		mov al, [edi]
if QUOTED_KEYS
		.if (al == '"')
			inc edi
			call checkstrings2
		.else
			call checkstrings
		.endif
else
		call checkstrings
endif
		and al,al  ;end of key reached?
		jnz @F
		cmp ah,'='
		jz done
@@:
		call skipline
		mov ecx, edi
		.continue
skip:
		call skipline
	.endw
error:
	stc
	ret
done:
	ret
	align 4

searchentry endp

;--- protect global variable g_fc

init proc
	.if (!g_bInit)
		mov g_bInit, 1
		invoke InitializeCriticalSection, addr g_cs
	.endif
	invoke EnterCriticalSection, addr g_cs
	ret
	align 4
init endp


DestroyFileCacheEntry proc public uses ebx esi edi pFC:ptr FCENTRY

	mov edi, pFC
	.if ([edi].FCENTRY.pCacheMem)
		@strace <"DestroyFileCacheEntry: pCacheMem=", [edi].FCENTRY.pCacheMem>
		.if ([edi].FCENTRY.bModified)
			mov esi, [edi].FCENTRY.pCacheMem
			invoke CreateFileA, esi, GENERIC_WRITE, 0, 0, CREATE_ALWAYS,\
					FILE_ATTRIBUTE_NORMAL, 0
			.if (eax != -1)
				mov ebx, eax
				invoke lstrlen, esi
				lea esi, [eax+esi+1]
				invoke lstrlen, esi
				push 0
				mov ecx, esp
				invoke WriteFile, ebx, esi, eax, ecx, 0
				pop ecx
				invoke SetEndOfFile, ebx
				invoke CloseHandle, ebx
				mov [edi].FCENTRY.bModified, 0
			.endif
		.endif
		invoke VirtualFree, [edi].FCENTRY.pCacheMem, 0, MEM_RELEASE
		mov [edi].FCENTRY.pCacheMem, 0
	.endif
	ret
	align 4

DestroyFileCacheEntry endp        

;--- test if a file is in the 1-entry cache
;--- if yes, return eax!=0
;--- if no, clear cache
;--- modifies edi

IsFileCached proc pszFile:ptr BYTE

	xor eax, eax
	mov edi, offset g_fc
	.if ([edi].FCENTRY.pCacheMem)
		invoke lstrcmpi, [edi].FCENTRY.pCacheMem, pszFile
		.if (!eax)
			invoke lstrlen, [edi].FCENTRY.pCacheMem
			mov edi, [edi].FCENTRY.pCacheMem
			lea edi, [edi+eax+1]
		.else
			invoke DestroyFileCacheEntry, edi
			xor eax, eax
		.endif
	.endif
	ret
	align 4

IsFileCached endp

;--- out: edi=start of file buffer
;--- g_fc.pCacheMem != null

CacheFile proc pszFile:ptr BYTE, bCreate:dword

local	dwSize:dword

	mov eax, OPEN_EXISTING
	mov ecx, GENERIC_READ
	.if (bCreate)
		mov eax, OPEN_ALWAYS
		mov ecx, GENERIC_READ or GENERIC_WRITE
	.endif
	invoke CreateFileA, pszFile, ecx, 0, 0, eax, FILE_ATTRIBUTE_NORMAL, 0
	mov ebx,eax
	cmp eax, -1
	jz exit
	invoke GetFileSize, ebx, 0
	cmp eax, -1
	jz @F
	mov dwSize, eax
	invoke lstrlen, pszFile
	inc eax
	mov esi, eax
	inc eax
	add eax, dwSize
	add eax, 4000h
	and ax, 0F000h
	mov g_fc.dwSize, eax
	invoke VirtualAlloc, 0, eax, MEM_COMMIT, PAGE_READWRITE
	and eax, eax
	jz @F
	mov g_fc.pCacheMem, eax
	lea edi, [esi+eax]
	push 0
	mov eax, esp
	invoke ReadFile, ebx, edi, dwSize, eax, 0
	pop ecx
	mov byte ptr [edi+ecx],0
	invoke lstrcpy, g_fc.pCacheMem, pszFile
@@:
	invoke CloseHandle, ebx
exit:
	mov eax, g_fc.pCacheMem
	ret
	align 4
CacheFile endp

;--- cases:
;--- lpAppName == NULL: copy all section names to buffer
;--- lpKeyName == NULL: copy all key names to buffer
;--- there is a "hidden" value returned in DL:
;--- eax=0, DL=0: value was returned unmodified
;--- eax=0, DL=1: (double) quotes have been stripped off the value string
;--- eax!=0, DL=-1: section wasn't found, but there exist "child" entries.
;---               (this is for the registry emulation in DADVAPI)

GetPrivateProfileStringA proc public uses esi edi ebx lpAppName:ptr byte,
        lpKeyName:ptr byte, lpDefault:ptr byte, retbuff:ptr byte, 
        bufsize:dword, filename:ptr byte

local	rc:dword
local	dwRead:dword
local	dwSize:dword
local	bString:BYTE

	@strace <"GetPrivateProfileStringA(", lpAppName, ", ", lpKeyName,  ", ", lpDefault, ", ", retbuff, ", ", bufsize, ", ", filename, ") enter">
	xor eax,eax
	mov rc,eax
	mov bString,al
	call init

	invoke IsFileCached, filename
	.if (!eax)
		invoke CacheFile, filename, FALSE
	.endif
	and eax, eax
	jz copydefault

	mov esi,lpAppName		  ;search section
	.if (esi)
		call searchsection
		jc copydefault_ex
	.else
		mov esi, edi
		mov ecx,bufsize
		mov edi,retbuff
		call getallsections
		sub edi, retbuff
		dec edi
		mov rc, edi
		jmp exit
	.endif

	mov esi,lpKeyName
	.if (esi)
		call searchentry
		jc copydefault
		jmp copyvalue
	.else
		mov esi, edi		;return all keys of a section
		mov ecx,bufsize
		mov edi,retbuff
		call getallkeys
		sub edi, retbuff
		mov rc, edi
	.endif
	jmp exit
	align 4

getescapechar:
	lodsb
	.if (al == 'r')
		mov al,13
	.elseif (al == 't')
		mov al,9
	.elseif (al == 'n')
		mov al,10
	.endif
	retn
copyvalue:
	mov esi, edi
	inc esi
	mov edi, retbuff
	mov ecx, bufsize
	jecxz cd2
	mov al,[esi]
	mov ah,0
	.if (al == '"')
		inc esi
		mov ah, al
		mov bString,1
	.endif
	dec ecx
nextvaluechar:
	lodsb
	cmp al,13
	jz copyvaluedone
	cmp ax,'"'* 100h + '\'
	jnz @F
	call getescapechar
	jmp storechar
@@:
	cmp ax,'""'			;end of string?
	jnz storechar
	cmp al,[esi]
	jnz copyvaluedone
	inc esi
storechar:
	stosb
	and al,al
	loopnz nextvaluechar
copyvaluedone:
	mov al,0
	stosb
	sub edi, retbuff
	dec edi
	mov rc, edi
	jmp exit
	align 4

copydefault_ex:
	mov bString, dl		;tell caller if there's a "subkey"
copydefault:
	mov esi, lpDefault
	mov edi, retbuff
	mov ecx, bufsize
	jecxz cd2
cd1:
	lodsb
	stosb
	and al,al
	loopnz cd1
	.if (!ecx)
		dec edi
		mov al,0
		stosb
	.endif
	sub edi, retbuff
	dec edi
	mov rc, edi
cd2:

exit:
	invoke LeaveCriticalSection, addr g_cs
	mov eax,rc
ifdef _DEBUG
	mov  ecx, lpAppName
	.if (!ecx)
		mov ecx, CStr("NULL")
	.endif
	mov  edx, lpKeyName
	.if (!edx)
		mov edx, CStr("NULL")
	.endif
	mov  esi, lpDefault
	.if (!esi)
		mov esi, CStr("NULL")
	.endif
	mov  ebx, filename
	.if (!ebx)
		mov ebx, CStr("NULL")
	.endif
	@strace <"GetPrivateProfileStringA(", &ecx, ", ", &edx,  ", ", &esi, ", ", retbuff, ", ", bufsize, ", ", &ebx, ")=", eax>
endif
	mov dl,bString
	ret
	align 4

GetPrivateProfileStringA endp

;--- this version copies all non-empty lines of a section into the buffer

GetPrivateProfileSectionA proc public uses esi edi ebx lpAppName:ptr BYTE,
        lpReturnedString:ptr BYTE, nSize:DWORD, lpFileName:ptr byte

local	rc:DWORD

	xor eax, eax
	mov rc, eax
	call init
	invoke IsFileCached, lpFileName
	.if (!eax)
		invoke CacheFile, lpFileName, FALSE
	.endif
	mov esi,lpAppName		  ;search section
	call searchsection
	jc exit
	mov esi, edi
	mov ecx,nSize
	mov edi,lpReturnedString
	jecxz @F
	dec ecx		;room for terminating 00
	.while (ecx)
		.repeat 
			lodsb
			dec ecx
		.until ( al != ' ' && al != 9 )
		inc ecx
		.break .if (al == 0)
		.break .if (al == '[')
			
		.if ((al == ';') || (al <= ' '))
			call skipline2
		.else
			stosb
			dec ecx
			.while (ecx)
				lodsb
				.continue .if (al == 13)
				.if (al == 10)
					mov al,0
				.endif
				stosb
				dec ecx
				.break .if (al == 0)
			.endw
		.endif
	.endw
	mov al,0
	mov [edi],al	;do not count the terminating 00
@@:        
	sub edi, lpReturnedString
	mov rc, edi
exit:

	invoke LeaveCriticalSection, addr g_cs
	mov eax,rc
	@strace <"GetPrivateProfileSectionA(", lpAppName, ", ", lpReturnedString, ", ", nSize, ", ", lpFileName, ")=", eax>
	ret
	align 4

GetPrivateProfileSectionA endp

;--- if lpAppName, lpKeyName and lpValue are NULL, the cache is flushed
;--- (this should always return 0)
;--- if lpKeyName is NULL, the entire section is deleted
;--- if lpValue is NULL, the key is deleted

WritePrivateProfileStringA proc public uses esi edi ebx lpAppName:ptr byte,
            lpKeyName:ptr byte, lpValue:ptr byte, filename:ptr byte
 
local	rc:dword
local	dwSize:dword
local	dwAppSize:dword
local	dwKeySize:dword
local	dwValueSize:dword

	xor eax, eax
	mov rc,eax
	mov dwKeySize, eax
	mov dwValueSize, eax
	call init

	mov ebx, lpAppName
	mov esi, lpKeyName
	mov edi, lpValue
	mov eax, ebx
	or eax, esi
	or eax, edi
	jnz @F
;--- all three entries NULL? -> flush cache
	invoke DestroyFileCacheEntry, offset g_fc
	jmp done
@@:
	and ebx, ebx		; section NULL? then exit with rc=0
	jz done
	invoke lstrlen, ebx
	mov dwAppSize, eax
	.if (esi)
		invoke lstrlen, esi
		mov dwKeySize, eax
	.endif
	.if (edi)
		invoke lstrlen, edi
		mov dwValueSize, eax
	.endif

	invoke IsFileCached, filename
	.if (!eax)
		invoke CacheFile, filename, TRUE
	.else
		invoke lstrlen, edi
		lea eax, [eax+edi+1]
		sub eax, g_fc.pCacheMem
		add eax, 1000h				;let's assume an entry is < 4 kB!
		cmp eax, g_fc.dwSize		;is there enough free space?
		jc @F
		invoke DestroyFileCacheEntry, addr g_fc
		invoke CacheFile, filename, FALSE
@@:
	.endif
	and eax, eax
	jz exit

	mov esi,lpAppName
	call searchsection
	jc insertnewsection
;	@strace <"section found at ", edi>

	mov esi,lpKeyName
	and esi, esi
	jz deletesection
	call searchentry
	jc insertnewkey
;	@strace <"key found at ", edi>

	mov esi,lpValue
	and esi, esi
	jz deletekey

replacevalue:
	inc edi					;skip "="
	xor ecx,ecx
	.while (1)
		mov al, [edi+ecx]
		.break .if ((al == 0) || (al == 13))
		inc ecx
	.endw
;---------------------------------------- if value hasnt changed, do nothing
	.if (ecx == dwValueSize)
		pushad
		repz cmpsb
		popad
		.if (ZERO?)
			mov rc,1
			jmp done
		.endif
	.endif
	mov esi, dwValueSize
	add esi, edi
	push edi
	lea edi, [edi+ecx]
	invoke lstrlen, edi		;get length of rest of profile file
	inc eax						;include terminating 0?
	invoke RtlMoveMemory, esi, edi, eax
	pop edi
	mov esi, lpValue
	mov ecx, dwValueSize
	rep movsb
	mov rc, 1					;no need to return size of string here
	jmp rewritefile
	align 4

deletesection:
;--- edi -> section content
;--- ecx -> start section entry [...]
	push ecx
	.while (byte ptr [edi] && byte ptr [edi] != '[')
		call skipline
	.endw
	invoke lstrlen, edi
	pop ecx
	inc eax
	invoke RtlMoveMemory, ecx, edi, eax
	mov rc, 1
	jmp rewritefile
	align 4

deletekey:
;--- edi -> behind key name
;--- ecx -> start key entry
	push ecx
	call skipline
	invoke lstrlen, edi
	pop ecx
	inc eax
	invoke RtlMoveMemory, ecx, edi, eax
	mov rc, 1
	jmp rewritefile
	align 4

;--- edi -> end of buffered text
insertnewsection:
	cmp lpKeyName, 0			; nonexisting section to be deleted?
	jz done

	@strace <"insert new section">
	mov ax, 0A0Dh
	stosw
	mov al,'['
	stosb
	mov esi, lpAppName
	mov ecx, dwAppSize
	rep movsb
	mov al,']'
	stosb
	mov ax,0A0Dh
	stosw
	mov byte ptr [edi],0
	mov ecx, edi
insertnewkey:
;--- ecx -> place to enter new key. This is behind the last key
;--- and before the start of an optional next section
	@strace <"insert new key">
	mov esi, lpKeyName
	cmp byte ptr [esi],' '  ;invalid key?
	jbe done
	mov rc, 1
	cmp lpValue, 0	;is the - non-existing - key to be deleted?
	jz done			;then just exit
	mov edi, ecx
	mov bl,0
	.if (byte ptr [edi])  ;make room for the entry to add
		invoke lstrlen, edi
		inc eax           ;don't forget to copy the terminating 0!
		mov edx, dwKeySize
		add edx, dwValueSize
		add edx, 3	;place for '=', cr and lf
		add edx, edi
		invoke RtlMoveMemory, edx, edi, eax
		mov bl,1
	.endif
	mov ecx, dwKeySize
	rep movsb
	mov al,'='
	stosb
	mov esi, lpValue
	mov ecx, dwValueSize
	rep movsb
	mov ax,0A0Dh
	stosw
	cmp bl,0
	jnz @F
	mov al,0
	stosb
@@:
rewritefile:
	mov g_fc.bModified, 1
done:
exit:
	invoke LeaveCriticalSection, addr g_cs
	mov eax,rc
ifdef _DEBUG
	push ebx
	mov  ecx, lpAppName
	.if (!ecx)
		mov ecx, CStr("NULL")
	.endif
	mov  edx, lpKeyName
	.if (!edx)
		mov edx, CStr("NULL")
	.endif
	mov  ebx, lpValue
	.if (!ebx)
		mov ebx, CStr("NULL")
	.endif
	@strace <"WritePrivateProfileStringA(", &ecx, ", ", &edx, ", ", &ebx, ", ", &filename, ")=", eax>
	pop ebx
endif
	ret
	align 4

WritePrivateProfileStringA endp

destructor proc
	@strace <"private profile destructor enter">
	invoke DestroyFileCacheEntry, offset g_fc
	ret
destructor endp

	end

