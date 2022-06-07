
;*** support for PE-files ***
;*** 32-Bit DPMI clients only ***

;--- best viewed with TABSIZE 4

;*** hierarchy of procs
;LoadModule32 (int 21h, AX=4B00h)
;   + SearchPEModule (scans for already loaded dlls)
;       + ScanImportsDir (loads all referenced modules)
;           + LoadModule32
;   + LoadPEModule (called if SearchPEModule failed)
;       + LoadImage (load image in memory, no modifications)
;       + DoFixups (updates all internal relocations of module)
;       + create PSP if it is an applications
;   + InitPEModule
;       + increments current module count
;       + DoImports (resolves all external references of module)
;           + SearchModuleHandle (only if ?SEARCHMODINIMP=1)
;           + LoadModule32 / int 21, ax=4b00 (if module not found)
;           + ResolveImports (inits IAT)
;               + SearchExport (no updates in image)
;                   + SearchExportByName (no updates in image)
;       + AddModuleToAppModList if(DLL && ?CALLDLLENTRY1TIME=0)
;       + calls app/dll entry point
;
;FreeModule32 (int 21h, AX=4B80h)
;   + SearchModuleInList
;   + UnlinkPEModule        ;delete module from module list
;   + FreeReferencedModules
;       + DeleteModuleFromAppModList if(DLL && ?CALLDLLENTRY1TIME=0)
;       + FreeModule32
;   + FreeDynLoadedModules
;       + SearchModuleInList
;       + FreeModule32
;
;CheckInt214B
;   + FreeLibrary32
;       + FreeModule32
;   + GetProcAddress32
;       + SearchExportByName
;   + GetModuleHandle32
;       + SearchModuleHandle
;   + GetNextModuleHandle32
;       + SearchModuleInList
;   + CallProc32W
;   + CallProc16
;   + SetModuleStart (sets start of module list)
;
;
;UnloadPEModules    (called by dpmildr before terminating)
;InitPELoader       (called by dpmildr to initialize peloader)
;DeinitPELoader     (called by dpmildr to deinitialize peloader)

	.386
	option proc:private
	option casemap:none

_TEXT segment dword use16 public 'CODE'
_TEXT ends
CCONST segment word use16 public 'CODE'
CCONST ends
_DATA segment word use16 public 'DATA'
_DATA ends
_ITEXT segment word use16 public 'DATA'
_ITEXT ends
_BSS segment word use16 public 'BSS'
_BSS ends
STACK segment para use16 stack  'STACK'
STACK ends

;TIBSEG segment para use16
;TIBSEG ends

DGROUP group _TEXT,CCONST,_DATA,_ITEXT,_BSS,STACK

	assume CS:DGROUP
	assume DS:DGROUP
	assume SS:NOTHING
	assume ES:DGROUP
;	assume FS:TIBSEG
	assume FS:nothing

;--- the MZ-Header (size 40h) is used to save some pointers
;--- see mzhdr32.inc for details

	include ascii.inc
;	include function.inc
	include dpmildr.inc
	include trace.inc
	include winnt.inc
;	include winerror.inc
	include mzhdr32.inc
	include peload.inc
	include debugsys.inc

?NBSTACK		equ 1	;std=1, 1=switch to flat stack when calling dll entries
?FLATES 		equ 0	;std=1, 1=set es to flat when calling dll entries 
?CALLDLLENTRY1TIME	equ 0	;call dll entry only 1 time (like win16 dlls)
?CLEARHEADER	equ 1	;std=1, 1=clear PE header after allocation
?LDRHEAP		equ 1	;std=1, 1=create a small loader heap in free area of first
						;       page to save referenced module handles by current app
?SEARCHMODINIMP equ 1	;std=1, 1=search module in list in DoImport
?FASTIMPDIRSCAN equ 0	;std 0, 0=call LoadModule32 always,1=just incr counter
?NOGUIAPPS		equ 1	;std=1, 1=dont load gui apps
?DPMI10 		= 1		;std=1, 1=use DPMI10 memory alloc if available		 
?SETSECATTR 	= 1		;std=1, 1=set section page attributes
?DISCARDSECTION	= 1		;std=1, 1=release memory for discardable sections
?FLATDSEXPDOWN	= 1		;std=1, support DPMILDR=2048 switch 
?EXTRASTACKHDL	= 1		;std=1, 1=stack is allocated as own dpmi memory block                        
;?ADD64KBTOSTACK	= 0		;std=1, 1=emulate win9x behaviour
?USESTACK		equ 1	;std=1, 1=use loader stack to first load MZ+PE header
                        ;this avoids to reallocate the memory
?EARLYMODLISTUPDATE	equ 1	;std=1, add a dll to the apps modlist very early
							;before any imports are resolved!
?CLEARSTACK		equ 0	;std=0, 1=clear the stack before it's used
?ALLOWGUIAPPS	equ 1	;std=1, allow GUI apps if DPMILDR=8192 is set
?CHECKCROSSREFS	equ 1	;std=1, 1=check for dll cross references
?LOADAPPSASDLLS	equ 1	;std=1, 1=allow apps to be loaded as dlls
?SKIPCOMMENTS	equ 1	;std=1, 1=skip sections not marked as r/w/e
?PEX64ERROR     equ 0   ;std=0, 1=display error for x64 PEs

;?ADDTOSTACK		equ 2000h	;add this to reserved stack
?ADDTOSTACK		equ 10000h	;add this to reserved stack

MODLISTITEM struct
handle	dd ?
wCnt	dw ?
		dw ?
MODLISTITEM ends

CCONST segment

szErrPE1	db "out of memory",lf,0
szErrPE2	db "cannot open PE file",lf,0
ife ?USESTACK
szErrPE3	db "no more memory",lf,0
endif
szErrPE4	db "read error PE file",lf,0
szErrPE5	db "invalid PE format",lf,0
szErrPE6	db "cannot resolve imports",lf,0
szErrPE7	db "cannot create psp",lf,0
szErrPE8	db "cannot load PE file",lf,0
szErrPE9	db "relocs stripped, cannot load",lf,0
szErrPE10	db "dll init failed",lf,0
if ?PEX64ERROR
szErrPE11	db "no x86 binary",lf,0
endif

?NODLLSUFF	equ 1

if ?NODLLSUFF
?DLLSUFFIX	equ <0>
else
?DLLSUFFIX	equ <".dll",0>
endif

szkernel32	db "kernel32", ?DLLSUFFIX
szdkrnl32	db "dkrnl32", ?DLLSUFFIX

szadvapi32	db "advapi32", ?DLLSUFFIX
szdadvapi32	db "dadvapi", ?DLLSUFFIX

szuser32	db "user32", ?DLLSUFFIX
szduser32	db "duser32", ?DLLSUFFIX

szgdi32 	db "gdi32", ?DLLSUFFIX
szdgdi32	db "dgdi32", ?DLLSUFFIX

szddraw 	db "ddraw", ?DLLSUFFIX
szdddraw	db "dddraw", ?DLLSUFFIX

szntdll 	db "ntdll", ?DLLSUFFIX
szdntdll	db "dkrnl32", ?DLLSUFFIX

pReplacestrings label ptr byte
	dw offset szkernel32,offset szdkrnl32
	dw offset szadvapi32,offset szdadvapi32
	dw offset szuser32,offset szduser32
	dw offset szgdi32,offset szdgdi32
	dw offset szntdll,offset szdntdll
	dw offset szddraw,offset szdddraw
	dw 0

if ?ALLOWGUIAPPS
szHxGuiHlp db "hxguihlp.dll",0
endif

CCONST ends

_DATA segment

wFlatCS	dw 0		;flat CS
wFlatDS	dw 0		;flat DS
wStk16	dw 0		;selector for 16-bit stack

dwMod32		dd 0	;start PE module list
dwBase		dd 0	;base address of loader
dwStkHdl	dd 0	;DPMI handle of 16 bit stack
dwSysDir	dd 0	;"system directory" linear address
if ?DOS4GMEM
w4GSel	dw 0
dw4GHdl	dd 0
endif
_DATA ends

_TEXT segment

;*** DS:EDX = program path ***
;*** ES:EBX = parameter block ***
;*** NE_hdr: the first 40h bytes of header ***

PELOADF struct
_xmemhdl	dd ?
_xmemadr	dd ?
_szExePath	df ?
_hFile		dw ?
			dw ?	;to align the stack to DWORD
PELOADF ends

LoadModule32 proc stdcall public

rEAX equ <[ebp+6+7*4]>
rEBX equ <[ebp+6+4*4]>		;apps only: before the call there was a pushad
rES_ equ <[ebp+6+8*4+2]>	;but remember, this is a 16-bit proc! 

hFile		equ <[ebp-sizeof PELOADF].PELOADF._hFile>
szExePath	equ <[ebp-sizeof PELOADF].PELOADF._szExePath>
xmemadr		equ <[ebp-sizeof PELOADF].PELOADF._xmemadr>
xmemhdl		equ <[ebp-sizeof PELOADF].PELOADF._xmemhdl>

	push ebp
	mov ebp,esp
if ?LFN
	sub esp,sizeof PELOADF
	mov dword ptr szExePath+0,edx
	mov word ptr szExePath+4,ds
else
	sub esp,80+sizeof PELOADF		;loader stack is 1024 bytes!
	mov edi,esp
@@:
	mov cl,[edx]
	mov ss:[edi],cl
	inc edx
	inc edi
	and cl,cl
	jnz @B
	mov dword ptr szExePath+0,esp
	mov word ptr szExePath+4,ss
endif
	@trace_s <"LoadModule32 enter",lf>
	mov ds,cs:[wFlatDS]
	push ds
	pop es

	@trace_s <"LoadModule32: calling SearchPEModule",lf>
	call SearchPEModule		;will only find dlls, no apps
	jnc @F
	@trace_s <"LoadModule32: module not found, calling LoadPEModule",lf>
	call LoadPEModule
	jc error
@@:
	@trace_s <"LoadModule32: calling InitPEModule",lf>
	call InitPEModule
	jc error
	mov eax,esi
exit:
	@printf <"LoadModule32 exit, eax=%lX fs=%X",lf>, eax, fs
	mov esp,ebp
	pop ebp
	ret
error:
	call error_ax_out
	jmp exit
LoadModule32 endp

;--- display error message in AX

dpmildrout proto

error_ax_out:
	movzx esi, ax
	and ax, ax				;error message?
	jz nomsg
	test byte ptr cs:[wErrMode+1], HBSEM_NOOPENFILEBOX
	jnz @F
	push ax
	call dpmildrout
	call printname
	invoke string_out, CStr(<": ">)
	call string_out			;print string in [esp] (WORD)
@@:
	mov ax,000Bh			;"invalid format"
nomsg:
	stc
	ret

;*** requested module is already loaded ***
;*** but we still need to scan its import directory (like in DoImports) ***
;*** and "load" all referenced modules (which is mostly a counter increment) ***
;*** called by SearchPEModule
;*** input: ESI-> MZ-Hdr

ScanImportsDir proc uses esi edi ebx

	mov ebx,esi
	add esi,[esi].MZHDR.ofsPEhdr
	mov ecx,[esi].IMAGE_NT_HEADERS.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_IMPORT*sizeof IMAGE_DATA_DIRECTORY].Size_
	jecxz exit
	mov edi,[esi].IMAGE_NT_HEADERS.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_IMPORT*sizeof IMAGE_DATA_DIRECTORY].VirtualAddress
	add edi,ebx
nextitem:
	mov eax,[edi.IMAGE_IMPORT_DESCRIPTOR.OriginalFirstThunk]		;import lookup table rva
	and eax,eax
	jz exit
	mov esi,[edi.IMAGE_IMPORT_DESCRIPTOR.TimeDateStamp] ;hModule saved here
if ?FASTIMPDIRSCAN
	inc [esi].MZHDR.wCnt			;increment counter
	call ScanImportsDir
