
	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
DGROUP group _TEXT
endif
	option casemap:none
	option proc:private

	include winbase.inc
	include dkrnl32.inc
	include macros.inc

	option dotname

?CHECKHDPMI	equ 1	;std=1, HDPMI can emulate "mov eax,cr2"                    
?INITMEM	equ 0	;1=init memory to a defined value
?TLSOFS		equ 88h	;win9x compatible offset in TIB for TLS slots
?CLEARTIB	equ 1	;clear TIB on init

TIBSEG segment use16
TIBSEG ends
	assume fs:TIBSEG	;declare FS=TIB a 16 bit segment (saves space)

ifdef ?OMF
	public __KERNELINIT
__KERNELINIT equ 12345678h
.BASE$	segment dword public 'DATA'
	dd offset __kernel32init
.BASE$	ends
DGROUP	group .BASE$
endif

.BASE$I		segment dword public 'DATA'
startinit	label byte
.BASE$I		ends	
.BASE$IZ	segment dword public 'DATA'
endinit		label byte
.BASE$IZ	ends	
.BASE$X		segment dword public 'DATA'
startdeinit	label byte
.BASE$X		ends	
.BASE$XZ	segment dword public 'DATA'
enddeinit	label byte
.BASE$XZ	ends	

ifdef ?OMF
CONST segment dword public 'CONST'
CONST ends
ife ?FLAT
DGROUP  group CONST, _DATA, .BASE$I, .BASE$IZ, .BASE$X, .BASE$XZ
else
DGROUP  group CONST, .BASE$I, .BASE$IZ, .BASE$X, .BASE$XZ
endif
endif

DeinstallDebugLog proto

	.DATA

;--- about the g_dwRefCnt variable:

;--- When running with DPMILDR=8 on HDPMI this has no meaning at all
;--- because each process will run in its own address space.

;--- else, when DPMILD32=8 is not set or HDPMI is not running:
;--- if Win32 functions are used to start a process this should also
;--- have no meaning, because CreateProcess() uses the loader API
;--- int 21h, ax=4b92h to reset/restore the module list. This results in
;--- a new copy of DKRNL32.DLL being loaded (into the same address space)
;--- for the new process.

if ?FLAT
g_dwRefCnt DD 0
endif

ife ?FLAT
g_oldint21 df 0
else
  if ?HOOKINT21
g_oldint21 df 0
  endif
endif
	align 4

g_indosaddr dd 0	;linear address of indos flag
g_dwFlags	dd 0	;global DKRNL32 flags (environment variable)
g_bIsActive	db 0	;is this kernel32 instance active?
g_bIntFl	db 0	;internal flags
g_bHost		db 0	;DPMI host
g_bDPMICap	db 0	;DPMI host capabilities (from int 31h, ax=0401h)
g_wPics     dw 0    ;HIBYTE=master, LOBYTE=slave PICs mapping

;--- g_bDPMICap
;--- 01: PTE dirty/accessed bits get/set supported

ife ?FLAT
	.DATA?
tib	THREAD_INFORMATION_BLOCK <>
	db (?TLSOFS + ?TLSSLOTS*4 + sizeof CONTEXT) - sizeof THREAD_INFORMATION_BLOCK dup (?)
endif

	.CODE

;--- this code is called by DllMain, PROCESS_ATTACH/DETACH
;--- and will call all constructors / destructors located
;--- in .BASE$I / .BASE$X

externdef g_defaultregistration:near

	assume gs:nothing

ife ?FLAT

extern	_USESEH:abs	;ensure SEH is included

_heapset proto c

endif

if ?HOOKINT21

;-- int 21h hook.

;-- handle AH=4Bh - required if module wasn't loaded by DPMILD32.

myint21x proc	;used if IKF_PELDR == 0
	cmp ah,4Bh
	jz int214b
	align 4
myint21x endp	;fall thru

myint21 proc	;used if IKF_PELDR == 1
	cmp ah,4Ch
	jz int214c
int21default::
	stc
	jmp cs:[g_oldint21]
	align 4
myint21 endp

