
;*** Thread support for DOS. This code only works if
;--- 1. server allows to switch stacks while on LPMS   or
;--- 2. trace flag is copied from LPMS to application stack

;--- Functions implemented here:
;--- CreateThread
;--- GetExitCodeThread, GetCurrentThreadId
;--- ResumeThread, SuspendThread
;--- TerminateThread, ExitThread
;--- new instances for g_dwIdleProc

	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
DGROUP group _TEXT 	   
endif
	option casemap:none
	option proc:private
	option dotname

	include winbase.inc
	include dpmi.inc
	include dkrnl32.inc
	include macros.inc

TIBSEG segment use16
TIBSEG ends
	assume fs:TIBSEG	;declare FS=TIB a 16 bit segment (saves space)

ifdef _DEBUG
?TRACE      = 1			;1=display thread switches in text window
else
?TRACE      = 0
endif

?INITIALSTACKSPACE	equ 18000h-1000h	;default stack size for threads

?VERBOSE		equ 1	;std=1, 1=log more messages in debug version
?FLOATSAVE		equ 1	;std=1, 1=save FPU state for each thread
?DISABLETHREADS	equ 0	;std=0, 1=disable thread support
?IDLECHECK		equ 1   ;std=1, 1=giveup timeslice if all threads are blocked
?BOOST			equ 1	;std=1, 1=boost threads

?TLSOFS			equ 88h	;std=88h, offset in TIB to the TLS slots (win9x compat)

if ?FLAT
?MODULENOTIFY	equ 1	;std=1, 1=send DLL_THREAD_ATTACH/DETACH msgs
else
?MODULENOTIFY	equ 0	;std=0 (there are no dlls in non-flat models)
endif

?CALLOLDINT08 = 1		;std=1, 1=call previous irq 0 handler
?NOBOOSTSLEEP = 0		;std=0, 1=???
?TRAPDOS    = 1         ;std=1, 1=watch dos int 21
?USEHEAP    = 0			;std=0, 1=use LocalAlloc to alloc thread stack
						;       0=use VirtualAlloc to alloc thread stack
?HDPMISPEC	= 1			;std=1, 1=use hdpmi special feature
?OWNSTACK	= 0			;std=0, 1=dispatcher uses its own stack
?SMOOTH		= 1			;std=1, 1=divide read/write into smaller chunks
?BLKSIZE	equ 8000h	;std=8000h, chunk size if ?SMOOTH==1
?PROTCONTEXT = 1		;std=1, 1=protect context
?SAVEFLAGS   = 0        ;std=0, 1=save eflags in handler (hdpmi only)
?INITMEM     = 0		;std=0, 1=initialize mem
?SETINT01    = 0		;std=0, 1=set int 01 if exc 01 is set
?CHECKCS	= 1			;std=1, 0=always dispatch, dont check CS


;--- g_bDispatchFlag values

FTI_INIT 	equ 1	;1=dispatcher is initialized
if ?DIRECTDISP
FTI_DIRDISP	equ 2	;0=use exception 01
					;1=dispatch directly in IRQ 0 routine

?WIN9XDIRECT = 0	;std=0, 1=dispatch without exc 01 for win9x
					;(does not work anymore)

;--- HDPMI/WIN9X LPMSTOP

HXLPMSTOP struct
		IRETDS <>
_EipPms	dd ?
_CsPms	dd ?
HXLPMSTOP ends

else
?WIN9XDIRECT = 0	;std=0, ?DIRECTDISP==0
endif                

@getcurrentthread macro        
if ?GBLCURRENT
	mov eax, [g_hCurThread]
else
	mov eax, fs:[THREAD_INFORMATION_BLOCK.pProcess]
	mov eax, [eax].PROCESS.hThread
endif
	endm
        
@dbgentry macro vers
ifdef _DEBUG
	push ds
	mov ds,cs:[g_csalias]
	mov byte ptr ds:[4ffh],vers
	pop ds
endif
	endm
        
.BASE$XC segment dword public 'DATA'
		dd offset deinit
.BASE$XC ends

	.DATA

externdef   g_dwGetLastError:dword
externdef   g_dwSetLastError:dword

_initializethread proto stdcall

if ?CLEARHIGHEBP
OrgExc01	PF16 0
if ?SETINT01 
OrgInt01	PF16 0
endif
else
OrgExc01	PF32 0
if ?SETINT01
OrgInt01	PF32 0
endif
	align 4
endif

if ?USERTC
g_hDispTimer	dd 0
else
  if ?CLEARHIGHEBP
OrgIrq00	PF16 0
  else
OrgIrq00	PF32 0
	align 4
  endif
endif

if ?DIRECTDISP
externdef g_dwDispProc:dword
endif

if ?TRAPDOS
g_DosMutex	dd 0	;store thread which owns DOS mutex here
  if ?CLEARHIGHEBP
OrgInt21	PF16 0
  else
OrgInt21	PF32 0
  endif
g_bDosFree	db 1
  ife ?USEINDOS
g_bDosUsed	db 0
  endif
endif

	align 4

;--- bit 0: 1=dispatch request occured
;--- bit 1: 1=don't accept further dispatch requests

if ?IDLECHECK
g_dwLastTicks	dd 0
g_dwIdleTicks	dd 0
g_bCallIdle		db 0
endif

if ?TRACE
trcScrnPos	dd 0B8000h
endif

	.data?

g_dwSavedBoostProc dd ?
g_dwSavedIdleProc dd ?	;contains former content of g_dwIdleProc when threads are active

if ?OWNSTACK
g_OldDS	dd ?
		db 400h-sizeof CONTEXT_CTRL dup (?)
endif        
g_ConCtrl	CONTEXT_CTRL <>
endofstack	label dword

	.CODE

externdef g_defaultregistration:near

Dispatchprocs proc

if ?DIRECTDISP
;----- if server supports this, we simply dispatch here in ISR
;----- this will switch away from LPMS, which some host dont like at all
;----- that's why it is restricted to be used in HDPMI (+WIN9X?) only

;----- currently there is no longer a switch from LPMS since it seems to
;----- be not stable, even in HDPMI.

  if ?HDPMISPEC
hxdispproc::
win9xdispproc::
if ?TRACE
	call trace2
endif
if ?CHECKCS
	cmp esp,1000h - (sizeof HXLPMSTOP)
	jnz nolpms2
	push eax
	mov eax, ss
	lsl eax, eax
	cmp eax, 0FFFh		;is it the LPMS?
	jnz nolpms
	mov eax,cs
	cmp ax,word ptr [esp+1*4].HXLPMSTOP._CsPms	;is a client CS on TOP?
	jnz nodisp