else
	pushad
	mov edx,[esi].MZHDR.pExeNam 	;let edx point to full name
	add edx,esi
	call LoadModule32
	popad
;	jc error
@@:
endif
	add edi,sizeof IMAGE_IMPORT_DESCRIPTOR
	jmp nextitem
error:
exit:
	ret
ScanImportsDir endp

;*** search module in module list
;*** if found & DLL, dont reload
;*** apps will always be loaded
;*** module to search is in szExePath
;*** output: esi->IMAGE_NT_HEADERS

;*** the modul to search can be changed (kernel32.dll -> dkrnl32.dll)
;*** so we need a temporary buffer were we get the unchanged full name

SearchPEModule proc
if ?LFN
	push es
	les edi,szExePath
	mov ecx,-1
	mov al,0
	repnz scas byte ptr [edi]
	pop es
	not ecx
	add cx,4
	and cl,0FCh
	sub esp, ecx
	mov edi,esp
	add ecx, edi
	push ecx
else
	sub esp,80
	mov edi,esp
endif
	push ds
	lds esi,szExePath
next:
	mov ecx,edi
@@:
	lods byte ptr [esi]
	call nocaps
	mov ss:[edi],al
	inc edi
	and al,al
	jz @F
	cmp al,'/'
	jz next
	cmp al,'\'
	jz next
	jmp @B
@@:
	push ss
	pop ds
	mov esi,ecx
	mov ah,01
	call checkandreplace 	;make sure its a win32 name
	pop ds

	mov esi,cs:[dwMod32]
SearchMod32_1:				;<----
	and esi,esi
	jz SearchMod32_er
	mov eax, esi
	add eax, [esi].MZHDR.ofsPEhdr
	test [eax].IMAGE_NT_HEADERS.FileHeader.Characteristics,IMAGE_FILE_DLL
	jz SearchMod32_2			;ignore apps
	mov edi,[esi].MZHDR.pExeNam
	add edi,esi
	mov edx,esi
if ?LFN
	lea esi,[esp+4]
else
	mov esi,esp
endif
@@:
	lods byte ptr ss:[esi]
	scas byte ptr [edi]
	jnz skipitem
	and al,al
	jnz @B
	mov esi,edx
if ?CHECKCROSSREFS
	test [esi].MZHDR.bFlags,FPE_CROSSREF
	jnz @F
	or [esi].MZHDR.bFlags,FPE_CROSSREF
endif
	call ScanImportsDir
if ?CHECKCROSSREFS
	and [esi].MZHDR.bFlags,not FPE_CROSSREF
endif
@@:
	@printf <"SearchPEModule: module found, handle=%lX",lf>, esi
	add esi,[esi].MZHDR.ofsPEhdr
if ?LFN
	pop esp
	clc
else
	add esp,80
endif
	ret
skipitem:
	mov esi,edx
SearchMod32_2:
	mov esi,[esi].MZHDR.pNxtMod
	jmp SearchMod32_1		;---->
SearchMod32_er:
if 0
	invoke string_out_prefix, CStr(<"module not found ">)
	call printname
	call cr_out
endif
if ?LFN
	pop esp
else
	add esp,80
endif
	stc
	ret
SearchPEModule endp

printname proc uses ds esi

	lds esi,szExePath
@@:
	lods byte ptr [esi]
	and al,al
	jz done
	call cs:printproc
	jmp @B
done:
	ret
printname endp

;*** skip "directory" part of module name
;*** input ds:edi -> module name

skippath proc
	mov ecx,edi
@@:
	mov al,[edi]
	inc edi
	cmp al,'\'
	jz skippath
	cmp al,'/'
	jz skippath
	cmp al,':'
	jz skippath
	and al,al
	jnz @B
	mov edi,ecx
	ret
skippath endp

;*** search module EDX=handle ***

SearchModuleInList proc stdcall
	mov ecx,cs:[dwMod32]
@@:
	mov eax,ecx
	jecxz @F
	cmp eax,edx
	mov ecx,[ecx].MZHDR.pNxtMod
	jnz @B
	ret
@@:
	stc
	ret
SearchModuleInList endp

;*** look in module list if module is already loaded
;*** input:
;*** edx = linear address of module name (left unchanged!)
;*** ds =  zero based flat selector
;*** outp: eax=module handle or zero

SearchModuleHandle proc stdcall uses esi edi ebx

	mov ecx, edx
	mov bl,0
@@:
	cmp byte ptr [ecx],0
	jz @F
	cmp byte ptr [ecx],'\'
	setz bl
	jz @F
	inc ecx
	jmp @B
@@:
	mov esi,cs:[dwMod32]
nextitem:
	and esi,esi
	jz error
	mov edi,[esi].MZHDR.pExeNam
	add edi,esi
	cmp bl,0
	jnz @F
	call skippath			;skip path in ds:edi
@@:
	push esi

	mov esi,edx
nextchar:
	lods byte ptr [esi]
	call nocaps
	mov ah,[edi]
	inc edi
	cmp al,ah
	jnz @F
	and al,al
	jnz nextchar
found:
	pop esi
	mov eax,esi
	ret
@@:
	and al,al
	jnz @F
	cmp ah,'.'
	jnz @F
	mov eax,[edi]
	or eax,202020h
	cmp eax,"lld"
	jz found
@@:
	pop esi
	mov esi,[esi.MZHDR.pNxtMod]
	jmp nextitem
error:
	xor eax,eax
	stc
	ret
SearchModuleHandle endp


nocaps proc
	cmp al,'A'
	jb @F
	cmp al,'Z'
	ja @F
	or al,20h
@@:
	ret
nocaps endp

;--- LoadPEModule
;*** read MZ + PE header
;--- alloc memory for image
;--- read image
;--- for apps and standalone dlls: alloc stack
;--- for apps: create PSP

;*** inp: ds,es = flat
;*** out: NC + esi -> hmodule
;*** modifies esi, edi, ebx

LoadPEModule proc near

	@trace_s <"LoadPEModule entry",lf>
	push ds
	lds edx,szExePath
	mov cl,00
	call openfile
	pop ds
	jnc @F
	mov ax,offset szErrPE2 		  ;file open error
	ret
@@:
	mov hFile,ax
if ?USESTACK
	mov xmemadr, esp
	sub esp, sizeof MZHDR
	mov edx, esp
	push ss
	pop ds
else
	mov bx,0000h
	mov cx,1000h				  ;alloc 4 kB
	mov ax,0501h
	int 31h
	jnc @F
	push offset szErrPE3
	jmp errorxx
@@:
	mov word ptr xmemadr+0,cx
	mov word ptr xmemadr+2,bx
	mov word ptr xmemhdl+0,di
	mov word ptr xmemhdl+2,si
	mov edx,xmemadr
  if ?CLEARHEADER
	mov edi,edx
	mov ecx,1000h/4
	xor eax,eax
	rep stos dword ptr [edi]
  endif
endif
	mov ecx, sizeof MZHDR
	mov bx,hFile
	mov ah,3Fh				;read MZ header
	int 21h
	jc error41
	sub eax,ecx
	jnz error51

	@printf <"LoadPEModule: MZ addr=%lX magic bytes=%lX ptr PE=%lX",lf>,edx,dword ptr [edx],dword ptr [edx+3Ch]

	mov dword ptr [edx].MZHDR.wCnt, eax	;count + flags init
	mov [edx].MZHDR.dwStack,eax
	push edx
	mov cx,word ptr [edx].MZHDR.ofsPEhdr+2
	mov dx,word ptr [edx].MZHDR.ofsPEhdr+0
	mov ax,4200h
	int 21h
	pop edx
	jc error51
if ?USESTACK
	mov ecx,sizeof IMAGE_NT_HEADERS/4
	xor eax,eax
@@:
	push eax
	loop @B
	mov edx, esp
	mov cx, sizeof IMAGE_FILE_HEADER+4	;read FileHeader only
else
	mov ecx,sizeof IMAGE_NT_HEADERS  ;read PE-Header
	add edx,sizeof MZHDR
endif
;------------------------- read PE-(File)Header
	mov ah,3Fh
	int 21h
	jc error42
	cmp eax,ecx
	jnz error52
	cmp [edx].IMAGE_NT_HEADERS.FileHeader.Machine, IMAGE_FILE_MACHINE_I386 
	jnz error62
if ?USESTACK
	movzx ecx,[edx].IMAGE_NT_HEADERS.FileHeader.SizeOfOptionalHeader       
	add edx, eax
	mov ah,3Fh
	int 21h
	jc error42
	cmp eax, ecx
	jnz error52
	mov edx, esp
endif

	@printf <"LoadPEModule: PE magic bytes=%lX",lf>, dword ptr [edx]

if ?NOGUIAPPS
	test [edx].IMAGE_NT_HEADERS.FileHeader.Characteristics,IMAGE_FILE_DLL
	jnz isdll1
  if ?LOADAPPSASDLLS
	xor ecx,ecx		;if an application binary is to load as a dll
	cmp cx, rES_	;ignore the entry point
	jnz @F
	or [edx].IMAGE_NT_HEADERS.FileHeader.Characteristics,IMAGE_FILE_DLL
	mov [edx].IMAGE_NT_HEADERS.OptionalHeader.AddressOfEntryPoint, ecx
	jmp isdll1
@@:
  endif
  if ?ALLOWGUIAPPS
	test cs:[bEnvFlgs2], ENVFL2_ALLOWGUI
	jnz @F
  endif
	cmp [edx].IMAGE_NT_HEADERS.OptionalHeader.Subsystem,IMAGE_SUBSYSTEM_WINDOWS_GUI
	jz error61
@@:
  if 0;?ADD64KBTOSTACK
;	inc word ptr [edx.IMAGE_NT_HEADERS.OptionalHeader.SizeOfStackReserve+2]
  endif

;--- restrict reserved stack to 128 kB if flag is set  

	test cs:bEnvFlgs2, ENVFL2_128KBSTACK
	jz @F
	mov eax,20000h
	cmp eax,[edx].IMAGE_NT_HEADERS.OptionalHeader.SizeOfStackCommit
	jc @F
	cmp eax,[edx].IMAGE_NT_HEADERS.OptionalHeader.SizeOfStackReserve
	jnc @F
	mov [edx].IMAGE_NT_HEADERS.OptionalHeader.SizeOfStackReserve, eax
@@:
	@printf <"LoadPEModule: pTaskStk=%X DPMILDR=%X",lf>, cs:[wTDStk], cs:wEnvFlgs
	cmp cs:[wTDStk],offset starttaskstk
	jz @F
	test cs:bEnvFlgs, ENVFL_LOAD1APPONLY
	jnz error61
@@:
isdll1:
endif

if ?USESTACK
	mov eax,[edx.IMAGE_NT_HEADERS.OptionalHeader.SizeOfImage]
  ife ?EXTRASTACKHDL        
	test [edx.IMAGE_NT_HEADERS.FileHeader.Characteristics],IMAGE_FILE_DLL
	jnz @F
	add eax,[edx.IMAGE_NT_HEADERS.OptionalHeader.SizeOfStackReserve]
	add eax,?ADDTOSTACK
@@:
  endif
  if ?DPMI10
	test cs:bEnvFlgs,ENVFL_DONTUSEDPMI1
	jnz UseStdAlloc
;---------------------- some apps have to be loaded at their ImageBase
;---------------------- although relocs are NOT stripped!
	test [edx.IMAGE_NT_HEADERS.FileHeader.Characteristics],IMAGE_FILE_DLL
	jz @F
;---------------------- for dlls dont use the prefered load address unless
;---------------------- relocs are stripped or DPMILDR=1024 is set
	test cs:bEnvFlgs2, ENVFL2_USEPREFADDR
	jnz @F
	test [edx.IMAGE_NT_HEADERS.FileHeader.Characteristics],IMAGE_FILE_RELOCS_STRIPPED
	jz UseStdAlloc