int214b proc
	cmp cs:[g_bIsActive],1
	jnz int21default
	cmp al,80h
	jb int21default
	xor eax,eax
	or dword ptr [esp+8],1	;set CF = 1
	iretd
	align 4
int214b endp

int214c proc
	cmp cs:[g_bIsActive],1
	jnz int21default
	pushad
	mov ah,51h
	int 21h
	mov eax,fs
	verw ax
	jnz notme
	mov esi,fs:[THREAD_INFORMATION_BLOCK.pProcess]
	cmp bx,cs:[esi].PROCESS.wPSP
	jnz notme
	mov ds, cs:[g_csalias]
	or byte ptr [esi].PROCESS.wFlags, PF_TERMINATING
if ?FLAT
	mov edx, [esi].PROCESS.hThread
	push gs
	mov gs, [edx].THREAD.dwTibSel
	mov ebx, gs:[THREAD_INFORMATION_BLOCK.pvStackUserTop]
	pop gs
	and ebx,ebx
	jz notme
	sub ebx,5*4			;IRET frame + 2 dwords
	mov [esp+18h],ebx	;set it in ECX
	popad
	push ds
	pop ss
	mov esp, ecx
	test [g_bIntFl],IKF_CALLTERM
	jz @F
else
	popad
endif
	push ds
	pop es
	call __kernel32exit
@@:
if ?FLAT
;-- for PE, run the exit code on the application stack
;-- this is the one stack valid all the time and
;-- it is released by DPMILD32 *after* all dlls are unloaded

	jmp int21default
@@:
endif
notme:
	popad
	jmp int21default

int214c endp

endif

;*** init a THREAD object ***

_initializethread proc public

	xor ecx,ecx
	mov [eax].THREAD.dwType, SYNCTYPE_THREAD
	mov [eax].THREAD.pNext,eax
	mov [eax].THREAD.flags,cl
	mov [eax].THREAD.dwExitCode,STILL_ACTIVE
;;	mov [eax].THREAD.pvExcept,offset g_defaultregistration
;;	mov [eax].THREAD.errno,ecx
	mov [eax].THREAD.bBoosted,cl
	mov [eax].THREAD.bSuspended,cl
	mov [eax].THREAD.bPriority, THREAD_PRIORITY_NORMAL
	ret
	align 4

_initializethread endp

InitProcess proc uses esi edi ebx

	inc g_bIsActive

;--- get selector for FS

	mov cx,0001 	  ;get 1 selector
	xor eax,eax
	int 31h
	jc fatal_exit
ife ?FLAT
	push eax

	mov ebx,ds
	mov ax,0006
	int 31h
	push cx
	push dx
	pop edx
	add edx,offset tib	;tib linear address

	pop ebx


	lea eax, [esp+32+4*4+4]
	mov esi, eax
	sub eax, edi
	mov edi, eax
	push cs			;hModule in segmented model
	push offset tib	;save TIB address
else
	mov ebx,eax		;ebx == FS 
	xor edx,edx

	mov eax,[ebp+1Ch]	;get org EAX
;	mov ax,4B82h	;get module handle
;	int 21h

	mov esi, esp
	add esi, 4096-1
	and si, 0F000h	;esi == stack top

	mov edx, [eax].IMAGE_DOS_HEADER.e_lfanew
	add edx, eax
	mov edx, [edx].IMAGE_NT_HEADERS.OptionalHeader.SizeOfStackReserve
	mov edi, esi
	sub edi, edx	;edi == stack bottom

	lea edx, [edi-2000h]	;edx=TIB

	push eax			;save hModule
	push edx			;save TIB address
endif
	push edx
	pop dx
	pop cx
	mov ax,0007		;set base of TIB selector
	int 31h
	mov dx,1000h-1
	xor ecx,ecx
	mov ax,0008
	int 31h
if ?CLEARTIB
	push edi
	mov edi,[esp+4]
	mov ecx,(?TLSOFS + ?TLSSLOTS*4 + sizeof CONTEXT) / 4
	xor eax,eax
	rep stosd
	pop edi