else
	push eax
endif
	mov eax, [esp+1*4].HXLPMSTOP._EipPms

	push ds
	mov ds, cs:[g_csalias]
	mov [esp+2*4].HXLPMSTOP._EipPms,offset calldispatch2
	mov g_ConCtrl.rEip, eax
	mov g_bDispReq,1+2
ife ?CHECKCS   
	mov eax, cs
	xchg eax, [esp+2*4].HXLPMSTOP._CsPms
	mov g_ConCtrl.SegCs, eax
endif
if ?SAVEFLAGS
	mov eax, [esp+2*4].HXLPMSTOP.rEflags
	mov g_ConCtrl.EFlags, eax
;	and byte ptr [esp+2*4].HXLPMSTOP.rEflags+1,not 2	;clear IF
	and byte ptr [esp+2*4].HXLPMSTOP.rEflags+1,not 1	;clear TF
endif
	pop ds
nolpms:
nodisp:
	pop eax
nolpms2:
	sti
	@iret
	align 4
  endif
endif
Dispatchprocs endp

ife ?USERTC

;--- standard is now to use the RTC for dispatch signals
;--- the RTC is maintained by the timer code
;--- optionally the dispatcher may use IRQ 0, but the interval
;--- of about 55 ms is too long

irq0default:        
	jmp cs:[OrgIrq00]
	align 4

irq00 proc

	cmp cs:[g_bIsActive],1		;kernel32 active?
	jb irq0default

if ?CALLOLDINT08
	@pushf
	call cs:[OrgIrq00]
else
 ife ?FLAT
	push @flat
	mov @flat,cs:[g_flatsel]
 endif
	inc dword ptr @flat:[46ch]
 ife ?FLAT
	pop @flat
 endif
	push eax
	mov al,20h
	out 20h,al
	pop eax
endif
if ?TRACE
	call trace2
endif
	jmp _DispatchRequest
	align 4
irq00 endp
endif

if ?TRAPDOS

GetDosMutex proc uses ds eax ebx

	mov ds,cs:[g_csalias]
newtry:
	dec [g_bDosFree]		;serialize the following code
	jz @F
newtry2:
	inc [g_bDosFree]
	call _idleproc
	jmp newtry
	align 4
@@:
	@getcurrentthread

	cmp g_DosMutex, 0		;DOS mutex free?
	jz @F
	cmp eax, g_DosMutex		;DOS mutex owned by this thread?
	jnz newtry2
@@:
	mov g_DosMutex, eax
	inc g_bDosFree

if ?USEINDOS
	mov ebx, [g_indosaddr]
endif
nexttry:
if ?USEINDOS
  ife ?FLAT
	push @flat
	mov @flat,[g_flatsel]
  endif
	cmp byte ptr @flat:[ebx],0
  ife ?FLAT
	pop @flat
  endif
else
	cmp [g_bDosused],0
endif
	jz dos_is_free
	call _idleproc
	jmp nexttry
dos_is_free:
  ife ?USEINDOS
	mov [g_bDosused],1
  endif
	ret
	align 4
GetDosMutex endp

;--- dont modify flags here!!!

ReleaseDosMutex proc
	push ds
	mov ds,cs:[g_csalias]
	mov g_DosMutex, 0
ife ?USEINDOS
	mov [g_bDosused],0
endif
	pop ds
	ret
	align 4
ReleaseDosMutex endp

myint21 proc

	cmp cs:[g_bIsActive],1		;kernel32 active?
	jb defaultint21
if ?SMOOTH
	cmp ah,3Fh
	jz readfile
	cmp ah,40h
	jz writefile
endif
	cmp ah,4ch
	jz @F
	cmp ah,1ah
	jz int211a
dos_nohook:
	call GetDosMutex
@@:
	stc
	@pushf
	call cs:[OrgInt21]
	call ReleaseDosMutex
dosdone:
	push eax
	push ebp
	lahf
	mov ebp,ss
	lar ebp,ebp
	test ebp,400000h
	mov ebp,esp
	jnz @F
	movzx ebp,bp
@@:
	mov byte ptr [ebp+2*4].IRETDS.rEflags,ah
	pop ebp
	pop eax
	cmp cs:[g_bDispReq],0
	jnz @F
	@iret
	align 4
@@:
	call calldispatch3
	@iret
	align 4
defaultint21:
	jmp cs:[OrgInt21]
	align 4

;--- dont release the dos mutex for Int 21h, ah=1A (Set DTA)

int211a:
	call GetDosMutex
	@pushf
	call cs:[OrgInt21]
	jmp dosdone

if ?SMOOTH
	align 4
writefile:
readfile:
	push ecx
	push edx
	push esi
	push edi
	push ebp
	mov ebp, eax
	mov esi, ecx
	xor edi, edi
	.repeat
		mov ecx, esi
		cmp ecx, ?BLKSIZE
		jbe @F
		mov ecx, ?BLKSIZE
@@:
		mov eax, ebp
		@pushf
if ?CLEARHIGHEBP
		push word ptr cs
		push LOWWORD(offset @F)
		jmp dos_nohook
@@:
else
		push cs
		call dos_nohook
endif
		jc rdwrerr
		add edi, eax
		cmp eax, ecx
		jnz rdwrdone
		add edx, ?BLKSIZE
		sub esi, ecx
		je rdwrdone
	.until 0
rdwrdone:
	mov eax, edi
	clc
rdwrerr:
	pop ebp
	pop edi
	pop esi
	pop edx
	pop ecx
	jmp dosdone
endif

	align 4
myint21 endp

endif

;--- exception 01 handler. change CS:EIP to our dispatcher
;--- but dont simulate a PUSH on the client's stack!
;--- ints are disabled!

myexc01 proc
	push ebp
if ?CLEARHIGHEBP
	movzx ebp, sp
else
	mov ebp, esp
endif
	push eax
	test cs:g_bDispReq,1	;dispatch request?

;--- routing the exception to previous handler may be dangerous
if 0
	jz defexc01		;no, route to previous handler
else
	jz exit2			;clear TF and exit
endif

if 1
;--- assume that dispatch is only secure if CS=FLAT
	mov eax,cs
	cmp ax,word ptr [ebp+4].DPMIEXC.rCS
	jnz exit2