@@:
	mov ebx, [edx.IMAGE_NT_HEADERS.OptionalHeader.ImageBase]
	mov ecx, eax
	mov edx, 1
	push eax
	mov ax, 0504h
	int 31h
	pop eax
	jc UseStdAlloc
	mov xmemhdl, esi
	mov edi, ebx
	jmp allocok
UseStdAlloc:
  endif

	@printf <"LoadPEModule: image size=%lX",lf>,eax

	push eax
	pop cx
	pop bx
	mov ax,0501h
	int 31h
	jc error1
	mov word ptr xmemhdl+0, di
	mov word ptr xmemhdl+2, si
	push bx
	push cx
	pop edi
allocok:

	@printf <"LoadPEModule: image memory base=%lX",lf>, edi

;	mov es,cs:[wFlatDS]
	lea esi, [esp+sizeof IMAGE_NT_HEADERS]
	mov ecx, 40h/4			;copy MZ header
	rep movs dword ptr [edi], [esi]
  if ?CLEARHEADER
	mov cx,(1000h-40h)/4
	xor eax, eax
	push edi
	rep stos dword ptr [edi]
	pop edi
  endif
	mov edx, edi
	mov esi, esp
	mov cx, sizeof IMAGE_FILE_HEADER+4
	add cx, [esi].IMAGE_NT_HEADERS.FileHeader.SizeOfOptionalHeader
	shr ecx, 2
	rep movs dword ptr [edi], [esi]
	push es
	pop ds
	mov bx,hFile
endif	;?USESTACK

;--------------------------------- now read object table
	@printf <"LoadPEModule: reading object table, # of sections=%X",lf>, [edx].IMAGE_NT_HEADERS.FileHeader.NumberOfSections
	push edx
	movzx eax, [edx].IMAGE_NT_HEADERS.FileHeader.NumberOfSections
	mov ecx, sizeof IMAGE_SECTION_HEADER
	mul ecx
	mov ecx, eax		;bytes to read
	mov edx, edi
	mov ah,3Fh			;read object table
	int 21h
	pop edx
	jc error43
	cmp eax,ecx
	jnz error53

	@printf <"LoadPEModule: reading object table done, size=%lX",lf>, eax
	lea eax, [eax+edi+sizeof MZHDR]
	sub eax, edx
	mov [edx - sizeof MZHDR].MZHDR.pExeNam, eax 	;is a RVA
	mov [edx - sizeof MZHDR].MZHDR.ofsPEhdr, sizeof MZHDR

;----------------------------- alloc space for total image

ife ?USESTACK
	mov eax,[edx].IMAGE_NT_HEADERS.OptionalHeader.SizeOfImage
  ife ?EXTRASTACKHDL        
	test [edx].IMAGE_NT_HEADERS.FileHeader.Characteristics,IMAGE_FILE_DLL
	jnz @F
	add eax,[edx].IMAGE_NT_HEADERS.OptionalHeader.SizeOfStackReserve
	add eax,?ADDTOSTACK
@@:
  endif
	push eax
	pop cx
	pop bx
	mov di,xmemhdl+0
	mov si,xmemhdl+2
	mov ax,0503h				 ;resize mem block
	int 31h
	jc error1
	mov xmemhdl+0, di
	mov xmemhdl+2, si
	push bx
	push cx
	pop eax
	mov xmemadr, eax
else
	lea eax, [edx-sizeof MZHDR]
endif
;----------------------------- save module name


	@printf <"LoadPEModule: header in edx=%lX",lf>,edx

	mov edi, eax

	add edi, [edx - sizeof MZHDR].MZHDR.pExeNam
	push ds
	lds esi,szExePath
nextchar0:
	mov ecx,edi
nextchar:
	lods byte ptr [esi]
	call nocaps
	stos byte ptr [edi]
	cmp al,'\'
	jz nextchar0 						;remember last '\' or '/'
	cmp al,'/'
	jz nextchar0
	and al,al
	jnz nextchar
	pop ds
	mov ah,01							;make sure its a win32 name
	mov esi,ecx 						;"dkrnl32.dll" -> "kernel32.dll"
	call checkandreplace 				;preserves all registers
	add edi,8							;let some free place here!
if ?LDRHEAP
	mov [edx.MZHDR.pModuleList - sizeof MZHDR],edi	;will be module list
endif

	mov esi, edx

	@printf <"LoadPEModule: header in esi=%lX",lf>, esi

;----------------------------- read rest of image

	mov bx,hFile
	call LoadImage
	jc error
	mov ah,3Eh			;file close
	int 21h
	mov word ptr hFile, -1

	call DoFixups		;do internal fixups
	jc errorx			;error if relocs are stripped

;--- test if a stand-alone dll is loaded. then it is necessary to
;--- allocate a stack even for dlls

	movzx eax, cs:[wTDStk]
	cmp ax, offset starttaskstk
	jz @F
	cmp word ptr cs:[eax - sizeof TASK].TASK.dwModul+2,0
	jz @F

	test [esi].IMAGE_NT_HEADERS.FileHeader.Characteristics,IMAGE_FILE_DLL
	jnz isdll
@@:

;----------------------------- alloc stack
;----------------------------- do this before createpsp!

if ?EXTRASTACKHDL
	mov edx,esi
	mov eax, [esi].IMAGE_NT_HEADERS.OptionalHeader.SizeOfStackReserve
 if ?ADDTOSTACK
	add eax,?ADDTOSTACK
 endif
	push eax
	pop cx
	pop bx
	mov ax,0501h
	int 31h
	jc error1_2
	mov word ptr [edx - sizeof MZHDR+0].MZHDR.hStack,di
	mov word ptr [edx - sizeof MZHDR+2].MZHDR.hStack,si
	mov esi, edx
	push bx
	push cx
	pop edi
	mov [edx - sizeof MZHDR].MZHDR.dwStack,edi
  if ?ADDTOSTACK		;uncommit the pages below the "reserved" part
	push esi
	push es
	mov edi,esp
	mov esi,[esi - sizeof MZHDR].MZHDR.hStack
	xor ebx,ebx
;	mov ebx,?ADDTOSTACK-1000h	;offset in memory block
	push ss
	pop es
  if ?ADDTOSTACK gt 2000h
	mov ecx,(?ADDTOSTACK shr 12) - 2
	.while (ecx)
		push 0			;page attributes (not committed)
		dec ecx
	.endw
	mov ecx,(?ADDTOSTACK shr 12) - 2
	mov edx, esp	;es:edx=ptr WORD
	mov ax,0507h	;esi=handle, ebx=ofs, ecx=pages
	int 31h
  else
	push 0
	mov edx, esp	;es:edx=ptr WORD
  endif
	mov ebx,?ADDTOSTACK - 1000h
	mov ecx,1
	mov ax,0507h	;esi=handle, ebx=ofs, ecx=pages
	int 31h
	mov esp,edi
	pop es
	pop esi
  endif
endif

	test [esi].IMAGE_NT_HEADERS.FileHeader.Characteristics,IMAGE_FILE_DLL
	jnz isdll

;------------------------- for apps: set loader task stack and
;						   create/set PSP, window title

	push ds
	pushad
	lea eax,[esi-sizeof MZHDR]		;hModule
	@printf <"LoadPEModule: load PE app, handle=%lX",lf>, eax
	mov ds,cs:[wLdrDS]
	mov si,[wTDStk]
	mov [si].TASK.dwModul,eax
	lea eax,[ebp+6] 				;save SS:ESP of caller
	mov [si].TASK.dwESP,eax
	mov [si].TASK.wSS,ss
	mov [si].TASK.wFlags,1			;set "loading"
if ?MULTPSP
	push es
	les edi,szExePath
	call CreatePsp
	pop es
	jc error71
endif
if ?INT24RES or ?INT23RES
	call saveint2x
endif
	push es
	mov es,rES_
	mov ebx,rEBX
	call SetCmdLine
	pop es
if ?MULTPSP
	@printf <"LoadPEModule: task=%X modul=%lX psp=%X",lf>, si, [si].TASK.dwModul, [si].TASK.wPSP
else
	@printf <"LoadPEModule: task=%X modul=%lX",lf>, si, [si].TASK.dwModul
endif
	add si,size TASK
	mov [wTDStk],si
	popad
	pop ds
isdll:

;----------------------------- insert module in module list

	push ds
	mov ds,cs:[wLdrDS]
	lea eax,[esi-sizeof MZHDR]
	xchg eax,ds:[dwMod32]
	pop ds
	mov [esi.MZHDR.pNxtMod - sizeof MZHDR],eax
	mov eax,xmemhdl
	mov [esi.MZHDR.hImage - sizeof MZHDR],eax
	clc
if ?USESTACK
	mov esp,xmemadr
endif
	ret
error1:
if ?USESTACK
	push offset szErrPE1
	jmp errorxx
