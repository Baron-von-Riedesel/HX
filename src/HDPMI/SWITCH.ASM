
;--- low-level mode switches

	page,132

	.486P

	include hdpmi.inc
	include external.inc
	include debugsys.inc

	option proc:private

_TEXT16 segment

;*** full switch to protected mode
;--- - save real-mode segment registers
;--- - raw jump to protected mode
;--- - adjust TSS:ESP0
;--- - restore protected mode segment registers (PMSTATE)
;--- - flags not touched

	@ResetTrace

_jmp_pmX proc near public
	@rm2pmbreak
_jmp_pmX endp		;fall through

_jmp_pm proc near public

	pop word ptr cs:[dwPmDest]
	@rawjmp_pm_savesegm _jmp_pm_pm
	align 4

_jmp_pm endp

_TEXT16 ends

_TEXT32 segment

_jmp_pm_pm proc

if ?FIXTSSESP
;--- pop value for wHostStack + set wHostStackExc
	pop ss:[dwHostStack]
else
 if ?SETEXCHS
	xchg ebx,[esp]
	mov ss:[taskseg._Esp0],ebx		;now a dword is pushed/poped
	lea ebx,[ebx-sizeof R3FAULT32]
	mov ss:[dwHostStackExc],ebx
	pop ebx							;restore ebx
 else
	pop ss:[taskseg._Esp0]
 endif
endif
	push ss:[dwPmDest]
_jmp_pm_pm endp	;fall throu!

load_pmsegs proc public
	mov ds,ss:tskstate.rDS
	mov es,ss:tskstate.rES
	mov fs,ss:tskstate.rFS
	mov gs,ss:tskstate.rGS
	ret
	align 4
load_pmsegs endp

_TEXT32 ends

_TEXT16 segment

if ?WDEB386

;--- called by switch to protected-mode

kdinit_rm proc
	pusha
	mov ax,D386_Reinit * 100h + 0
	mov bx, _FLATSEL_
	mov cx, _KDSEL_		;2 selectors for WDEB386
	mov dx, _GDTSEL_	;GDT selector
	int D386_RM_Int
	popa
	ret
	align 4
kdinit_rm endp

;--- called by switch to real-mode

kdinit2_rm proc
	mov ah,D386_Real_Mode_Init
	int D386_RM_Int
	ret
	align 4
kdinit2_rm endp

if ?WDEB386
;--- if no debugger present, this code is disabled
;--- currently moved to a dead location, since
;--- wdeb386 doesn't work
kdpatch1::call kdinit_rm
endif

endif

;*** raw jump to pm with rm segs set
;--- out: esp=taskseg._Esp0

_rawjmp_pm_savesegm proc public
	mov cs:[v86iret.rES],es
	mov cs:[v86iret.rDS],ds
	mov cs:[v86iret.rFS],fs
	mov cs:[v86iret.rGS],gs
_rawjmp_pm_savesegm endp	;fall throu

;*** raw jump to pm, segment registers undefined
;--- flags saved

_rawjmp_pm proc near public

	pop word ptr cs:[dwPmDest2]
	mov cs:[taskseg._Eax],eax
;	@stroutrm <"entry rawjmp_pm",lf>
	pushf
	pop ax
	and ah,8Fh			;mask out IOPL and NT
	or ah,?PMIOPL
	mov word ptr cs:[taskseg._Efl],ax
rawjmp_pm_patch::
;--- if there's no VCPI host, this location will be patched
;--- with a jump to _diff_pm
	mov cs:[taskseg._Esi],esi
;	mov esi,cs:[avs]
	mov esi,0			;esi = linear address of v862pm variable
	org $-4
linadvs dd ?
	mov ax,0DE0Ch
	int 67h 			;modifies eax,esi,ds,es,fs,gs

_diff_pm = $ - offset rawjmp_pm_patch

RAWJMP_PM_PATCHVALUE = 0EBh+100h*(_diff_pm - 2)

;--- here's the XMS and "raw" mode version for pm switching

if ?SAVERMCR3
	mov eax,cr3
	mov cs:[dwOldCR3],eax