endif
	push ds
	mov ds,cs:[g_csalias]
if ?CLEARHIGHEBP
	movzx eax,word ptr [ebp+4].DPMIEXC.rEip
	mov [ebp+4].DPMIEXC.rEip, LOWWORD(offset calldispatch1)
else
	mov eax,[ebp+4].DPMIEXC.rEip
	mov [ebp+4].DPMIEXC.rEip, offset calldispatch1
endif
	mov g_ConCtrl.rEip, eax
	mov g_bDispReq,1+2
if ?CLEARHIGHEBP
	mov ax,[ebp+4].DPMIEXC.rCS
	mov word ptr [ebp+4].DPMIEXC.rCS, cs
else
	mov eax,[ebp+4].DPMIEXC.rCS
	mov [ebp+4].DPMIEXC.rCS, cs
endif
	mov g_ConCtrl.SegCs, eax
if ?CLEARHIGHEBP
	mov ax,word ptr [ebp+4].DPMIEXC.rEflags
else
	mov eax,[ebp+4].DPMIEXC.rEflags
endif
	and ah,not 1		;reset TF
	mov g_ConCtrl.EFlags, eax
if ?OWNSTACK
	pop eax
	mov g_OldDS, eax
	mov ds, eax
else
	pop ds
endif

;--- reseting the IF should work in any case - it is the virtual IF
;--- for this VM

	and byte ptr [ebp+4].DPMIEXC.rEflags+1, not 2	;reset IF
exit2:
	and byte ptr [ebp+4].DPMIEXC.rEflags+1, not 1	;reset TF
	pop eax
	pop ebp
if ?CLEARHIGHEBP
	db 66h
endif
	retf			  ;terminate dpmi exceptions with RETF
defexc01:
	pop eax
	pop ebp
	jmp cs:[OrgExc01]
	align 4
myexc01 endp

if ?SETINT01
myint01 proc
	iretd
	align 4
myint01 endp
endif

;--- call dispatcher synchronously

calldispatch3 proc

	@dbgentry 3
  if ?OWNSTACK
	push ds
	mov ds,cs:[g_csalias]
	mov g_ConCtrl.rEsp,esp
	mov g_ConCtrl.SegSs,ss
	pop ds
	mov ss,cs:[g_csalias]
	mov esp,offset endofstack-2*4
  else
	push ss
	push esp
  endif   
	pushfd
	push cs
	push [esp+4*4]
	add dword ptr [esp+3*4],4
	jmp _dispatch
	align 4
calldispatch3 endp

if ?DIRECTDISP

;--- dispatcher is called "directly" for HDPMI

calldispatch2 proc
	@dbgentry 2
if ?OWNSTACK
	push ds
	mov ds,cs:[g_csalias]
	mov g_ConCtrl.rEsp,esp
	mov g_ConCtrl.SegSs,ss
	pop ds
	mov ss,cs:[g_csalias]
	mov esp,offset endofstack - 2*4
else
	push ss
	push esp
endif
if ?SAVEFLAGS
	push cs:g_ConCtrl.EFlags
else        
	pushfd
endif
ife ?CHECKCS
	push cs:[g_ConCtrl.SegCs]
else
	push cs
endif
	push cs:g_ConCtrl.rEip
	jmp _dispatch
	align 4
calldispatch2 endp

endif

;--- dispatcher is called with the help of an exception 01

calldispatch1 proc
	@dbgentry 1
if ?OWNSTACK
	mov ds,cs:[g_csalias]
	mov g_ConCtrl.rEsp,esp
	mov g_ConCtrl.SegSs,ss
	mov ss,[g_csalias]
	mov esp,offset endofstack-2*4
	sub g_ConCtrl.rEsp,4
	mov ds,g_OldDS
else
	push ss
	push esp
endif
	push cs:g_ConCtrl.EFlags
	push cs:g_ConCtrl.SegCs
	push cs:g_ConCtrl.rEip
	jmp _dispatch
	align 4
calldispatch1 endp

;--- dispatcher. will switch threads.
;--- expects ESP -> CONTEXT_CTRL (without ebp) 

_dispatch proc

	cli
	cld
	push ebp
if ?CLEARHIGHEBP
	movzx ebp,sp
else
	mov ebp, esp
endif
	add [ebp].CONTEXT_CTRL.rEsp,4
if 0
	verw word ptr [ebp].CONTEXT_CTRL.SegSs
	jz @F
	int 3
@@:
	verr word ptr [ebp].CONTEXT_CTRL.SegCs
	jz @F
	int 3
@@:
endif

;--- save current thread's context

if ?GBLCURRENT
	push cs:[g_hCurThread]
	call _SaveContext
else
	mov ebp, fs:[THREAD_INFORMATION_BLOCK.pProcess]
	push cs:[ebp.PROCESS.hThread]
	call _SaveContext
endif

if ?TRACE
	call trace1
endif

if 1
	mov eax, fs:[THREAD_INFORMATION_BLOCK.pProcess]
	test [eax].PROCESS.wFlags, PF_TERMINATING or PF_LOCKED
	jnz exit
endif        

if ?USERTC
	mov ecx, [g_hDispTimer]
  ifdef _DEBUG
	and ecx,ecx
	jz faterror   
  endif
  if ?MICROSECS
	mov dword ptr [ecx].TIMER.lCnt,?TIMESLICE*1000
  else
	mov [ecx].TIMER.lCnt,?TIMESLICE
  endif
endif

if ?GBLCURRENT
	mov esi, [g_hCurThread]
else
	mov eax, fs:[THREAD_INFORMATION_BLOCK.pProcess]
	mov esi, [eax].PROCESS.hThread
endif

if 1        
;--- this is a hack to prevent any thread switches
;--- when the hxguihlp menu is displayed
	cmp [esi].THREAD.bPriority, THREAD_PRIORITY_TIME_CRITICAL * 2 
	jge exit
endif

	mov edi, [esi].THREAD.pNext

;--- unlink suspended threads
;--- delete threads which are terminated and closed

	.while ([edi].THREAD.bSuspended)
		mov ebx, [edi].THREAD.pNext
		mov cl, [edi].THREAD.flags
		and cl, TF_CLOSED or TF_TERMINATED
		.if (cl == (TF_CLOSED or TF_TERMINATED))