error1_2:
	mov ax,offset szErrPE1 ;memory error (stack cannot be alloc'ed)
	jmp error
else
	mov ax,offset szErrPE1 ;memory error
	jmp error
endif
error71:
	popad
	pop ds
	mov ax,offset szErrPE7
	jmp error
error41:
error42:
error43:
	mov ax,offset szErrPE4
	jmp error
error62:
if ?PEX64ERROR
	mov ax,offset szErrPE11
	jmp error
endif
error61:
	@trace_s <"LoadPEModule: error, will skip binary loading (no 80386, GUI or DPMILDR=8)",lf>
	xor ax, ax
	jmp error
error51:
error52:
error53:
	mov ax,offset szErrPE5
error:
errorx:
	push ax
	mov di, word ptr xmemhdl+0
	mov si, word ptr xmemhdl+2
	mov ax, 0502h
	int 31h
errorxx:
	mov bx,hFile
	.if (bx != -1)
		mov ah,3Eh
		int 21h
	.endif
	pop ax
	stc
if ?USESTACK
	mov esp,xmemadr
endif
	ret

LoadPEModule endp

if ?CALLDLLENTRY1TIME eq 0

;*** scan module list of current application if dll is in there
;*** if not, return C, else NC
;--- called by AddModuleToAppModList/DeleteModuleFromAppModList
;--- in: esi = IMAGE_NT_HEADERS of dll
;--- ds, es = FLAT
;--- FS has to be set!
;--- out: EAX = handle/NULL
;--- out: EDX = module handle of dll
;--- out: ESI = ptr MODLISTITEM

if ?LDRHEAP
SearchModuleInAppModList proc

	lea edx, [esi - sizeof MZHDR]
	mov si, cs:[wTDStk]
	cmp si,offset starttaskstk
	jz notfound
	mov esi, cs:[si-sizeof TASK].TASK.dwModul
	mov esi, [esi].MZHDR.pModuleList
next:
	mov eax,[esi].MODLISTITEM.handle
	and eax,eax
	jz notfound
	cmp eax,edx
	jz found
	add esi, sizeof MODLISTITEM
	jmp next
notfound:
	stc
found:
	ret
SearchModuleInAppModList endp
endif

;--- inp: esi = IMAGE_NT_HEADERS
;--- ds, es = FLAT
;--- called by InitPEModule
;--- modifies EDX

AddModuleToAppModList proc uses esi

if ?LDRHEAP
	call SearchModuleInAppModList
	jnc @F					;done if found
	mov [esi].MODLISTITEM.handle,edx
	mov dx,[edx].MZHDR.wCnt
	mov [esi].MODLISTITEM.wCnt,dx
	xor edx,edx
	mov [esi + sizeof MODLISTITEM].MODLISTITEM.handle,edx
found:
	stc
@@:
else
	stc
endif
	ret
AddModuleToAppModList endp

;*** esi -> IMAGE_NT_HEADER
;*** scan module list of application if dll is in there
;*** if not, do nothing
;*** if yes, compare saved count with current count. if current count
;*** is below, delete entry from list
;--- out: C = module found in AppModList + deleted
;---     NC = not found or not deleted
;--- ds,es = FLAT
;--- called by FreeModule32

DeleteModuleFromAppModList proc uses esi

if ?LDRHEAP
	@printf <"dpmild32, DeleteModuleFromAppModList enter, esi=%lX",lf>, esi
	call SearchModuleInAppModList
	jc notfound
	mov ax,[edx].MZHDR.wCnt		;get current count (already decremented!)
	cmp ax,[esi].MODLISTITEM.wCnt ;cmp current count / saved count
	jae notfound
@@:
	mov eax, [esi.MODLISTITEM.handle + sizeof MODLISTITEM]
	mov cx, [esi.MODLISTITEM.wCnt + sizeof MODLISTITEM]
	mov [esi].MODLISTITEM.handle,eax
	mov [esi].MODLISTITEM.wCnt,cx
	add esi, sizeof MODLISTITEM
	and eax,eax
	jnz @B
found:
	@trace_s <"DeleteModuleFromAppModList: exit with C",lf>
	stc
	ret
notfound:
	@trace_s <"DeleteModuleFromAppModList: exit with NC",lf>
	clc
else
	stc
endif
	ret
DeleteModuleFromAppModList endp

endif   ;CallDllEntry1Time

if 0
;--- get a flat ESP for dll entry calls (if no PE app is active)
;--- edx == esp

getesp proc uses bx cx
	mov bx,ss
	push dx
	mov ax, 6
	int 31h
	push cx
	push dx
	pop eax
	pop dx
	add eax, edx
	ret
getesp endp

endif

;--- get top of stack in EAX
;--- modifies EDX

getstacktop proc
	movzx eax, cs:[wTDStk]
	cmp ax,offset starttaskstk
	jz notask
	mov edx, cs:[eax-sizeof TASK].TASK.dwModul
	mov eax, [edx].MZHDR.dwStack
	add eax, [edx+sizeof MZHDR].IMAGE_NT_HEADERS.OptionalHeader.SizeOfStackReserve
if ?ADDTOSTACK
	add eax,?ADDTOSTACK
endif
	ret
notask:
	mov eax, [esi - size MZHDR].MZHDR.dwStack
	add eax, [esi].IMAGE_NT_HEADERS.OptionalHeader.SizeOfStackReserve
if ?ADDTOSTACK
	add eax,?ADDTOSTACK
endif
	ret
getstacktop endp


if ?ALLOWGUIAPPS
loadguihelper proc
ife ?STUB
	test cs:[fCmdLOpt], FO_GUI
	jnz @F
endif
	cmp [esi].IMAGE_NT_HEADERS.OptionalHeader.Subsystem,IMAGE_SUBSYSTEM_WINDOWS_GUI
	jnz nogui
@@:
	push ds
	push cs
	pop ds
	mov edx, offset szHxGuiHlp
	mov ax,4B00h
	int 21h
	pop ds
nogui:
	ret
loadguihelper endp
endif

;*** here image is loaded into memory, fixups done
;*** input: ds=es=FLAT
;*** esi -> IMAGE_NT_HEADERS
;--- edi == 0 if dynamically loaded (dlls only)
;*** now do: 
;*** - resolve imports
;*** - set attributes of pages for each section (r/w r/o discard)
;*** - call Entry
;*** out: esi modulehandle
;*** C if error, ax=error text

InitPEModule proc
if ?CHECKCROSSREFS
	test [esi-sizeof MZHDR].MZHDR.bFlags, FPE_CROSSREF
	jnz exit
endif
	inc [esi-sizeof MZHDR].MZHDR.wCnt	;increment counter 
	@printf <"InitPEModule, handle=%lX">, esi
if _TRACE_
	@trace_s <" ">
	lea ebx,[esi-sizeof MZHDR]
	call modulenameout
endif
;;	@trace_s lf
	test [esi].IMAGE_NT_HEADERS.FileHeader.Characteristics,IMAGE_FILE_DLL
	jz init_app
if ?EARLYMODLISTUPDATE
;--- add module here to module list before calling DoImports - which may crash!
	call AddModuleToAppModList
	jnc exit				;jump if it is already in there
endif
	cmp [esi - sizeof MZHDR].MZHDR.wCnt,1
	jnz imports_done
if ?CHECKCROSSREFS
	or [esi - sizeof MZHDR].MZHDR.bFlags, FPE_CROSSREF
endif
	call DoImports	   ;now resolve all imports
if ?CHECKCROSSREFS		  
	pushf
	and [esi - sizeof MZHDR].MZHDR.bFlags,not FPE_CROSSREF
	popf
endif
	jc error_imports_dll   
if ?SETSECATTR
	call SetSecAttr
endif
imports_done:
if ?CALLDLLENTRY1TIME
	test byte ptr [esi].IMAGE_NT_HEADERS.OptionalHeader.DllCharacteristics+1,80h
	jnz exit
	or byte ptr [esi].IMAGE_NT_HEADERS.OptionalHeader.DllCharacteristics+1,80h
else
ife ?EARLYMODLISTUPDATE
	call AddModuleToAppModList
	jnc exit				;jump if it is already in there
endif
endif

	mov eax,[esi].IMAGE_NT_HEADERS.OptionalHeader.AddressOfEntryPoint
	and eax,eax
	jz exit
	@printf <"InitPEModule: calling dll entry, module=%lX, entry=%lX",lf>, esi, eax

if ?FLATES
	push es
endif

if ?NBSTACK	;switch to flat stack
	mov cx, ss
	mov ax, ds
	.if (ax != cx)
if 0
		mov edx, esp
		invoke getesp
else
		call getstacktop
		mov edx, esp
endif
		push ds
		pop ss
		mov esp,eax
	.else
		mov edx, esp
		and sp,-4
	.endif
	push ecx			;save old ss
	push edx			;save old esp
endif

if ?FLATES
	push ds
	pop es
endif
	mov cx, cs:[wFlatCS]
	mov ebx, [esi].IMAGE_NT_HEADERS.OptionalHeader.AddressOfEntryPoint
	lea edx, [esi - sizeof MZHDR]
	add ebx, edx
if ?INT41SUPPORT
	mov ax,DS_LOADDLL+100h			;"dll loading"
	int 41h 						;cs:eip in cx:ebx, handle = edx
endif
	push cs
	push offset retdll
	call GetTaskFlags
	push eax
	pushd DLL_PROCESS_ATTACH		;parm2: reason
	push edx						;parm1: handle
	mov eax,cs:[dwBase]
	add eax,offset retdll32
	push eax						;return addr
	push dword ptr cs:[wFlatCS]
	push ebx						;eip
retdll32:
	db 66h							;retfd!
	retf
retdll:
if ?NBSTACK
	pop ecx
	pop ss			;just a WORD is popped, but that doesnt matter
	mov esp,ecx
endif
if ?FLATES
	pop es
endif
	movzx edx,dx
	movzx ecx,cx
	@printf <"InitPEModule: returned from dll entry, eax=%lX fs=%X",lf>, eax, fs
	cmp eax,1
;	jnz error_dll_initfailed
	jc error_dll_initfailed
	jmp exit

;*** esi= modulehandle

init_app:						;PE application
if ?MULTPSP
if ?SUPAPPTITLE
	push ds
	mov ds,cs:[wLdrDS]
	mov al,01					;expects DS=DGROUP!
	call SetAppTitle			;requires wTIBSel to be set
	pop ds
endif
endif
	call savepathPE
	mov bx,ss
	mov edi,esp
	push ds
	pop es
	mov eax, [esi-sizeof MZHDR].MZHDR.dwStack
	add eax, [esi].IMAGE_NT_HEADERS.OptionalHeader.SizeOfStackReserve
  if ?ADDTOSTACK
	add eax,?ADDTOSTACK
  endif
	push ds
	pop ss
	mov esp, eax
	@printf <"InitPEModule: stack switched to %lX",lf>, eax
	xor edx, edx
	push edx			;make room for 2 dwords!
	push edx

if 1
	mov ax,0901h		; enable interrupts
	int 31h
else
	pushf
	pop ax
	test ah, 2
	jnz @F
	sti
@@:
endif
if ?ALLOWGUIAPPS
;	test cs:bEnvFlgs2, ENVFL2_EARLYGUIHLP
;	jz @F
	call loadguihelper
@@:
endif
	call DoImports			;resolve imports (esi,edi,ebx unchanged)
	jc error_imports_app
if ?SETSECATTR
	call SetSecAttr
endif

;--- the lpReserved parameter must be 0 for dynamic loads

	xor ax,ax
	call SetTaskFlags
if 0
	xor dx,dx				;this will reset errormode!
else
	mov dx,8000h
endif
	call _SetErrorMode
	mov cx,cs:[wFlatCS]
	mov ebx,[esi].IMAGE_NT_HEADERS.OptionalHeader.AddressOfEntryPoint

	lea esi, [esi-sizeof MZHDR]
	add ebx,esi
if 0
;--- this was an ugly hack, to terminate the serialization of the init phase
	mov byte ptr [esi+0012h],0
endif

if _TRACE_
	mov ax, ds
	lar eax, eax
	shr eax,8
	@printf <"InitPEModule: app starting, handle=%lX, ds/es/ss=%X(%X)">, esi, ds, ax
	mov ax, cx
	lar eax, eax
	shr eax,8
	@printf <",cs=%X(%X) fs=%X eip=%lX esp=%lX",lf,lf>, cx, ax, fs, ebx, esp
endif

	mov edi,cs:[dwBase]
	add edi,offset retapp32
	push edi
if ?INT41SUPPORT
	mov ax,DS_StartTask+100h;CX:EBX=CS:IP
	int 41h
	test byte ptr rEAX,1		;was it int 21h, ax=4B01h?
	jnz @F
	test cs:bEnvFlgs,ENVFL_BREAKATENTRY
	jz nobreak
@@:
	mov ax,DS_ForcedGO		;"set breakpoint at cx:ebx"
	int 41h 				;cx:ebx=cs:eip
nobreak:
endif
	push ecx
	push ebx
	db 66h
	retf
retapp32:
	mov ah, 4Ch
	int 21h

error_imports_app:
	@trace_s <"*** InitPEModule, error_imports_app reached! ***",lf>
	mov ss,bx
	mov esp,edi
	call error_ax_out
	mov ax, 4C00h + RC_INITAPP
	int 21h
error_dll_initfailed:
	mov ax,offset szErrPE10
	jmp error2				;immediately exit this dll
error_imports_dll:
	mov [esi.IMAGE_NT_HEADERS.OptionalHeader.AddressOfEntryPoint], 0	;dont call entry
error2:
if 1
	push ax
	lea eax, [esi - sizeof MZHDR]
	call FreeModule32
	pop ax
endif
error1:					;TIBSel not allocated????
error:
	stc
exit:
	lea esi,[esi-sizeof MZHDR]
	ret
InitPEModule endp


;--- get virtual/physical size into ecx, whatever is larger
;--- thats because some binaries always have virtual size = zero
;--- modifies ecx + edx

getsectionsize proc                
	mov ecx, [edi.IMAGE_SECTION_HEADER.Misc.VirtualSize]
	mov edx, [edi.IMAGE_SECTION_HEADER.SizeOfRawData]
	cmp ecx, edx
	jnc @F
	mov ecx, edx
@@:
	ret
getsectionsize endp

;*** load image in memory, dont resolve anything
;*** bx=file handle
;*** esi=IMAGE_NT_HEADER
;*** the object table is located behind the NT_HEADERS 
;--- returns with C on errors in binary

LoadImage proc uses edi ebp es

if ?INT41SUPPORT
	sub esp, sizeof D386_Device_Params
	;@loadesp ebp
	mov ebp,esp
	mov [ebp].D386_Device_Params.DD_logical_seg,0
	mov dword ptr [ebp].D386_Device_Params.DD_name,0
	mov word ptr [ebp].D386_Device_Params.DD_name+4,0
	mov edi, [esi.MZHDR.pExeNam - sizeof MZHDR]
	lea edi, [edi + esi - sizeof MZHDR]
	call skippath
	mov dword ptr [ebp].D386_Device_Params.DD_sym_name,edi
	mov word ptr [ebp].D386_Device_Params.DD_sym_name+4,ds
endif
	@printf <"LoadImage start, header=%lX",lf>, esi

	movzx edi, [esi].IMAGE_NT_HEADERS.FileHeader.SizeOfOptionalHeader
	lea edi,[esi + edi + sizeof IMAGE_FILE_HEADER + 4]
	mov cx,[esi].IMAGE_NT_HEADERS.FileHeader.NumberOfSections
	push ds
	pop es
nextsection:
	push cx
	push edx

	@printf <"LoadImage base=%lX length=%lX rawdata=%lX size=%lX",lf>,\
		[edi].IMAGE_SECTION_HEADER.VirtualAddress,\
		[edi].IMAGE_SECTION_HEADER.Misc.VirtualSize,\
		[edi].IMAGE_SECTION_HEADER.PointerToRawData,\
		[edi].IMAGE_SECTION_HEADER.SizeOfRawData

if ?SKIPCOMMENTS
	test byte ptr [edi].IMAGE_SECTION_HEADER.Characteristics+3, 0E0h ;is is read/write/exec?
	jz @F
endif
;-------------------------------------------- section size into ecx
	call getsectionsize

	shr ecx, 2
	push edi
	mov edi,[edi].IMAGE_SECTION_HEADER.VirtualAddress
	lea edi,[edi + esi - sizeof MZHDR]
	mov edx,edi
	xor eax, eax
	rep stos dword ptr [edi]
	pop edi
if 0
	test [edi].IMAGE_SECTION_HEADER.Characteristics,IMAGE_SCN_CNT_UNINITIALIZED_DATA
	jnz @F
else
	cmp [edi].IMAGE_SECTION_HEADER.SizeOfRawData,eax
	jz @F
	cmp [edi].IMAGE_SECTION_HEADER.PointerToRawData,eax
	jz @F
endif
	push edx
	push [edi].IMAGE_SECTION_HEADER.PointerToRawData
	pop dx
	pop cx
	mov ax,4200h
	int 21h
	pop edx
	mov ecx,[edi].IMAGE_SECTION_HEADER.SizeOfRawData
	mov ah,3Fh
	int 21h
	jc error
	cmp eax,ecx
	jnz error
@@:

if ?INT41SUPPORT

;--- ebp -> D386_Device_Params
;--- edi -> IMAGE_SECTION_HEADER

	push ebx
	push esi
	mov ax, cs:[wFlatDS]
	test [edi].IMAGE_SECTION_HEADER.Characteristics, IMAGE_SCN_CNT_CODE
	jz @F
	mov ax, cs:[wFlatCS]
@@:
	mov [ebp].D386_Device_Params.DD_actual_sel, ax
	mov eax,[edi].IMAGE_SECTION_HEADER.VirtualAddress
	lea eax,[eax + esi - sizeof MZHDR]
	mov [ebp].D386_Device_Params.DD_base, eax
	call getsectionsize
	mov [ebp].D386_Device_Params.DD_length, ecx
	mov ebx, ebp
	mov dx, ss
	mov si, ST_code_sel
	mov ax, DS_LoadSeg_32
	int Debug_Serv_Int

	inc [ebp].D386_Device_Params.DD_logical_seg
	pop esi
	pop ebx

endif

	add edi,sizeof IMAGE_SECTION_HEADER
	pop edx
	pop cx
	dec cx
	jnz nextsection
if ?INT41SUPPORT
	add esp, sizeof D386_Device_Params
endif
	clc
	ret
error:
if ?INT41SUPPORT
	add esp, sizeof D386_Device_Params
	stc
endif
	pop edx
	pop cx
	mov ax,offset szErrPE5
	ret
LoadImage endp


if ?SETSECATTR

;--- inp: esi = IMAGE_NT_HEADER
;--- modifies cx

SetSecAttr proc uses edi

	test cs:bEnvFlgs,ENVFL_DONTPROTECT or ENVFL_DONTUSEDPMI1
	jnz exit
	@trace_s <"SetSecAttr enter",lf>
	mov cx,[esi.IMAGE_NT_HEADERS.FileHeader.NumberOfSections]
	lea edi,[esi + sizeof IMAGE_NT_HEADERS]
	.while (cx)
if ?SKIPCOMMENTS
		test byte ptr [edi].IMAGE_SECTION_HEADER.Characteristics+3, 0E0h
		jz skipitem
endif
		.if (!([edi.IMAGE_SECTION_HEADER.Characteristics] & IMAGE_SCN_MEM_WRITE))
			pushad
			mov ebx, [edi.IMAGE_SECTION_HEADER.VirtualAddress]
			call getsectionsize		;modifies ecx + edx
			mov ax,cx
			shr ecx, 12
			test ax,0FFFh
			jz @F
			inc ecx
@@:
			@printf <"SetSecAttr mod=%lX, VA=%lX, pgs=%lX read-only",lf>, esi, ebx, ecx
			push es
;----------------------------- we cannot assume that SS is flat here
			push ss
			pop es
			mov ax, 11h	;reset read/write and reset accessed/dirty
if ?DISCARDSECTION
			test [edi].IMAGE_SECTION_HEADER.Characteristics, IMAGE_SCN_MEM_DISCARDABLE
			jz @F
			and al,0F8h	;release memory for discardable sections
@@:
endif
			sub esp, ecx
			sub esp, ecx
			mov edi, esp
			mov edx, ecx
			rep stos word ptr [edi]
			mov ecx, edx	;ecx=number of pages
			mov edx, esp	;es:edx=page attributes
			mov esi, [esi.MZHDR.hImage - sizeof MZHDR]
			mov ax, 0507h
			int 31h
			mov esp, edi
			pop es
			popad
		.endif
skipitem:
		add edi,sizeof IMAGE_SECTION_HEADER
		dec cx
	.endw
exit:
	@trace_s <"SetSecAttr exit",lf>
	ret
SetSecAttr endp
endif

;*** search a function/export
;*** eax -> name
;*** edi -> export directory
;*** ebx = hmodule
;--- es= flat
;*** out: carry if not found
;*** else ordinal in eax

SearchExportByName proc
	push ebp
	mov ebp,esp

	push eax						  ;^ imported names [ebp-4]
	push edi						  ;saved edi = [ebp-8]

	mov edx,[edi.IMAGE_EXPORT_DIRECTORY.NumberOfNames]
	mov esi,[edi.IMAGE_EXPORT_DIRECTORY.AddressOfNames]
	add esi,ebx
	push esi						  ;start of export table [ebp-12]
	pushd 0							  ;[ebp-16]:start
	push edx						  ;[ebp-20]:ende

	mov edi,eax
	mov ecx,-1
	xor al,al
	repnz scas byte ptr [edi]		  ;length of name
	not ecx
	jmp se_01
se_0:
	jc @F
	sub [ebp-20],edx				  ;set upper limit
	jmp se_01
@@:
	add [ebp-16],edx				  ;set lower limit
se_01:
	and edx,edx
	jz notfound
	mov edx,[ebp-20]
	sub edx,[ebp-16]
	shr edx,1
	mov eax,edx
	add eax,[ebp-16]
	shl eax,2						  ;each entry 4 byte

	add eax,[ebp-12]
	mov esi,[eax]					  ;offset to name of export
	add esi,ebx
	mov edi,[ebp-4] 				  ;name entry
	push ecx
	repz cmps byte ptr [edi], [esi]
	pop ecx
	jnz se_0
	mov edi,[ebp-8]
	add edx,[ebp-16]
	mov eax,[edi.IMAGE_EXPORT_DIRECTORY.AddressOfNameOrdinals]
	add eax,ebx
	movzx eax,word ptr [eax+edx*2]	  ;these values are adjusted
	mov esp,ebp
	pop ebp
	ret
notfound:
if _TRACE_
	push ebx
	mov ebx,[ebp-4]
	@printf <"*** SearchExportByName '%lS' failed",lf>, ebx
	pop ebx
endif
	stc
	mov eax,[ebp-4]
	mov esp,ebp
	pop ebp
	ret
SearchExportByName endp

;*** search export in module
;*** eax=value of entry
;*** esi=hModule
;*** ebx=image base of module which imports

;*** if bit31 of eax is set, import by number,
;*** -> export address table (EAT) has to be used
;*** else it is import by name
;*** then export name ptr table + export ordinal
;*** table has to be used

SearchExport proc uses esi edi

	push ebx
	lea ebx,[esi-sizeof MZHDR]
	mov edi,[esi].IMAGE_NT_HEADERS.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_EXPORT*sizeof IMAGE_DATA_DIRECTORY].VirtualAddress
	add edi,ebx
	test eax,80000000h			;import by number?
	jnz se_3
	add eax,[esp]				;RVA -> linear address
	inc eax
	inc eax
	call SearchExportByName		;eax ^ name
	jnc se_31
	jmp exit