endif
	mov fs,ebx
	mov fs:[THREAD_INFORMATION_BLOCK.pvExcept], offset g_defaultregistration
	pop fs:[THREAD_INFORMATION_BLOCK.ptibSelf]
	mov fs:[THREAD_INFORMATION_BLOCK.pvStackUserBase], edi
	mov fs:[THREAD_INFORMATION_BLOCK.pvStackUserTop], esi

	invoke KernelHeapAlloc, sizeof PROCESS	;allocs a zerod block
	and eax, eax
	jz fatal_exit
	@strace <"process handle ", eax, " allocated">
	mov fs:[THREAD_INFORMATION_BLOCK.pProcess], eax
	mov [eax].PROCESS.dwType, SYNCTYPE_PROCESS
	pop [eax].PROCESS.hModule
;	mov [eax].PROCESS.pHeap, NULL
;	mov [eax].PROCESS.pCmdLine, NULL
	test [g_bIntFl],IKF_PELDR	;modules supported?
	jz @F
	mov [eax].PROCESS.wFlags, PF_LOCKED
@@:
	invoke KernelHeapAlloc, sizeof THREAD
	and eax,eax
	jz fatal_exit
	@strace <"default thread handle ", eax, " allocated">
	call _initializethread
	mov fs:[?LERROROFS],ecx
if ?GBLCURRENT		  
	mov [g_hCurThread],eax
endif
	mov [eax].THREAD.dwTibSel, fs
	mov edx, fs:[THREAD_INFORMATION_BLOCK.pProcess]
	mov [edx].PROCESS.hThread, eax
	mov ecx, fs:[THREAD_INFORMATION_BLOCK.pvStackUserBase]

;--- DPMILD32 has uncommitted the page below the reserved part of the stack
;--- adjust this to get the true stack handle

if ?FLAT
	sub ecx, 2000h
endif
	mov [eax].THREAD.hStack, ecx

	test [g_bIntFl],IKF_PELDR
	jz @F
	mov ecx,[ebp+14h]	;get value of EDX on entry
	mov ebx,[ebp+18h]	;start of module list in ECX
	mov [edx].PROCESS.pModuleList, ebx
@@:

;--- add the stack region to the memory regions so VirtualQuery knows it.
;--- give it a DPMI handle of -1 so it isn't released on exit

	mov edx, fs:[THREAD_INFORMATION_BLOCK.pvStackUserTop]
	sub edx, ecx	;edx = true size of stack
	push eax
	invoke _AddMemoryRegion, -1, ecx, ecx, edx
	pop eax

	mov edx, [eax].THREAD.hStack
	add edx, ?TLSOFS
	mov fs:[THREAD_INFORMATION_BLOCK.pvTLSArray],edx
ife ?CLEARTIB
	mov edi, edx
	mov ecx, ?TLSSLOTS
	push eax
	xor eax, eax
	rep stosd
	pop eax
else
	add edi,?TLSSLOTS*4
endif
	mov [eax].THREAD.pContext, edi
	ret
fatal_exit:
	mov ax,4CFFh
	int 21h
	align 4

InitProcess endp

;--- this proc is called by DllMain of DKRNL32.DLL (PE)
;--- or by jmppm32.obj (MZ)
;--- in segmented model, ebp contains heap size allocated
;--- in flat model, eax contains hModule of current process 

__kernel32init proc public

	pushad
if ?FLAT
	mov ebp,esp
	inc g_dwRefCnt
	cmp g_dwRefCnt,1
	jz @F
	call InitProcess
	popad
	ret
@@:
endif
	mov [g_csalias],ds
ife ?FLAT
	mov [g_flatsel],gs
endif
	push es
	mov ah,34h
	int 21h
	movzx ebx,bx
	push ebx
	mov ebx,es
	mov ax,6
	int 31h
	push cx
	push dx
	pop ecx
	pop eax
	add eax,ecx
	mov [g_indosaddr],eax
	pop es
	mov ax,0400h
	int 31h
	mov g_wPics,dx

	call InitProcess

ife ?FLAT

	.if (ebp)
		mov ecx, ebp
		lea eax, [esp+32+4]
		mov edx, fs:[THREAD_INFORMATION_BLOCK.pProcess]
		mov [edx].PROCESS.pHeap, eax
		mov edx, HEAP_GROWABLE
		invoke _heapset
	.endif