;--- calling CloseHandle may be a problem if the kernel heap is locked
;--- so check if it is and if yes, skip this item in this turn
			invoke IsKernelHeapLocked
			and eax, eax
			jnz skipitem
			invoke CloseHandle, edi
		.endif
		and byte ptr [edi].THREAD.flags, not TF_LINKED
		mov [edi].THREAD.pNext, edi
		mov [esi].THREAD.pNext, ebx
skipitem:
		cmp edi, ebx			;no active threads remaining
		jz faterror 			;that's a fatal exit
		mov edi, ebx
	.endw

	cmp edi, esi				;is next thread = current thread
	jz exitdispatch				;then deactivate dispatcher


if 0
	mov ebx,[edi].THREAD.pNext
	.while (ebx != esi)
		mov al,[ebx].THREAD.bPriority
		.if ((sbyte ptr al > [edi].THREAD.bPriority) && (!([ebx].THREAD.bSuspended)) && (!([ebx].THREAD.flags & TF_WAITING)))
			mov edi, ebx
		.endif
		mov ebx, [ebx].THREAD.pNext
	.endw
endif

if ?IDLECHECK

;--- if thread to activate is waiting, check if all
;--- threads are currently waiting. if yes, enter pre-idle state

	mov eax, @flat:[46ch]
	.if ([edi].THREAD.flags & TF_WAITING)
		mov ecx, [edi].THREAD.pNext
		.repeat
			test [ecx].THREAD.flags, TF_WAITING
			jz is_not_idle
			mov ecx, [ecx].THREAD.pNext
		.until (ecx == edi)
		sub eax, g_dwLastTicks
		mov g_dwIdleTicks, eax
		jmp is_idle
	.endif
is_not_idle:
	mov g_dwLastTicks, eax
is_idle:
endif

if ?BOOST
	cmp [esi].THREAD.bBoosted,0 ;was last thread boosted?
	jz boost_done
	dec [esi].THREAD.bBoosted
if 1
	mov ecx, edi
@@: 							;get predecessor (simple list)
	mov ecx,[ecx].THREAD.pNext
	cmp esi,[ecx].THREAD.pNext
	jnz @B
								;now predecessor in ecx
	cmp ecx, edi
	jz boost_done				;do nothing if 2 threads only exists?
	mov edx,esi
	xchg edx,[edi].THREAD.pNext	;insert at new location
	xchg edx,[esi].THREAD.pNext
	mov [ecx].THREAD.pNext,edx	;delete at old location
  ifdef _DEBUG
	cmp ecx,[ecx].THREAD.pNext
	jnz @F
	int 3
@@:
  endif
else
	jmp exit
	align 4
endif
boost_done:        
endif        

;--- set new thread

if ?GBLCURRENT
	mov [g_hCurThread], edi
else
	mov eax, fs:[THREAD_INFORMATION_BLOCK.pProcess]
	mov [eax].PROCESS.hThread, edi
endif

dispatch_ex:

	and byte ptr [edi].THREAD.flags, not TF_WAITING
if ?IDLECHECK
	cmp g_dwIdleTicks, 8	;wait some ms until true idle 
	jc @F
	xor g_bCallIdle,1	;call the idle proc every 2. time only!
	jz @F
	mov edi, [edi].THREAD.pContext
	mov ecx, [edi].CONTEXT.rEip
	mov eax, [edi].CONTEXT.SegCs
	mov [edi].CONTEXT.rEip, offset myidleproc
	mov [edi].CONTEXT.SegCs, cs
	mov edx, ds
	lds esi, fword ptr [edi].CONTEXT.rEsp
	mov [esi-2*4],ecx
	mov [esi-1*4],eax
	mov ds, edx
	sub [edi].CONTEXT.rEsp, 2*4
@@:
endif
exit:
	mov g_bDispReq, 0
if ?GBLCURRENT
	push [g_hCurThread]
else
	mov eax,fs:[THREAD_INFORMATION_BLOCK.pProcess]
	push [eax].PROCESS.hThread
endif
	call _LoadContext	;won't return
exitdispatch:
	call DispatchExit	;then deactivate dispatcher
	jmp dispatch_ex
faterror:
	invoke RaiseException, ERROR_THREAD_1_INACTIVE, 0, 0, 0
	align 4

_dispatch endp

;--- todo: describe what this is supposed to do!

myidleproc proc
	pushfd
	pushad
if 0
	mov ax,1680h
	int 2Fh
else
	call cs:[g_dwSavedIdleProc]	;usually contains GiveupTimeSlice
endif
	popad
	popfd
	retf
	align 4
myidleproc endp

if ?TRACE

;*** trace: called by dispatch, all registers saved ***
;--- this routine will increase a number at the bottom line (the right one)
;--- whenever proc dispatch is called

trace1 proc
if ?FLAT
	mov ds,cs:[g_csalias]
else
	mov ds,cs:[g_flatsel]
endif
	mov cl,8
	mov ebx,cs:[trcScrnPos]
@@:
	inc byte ptr [ebx]
	cmp byte ptr [ebx],'9'
	jbe @F
	mov byte ptr [ebx],'0'
	dec ebx
	dec ebx
	dec cl
	jnz @B
@@:
	ret
	align 4
trace1 endp

;*** trace2: called by isr irq 00/08 ***
;--- this routine will increase a number at the bottom line (the left one)
;--- whenever proc irq 00/08 is called

trace2 proc
	push ds
	push ebx
	push ecx
if ?FLAT
	mov ds,cs:[g_csalias]
else
	mov ds,cs:[g_flatsel]
endif
	mov ebx,cs:[trcScrnPos]
	sub ebx,9*2
	mov cl,8
@@:
	inc byte ptr [ebx]
	cmp byte ptr [ebx],'9'
	jbe @F
	mov byte ptr [ebx],'0'
	dec ebx
	dec ebx
	dec cl
	jnz @B
@@:
	pop ecx
	pop ebx
	pop ds
	ret
	align 4
trace2  endp

;--- init trace: we do some screen output (2 numbers counting ?)


inittrace proc
	pushad
	movzx eax,byte ptr [VIOROWS]	;number of rows-1
	movzx ecx,word ptr [VIOCOLS]	;number of columns
	mul ecx
	dec ecx
	add eax,ecx
	shl eax,1
	add eax,0B8000h
	mov ds:trcScrnPos,eax
	mov ch,2
nextnum:
	mov cl,8
@@:
	mov byte ptr @flat:[eax],'0'
	dec eax
	dec eax
	dec cl
	jnz @B

	dec eax
	dec eax
	dec ch
	jnz nextnum

	popad
	ret
	align 4