se_3:							;<- export by number (in eax)
	and eax,7FFFFFFFh
	mov ecx,[edi].IMAGE_EXPORT_DIRECTORY.NumberOfFunctions
	mov edx,[edi].IMAGE_EXPORT_DIRECTORY.Base
	sub eax, edx
	cmp eax, ecx
	jnc error					;index too high!
se_31:
	mov ecx,[edi].IMAGE_EXPORT_DIRECTORY.AddressOfFunctions
	add ecx,ebx
	mov ecx,[ecx+eax*4]			;is it a "hole" in the table?
	jecxz error
	lea eax,[ecx+ebx]
exit:
	pop ebx
	ret
error:							;convert EAX to a string
	@trace_s <"*** SearchExport failed",lf>
	add eax, edx
	push ds
	mov ds,cs:[wLdrDS]
	mov di, offset segtable		;use segtable for the string
	call dw_2_str
	mov byte ptr [di],0
	mov eax, [dwBase]			;now let EAX point to that string
	pop ds
	add eax, offset segtable
	stc
	jmp exit

SearchExport endp

stringout32 proc uses esi
	mov esi,eax
@@:
	lods byte ptr [esi]
	and al,al
	jz @F
	call cs:printproc
	jmp @B
@@:
	ret
stringout32 endp

;*** resolve imports for 1 referenced module ***
;*** called by	DoImports ***
;*** eax=current hModule to initialize ***
;*** edi=current entry in import directory ***
;*** ebx=image base of current module to initialize ***
;*** every referenced module is already loaded (and counter is updated) ***
;*** we only change/init the IAT here ***

ResolveImports proc uses edi esi

	mov esi,eax
	add esi,sizeof MZHDR
	mov ecx,[edi].IMAGE_IMPORT_DESCRIPTOR.OriginalFirstThunk	;array of pointers (name)
	mov edx,[edi].IMAGE_IMPORT_DESCRIPTOR.FirstThunk	;array of pointers
;--------------------------------------- borland PEs miss the ilt
	.if (!ecx)
		mov ecx, edx
	.endif
	xor edi, edi				;counter unresolved imports
nextitem:
	mov eax,[ebx+ecx]
	and eax,eax					;done?
	jz exit
	push ecx
	push edx
	call SearchExport			;search export in EAX
	jnc importok
	@trace_s <"*** ResolveImports: import not found",lf>
	inc edi
	test cs:bEnvFlgs, ENVFL_IGNUNRESIMP
	jnz @F
	test byte ptr cs:[wErrMode+1],HBSEM_NOOPENFILEBOX
	jnz @F
	invoke string_out_prefix, CStr(<"import not found: ">)
	call stringout32			;eax -> string
	call cr_out
@@:
	mov eax,cs:dwBase
	add eax,offset UnresolvedImp
importok:
	pop edx
	pop ecx
	mov [ebx+edx],eax			;modify import address table entry
	add ecx,4
	add edx,4
	jmp nextitem