endif

;--- hook int 21h

if ?HOOKINT21

	mov ah,51h
	int 21h
	mov eax, fs:[THREAD_INFORMATION_BLOCK.pProcess]
	mov [eax].PROCESS.wPSP, bx

	mov ax,0204h
	mov bl,21h
	int 31h
  if ?DPMI16
	movzx edx, dx
  endif
	mov dword ptr g_oldint21+0,edx
	mov word ptr g_oldint21+4,cx
	mov ecx, cs
	mov edx, offset myint21
	test [g_bIntFl],IKF_PELDR
	jnz @F
	mov edx, offset myint21x
@@:
	mov ax,0205h
	int 31h
endif
	invoke _GetEnvironmentVariableInt, CStr("DKRNL32")
	mov g_dwFlags, eax

;--- set g_bHost variable

	sub esp,128		;make room for int 31h, ax=0401h

	mov ax,3306h
	int 21h
	cmp bx,3205h		;NT, 2k, XP?
	mov al, HF_WINNT
	mov cl,DKF_USERTC
	jz set_host
	mov ax,1600h
	int 2Fh
	and al,7Fh
	mov al,HF_WIN9X
	jnz set_host
	mov cl,0
if ?CHECKHDPMI
	@loadesp edi
	mov ax,401h
	int 31h
	jc host_unknown
	mov g_bDPMICap, al
	cmp dword ptr [edi+2],"MPDH"
	jnz @F
	cmp word ptr [edi+6],"I"
	mov cl,DKF_FULLSTACK
	mov al,HF_HDPMI
	jz set_host
@@:
	cmp dword ptr [edi+2],"IMPD"
	jnz @F
	cmp dword ptr [edi+6],"ENO"
	mov cl,0
	mov al, HF_DPMIONE
	jz set_host
@@:
	cmp dword ptr [edi+2],"ESOD"
	jnz @F
	cmp word ptr [edi+6],"UM"
	mov cl,DKF_USERTC
	mov al, HF_DOSEMU
	jz set_host
@@:
host_unknown:
endif
	mov cl,0
	mov al,0
set_host:
	mov g_bHost,al
	or byte ptr [g_dwFlags],cl
	add esp, 128

	mov esi, offset startinit
	mov edi, offset endinit
	.while (esi < edi)
		lodsd
		.if (eax)
			call eax
		.endif
	.endw

if ?FLAT
	invoke initstaticTLS
endif
	popad
	ret

	align 4

__kernel32init endp

_FreeAllRegions proto

__kernel32exit proc public

	pushad
	@strace <"kernel32 termination started">
if ?FLAT
	dec g_dwRefCnt
	jnz nofinalterm
endif
	mov eax, [g_hCurThread]
	and eax, eax
	jz @F
	mov fs, [eax].THREAD.dwTibSel
@@:
	mov esi, offset enddeinit
	mov edi, offset startdeinit
	.while (esi > edi)
		sub esi, 4
		xor eax, eax	;v3.6: ensure the termination is called just once!
		xchg eax, [esi]
		.if (eax)
			@strace <"kernel32 termination: calling ", eax, " terminator">
			call eax
		.endif
	.endw
ife ?FLAT

	mov edx, dword ptr g_oldint21+0
	mov cx, word ptr g_oldint21+4
	mov bl, 21h
	mov ax, 0205h
	int 31h
else
  if ?HOOKINT21
	mov edx, dword ptr g_oldint21+0
	mov cx, word ptr g_oldint21+4
	mov bl, 21h
	mov ax, 0205h
	int 31h
  endif
endif
nofinalterm:
	invoke _FreeAllRegions	;--- free memory of current process
	invoke DeinstallDebugLog
	dec g_bIsActive
	mov eax, [g_hCurThread]
	.if (eax)
		push 0
		pop fs
		mov ebx, [eax].THREAD.dwTibSel
		mov ax,1
		int 31h
	.endif
	popad
	@strace <"kernel32 termination finished">
	ret

__kernel32exit endp

	end