inittrace endp
endif

if ?MODULENOTIFY
NotifyModule proc uses esi
	test [g_bIntFl],IKF_PELDR	;DPMILD32 active?
	jz done
	invoke GetCurrentProcess
	mov esi, [eax].PROCESS.pModuleList
nextitem:
	mov eax, [esi]
	and eax, eax
	jz done
	mov edx, eax
	add eax,[eax].IMAGE_DOS_HEADER.e_lfanew
	test [eax].IMAGE_NT_HEADERS.FileHeader.Characteristics, IMAGE_FILE_DLL
	jz @F
	test [eax].IMAGE_NT_HEADERS.OptionalHeader.DllCharacteristics, FKF_DISTHREADLIBCALLS
	jnz @F
	mov eax, [eax].IMAGE_NT_HEADERS.OptionalHeader.AddressOfEntryPoint
	and eax, eax
	jz @F
	add eax, edx
	push 0	;lpReserved (not used here)
	push ebx;DLL_THREAD_ATTACH/DLL_THREAD_DETACH
	push edx;hModule
	call eax
@@:
	add esi, 2*4
	jmp nextitem
done:
	ret
	align 4
NotifyModule endp        
endif

ife ?WIN9XDIRECT 
makeexc01working proc
	@noints
	mov edx,offset tmpexc01
	mov ecx,cs
	mov ax,0203h
	int 31h
	mov ecx,200000
	@loadesp edx
@@:
	pushfd
	or byte ptr [edx-3],1
	popfd
	loop @B
exctestdone:
	@restoreints
	ret
tmpexc01:
	and byte ptr [esp].DPMIEXC.rEflags+1,not 1
if ?CLEARHIGHEBP
	mov [esp].DPMIEXC.rEip, LOWWORD(offset exctestdone)
	db 66h
else
	mov [esp].DPMIEXC.rEip, offset exctestdone
endif
	retf
	align 4

makeexc01working endp
endif

;--- init dispatcher. hook IRQ 0, int 21 and exception 1

DispatchInit proc

	test [g_bDispatchFlags], FTI_INIT
	jz init
	ret
init:
	@strace <"DispatchInit enter">
	pushad
if ?DIRECTDISP
	.if (g_bHost == HF_HDPMI)
		mov g_dwDispProc, offset hxdispproc
		or [g_bDispatchFlags],FTI_DIRDISP
  if ?WIN9XDIRECT
	.elseif (g_bHost == HF_WIN9X)
		mov g_dwDispProc, offset win9xdispproc
		or [g_bDispatchFlags],FTI_DIRDISP
  endif
;	.elseif (g_bHost, HF_WINNT)	;does not work for xp
	.endif
endif

if ?TRAPDOS
	mov bl,21h
	mov ax,0204h
	int 31h
if ?CLEARHIGHEBP
	mov word ptr OrgInt21+0,dx
	mov word ptr OrgInt21+2,cx
else
	mov dword ptr OrgInt21+0,edx
	mov word ptr OrgInt21+4,cx
endif
	mov ecx,cs
	mov edx,offset myint21
	mov ax,0205h
	int 31h
endif

if ?DIRECTDISP
	test [g_bDispatchFlags],FTI_DIRDISP
	jnz @F
endif
	mov bl,01
	mov ax,0202h
	int 31h
if ?CLEARHIGHEBP
	mov word ptr OrgExc01+0,dx
	mov word ptr OrgExc01+2,cx
else
	mov dword ptr OrgExc01+0,edx
	mov word ptr OrgExc01+4,cx
endif
ife ?WIN9XDIRECT
	.if (g_bHost == HF_WIN9X)
		pushad
		invoke makeexc01working
		popad
	.endif
endif
	mov edx,offset myexc01
	mov ecx,cs
	inc al
	int 31h
if ?SETINT01
	.if (g_bHost == HF_WIN9X)
		mov bl,01
		mov ax,0204h
		int 31h
  if ?CLEARHIGHEBP
		mov word ptr OrgInt01+0,dx
		mov word ptr OrgInt01+2,cx
  else
		mov dword ptr OrgInt01+0,edx
		mov word ptr OrgInt01+4,cx
  endif
		mov edx,offset myint01
		mov ecx,cs
		inc al
		int 31h
	.endif
endif
@@:

if ?USERTC
	.if (!g_hDispTimer)
		invoke CreateWaitableTimer, 0, 0, 0
		and eax, eax
		jz exit
		mov [g_hDispTimer], eax
	.endif
	sub esp, sizeof FILETIME
	mov eax, 20*1000*10
	cdq
	not eax
	not edx
	mov [esp].FILETIME.dwLowDateTime, eax
	mov [esp].FILETIME.dwHighDateTime, edx
	mov ecx, 20
	mov edx, esp
	invoke SetWaitableTimer, [g_hDispTimer], edx, ecx, 0, 0, 0
	mov eax, [g_hDispTimer]
	mov [eax].TIMER.bDispatch,2
	lea esp, [esp+sizeof FILETIME]
else
	mov bl,byte ptr g_wPics+1
	mov ax,0204h
	int 31h
 if ?CLEARHIGHEBP
	mov word ptr OrgIrq00+0,dx
	mov word ptr OrgIrq00+2,cx
 else
	mov dword ptr OrgIrq00+0,edx
	mov word ptr OrgIrq00+4,cx
 endif
	mov ecx,cs
	mov edx,offset irq00
	mov ax,0205h
	int 31h
endif
	or [g_bDispatchFlags],FTI_INIT
	mov eax, offset _idleproc
	mov ecx, offset _boostproc
	xchg eax, g_dwIdleProc
	xchg ecx, g_dwBoostProc
	mov g_dwSavedIdleProc, eax
	mov g_dwSavedBoostProc, ecx
	mov g_bDispReq, 0
	mov g_bDosFree, 1
exit:
	popad
	@strace <"DispatchInit exit">
	ret
	align 4
DispatchInit endp

;*** deactivate dispatcher ***
;*** this is called with ints disabled 

DispatchExit proc uses ebx

	test [g_bDispatchFlags],FTI_INIT
	jz exit
	@strace <"DispatchExit enter">
	and [g_bDispatchFlags],not FTI_INIT
	mov eax, g_dwSavedIdleProc
	mov ecx, g_dwSavedBoostProc
	mov g_dwIdleProc,eax
	mov g_dwBoostProc, ecx