exit:
	and edi,edi
	jz @F
	test cs:bEnvFlgs, ENVFL_IGNUNRESIMP
	jnz @F
	@printf <"*** ResolveImports %lX failed ***",lf>, ebx
	mov ax, offset szErrPE6		;'cannot resolve imports'
	stc
@@:
	ret

ResolveImports endp

;--- this is 32bit code

UnresolvedImp:
	db 66h, 0EAh
	dw offset Unres16
urCS dw 0

Unres16 proc
	invoke string_out_prefix, CStr(<"unresolved import called",cr,lf>)
	int 3
	mov ax,4C00h + RC_INITAPP
	int 21h
Unres16 endp

;*** DoImports: called by InitPEModule
;*** input: esi -> PEHEADER
;*** scans import directory looking for each module if it's already loaded 
;*** if no, load it via int 21, ax=4b00h
;*** if yes, load it via LoadPEModule (avoids path scan)
;*** after this, resolve imports via ResolveImports
;*** output:
;*** C if error, ax = error text

DoImports proc uses edi ebx

	mov ecx,[esi].IMAGE_NT_HEADERS.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_IMPORT*sizeof IMAGE_DATA_DIRECTORY].Size_

	@printf <"DoImports esi=%lX",lf>,esi

if ?DEBUG
	and ecx, ecx
	jz exit
else
	jecxz exit
endif
	mov edi,[esi].IMAGE_NT_HEADERS.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_IMPORT*sizeof IMAGE_DATA_DIRECTORY].VirtualAddress
	lea ebx,[esi-sizeof MZHDR]
	add edi,ebx
	@printf <"DoImports ebx=%lX",lf>, ebx
	.while (1)
		mov edx,[edi].IMAGE_IMPORT_DESCRIPTOR.Name_
		.break .if (!edx)
		@printf <"DoImports, hModule=%lX name=%lX",lf>, ebx, edx
		add edx,ebx
;;		mov eax,[edi.IMAGE_IMPORT_DESCRIPTOR.OriginalFirstThunk]	;import lookup table rva
if ?SEARCHMODINIMP
		call SearchModuleHandle			;search module in ds:edx
else
		xor eax,eax
endif
		push edi
		push esi
		push ebx
		and eax,eax
		jz @F
		mov edx,[eax].MZHDR.pExeNam 	;let edx point to full name
		add edx,eax
		call LoadModule32
		jmp s1
@@:
		@printf <"DoImports, int 21h, ax=4b00, edx=%lX",lf>, edx
		mov ax,4B00h					;load module, search in PATH
		int 21h
		@printf <"DoImports, int 21h returned, fs=%X",lf>, fs
s1:
		pop ebx
		pop esi
		pop edi
		jc error1						;error loading module
		mov [edi].IMAGE_IMPORT_DESCRIPTOR.TimeDateStamp, eax ;save hModule here
		call ResolveImports
		jc error2
		add edi,sizeof IMAGE_IMPORT_DESCRIPTOR
	.endw
exit:
	clc
	ret
error2:
	mov edx,[edi.IMAGE_IMPORT_DESCRIPTOR.Name_]
	add edx,ebx
	call fileout		;display file in ds:edx
	jmp @F
error1:
	mov ax,offset szErrPE8
@@:
;	call fileout		;display file in ds:edx
	@printf <"*** DoImports failed, esi=%lX ***",lf>, esi
	stc
	ret
DoImports endp

;*** print "dpmild32: file xxxx.xxx<CR><LF>"
;--- file in ds:edx
;--- modifies edx

fileout proc uses ax
	test byte ptr cs:[wErrMode+1],HBSEM_NOOPENFILEBOX
	jnz done
	push ds
	mov ds,cs:[wLdrDS]
	invoke string_out_prefix, CStr(<"file ">)
	pop ds
@@:
	mov al,[edx]
	and al,al
	jz @F
	call cs:printproc
	inc edx
	jmp @B
@@:
	call cr_out
done:
	ret
fileout endp

;*** resolve internal references of a module
;--- C if error, ax=code

;--- the fixups consist of
;--- 1 IMAGE_BASE_RELOCATION entry for each page
;--- n WORDs, lower 12 bits are offset, high 4 bits are reloc type
;--- an empty IMAGE_BASE_RELOCATION entry marks end of relocs.

DoFixups proc uses edi esi ebx ebp

	mov ebx,[esi].IMAGE_NT_HEADERS.OptionalHeader.ImageBase

	@trace_s <"DoFixups start",lf>

	lea edx,[esi-sizeof MZHDR]	;module base to edx
	test [esi].IMAGE_NT_HEADERS.FileHeader.Characteristics,IMAGE_FILE_RELOCS_STRIPPED
	jz @F
	cmp ebx,edx 				;if relocs are stripped, check		
	jnz error					;module base
	jmp done					;do nothing
@@:
	mov ebp, [esi].IMAGE_NT_HEADERS.OptionalHeader.SizeOfImage
	mov ecx, [esi].IMAGE_NT_HEADERS.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_BASERELOC*sizeof IMAGE_DATA_DIRECTORY].Size_
	jecxz done
	mov esi, [esi].IMAGE_NT_HEADERS.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_BASERELOC*sizeof IMAGE_DATA_DIRECTORY].VirtualAddress
	add esi,edx
nextblock:						;<---
	@printf <"DoFixups block=%lX size=%lX",lf>, [esi].IMAGE_BASE_RELOCATION.VirtualAddress,\
		[esi].IMAGE_BASE_RELOCATION.SizeOfBlock

	mov edi, [esi].IMAGE_BASE_RELOCATION.VirtualAddress
	cmp edi, ebp
	jnc done			;invalid relocations found!!!

	push ecx
	push esi
	push edx
	push ebx

	add edi, edx
	sub edx, ebx
	mov ecx, [esi].IMAGE_BASE_RELOCATION.SizeOfBlock
	add ecx, esi
	add esi, sizeof IMAGE_BASE_RELOCATION
	xor eax, eax
	.while (esi < ecx)
		lods word ptr [esi]
		mov bl,ah
		and ah,0Fh
		shr bl,4
		.if (bl == IMAGE_REL_BASED_HIGHLOW)
			add [edi+eax],edx
		.endif
	.endw
	pop ebx
	pop edx
	pop esi
	pop ecx
	mov eax,[esi].IMAGE_BASE_RELOCATION.SizeOfBlock
	add esi, eax
	sub ecx, eax
	ja nextblock
done:
	clc
exit:
	ret
error:
	mov ax,offset szErrPE9			;relocs stripped
if ?DEBUG
;	int 3
endif
	stc
	jmp exit
DoFixups endp

;*** direkt aus Int21 Handler ***

CheckInt214B proc stdcall public

	push commonexit
	cmp al,80h
	jz FreeLibrary32
	cmp al,81h
	jz GetProcAddress32		;input: PE handle
	cmp al,82h
	jz GetModuleHandle32
	cmp al,83h
	jz GetNextModuleHandle32
	cmp al,84h
	jz CallProc32W
	cmp al,86h
	jz GetModuleFileName		;input: module handle in EDX
	cmp al,87h
	jz _CallProc16				;input: CS:IP in EDX
;	cmp al,91h
;	jz SetPELoadState
	cmp al,92h
	jz SetModuleStart
	cmp al,95h
	jz SetSysDir
	add esp,2
	ret 						;return to handler, dont change registers
commonexit:
	lea esp,[esp+2] 			;pop return to int handler
	jc @F
	and byte ptr [esp+2*4],not 1
	iretd						;terminate int 21
@@:
	or byte ptr [esp+2*4],1
	iretd

CheckInt214B endp

SetSysDir:
	push ds
	mov ds,cs:[wLdrDS]
	xchg edx, [dwSysDir]
	pop ds
	ret

if 0
SetErrorMode proc uses ds
	mov ds,cs:[wLdrDS]
	test bEnvFlgs, ENVFL_IGNNOOPENERR
	jz @F
	and dh,7Fh			;reset this bit
@@:
	xchg dx,[wErrMode]
	ret
SetErrorMode endp
endif

;--------------------------------- call a flat procedure

CallProc32W proc uses ds es

	push bx
	push dx
	mov bx,ss
	mov ax,0006 			;get base of SS
	int 31h
	push cx
	push dx
	pop ecx 				;into ecx
	pop dx
	pop bx
	mov ax,cs:[wFlatDS]
	mov ds,ax				;set ds,es to flat
	mov es,ax
	push ss
	push esp 				;save old ss:esp

	add ecx,esp
	mov ss,ax
	mov esp,ecx 			;set stackpointer to flat

	mov edi,offset cp32_ret1
	add edi,cs:[dwBase]
	push cs							;we only push CS:xxx as FAR16	
	push offset cp32_ret2			;because we will execute a RETF (not RETFD)
	push ebx 						;parm1: EBX (_stdcall)
	push edi 						;return addr
	push dword ptr cs:[wFlatCS]
	push edx 						;eip
cp32_ret1:							;back from call, but still in 32 bit mode
	db 66h							;retfd in 16 bit mode, retf in 32-bit mode
	retf
cp32_ret2:							;now in 16 bit mode
	pop ecx
	pop ss
	mov esp,ecx
	pop cx							;esp correction
	ret
CallProc32W endp

;--- call 16bit far proc, CS:IP in EDX

_CallProc16 proc
	call CallProc16
if 0
	jc @F
	and byte ptr [esp+4+2*4],0FEh
	ret
@@:
	or byte ptr [esp+4+2*4],01h
endif
	ret
_CallProc16 endp

if ?ZEROHIWORDEBP
CallProc16 proc stdcall public uses es fs gs esi edi ebx ebp
else
CallProc16 proc stdcall public uses es fs gs esi edi ebx
endif

	.if (!cs:wStk16)
		call GetStack16
		jc error
	.endif
	xchg esi, ebx		;ebx holds linear address of stack parameters
	mov ax,ss
	movzx edi, sp
	cmp ax,cs:wStk16	;no stack switch necessary
	mov ax,offset cp16_ret2
	jz @F
	mov es,cs:wStk16
	mov di, es:[0]
	sub word ptr es:[0], 400h
	sub di, 6
	mov es:[di+0], esp
	mov es:[di+4], ss
	mov ax,offset cp16_ret1
@@:
	sub di, cx
	sub di, cx
	push es
	pop ss
	movzx esp, di
	movzx ecx, cx
	push ds
	mov ds,cs:[wFlatDS]
	rep movs word ptr [edi],[esi]
	pop ds
	mov si,bx
	push cs
	push ax
	push edx		;push CS:IP
if ?ZEROHIWORDEBP
	movzx ebp,bp
endif
	movzx edx,dx
	movzx esi,si
	movzx ebx,bx
	retf
cp16_ret1:
	assume ss:DGROUP
	add word ptr ss:[0],400h
	mov si,sp
	lss esp,ss:[si]
cp16_ret2:
	clc
error:
	ret
CallProc16 endp

	assume ss:nothing

;---------------------------------
;--- inp: previous module handle in EDX (or 0)
;--- out: next module handle in EAX
;---      module count in ECX
;---      DPMI handle for image in EDX

GetNextModuleHandle32 proc uses ds

	mov ds,cs:[wFlatDS]
	mov ecx,cs:[dwMod32]
	and edx,edx 		   ;first module?
	jz @F
	call SearchModuleInList ;search module EDX
@@:
	mov eax,ecx 		   ;next handle in EAX
	jecxz @F
	movzx ecx,[eax.MZHDR.wCnt]
	mov edx,[eax.MZHDR.hImage]
@@:
	clc
	ret
GetNextModuleHandle32 endp

;---------------------------------
;--- inp: module name in EDX (or NULL)
;--- out: handle in EAX

GetModuleHandle32 proc uses ds

	mov ds,cs:[wFlatDS]
	and edx,edx
	jz @F
	call SearchModuleHandle
	jmp exit
