
;--- low-level mode switches

	page ,132

	.486P

	include hdpmi.inc
	include external.inc
	include debugsys.inc

	option proc:private

_TEXT16 segment

;*** switch to protected mode
;--- - clear IF
;--- - save real-mode segment registers
;--- - raw jump to protected mode
;--- - restore protected mode segment registers
;--- flags not touched

	@ResetTrace

_jmp_pmX proc near public
	@rm2pmbrk
_jmp_pmX endp		;fall through

_jmp_pm proc near public

	pop word ptr cs:dwPmDest
	@rawjmp_pm_savesegm _jmp_pm_pm
	align 4
_TEXT32 segment
_jmp_pm_pm:
	mov es, ss:pmstate.rES
	mov ds, ss:pmstate.rDS
	mov fs, ss:pmstate.rFS
	mov gs, ss:pmstate.rGS
	pop ss:dwHostStack
	jmp ss:dwPmDest
	align 4
_TEXT32 ends

_jmp_pm endp

;*** raw jump to pm with rm segs set
;--- out: esp=dwHostStack

_rawjmp_pm_savesegm proc public
	mov cs:v86iret.rES, es
	mov cs:v86iret.rDS, ds
	mov cs:v86iret.rFS, fs
	mov cs:v86iret.rGS, gs
_rawjmp_pm_savesegm endp	;fall throu

;*** raw jump to pm, segment registers undefined
;--- flags saved

_rawjmp_pm proc near public

	pop word ptr cs:[dwPmDest2]
	mov cs:taskseg._Eax,eax
;	@drprintf "entry rawjmp_pm"
	pushf
	pop ax
	and ah,8Fh			;mask out IOPL and NT
if ?PMIOPL
	or ah, ?PMIOPL shl 4
endif
	mov word ptr cs:v86iret.rFL,ax
rawjmp_pm_patch::
;--- if there's no VCPI host, this location will be patched
;--- with a jump to _diff_pm
	mov cs:taskseg._Esi,esi
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
ife ?SINGLESETCR3
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
	mov esp, ss:dwHostStack
	lidt ss:[pdIDT]		;set IDTR

	mov al,_LDTSEL_
	lldt ax				;set LDTR

	mov eax, ss:[dwTSSdesc]
	mov ss:[eax].DESCRPTR.attrib,89h ;TSS available
	mov ax,_TSSSEL_
	ltr ax				;set TR

	push ss:v86iret.rEFL
	mov eax,ss:taskseg._Eax
	popfd
	jmp ss:[dwPmDest2]
	align 4

xms_pmentry endp

;--- protected mode entry if running as VCPI client

vcpi_pmentry proc public
	mov ax,_SSSEL_
	mov ss,eax
	mov esp,ss:dwHostStack
	mov esi,ss:taskseg._Esi
ife ?CR0COPY
	mov eax,ss:dwCR0
	mov cr0, eax
endif
	push ss:v86iret.rEFL
	mov eax,ss:taskseg._Eax
	popfd
	jmp ss:[dwPmDest2]
	align 4
vcpi_pmentry endp

	@ResetTrace

;--- normal jump to real-mode
;--- - save protected mode segment registers in pmstate
;--- - raw jump to real mode
;--- - the destination address in real-mode has been
;--- - saved in wRmDest (see @jmp_rm)

_jmp_rm proc public
	@store_ssesp
	push ss:[dwHostStack]	;v3.19: added
	mov ss:[dwHostStack],esp;v3.19: added
_rawjmp_rm_savesegm::       ;v3.19: added
	mov ss:pmstate.rES, es
	mov ss:pmstate.rDS, ds
	mov ss:pmstate.rFS, fs
	mov ss:pmstate.rGS, gs
_jmp_rm endp	;fall thru

;--- raw jump to real-mode
;--- NO pm segregs saved
;--- obsolete: [ring 0 esp saved in dwHostStack]
;--- stack switch to SS:SP in v86iret
;--- real-mode segment registers set to values in v86iret
;--- real-mode IP in wRmDest
;--- all general registers preserved, including flags.

_rawjmp_rm proc public
	pushfd
	mov ss:taskseg._Eax,eax
if ?SETRMIOPL	;is 0 by default
	and byte ptr [esp+1],0CFh		;reset IOPL
	or byte ptr [esp+1], ?RMIOPL shl 4
endif
;--- v86iret.rEFL cannot be used to store flags.
;--- This field will be set by the vcpi host.
;	pop ss:v86iret.rEFL
	pop ss:taskseg._Efl
ife ?CR0COPY
	mov eax, cr0
	mov ss:dwCR0, eax
endif
;	mov ss:[dwHostStack],esp
	jmp ss:[rawjmp_rm_vector]
	align 4

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
	clts				;clear CR0.TS flag? hdpmi does no task switching, so probably useless...
	mov ax,0DE0Ch
	call ss:[vcpicall]	;modifies eax
	int 3				;should never return
	align 4

nullidt PDESCR <3FFh,0>			;pseudo descriptor IDT real mode

rawjmp_rm_novcpi::	;the label if no vcpi host was detected (xms or raw)

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

_TEXT16 segment

rawjmp_rm_xms:	; xms branch of raw jump to real-mode

if 1;?MOVEHIGHHLP
	mov cr0,eax
	db 0eah
	dw offset @F
wPatchGrp161 dw 0	;seg rawjmp_rm_xms_1	PATCH with GROUP16
	align 4
@@:
endif
if ?SAVERMGDTR
	@lgdt cs:[rmgdt]
endif
if ?SAVERMCR3
	mov eax,cs:[dwOldCR3]
	mov cr3,eax
endif
	lss esp, fword ptr cs:v86iret.rESP
;	push cs:v86iret.rEFL
	mov es,cs:[v86iret.rES]   ;do it in this order!
	mov ds,cs:[v86iret.rDS]
	mov fs,cs:[v86iret.rFS]
	mov gs,cs:[v86iret.rGS]
;	popfd
rawjmp_rm_all::		; this code runs for both xms and vcpi mode
if 1
	push word ptr cs:taskseg._Efl
	mov eax, cs:taskseg._Eax
	popf
else
;--- this version doesn't touch the real-mode stack
	mov ah, byte ptr cs:taskseg._Efl
	sahf
	mov eax, cs:taskseg._Eax
endif
	jmp cs:[wRmDest]

_TEXT16 ends

_rawjmp_rm endp

_TEXT32 ends

end