if ?USERTC
	.if (g_hDispTimer)
		invoke CancelWaitableTimer, g_hDispTimer
;		invoke CloseHandle, g_hDispTimer
;		mov g_hDispTimer, 0
	.endif
else
  if ?CLEARHIGHEBP
	mov dx,word ptr OrgIrq00+0
	mov cx,word ptr OrgIrq00+2
  else
	mov edx,dword ptr OrgIrq00+0
	mov cx,word ptr OrgIrq00+4
  endif
	mov bl,byte ptr g_wPics+1
	mov ax,0205h
	int 31h
endif

if ?DIRECTDISP
	test [g_bDispatchFlags],FTI_DIRDISP
	jnz @F
	and [g_bDispatchFlags],not FTI_DIRDISP
endif
if ?CLEARHIGHEBP
	mov dx,word ptr OrgExc01+0
	mov cx,word ptr OrgExc01+2
else
	mov edx,dword ptr OrgExc01+0
	mov cx,word ptr OrgExc01+4
endif
	mov bl,01
	mov ax,0203h
	int 31h
if ?SETINT01
	.if (g_bHost == HF_WIN9X)
  if ?CLEARHIGHEBP
		mov dx,word ptr OrgInt01+0
		mov cx,word ptr OrgInt01+2
  else
		mov edx,dword ptr OrgInt01+0
		mov cx,word ptr OrgInt01+4
  endif   
		mov bl,01
		mov ax,0205h
		int 31h
	.endif
endif
@@:

if ?TRAPDOS
if ?CLEARHIGHEBP
	mov cx,word ptr OrgInt21+2
	mov dx,word ptr OrgInt21+0
else
	mov cx,word ptr OrgInt21+4
	mov edx,dword ptr OrgInt21+0
endif
	mov bl,21h
	mov ax,0205h
	int 31h
endif

	@strace <"DispatchExit exit">
exit:
	ret
	align 4
DispatchExit endp

;*** insert thread in thrd list
;--- handle in eax
;--- called by ResumeThread
;--- eax remains unchanged

AddThreadToList proc

	@noints
if ?GBLCURRENT
	mov edx, g_hCurThread
else
	mov edx, fs:[THREAD_INFORMATION_BLOCK.pProcess]
	mov edx, [edx].PROCESS.hThread
endif
	mov [eax].THREAD.pNext,edx
	mov ecx, edx
	.while ([ecx].THREAD.pNext != edx)
		mov ecx, [ecx].THREAD.pNext
	.endw
	mov [ecx].THREAD.pNext,eax
ifdef _DEBUG
	cmp ecx,[ecx].THREAD.pNext
	jnz @F
	int 3
@@:
endif
	or [eax].THREAD.flags, TF_LINKED
	@restoreints
	ret
	align 4

AddThreadToList endp

;--- ends a thread
;--- inp: eax = exitcode

EndThread proc
if ?MODULENOTIFY
	push eax
	push ebx
	mov ebx, DLL_THREAD_DETACH
	invoke NotifyModule
	pop ebx
	pop eax
endif
if ?GBLCURRENT
	mov esi,[g_hCurThread]
else
	mov esi,fs:[THREAD_INFORMATION_BLOCK.pProcess]
	mov esi, [esi].PROCESS.hThread
endif
	@strace <"EndThread(): current thread=", esi, " ESP=", esp, " exitcode=", eax>
	and esi, esi
	jz exit
	mov [esi].THREAD.dwExitCode,eax
	or byte ptr [esi].THREAD.flags,TF_TERMINATED
	.if (esi == g_DosMutex)
		mov g_DosMutex, 0
	.endif
if 1
	mov [esi].THREAD.bSuspended,1
	call calldispatch3
else
	invoke SuspendThread, esi
endif
exit:        
	invoke ExitProcess, eax
	align 4
EndThread endp

;--- win32 API function ExitThread

	option prologue:none

ExitThread proc public dwExitCode:dword
	pop eax		;throw away return address
	pop eax
	@strace	<"ExitThread(", eax, ")">
	jmp  EndThread
	align 4
ExitThread endp

if ?FLAT
FreeLibraryAndExitThread proc public hModule:dword, dwExitCode:dword
	pop eax		;throw away return address
ifdef _DEBUG
	mov ecx, [esp+0]
	mov edx, [esp+4]
	@strace	<"FreeLibraryAndExitThread(", ecx, ", ", edx, ")">
endif
;---- hModule now at [esp]		  
	call FreeLibrary
	pop eax 	;dwExitCode -> eax
	jmp EndThread
	align 4
FreeLibraryAndExitThread endp
endif

	option prologue:prologuedef

;*** boost thread in EAX (0 == current thread)
;--- this routine may be called during interrupt time, SS is unknown
;--- if it is the current, modify bBoosted
;--- else make it the next thread to be scheduled and, if it is
;--- "real-time", reduce current thread's time-slice to the minimum.

;--- this proc may be called during interrupt time
;--- when SS might be NOT flat!
;--- also don't modify IF!

_boostproc proc
	.if (eax)
if ?GBLCURRENT
		mov ecx, [g_hCurThread]
else
		mov ecx, fs:[THREAD_INFORMATION_BLOCK.pProcess]
		mov ecx, [ecx].PROCESS.hThread
endif
		cmp ecx, eax
		jz done

;--- if thread is not linked (TF_LINKED==0), nothing will happen			

		@noints
		mov edx, [ecx].THREAD.pNext
		cmp eax, edx
		jz found
		.while (ecx != edx)
			.if (eax == [edx].THREAD.pNext)
				push [ecx].THREAD.pNext
				mov [ecx].THREAD.pNext, eax	;make thread the next one
				mov ecx, [eax].THREAD.pNext
				pop [eax].THREAD.pNext
				mov [edx].THREAD.pNext, ecx	;and delete at old place
				jmp found
			.endif
			mov edx, [edx].THREAD.pNext
		.endw
		jmp notfound
found:
 if ?USERTC
		.if ([eax].THREAD.bPriority == THREAD_PRIORITY_TIME_CRITICAL)
			mov ecx, [g_hDispTimer]
  if ?MICROSECS
			mov dword ptr [ecx].TIMER.lCnt,1
			mov dword ptr [ecx].TIMER.lCnt+4,0
  else
			mov [ecx].TIMER.lCnt,1
  endif
		.endif
 endif 