endif
if ?SAVERMIDTR
	@sidt cs:[nullidt]
endif
if ?SAVERMGDTR
	@sgdt cs:[rmgdt]
endif
ife ?LATELGDT
	@lgdt cs:[pdGDT]
endif
if ?SINGLESETCR3 eq 0
if ?CMPCR3
	mov eax,cr3
	cmp eax,cs:[v86topm._cr3]
	jz @F
endif
	mov eax,cs:[v86topm._cr3]
	mov cr3,eax
@@:
endif
if ?CR0COPY
	mov eax,cr0
	or eax,CR0_PG or CR0_PE
else
	mov eax,cs:[dwCR0]
endif
	mov cr0,eax
if ?LATELGDT
	@lgdt cs:[pdGDT]
endif
if 0
	db 66h, 0eah	;jmp far32
	dd offset xms_pmentry
else
	db 0eah	;jmp far16
	dw LOWWORD offset xms_pmentry
endif
	dw _CSSEL_
	align 4

_rawjmp_pm endp

_TEXT16 ends

_TEXT32 segment

xms_pmentry proc
	mov ax,_SSSEL_
	mov ss,eax
	mov esp, ss:[taskseg._Esp0]
	lidt ss:[pdIDT]		;set IDTR

	mov al,_LDTSEL_
	lldt ax				;set LDTR

	mov eax, ss:[dwTSSdesc]
	mov ss:[eax].DESCRPTR.attrib,89h ;TSS available
	mov ax,_TSSSEL_
	ltr ax				;set TR

	push ss:[taskseg._Efl]
	mov eax,ss:[taskseg._Eax]
	popfd
	jmp ss:[dwPmDest2]
	align 4

xms_pmentry endp

;--- protected mode entry if running as VCPI client

vcpi_pmentry proc public
	mov ax,_SSSEL_
	mov ss,eax
	mov esp,ss:[taskseg._Esp0]
	mov esi,ss:[taskseg._Esi]
ife ?CR0COPY
	mov eax,ss:dwCR0
	mov cr0, eax
endif
	push ss:[taskseg._Efl]
	mov eax,ss:[taskseg._Eax]
	popfd
	jmp ss:[dwPmDest2]
	align 4
vcpi_pmentry endp

	@ResetTrace

;--- normal jump to real-mode
;--- - save protected mode segment registers in tskstate
;--- - adjust TSS:ESP0
;--- - raw jump to real mode
;--- - switch to real mode stack
;--- - restore real-mode segment registers
;--- - jmp to wRmDest

_jmp_rm proc public

;--- save segregs and ring3 stack in tskstate
	@savepmstate

;--- save ring0 esp on host stack, then set new value for it
;--- the old value is restored in _jmp_pm_pm
if ?FIXTSSESP
	push ss:[dwHostStack]
	mov ss:[dwHostStack],esp
else
	push ss:[taskseg._Esp0]
	mov ss:[taskseg._Esp0], esp
 if ?SETEXCHS
	lea esp,[esp-sizeof R3FAULT32]
	mov ss:[dwHostStackExc], esp
 endif
endif

	@rawjmp_rm _jmp_rm_rm	;rawjmp rm, no stack switch
	align 4
_jmp_rm endp

_TEXT32 ends

_TEXT16 segment

if ?WDEB386
;--- if no debugger present, this code is disabled
;--- currently moved to a dead location, since wdeb386
;--- doesn't work
kdpatch2:: call kdinit2_rm
endif

_jmp_rm_rm proc
	lss sp,cs:tskstate.rmSSSP
	push cs:[wRmDest]
_jmp_rm_rm endp	;fall through

load_rmsegs proc public
	mov es,cs:[v86iret.rES]   ;do it in this order!
	mov ds,cs:[v86iret.rDS]
	mov fs,cs:[v86iret.rFS]
	mov gs,cs:[v86iret.rGS]
	ret
	align 4
load_rmsegs endp

_TEXT16 ends

_TEXT32 segment