@@:
	movzx eax, cs:[wTDStk]
	cmp ax,offset starttaskstk
	jz notask
	mov eax, cs:[eax-sizeof TASK].TASK.dwModul
	test eax, 0FFFF0000h		;is it a PE task?
	jz notask
	mov edx, [eax].MZHDR.dwStack
	mov ecx, [eax].MZHDR.pModuleList
	jmp exit
notask:
	mov eax, cs:[dwMod32]	;search the first module which has a stack
nextitem:
	and eax, eax
	jz exit
	cmp [eax].MZHDR.dwStack,0
	jnz exit
	mov eax, [eax].MZHDR.pNxtMod
	jmp nextitem
exit:
	ret
GetModuleHandle32 endp

;--------------------------------- hModule in EDX, returns ^name in EAX

GetModuleFileName proc uses ds bx
	mov ds,cs:[wFlatDS]
	and edx, edx
	jnz @F
	movzx eax, cs:[wTDStk]
	mov eax, cs:[eax-sizeof TASK].TASK.dwModul
	jmp step2
@@:
	test edx, 0FFFF0000h
	jnz ispe
	mov bx, dx
	mov ax, 6
	int 31h
	jc error
	push cx
	push dx
	pop eax
	add eax,offset NEHDR.szModPath
	jmp exit
ispe:
	invoke SearchModuleInList
	jc exit
step2:
	add eax, [eax].MZHDR.pExeNam
exit:
	ret
error:
	xor eax, eax
	stc
	ret

GetModuleFileName endp

;--- GetProcAddress()
;--- hModule in EBX, procname in EDX
;--- procname may be a number (then HIWORD(edx) == 0)

GetProcAddress32 proc uses ds es

	mov ds,cs:[wFlatDS]
	xor eax,eax			;return 00000000 as default
	pushad
	push edx
	mov edx, ebx
	invoke SearchModuleInList
	pop edx
	jc error
	mov edi,[ebx].IMAGE_NT_HEADERS.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_EXPORT*sizeof IMAGE_DATA_DIRECTORY].VirtualAddress+sizeof MZHDR
	and edi,edi
	jz  error		;no export directory?
	add edi,ebx
	mov eax,edx
	test eax, 0FFFF0000h
	jnz isname
	sub eax,[edi].IMAGE_EXPORT_DIRECTORY.Base
	cmp eax,[edi].IMAGE_EXPORT_DIRECTORY.NumberOfFunctions
	jnc error
	jmp found
isname:
	push ds
	pop es
	call SearchExportByName
	jc error
found:
	mov edx,[edi].IMAGE_EXPORT_DIRECTORY.AddressOfFunctions
	add edx,ebx
	shl eax,2
	mov eax,[edx+eax]
	and eax,eax
	jz error
	add eax,ebx
	mov [esp+1Ch],eax
	jmp exit
error:
	stc
exit:
	popad
	ret

GetProcAddress32 endp

if 0
SetPELoadState proc uses ds
	mov ds,cs:[wLdrDS]
	xchg bl,[bEnabled]
	ret
SetPELoadState endp
endif

SetModuleStart proc uses ds
	mov ds,cs:[wLdrDS]
	mov eax,edx
if 0
	test bEnvFlgs2, ENVFL2_IGN214B92
	jz done
	and edx, edx
	jnz done
	push ds
	mov edx, offset szkernel32
	add edx, [dwBase]
	mov ds,[wFlatDS]
	call SearchModuleHandle
	pop ds
endif
done:
	xchg eax,[dwMod32]
	ret
SetModuleStart endp

FreeLibrary32 proc
	@trace_s <"FreeLibrary32: enter",lf>
	mov eax,edx
	call FreeModule32
	ret
FreeLibrary32 endp

;*** delete a pe modul from module list
;*** inp: EBX=module, DS=FLAT

UnlinkPEModule proc
	lea edx,dwMod32
	add edx,cs:[dwBase]
@@:
	mov ecx,[edx]
	jecxz fertig
	cmp ecx,ebx
	jz found
	lea edx,[ecx.MZHDR.pNxtMod]
	jmp @B
found:
	mov eax,[ecx.MZHDR.pNxtMod]
	mov [edx],eax
fertig:
	ret
UnlinkPEModule endp

;--- free all referenced modules of a module
;--- inp: esi -> module NT_HEADERS
;---      ebx = hModule
;--- modifies edi

FreeReferencedModules proc

	mov ecx,[esi].IMAGE_NT_HEADERS.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_IMPORT*sizeof IMAGE_DATA_DIRECTORY].Size_
	jecxz done
	mov edi,[esi].IMAGE_NT_HEADERS.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_IMPORT*sizeof IMAGE_DATA_DIRECTORY].VirtualAddress
	add edi,ebx
next:
	mov eax,[edi.IMAGE_IMPORT_DESCRIPTOR.Name_]
	and eax,eax
	jz done
	mov eax,[edi.IMAGE_IMPORT_DESCRIPTOR.TimeDateStamp]
	and eax, eax	;was there an error loading this module?
	jz @F
	call FreeModule32
@@:
	add edi,sizeof IMAGE_IMPORT_DESCRIPTOR
	jmp next
done:
	ret
FreeReferencedModules endp

if _TRACE_
DispDynLoadedTab proc
	mov esi, [ebx].MZHDR.pModuleList
nextitem:
	mov eax,[esi.MODLISTITEM.handle]
	and eax,eax
	jz done
	push ebx
	@printf <"entry: %lX %X/%X ">, eax, [esi].MODLISTITEM.wCnt,[eax].MZHDR.wCnt
	mov ebx, eax
	call modulenameout
	pop ebx
	add esi, sizeof MODLISTITEM
	jmp nextitem
done:
	ret
DispDynLoadedTab endp
endif

;--- check if a module is referenced by another
;--- eax = current module
;--- ecx = other module

IsReferenced proc uses edx edi

	mov edx,[eax+sizeof MZHDR].IMAGE_NT_HEADERS.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_IMPORT*sizeof IMAGE_DATA_DIRECTORY].Size_
	and edx, edx
	jz notreferenced
	mov edi,[eax+sizeof MZHDR].IMAGE_NT_HEADERS.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_IMPORT*sizeof IMAGE_DATA_DIRECTORY].VirtualAddress
	add edi,eax
	.while (edx)
		.break .if (![edi].IMAGE_IMPORT_DESCRIPTOR.Name_)
		.if ([edi.IMAGE_IMPORT_DESCRIPTOR.TimeDateStamp] == ecx)
			jmp isreferenced
		.endif
		add edi,sizeof IMAGE_IMPORT_DESCRIPTOR
	.endw
notreferenced:
	clc
	ret
isreferenced:
	stc
	ret
IsReferenced endp

;--- free dynamically loaded modules
;--- inp: ebx = hModule
;--- modifies no registers!

;--- there are 2 loops
;--- the first one calcs the module which has been loaded
;--- the least times.

FreeDynLoadedModules proc

if ?LDRHEAP
	@trace_s <"FreeDynLoadedModules: entry",lf>
	pushad
if _TRACE_
	call DispDynLoadedTab
endif
newscan:
	mov edi, -1
	mov esi, [ebx].MZHDR.pModuleList
next:
	mov eax,[esi.MODLISTITEM.handle]
	and eax,eax
	jz endoflist
	mov dx, [eax.MZHDR.wCnt]			;calculate how often the 
	sub dx, [esi.MODLISTITEM.wCnt]		;module has been loaded
	jc isgreater						;dynamically in edx
	cmp di, dx
	jc isgreater
	jne @F
;---------------------- both modules have an identical diff count
;---------------------- check if previous module in ecx is referenced by
;---------------------- this one. If yes, then use this one
	call IsReferenced
	jnc isgreater
@@:
	mov edi, edx						;remember the module
	mov ecx, eax						;being loaded the least times
isgreater:
	add esi, sizeof MODLISTITEM
	jmp next
endoflist:
	cmp edi, -1
	jz done
if 0
	mov edx, ecx
	call SearchModuleInList
	jc done
else
	mov eax, ecx
endif
	call FreeModule32
	and eax, eax
	jnz newscan
done:
	popad
	@trace_s <"FreeDynLoadedModules: exit",lf>
endif
	ret
FreeDynLoadedModules endp

GetTaskFlags proc
	movzx eax, cs:[wTDStk]
	cmp ax,offset starttaskstk
	jz @F
	mov ax, cs:[eax-sizeof TASK].TASK.wFlags
	ret
@@:
	xor ax,ax
	ret
GetTaskFlags endp

SetTaskFlags proc

	push bx
	push ds
	mov ds,cs:[wLdrDS]
	mov bx,[wTDStk]
	cmp bx,offset starttaskstk
	jz @F
	and [bx-sizeof TASK].TASK.wFlags,not 1
	or [bx-sizeof TASK].TASK.wFlags,ax
@@:
	pop ds
	pop bx
	ret
SetTaskFlags endp

;*** DLL detach ***
;*** eax=hModule
;--- edi=0 if dynamically freed (FreeLibrary), else != 0
;--- returns 0 if module is not found
;--- else, for Apps, eax will return the dpmi handle of the stack!

FreeModule32 proc stdcall public uses esi edi ebx

	push ds
	push es
	mov ds,cs:[wFlatDS]
	push ds
	pop es
	@printf <"FreeModule32: entry FreeModule32 hdl=%lX",lf>, eax
	mov edx,eax
	call SearchModuleInList
if _TRACE_
	.if (CARRY?)
		@trace_s <"FreeModule32: module NOT found in module list",lf>
		jmp exit
	.endif
else
	jc exit
endif
	mov ebx,eax
	@trace_s <"FreeModule32: module found in module list",lf>
if _TRACE_
	call modulenameout
endif
	lea esi,[ebx+sizeof MZHDR]
	test [esi.IMAGE_NT_HEADERS.FileHeader.Characteristics],IMAGE_FILE_DLL
	jnz FreeDll32
ife ?EARLYMODLISTUPDATE
	call UnlinkPEModule			;remove module EBX from list
endif
	@trace_s <"FreeModule32: calling FreeReferencedModules",lf>
	mov ax,1
	call SetTaskFlags
	call FreeReferencedModules	;input ESI, modifies EDI
	@trace_s <"FreeModule32: calling FreeDynLoadedModules",lf>
	call FreeDynLoadedModules	;preserves all registers
if ?EARLYMODLISTUPDATE		  
	call UnlinkPEModule			;remove ebx=handle from list
endif

if ?EXTRASTACKHDL
	push [ebx].MZHDR.hStack
;	pop di
;	pop si
;	mov ax,0502h			;free memory
;	int 31h
endif
	jmp fl_exx

FreeDll32:

	@printf <"FreeModule32: dec count %X",lf>, [ebx].MZHDR.wCnt
if ?CHECKCROSSREFS
	test [ebx].MZHDR.bFlags,FPE_CROSSREF
	jnz exit
endif
	cmp [ebx].MZHDR.wCnt,0
	jz @F
	dec [ebx].MZHDR.wCnt			;dlls counter decrement
@@:
if ?CALLDLLENTRY1TIME
	jnz fl_3
	test byte ptr [esi].IMAGE_NT_HEADERS.OptionalHeader.DllCharacteristics+1,80h
	jz fl_3
	and byte ptr [esi].IMAGE_NT_HEADERS.OptionalHeader.DllCharacteristics+1,7Fh
else
	call DeleteModuleFromAppModList
	jnc fl_3					;NC = not found or not deleted
endif
	mov eax,[esi].IMAGE_NT_HEADERS.OptionalHeader.AddressOfEntryPoint
	and eax,eax
	jz fl_3
if _TRACE_
	invoke string_out_prefix, CStr(<"call dll detach for ">)
	call modulenameout
endif
if ?FLATES
	push es
endif
if ?NBSTACK	;switch to flat stack
	mov cx, ss
	mov ax, ds
	.if (ax != cx)
		call getstacktop
		mov edx, esp
		push ds
		pop ss
		mov esp,eax
	.else
		mov edx, esp
		and sp,not 3
	.endif
	push ecx
	push edx
