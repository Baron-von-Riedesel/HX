
;--- implements CreateFileA()

	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:none
	option proc:private
	option dotname

	include winbase.inc
	include macros.inc
	include dkrnl32.inc

;;_DEBUG	equ 1

extern __CHECKOS:abs	;check if NT/W2K/XP (bug in LFN functions)

.BASE$D	segment dword public 'DATA'
_startvxd label near
.BASE$D	ends

.BASE$DA segment dword public 'DATA'
.BASE$DA ends

.BASE$DZ segment dword public 'DATA'
_endvxd label near
.BASE$DZ ends

ifdef ?OMF
DGROUP	group .BASE$D, .BASE$DA, .BASE$DZ
endif
	.DATA
        
if ?COMMSUPP        
	public g_ComHandler
g_ComHandler dd 0
endif

	.CODE

;access:    GENERIC_READ        80000000
;           GENERIC_WRITE       40000000
;sharemode: FILE_SHARE_DELETE   4
;           FILE_SHARE_WRITE    2
;           FILE_SHARE_READ     1

;bits 7-4: actions if file does not exist
;bits 3-0: actions if file does exist

FILE_CREATE   equ 0010h  ; file doesnt exist, create it (error if file exists)

FILE_OPEN     equ 0001h  ; file exists, open (error if file not exists)
FILE_TRUNCATE equ 0002h  ; file exists, truncate (error if file not exists)


;Win32      FILE_ATTRIBUTE_ARCHIVE       20        x
;Attribs    FILE_ATTRIBUTE_COMPRESSED   800
;           FILE_ATTRIBUTE_DIRECTORY     10       (x)
;           FILE_ATTRIBUTE_HIDDEN         2        x
;           FILE_ATTRIBUTE_NORMAL        80
;           FILE_ATTRIBUTE_OFFLINE     1000
;           FILE_ATTRIBUTE_READONLY       1        x
;           FILE_ATTRIBUTE_SYSTEM         4        x
;           FILE_ATTRIBUTE_TEMPORARY    100

;Win32      FILE_FLAG_WRITE_THROUGH     80000000
;Flags      FILE_FLAG_OVERLAPPED        40000000
;           FILE_FLAG_NO_BUFFERING      20000000
;           FILE_FLAG_RANDOM_ACCESS     10000000
;           FILE_FLAG_SEQUENTIAL_SCAN   08000000
;           FILE_FLAG_DELETE_ON_CLOSE   04000000
;           FILE_FLAG_BACKUP_SEMANTICS  02000000
;           FILE_FLAG_POSIX_SEMANTICS   01000000

;DOS        _A_NORMAL 0000
;Attribs    _A_RDONLY 0001
;(in CX)    _A_HIDDEN 0002
;           _A_SYSTEM 0004
;           _A_VOLID  0008
;           _A_ARCH   0020

;--- CREATE_NEW		1
;--- CREATE_ALWAYS	2
;--- OPEN_EXISTING	3
;--- OPEN_ALWAYS	4
;--- TRUNCATE_EXISTING 5

translate_action proc

	mov     dl,FILE_CREATE      ;create if not exist, else error
	cmp     eax,CREATE_NEW
	jz      exit
	or      dl,FILE_OPEN        ;create if not exist, open if exist
	cmp     eax,OPEN_ALWAYS     ;never fails
	jz      exit
	mov     dl,FILE_CREATE or FILE_TRUNCATE
	cmp     eax,CREATE_ALWAYS   ;never fails
	jz      exit
	mov     dl,FILE_TRUNCATE    ;open & trunc, error if exists
	cmp     eax,TRUNCATE_EXISTING
	jz      exit
	mov     dl,FILE_OPEN        ;fails if file not exists
;	cmp     eax,OPEN_EXISTING
;	jz      exit
exit:
	ret
	align 4

translate_action endp

translate_attributes proc

;ax = HIDDEN,NORMAL,READONLY,SYSTEM (TEMPORARY,COMPRESSED,ARCHIVE)

	movzx ecx,ax
	and cl,7Fh		;attribut Win32-"Normal"=80h,dos-"normal"=0