notfound:
		@restoreints
	.else
		@getcurrentthread
		cmp [eax].THREAD.bBoosted,9	;20
		jae @F
		add [eax].THREAD.bBoosted,3	;4
@@:
	.endif
done:
	ret
	align 4
_boostproc endp

;--- do not modify any registers except EAX here!
;--- DS is set, but SS is unknown

_idleproc proc

	@getcurrentthread
	and ecx, TF_WAITING
	or [eax].THREAD.flags, cl
if ?NOBOOSTSLEEP
	cmp [eax].THREAD.bBoosted,0
	jnz exit
else
;	mov [eax].THREAD.bBoosted,0	;thread is idle, reset boost
endif
	jmp calldispatch3
if ?NOBOOSTSLEEP        
exit:        
	ret
endif        
	align 4
_idleproc endp

;*** initialize a just created THREAD object
;*** here edi, esi, ebx may be modified
;*** in: ebx=TIB selector
;*** Out: eax=hThread
;*** this call cannot fail!

InitThread proc uses esi edi hThread:DWORD, dwEip:DWORD, dwStackSize:DWORD, dwParm:DWORD, dwCreationFlags:DWORD

;	invoke _GetCurrentThread	 ;make sure there is already one
;								 ;thread
	mov edi, hThread
	mov [edi].THREAD.dwTibSel, ebx

	mov eax, edi
	call _initializethread
	mov [edi].THREAD.bSuspended, 1

	mov esi, [edi].THREAD.hStack
	push esi
	pop dx
	pop cx
	mov ax,7		;set base of TIB selector
	int 31h
	mov dx,1000h-1
	xor ecx, ecx
	mov ax,8
	int 31h		;set limit

	push edi
	mov edi,esi
	mov ecx,(?TLSOFS + ?TLSSLOTS*4 + sizeof CONTEXT) / 4
	xor eax,eax
	rep stosd
	pop edi

	mov [esi].THREAD_INFORMATION_BLOCK.pvExcept, offset g_defaultregistration
	mov [esi].THREAD_INFORMATION_BLOCK.ptibSelf, esi
	mov eax, fs:[THREAD_INFORMATION_BLOCK.pProcess]    
	mov [esi].THREAD_INFORMATION_BLOCK.pProcess, eax

if ?PROTCONTEXT

;--- stack structure:
;--- 0xxx: TIB, TLS, context
;--- 1xxx: uncommitted
;--- 2xxx: stack bottom

;	lea eax, [esi+2000h]
;	mov [esi].THREAD_INFORMATION_BLOCK.pvStackUserBase, eax 	   

;	sub eax, 1000h
;	invoke VirtualFree, eax, 1000h, MEM_DECOMMIT
else
;	lea eax, [esi+1000h]
;	mov [esi].THREAD_INFORMATION_BLOCK.pvStackUserBase, eax 	   
endif
	mov eax, dwStackSize
	add eax, [edi].THREAD.hStack
	mov [esi].THREAD_INFORMATION_BLOCK.pvStackUserTop, eax

	lea eax, [esi + ?TLSOFS]
	mov [esi].THREAD_INFORMATION_BLOCK.pvTLSArray, eax

	lea eax, [esi + ?TLSOFS + ?TLSSLOTS * 4]
	mov [edi].THREAD.pContext, eax

if ?FLOATSAVE
	mov edx, [edi].THREAD.pContext
	fnsave [edx].CONTEXT.FloatSave
endif
	mov [edx].CONTEXT.SegGs,gs
	mov [edx].CONTEXT.SegFs,ebx
	mov [edx].CONTEXT.SegEs,es
	mov [edx].CONTEXT.SegDs,ds
	mov [edx].CONTEXT.SegCs,cs
	mov [edx].CONTEXT.SegSs,ss
	pushfd
	pop [edx].CONTEXT.EFlags

	mov esi, [esi].THREAD_INFORMATION_BLOCK.pvStackUserTop
	sub esi,5*4
	mov eax, dwEip
	mov [esi+0],eax
	mov [esi+4],offset EndThread
	mov eax, dwParm
	mov [esi+8],eax
	mov [edx].CONTEXT.rEip, offset StartThread
	mov [edx].CONTEXT.rEsp,esi

	test dwCreationFlags, CREATE_SUSPENDED
	jnz @F
	invoke ResumeThread, hThread
@@:
	mov eax, hThread
	ret
	align 4
InitThread endp

if ?FLAT
initstaticTLSthread proto 
endif

StartThread proc
if ?FLAT
	invoke initstaticTLSthread
endif        
if ?MODULENOTIFY
	push ebx
	mov ebx, DLL_THREAD_ATTACH
	invoke NotifyModule
	pop ebx
endif
	ret
	align 4
StartThread endp

;--- Win32 API TerminateThread

TerminateThread proc public hThread:dword, dwExitCode:dword

	@strace <"TerminateThread(", hThread, ", ", dwExitCode, ")">
	xor eax,eax
	mov edx,hThread
	and edx,edx
	jz exit
	cmp [edx].THREAD.dwType, SYNCTYPE_THREAD
	jnz exit
	test [edx].THREAD.flags,TF_TERMINATED
	jnz exit
	mov eax, dwExitCode
if ?GBLCURRENT
	cmp edx, g_hCurThread
else
	mov ecx, fs:[THREAD_INFORMATION_BLOCK.pProcess]
	cmp edx, [ecx].PROCESS.hThread
endif
	jz EndThread					;it is current thread!
	mov [edx].THREAD.dwExitCode, eax
	or byte ptr [edx].THREAD.flags,TF_TERMINATED
	invoke SuspendThread, edx
	@mov eax, 1
exit:
	ret
	align 4
TerminateThread endp

;--- Win32 API SuspendThread

SuspendThread proc public hThread:dword

	or eax, -1			;failure is -1!
	mov ecx,hThread
	jecxz exit
	cmp [ecx].THREAD.dwType, SYNCTYPE_THREAD
	jnz exit
;	test [ecx].THREAD.flags,TF_TERMINATED
;	jnz exit
	movzx eax,[ecx].THREAD.bSuspended
	inc [ecx].THREAD.bSuspended
	.if (!eax)

;--- suspending the current thread locks process in Windows!
;--- and SuspendThread does not return
        
if ?GBLCURRENT        
		.if (ecx == g_hCurThread)
else
		mov edx, fs:[THREAD_INFORMATION_BLOCK.pProcess]
		.if (ecx == [edx].PROCESS.hThread)
endif
			invoke SwitchToThread
		.endif
	.endif