;--- raw jump to real-mode
;--- no stack switch to tskstate.rmSSSP, no segment register save
;--- all general registers preserved
;--- real-mode segment registers undefined
;--- real-mode dest in wRmDest2

_rawjmp_rm proc public
	pushfd
	mov ss:[taskseg._Eax],eax
if ?SETRMIOPL
	and byte ptr [esp+1],0CFh		;reset IOPL
	or byte ptr [esp+1],?RMIOPL
endif
	pop ss:[taskseg._Efl]
ife ?CR0COPY
	mov eax, cr0
	mov ss:dwCR0, eax
endif

ife ?PATCHCODE
	jmp ss:[rawjmp_rm_vector]
	align 4
else
rawjmp_rm_patch::					;might be patched!
endif

rawjmp_rm_vcpi::
	mov ax,_FLATSEL_
if ?HSINEXTMEM and ?MAPDOSHIGH
;--- the v86iret struct in the clone of GROUP16
;--- which is mapped high cannot be used, it must
;--- be the original one located in conv. memory!
	mov esp,ss:v86iretesp
else
	mov esp,offset v86iret
endif
	mov ds,eax
	clts				;clear task switched flag
	mov ax,0DE0Ch
	call ss:[vcpicall]	;modifies eax
	int 3				;should never return
	align 4

nullidt PDESCR <3FFh,0>			;pseudo descriptor IDT real mode

rawjmp_rm_novcpi::	;the label if no vcpi host was detected (xms or raw)

if ?PATCHCODE

_diff_rm = offset rawjmp_rm_novcpi - offset rawjmp_rm_patch

;--- MASM has a severe bug calculating the difference of 2 offsets
;--- when there is a short jump between them

RAWJMP_RM_PATCHVALUE = 0EBh+100h*(_diff_rm - 2)
endif

	lidt cs:[nullidt]

;--- continue for xms + raw

	mov ax,_STDSEL_
	mov ds,eax
	mov es,eax
	mov fs,eax
	mov gs,eax
	mov ss,eax
if ?CLRLDTR
	xor eax,eax
	lldt ax
endif
	mov eax,cr0
	and eax,not (CR0_PE or CR0_TS or CR0_PG)

;--- when the _TEXT32 segment has been moved in extended memory
;--- it is not possible to disable paging here. So first jump
;--- to conventional memory, then disable paging and protected mode

if 1;?MOVEHIGHHLP
	db 066h
	db 0eah
	dw offset rawjmp_rm_xms
	dw _CSGROUP16_
else
	mov cr0,eax
	db 0eah
	dw offset rawjmp_rm_xms_1
;--- the following line cannot work, because the
;--- 32-bit code is not loaded by DOS, and anyway,
;--- the segment part is NOT fix, at least not with option -a!
;--- So ?MOVEHIGHHLP simply MUST be set to 1!
	dw seg rawjmp_rm_xms_1
endif

_rawjmp_rm endp

_TEXT32 ends

_TEXT16 segment

;--- final part of raw jump to real-mode for xms.

rawjmp_rm_xms proc

if 1;?MOVEHIGHHLP
	mov cr0,eax
	db 0eah
	dw offset rawjmp_rm_xms_1
wPatchGrp161 dw 0	;seg rawjmp_rm_xms_1	PATCH with GROUP16
	align 4

rawjmp_rm_xms_1:
endif
;--- v3.18: no need to set a stack, since
;--- all code that uses the rawjmp will set
;--- the rm stack as its first step.
;	mov ax,cs
;	mov ss,ax
;if ?HSINEXTMEM
;	mov sp,20h
;endif
if ?SAVERMGDTR
	@lgdt cs:[rmgdt]
endif
if ?SAVERMCR3
	mov eax,cs:[dwOldCR3]
	mov cr3,eax
endif
;--- this code runs for both xms and vcpi mode
vcpi_rmentry::
	mov ax, word ptr cs:[taskseg._Efl]
	sahf
	mov eax, cs:[taskseg._Eax]
	jmp cs:[wRmDest2]
rawjmp_rm_xms endp

_TEXT16 ends

end