if 0
	test eax, FILE_FLAG_WRITE_THROUGH
	jz @F
	or bh, 40h		;auto commit on every write
@@:
endif
	ret
	align 4

translate_attributes endp

;*** set mode + flags
;*** inp: ecx=desired access: GENERIC_READ=80000000h GENERIC_WRITE=40000000h
;--- inp: eax=share mode: FILE_SHARE_READ=1 FILE_SHARE_WRITE=2
;--- 0 -> SH_DENYRW (10)
;--- 1 (FILE_SHARE_READ) -> SH_DENYWR (20)
;--- 2 (FILE_SHARE_WRITE) -> SH_DENYRD (30)
;--- 3 (FILE_SHARE_READ or FILE_SHARE_WRITE) -> SH_DENYNO (40)

;--- out: BX

translate_sharemode proc

	and al, 3		;0,1,2,3
	inc al			;1,2,3,4
	shl al, 4		;10,20,30,40

	shr ecx,30		;move access to bits 0-1: 1=write,2=read,3=read/write
	cmp cl,0		;this was a "device query" access
	jz @F
	cmp cl,2		;read-only access?
	jz @F
	inc al			;al=1 (w/o)
	cmp cl,1		;write-only access?
	jz @F
	inc al			;al=2 (r/w)
@@:
	movzx	ebx,al
;--- the following line gives error 57 (invalid parameter) under XP
;--- since it is not a must to be set, it is deactivated
;      or      bh, 30h     ;allow 4 GB, dont use int 24h (9.7.2005)
	ret
	align 4

translate_sharemode endp

	.const

coninstr db "conin$",0
lconinstr equ $ - coninstr
conoutstr db "conout$",0
lconoutstr equ $ - conoutstr

	.code

_strcmpi proc uses esi

nextchar:        
	lodsb
	cmp al,'A'
	jb @F
	cmp al,'Z'
	ja @F
	or al,20h
@@:
	scasb
	jnz notequal
	and al,al
	jnz nextchar
	ret
notequal:
	stc
	ret
	align 4

_strcmpi endp

;*** int 21,ax=716C parameter
;*** ds:esi -> filename
;*** di = aliashint (if bh & 04)
;*** dx = action  (FILE_CREATE, FILE_OPEN, FILE_TRUNCATE)
;*** cx = attributes  (normal,r/o,hidden,system)
;*** bl = mode & flags access mode:
;--- 0-2: 000=r/o   O_RDONLY
;---      001=w/o   O_WRONLY
;---      010=r/w   O_RDWR
;---      011=reserved
;---      100=r/o without date modify
;--- 4-6: 001=share deny all     SH_DENYRW  10
;---      010=share deny write   SH_DENYWR  20
;---      011=share deny read    SH_DENYRD  30
;---      100=share deny none    SH_DENYNO  40
;--- 7:   1=noinherit   
;--- bh = 
;---      01:nobuffering (716C only?)
;---      02:do not compress (716C only?)
;---      04:use alias hint in DI (716C only)
;---      08:unused?
;---      10:allow 4 GB instead of 2 GB max file size
;---      20:return error instead int 24h
;---      40:auto-commit
;---      80:unused

;            O_APPEND 0008
;            O_CREATE 0100
;            O_TRUNC  0200
;            O_EXCL   0400
;            O_TEXT   4000
;            O_BINARY 8000
;
;*** desired access:0=read,1=write;2=r/w ***
;*** sharemode:
;*** fCreation: 1=create new
;              2=create always
;              3=openexisting
;              4=openalways
;              5=truncateexisting
;*** attributes:
;			80h = normal
;--- CreateFile should set error FILE_ALREADY_EXISTS if flags
;--- CREATE_ALWAYS or OPEN_ALWAYS were set and the file existed.
;--- Else last error should be set to 0.