exit:
	@strace <"SuspendThread(", hThread, ")=", eax>
	ret
	align 4
SuspendThread endp

;--- Win32 API ResumeThread
;--- returns:
;--- -1: invalid handle
;--- 0: thread was not suspended (count was zero)
;--- 1: thread was restarted
;--- >1: thread still suspended

ResumeThread proc public hThread:dword

	or eax, -1 	;failure is -1!
	mov ecx,hThread
	jecxz @F
	cmp [ecx].THREAD.dwType, SYNCTYPE_THREAD
	jnz @F
	test [ecx].THREAD.flags,TF_TERMINATED
	jnz @F
	movzx eax,[ecx].THREAD.bSuspended
	and eax,eax
	jz @F
	dec [ecx].THREAD.bSuspended
	jnz @F
	test [ecx].THREAD.flags,TF_LINKED	;skip if it is still linked
	jnz @F
	push eax
	mov eax, ecx
	invoke AddThreadToList
	invoke DispatchInit	;does not modify std regs
	pop eax
@@:
	@strace <"ResumeThread(", hThread, ")=", eax>
	ret
	align 4
ResumeThread endp

;--- Win32 API CreateThread
;--- the lStack parameter is the COMMITTED stack size
;--- the reserved stack size is still the one stored in the MD

CreateThread proc public uses ebx edi esi attr:dword, lStack:dword,
			lpproc:dword, dwArgument:dword, dwCreationFlags:dword, pThreadId:dword

if ?FLAT
local	dwCommit:dword
endif

	@strace <"CreateThread(", attr, ", ", lStack, ", ", lpproc, ", ", dwArgument, ", ", dwCreationFlags, ", ", pThreadId, ")">
if ?DISABLETHREADS
	xor eax,eax
	jmp exit
endif

	invoke KernelHeapAlloc, sizeof THREAD
	and eax,eax
	jz exit						;EAX=hThread
	mov edi,eax
	mov dword ptr [edi-4], offset destructor

	mov esi,?INITIALSTACKSPACE
if ?FLAT
	mov ebx,1000h
	cmp g_bHost, HF_HDPMI
	jz @F
	test byte ptr g_dwFlags,DKF_FULLSTACK
	jz usedefs
@@:
	invoke GetModuleHandle, 0
	mov ecx, [eax].IMAGE_DOS_HEADER.e_lfanew
	add ecx, eax
	mov esi, [ecx].IMAGE_NT_HEADERS.OptionalHeader.SizeOfStackReserve
	mov ebx, [ecx].IMAGE_NT_HEADERS.OptionalHeader.SizeOfStackCommit
	cmp esi, 10000h
	jnc @F
	mov esi, 10000h
@@:
	cmp ebx, 1000h
	jnc @F
	mov ebx, 1000h
@@:
usedefs:
	mov dwCommit, ebx
endif
	xor ebx, ebx
	mov cx,1		;alloc TIB selector for thread
	mov ax,0
	int 31h
	jc error
	movzx ebx, ax

;--- esi=dwReserved

if ?PROTCONTEXT
	add esi,2000h
else
	add esi,1000h
endif
if ?USEHEAP
	invoke LocalAlloc, LMEM_FIXED, esi
else
 if ?FLAT
	invoke VirtualAlloc, 0, esi, MEM_RESERVE, PAGE_READWRITE
 else
	invoke VirtualAlloc, 0, esi, MEM_COMMIT, PAGE_READWRITE
 endif
endif
	and eax,eax
	jz error
	mov [edi].THREAD.hStack, eax
if ?FLAT
	push eax
	invoke VirtualAlloc, eax, 1000h, MEM_COMMIT, PAGE_READWRITE	;commit first page
	pop eax
	add eax,esi
	mov ecx, lStack
	and ecx, ecx
	jnz @F
	mov ecx,dwCommit
@@:
	add ecx, 4096-1
	and cx,0F000h
	sub eax,ecx
	push eax
	invoke VirtualAlloc, eax, ecx, MEM_COMMIT, PAGE_READWRITE	;commit initial stack
endif

	mov ecx, pThreadId
	jecxz @F
	mov [ecx], edi
@@:
	invoke InitThread, edi, lpproc, esi, dwArgument, dwCreationFlags

if ?FLAT
	mov edx, [edi].THREAD.hStack
	pop dword ptr [edx+8]
endif

if ?TRACE
	call inittrace
endif
	test dwCreationFlags, CREATE_SUSPENDED
	jnz @F
	invoke DispatchInit 			;activate dispatcher
@@:
exit:
	@strace <"CreateThread()=", eax>
	ret
error:
	invoke KernelHeapFree, edi
	.if (ebx)
		mov ax,1
		int 31h
	.endif
	xor eax, eax
	jmp exit
	align 4

CreateThread endp

;--- just switch to another thread if possible

SwitchToThread proc public
	xor eax, eax
	test [g_bDispatchFlags], FTI_INIT
	jz exit
	call calldispatch3
	inc eax
exit:
	ret
	align 4
SwitchToThread endp

;--- thread destructor
;--- dont free the THREAD object if the thread is still running

destructor proc uses ebx pThis:DWORD

	@strace <"~THREAD(", pThis, ")">
	mov ebx, pThis
	or byte ptr [ebx].THREAD.flags, TF_CLOSED
if 0
	xor edx, edx
	xchg edx, [ebx].THREAD.pAPC
	.while (edx)
		push dword ptr [edx+0]
		invoke LocalFree, edx
		pop edx
	.endw
endif
	xor eax, eax
	mov cl, byte ptr [ebx].THREAD.flags
	and cl, TF_TERMINATED or TF_LINKED
	cmp cl, TF_TERMINATED			;must be unlinked and terminated
	jnz @exit
	mov ecx,[ebx].THREAD.hStack
	.if (ecx)
if ?USEHEAP
		invoke LocalFree, ecx
else
		invoke VirtualFree, ecx, 0, MEM_RELEASE
endif
	.endif

	mov ebx, [ebx].THREAD.dwTibSel
	mov ax,1
	int 31h

	@mov eax, 1
@exit:
	ret
	align 4
destructor endp

deinit proc
	@strace <"thread::deinit">
	invoke DispatchExit
if ?USERTC        
	.if (g_hDispTimer)
		invoke CloseHandle, g_hDispTimer
		mov g_hDispTimer, 0
	.endif
endif
	ret
	align 4
deinit endp

	end