endif
if ?FLATES
	push ds
	pop es
endif
	mov eax,cs:[dwBase]
	add eax,offset retdll32
if 1
	xor edx, edx
	xchg edx,[esi].IMAGE_NT_HEADERS.OptionalHeader.AddressOfEntryPoint
else
	mov edx,[esi].IMAGE_NT_HEADERS.OptionalHeader.AddressOfEntryPoint
endif
	add edx,ebx

	push cs
	push offset retdll

;------------ now calling: LibEntry(hModule:DWORD,dwFlags:DWORD,dwReserved:DWORD)

	mov ecx,eax
	call GetTaskFlags
	push eax
	pushd DLL_PROCESS_DETACH
	push ebx						;module handle (^MZ)
	push ecx						;near32 ptr retdll32
	push dword ptr cs:[wFlatCS]
	push edx
retdll32:							;this is called in 16 AND 32-bit code segment!!!
	db 66h
	retf
retdll:
if ?NBSTACK
	pop ecx
	pop ss			;just a WORD is popped, but doesnt matter here
	mov esp,ecx
endif
if ?FLATES
	pop es
endif
fl_3:						;free all referenced modules now
if ?CHECKCROSSREFS
	or [ebx].MZHDR.bFlags,FPE_CROSSREF
endif
	call FreeReferencedModules	;this returns with eax=0
if ?CHECKCROSSREFS
	and [ebx].MZHDR.bFlags,not FPE_CROSSREF
endif
	inc eax
	cmp [ebx.MZHDR.wCnt],0
	jnz exit
	call UnlinkPEModule	

if ?EXTRASTACKHDL
	push ebx				;for app we pushed the stack dpmi handle
endif

;----------------------------------- code common for apps + dlls
fl_exx:
if 0
	invoke string_out_prefix, CStr(<"free module ">)
	call modulenameout
endif
if ?INT41SUPPORT
							;dx:edi = module name
if 1
	mov dx,ds
	mov edi,[ebx].MZHDR.pExeNam
	add edi,ebx
	call skippath
endif
	mov cx,[ebx.IMAGE_NT_HEADERS.FileHeader.NumberOfSections]+sizeof MZHDR
	push bx
	xor bx,bx				;segment #
@@:
	mov ax, DS_FreeSeg_32
	int Debug_Serv_Int
	inc bx
	loop @B
	pop bx
endif
	@printf <"FreeModule32: about to free module memory=%lX",lf>, [ebx].MZHDR.hImage
	push [ebx].MZHDR.hImage
if 0
	test cs:fMode, FMODE_DOSEMU
	jz @F
	mov ecx, [ebx+sizeof MZHDR].IMAGE_NT_HEADERS.OptionalHeader.SizeOfImage
	shr ecx, 12
	mov edi, esp
	mov edx, ecx
	.while (ecx)
		push 0
		dec ecx
	.endw
	mov ecx, edx
	mov edx, esp
	push ss
	pop es
	mov esi, [ebx.MZHDR.hImage]
	xor ebx, ebx
	mov ax, 0507h
	int 31h
	mov esp, edi
@@:
endif

	pop di
	pop si
	mov ax,0502h			;free memory
	int 31h
	movzx edx,dx
	movzx ecx,cx
if ?EXTRASTACKHDL
	pop eax					;for apps this is the stack handle
endif
exit:
;	movzx eax,ax
	pop cx
	verr cx
	jz @F
	xor cx, cx
@@:
	mov es, cx
	pop ds
	ret
FreeModule32 endp

if _TRACE_
modulenameout proc
	push eax
	mov eax, ebx
	add eax,[ebx].MZHDR.pExeNam
	@printf <"module %lS cnt=%X",lf>, eax, [ebx.MZHDR.wCnt]
	pop eax
	ret
modulenameout endp
endif

;*** DPMILD32 terminates ***
;*** scan list of loaded PE modules
;*** and free the resources (memory)

UnloadPEModules proc stdcall public
	push ds
	mov eax,[dwMod32]
	mov ds,[wFlatDS]
@@:
	and eax,eax
	jz @F
	push [eax.MZHDR.pNxtMod]
	push [eax.MZHDR.hImage]
	pop di
	pop si
	mov ax,0502h		  ;free dpmi memory
	int 31h
	pop eax
	jmp @B
@@:
	pop ds
	ret
UnloadPEModules endp

;*** check to see if kernel32.dll/user32.dll/ddraw32.dll
;*** are referenced. if yes, replace with dkrnl32.dll/duser32.dll/dddraw32.dll
;*** pointer to name is in ds:esi
;*** ah=0 -> check for win32 name, replace with dos32 name
;*** ah=1 -> check for dos32 name, replace with win32 name

checkandreplace proc public

	pushad
	push es
	mov edx,esi
	mov bx,offset pReplacestrings
	push cs
	pop es
nextitem:
	mov esi,edx
	mov di,cs:[bx+0]		;old name (win32)
	and di,di
	jz done
	mov cx,cs:[bx+2]		;new name (dos32)
	add bx,4
	cmp ah,00
	jz @F
	xchg di,cx
@@:
	lods byte ptr [esi]
ife ?NODLLSUFF
	and al,al
	jz found
endif
	or al,20h
	scasb
	jz @B
if ?NODLLSUFF
	cmp al,'.'
	jnz nextitem
	cmp byte ptr es:[di-1],0
	jnz nextitem
	mov esi,[esi]
	or esi,202020h
	cmp esi,"lld"
	jnz nextitem
else
	jmp nextitem
endif
found:
ife ?NODLLSUFF
	scasb
	jnz nextitem
endif
	mov edi,edx
	push ds
	pop es
	mov si,cx
@@:
	db 2Eh
	lodsb
	stos byte ptr [edi]
	and al,al
	jnz @B
if ?NODLLSUFF
	dec edi
	mov eax,"lld."
	stos dword ptr [edi]
	mov al,0
	stos byte ptr [edi]
endif
done:
	pop es
	popad
	ret
checkandreplace endp


GetStack16 proc uses ds

	pushad
	mov ds,cs:[wLdrDS]
	xor ax,ax
	mov cx, 1
	int 31h 				;alloc selector
	jc exit
	mov wStk16, ax
	mov bx,0000h			;alloc 4k 16 bit stack
	mov cx,1000h
	mov ax,0501h
	int 31h
	jc exit
	mov word ptr dwStkHdl+0, di
	mov word ptr dwStkHdl+2, si
	mov dx,cx
	mov cx,bx
	mov bx,wStk16
	mov ax, 7
	int 31h 				;set base of 16 bit stack
	mov dx,0FFFh
	xor cx,cx
	mov ax, 8
	int 31h 				;set limit to 0FFFh
	lar ecx,ebx
	shr ecx, 8
;---- set D/efault bit of stack for 16-bit procs        
;---- the default bit determines whether SP or ESP
;---- is used for implicit stack references, which are:
;---- PUSH, POP, ENTER, LEAVE
;---- usually best would be to reset the D bit, but some
;---- software doesn't expect to find a 16-bit stack in a
;---- 32bit host! As long as HIWORD(ESP) remains 0, there is
;---- no problem, but on some systems HIWORD(ESP) gets lost
;---- if SS is a 16bit selector!
if 1
	or ch,40h				;set BIG attribute
else
	and ch,not 40h			;reset BIG attribute
endif
	mov ax, 9
	int 31h
	mov ds,wStk16
	mov word ptr ds:[0],1000h
exit:
	popad
	ret

GetStack16 endp

if ?DOS4GMEM
Init4G proc stdcall public
	pusha
	push ds
	mov cx,1
	mov ax,0
	int 31h
	jc exit
	mov ds,cs:[wLdrDS]
	mov w4GSel,ax
	mov bx,0
	mov cx,1000h
	mov ax,501h
	int 31h
	jc exit
	mov word ptr dw4GHdl+0,di
	mov word ptr dw4GHdl+2,si
	mov dx,cx
	mov cx,bx
	mov bx,w4GSel
	mov ax,7
	int 31h
	mov dx,0FFFh
	xor cx,cx
	mov ax,8
	int 31h
	push es
	mov es,bx
	xor di,di
	mov cx,1000h/2
	xor ax,ax
	rep stosw
	pop es
exit:
	pop ds
	popa
	ret
Init4G endp
endif

_TEXT ends

_ITEXT segment

;--- this is called on initialization

InitPELoader proc stdcall public

	mov ds:[urCS],cs
if ?FLATDSEXPDOWN
	mov cx,2
else
	mov cx,1				;alloc 32 bit flat code selector
endif
	xor ax,ax
	int 31h
	jc exit
	mov bx,ax
	mov [wFlatCS],ax
	sub cx,cx
	sub dx,dx
	mov ax,7
	int 31h 				;set base of descriptor to 00000000
	dec cx
	dec dx
	mov ax,8
	int 31h 				;set limit to -1
	lar ecx,ebx
	shr ecx,8
	or ch,0C0h				;32Bit + BIG
	or cl,08h				;set code segment
	mov ax,9
	int 31h 				;set attribut of flat code desc
ife ?FLATDSEXPDOWN
	mov ax, 000ah			;now create an alias descriptor
	int 31h
	jc exit
	mov [wFlatDS],ax		;is a zero-based flat data descriptor
if ?32RTMBUG
	mov bx,ax
	lar ecx,eax 			;32RTM creates a 16-bit alias!!!!
	shr ecx,8
	or ch,40h
	mov ax,9
	int 31h
endif
else
	add bx, 8
	mov wFlatDS,bx
	sub cx,cx
	sub dx,dx
	mov ax,7				;set base
	int 31h
	dec cx
	dec dx
	lar eax,ebx
	shr eax,8
	or ah,0C0h				;set D bit + granularity bit
	test bEnvFlgs2,ENVFL2_EXPANDDOWN
	jz @F
	or al,4					;set expand down bit
	and ah,7Fh				;reset granularity bit
	mov dx,3ffh				;set limit of expand down
	inc cx					;cx==0
@@:
	push ax
	mov ax,8				;set limit
	int 31h
	pop cx
	mov ax,9				;set access rights
	int 31h
endif
	mov bx,cs
	mov ax,0006h
	int 31h 				;get base address of current CS
	mov word ptr [dwBase+0],dx
	mov word ptr [dwBase+2],cx
exit:
	ret
InitPELoader endp

_ITEXT ends
_TEXT segment

DeinitPELoader proc stdcall public
	mov ax,1
if ?DOS4GMEM
	mov bx,w4GSel
	and bx,bx
	jz @F
	int 31h
	push ax
	mov di, word ptr dw4GHdl+0
	mov si, word ptr dw4GHdl+2
	mov ax,0502h
	int 31h
	pop ax
@@:
endif
	mov bx,[wFlatCS]
	and bx,bx
	jz @F
	int 31h
@@:
	mov bx,[wFlatDS]
	and bx,bx
	jz @F
	int 31h
@@:
	mov bx,[wStk16]
	and bx,bx
	jz @F
	int 31h
;;@@:
	mov di,word ptr dwStkHdl+0
	mov si,word ptr dwStkHdl+2
if 0								;0 is a valid dpmi handle!
	mov cx,di
	or cx,si
	jcxz @F
endif
	mov ax,0502h
	int 31h
@@:
	ret
DeinitPELoader endp

;--- input: ESI=MZHDR

savepathPE proc uses es esi

	mov es, cs:[wLdrDS]
	mov di, offset szPath
	mov edx, [esi.MZHDR.pExeNam - sizeof MZHDR]
	lea esi, [esi+edx - sizeof MZHDR]
savepath0:
	mov dx,di
savepath1:
	lods byte ptr [esi]
	stosb
	cmp al,'\'
	jz savepath0
	cmp al,'/'
	jz savepath0
	and al,al
	jnz savepath1
	mov di,dx
	stosb
	@printf <"savepathPE: szPath=%S",lf>, offset szPath
	ret
savepathPE endp

_TEXT ends

	end