CreateFileA proc public uses ebx esi edi fname:dword,
									 access:dword,	   ; read or write?
									 sharemode:dword,  ; share read/write?
									 pSecurity:dword,  ; 0
									 fCreation:dword,  ; CREATE_NEW, ... 
									 attributes:dword, ; flags + attribs
									 handle:dword

local	dwCnt:DWORD

	mov dwCnt, -1
nexttry:
	mov esi,fname			   ;set ESI
	mov eax,[esi]
	or ax,2020h
	cmp ax,"oc"
	jnz noconcom
	xor ebx, ebx			   ;CONIN handle = 0
	mov edi,offset coninstr
	invoke _strcmpi
	jnc duphandle
	mov edi,offset conoutstr
	invoke _strcmpi
	jc testcom
	inc ebx
duphandle:
	mov ah,45h
	int 21h
	jc errorX
	movzx eax,ax
	btr g_bProcessed, eax
	bt g_bProcessed, ebx
	jnc @F
	bts g_bProcessed, eax
@@:
	btr g_bIsConsole, eax
	bt g_bIsConsole, ebx
	jnc @F
	bts g_bIsConsole, eax
@@:
	jmp handleok
testcom:
if ?COMMSUPP
	cmp [g_ComHandler],0	;is low-level COM handler implemented?
	jz noconcom
	shr eax,16
	or al,20h
	cmp al,'m'
	jnz noconcom
	cmp ah,'1'
	jb noconcom
	cmp ah,'4'	   ;allow COM1 - COM4
	ja noconcom
	cmp byte ptr [esi+4],0
	jnz noconcom
	call [g_ComHandler]	;called with ESI=filename, ebp=stackframe
	jmp exit			;must return handle in EAX, -1 on failure
endif
noconcom:
	mov eax,[esi]
	cmp eax,"\.\\"	;filename beginning with "\\.\"?
	jz @F
	cmp eax,"/.//"	;or "//./"?
	jnz nospecial
@@:
	lea ebx,[esi+4]
	mov edi, offset _startvxd
	.while (edi < offset _endvxd)
		invoke [edi].VXDENTRY.pCmpProc, ebx
		.if (eax != -1)
			jmp exit
		.endif
		add edi, sizeof VXDENTRY
	.endw
nospecial:
	mov eax,sharemode
	mov ecx,access
	call translate_sharemode    ;set BX
	mov eax,fCreation
	call translate_action	   ;set DX
	mov eax,attributes
	call translate_attributes   ;set CX
	mov di,0
	mov dh,00
	mov ax,716Ch
	stc
	int 21h			;CX returns status!
	jnc handleok
	cmp ax,0004
	jz increasehandles
	cmp ax,7100h	;function supported?
	jnz error
	mov ax,6C00h
	stc
	int 21h			;CX returns status!
	jnc handleok
errorX:
	cmp ax, 0004
	jz increasehandles
error:
	movzx eax,ax
ifdef _DEBUG
	@trace <"last error=">
	@tracedw eax
	@trace <13,10>
endif
	invoke SetLastError,eax
	or eax,-1
	jmp exit
	align 4

;--- cx contains status:
;--- 1=file opened
;--- 2=file created
;--- 3=file replaced

handleok:
	test fCreation,2	;CREATE_ALWAYS or OPEN_ALWAYS?
	jz nolasterr
	xor edx,edx
	cmp cl,2		;was file created
	jz @F
	mov edx,ERROR_ALREADY_EXISTS
@@:
	invoke SetLastError,edx
nolasterr:
	movzx eax, ax
exit:
	@trace <"CreateFileA('">
	@trace fname
	@trace <"', ">
	@tracedw access
	@trace <", ">
	@tracedw sharemode
	@trace <", ">
	@tracedw fCreation
	@trace <", ">
	@tracedw attributes
	@trace <")=">
	@tracedw eax
	@trace <13,10>
	ret
increasehandles:
	inc dwCnt
	jnz error
	invoke SetHandleCount, 255
	jmp nexttry
	align 4

CreateFileA endp

	end

