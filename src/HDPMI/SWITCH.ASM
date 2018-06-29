
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

	@ResetTrace

_gotopmEx proc near public
	@rm2pmbreak
_gotopmEx endp		;fall through

_gotopm proc near public

;	@stroutrm <"entry gotopm",lf>

	pop word ptr cs:[dwRetAdr]
	@rawjmp_pm _gotopm_pm,1
	align 4

_gotopm endp

_TEXT16 ends

_TEXT32 segment

_gotopm_pm proc

;------------------------------ pop value for wHostStack + set wHostStackExc		
if ?FIXTSSESP
	xchg ebx,[esp]
	mov ss:[dwHostStack],ebx
	pop ebx
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

	push ss:[dwRetAdr]
_gotopm_pm endp	;fall throu!

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

;--- called for each switch to real-mode

kdinit2_rm proc
	mov ah,D386_Real_Mode_Init
	int D386_RM_Int
	ret
	align 4
kdinit2_rm endp

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

_rawjmp_pm proc near public

	pop word ptr cs:[dwRetAdr2]
	mov cs:[taskseg._Eax],eax
;	@stroutrm <"entry rawjmp_pm",lf>
	pushf
	pop ax
	and ah,8Fh			;mask out IOPL and NT
	or ah,?PMIOPL
	mov word ptr cs:[taskseg._Efl],ax
rawjmp_pm_patch::
	mov cs:[taskseg._Esi],esi
;	mov esi,cs:[avs]
	mov esi,0
linadvs label byte
	mov ax,0DE0Ch
	int 67h 			;modifies eax,esi,ds,es,fs,gs

_diff_pm = $ - offset rawjmp_pm_patch

RAWJMP_PM_PATCHVALUE = 0EBh+100h*(_diff_pm - 2)

if ?WDEB386
kdpatch1::
	call kdinit_rm
endif
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
	db 66h, 0eah
	dd offset xms_pmentry
else
	db 0eah
	dw LOWWORD(offset xms_pmentry)
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
	jmp ss:[dwRetAdr2]
	align 4

xms_pmentry endp

;--- protected mode entry if running as VCPI client and HDPMI=1

if ?GUARDPAGE0

	assume DS:GROUP16

vcpi_pmentry2 proc public
	mov ax,_SSSEL_
	mov ds,eax
	mov ss,eax
	mov esp,[taskseg._Esp0]
	mov esi,[taskseg._Esi]
ife ?CR0COPY
	mov eax,dwCR0
	mov cr0, eax
endif
	mov eax,[pg0ptr]
	and byte ptr [eax],not ?GPBIT	;reset PTE 'user' bit
	push [taskseg._Efl]
	mov eax,[taskseg._Eax]
	popfd
	jmp [dwRetAdr2]
	align 4
vcpi_pmentry2 endp
endif

;--- protected mode entry if running as VCPI client and not HDPMI=1

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
	jmp ss:[dwRetAdr2]
	align 4
vcpi_pmentry endp

	@ResetTrace

;--- normal jump to real-mode
;--- - save protected mode segment registers in tskstate
;--- - adjust TSS:ESP0
;--- - raw jump to real mode
;--- - switch to real mode stack
;--- - restore real-mode segment registers
;--- - jmp to wRetAdrRm

_gotorm proc public
;	pop ss:[wRetAdrRm]

;--- save segments and ring3 stack in tskstate
	@savepmstate

;--- push wHostStack + set new value for TSS:ESP0
;--- this is restored where???
if ?FIXTSSESP
	push ss:[dwHostStack]
	mov ss:[dwHostStack],esp
else
	push ss:[taskseg._Esp0]		;now a DWORD is pushed
	mov ss:[taskseg._Esp0], esp
 if ?SETEXCHS
	lea esp,[esp-sizeof R3FAULT32]
	mov ss:[dwHostStackExc], esp
 endif
endif

	@rawjmp_rm _gotorm_rm	;rawjmp rm, no stack switch
	align 4
_gotorm endp

_TEXT32 ends

_TEXT16 segment

_gotorm_rm proc
	lss sp,cs:tskstate.rmSSSP
	push cs:[wRetAdrRm]
_gotorm_rm endp	;fall through

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
;--- no stack switch and no segment register save
;--- all general registers preserved
;--- real-mode segment registers undefined
;--- real-mode dest in wRetAdrRm2

_rawjmp_rm proc public
;	@strout <"entry rawjmp_rm, ss:sp=%X:%X",lf>,ss,sp
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

rawjmp_rm_vcpi_1::

if ?GUARDPAGE0
	mov eax,ss:[pg0ptr]
	or byte ptr ss:[eax],?GPBIT	;set page to user
endif

rawjmp_rm_vcpi_2::
	clts							;clear task switched flag
	mov ax,_FLATSEL_
	mov ds,eax
ife ?HSINEXTMEM
	mov ss:[v86iret.rESP],esp		;SS:ESP -> dq ?,V86IRET
endif
	mov esp,offset v86iret
	mov ax,0DE0Ch
	call fword ptr ss:[vcpicall]	;changes eax
	int 3							;should never return
	align 4

nullidt PDESCR <3FFh,0>			;pseudo descriptor IDT real mode

rawjmp_rm_novcpi::	;the true real-mode jump

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

;--- when the _TEXT32 segment has been moved in extended memory
;--- it is not possible to disable paging here. So first jump
;--- to conventional memory, then disable paging and protected mode

if ?MOVEHIGHHLP
	db 0eah
	dd offset rawjmp_rm_xms
	dw _CSGROUP16_
else
	mov eax,cr0
	and eax,not (CR0_PE or CR0_TS or CR0_PG)
	mov cr0,eax
	db 0eah
	dd offset rawjmp_rm_xms
	dw seg rawjmp_rm_xms
endif

size_rawjmp_rm_novcpi equ $ - offset rawjmp_rm_novcpi

	align 4

_rawjmp_rm endp

_TEXT32 ends

_TEXT16 segment

rawjmp_rm_xms proc

if ?MOVEHIGHHLP
	mov eax,cr0
	and eax,not (CR0_PE or CR0_TS or CR0_PG)
	mov cr0,eax
	db 0eah
	dw offset rawjmp_rm_xms_1
wPatchDgrp1 dw 0	;seg rawjmp_rm_xms_1	PATCH with GROUP16
	align 4

rawjmp_rm_xms_1:
endif
	mov ax,cs
	mov ss,ax
if ?HSINEXTMEM
	mov sp,40h
endif
if ?SAVERMGDTR
	@lgdt cs:[rmgdt]
endif
if ?SAVERMCR3
	mov eax,cs:[dwOldCR3]
	mov cr3,eax
endif
if ?WDEB386
kdpatch2::		;if no debugger present, this code is disabled
	call kdinit2_rm
endif
vcpi_rmentry::	; v86-mode entry if running as VCPI client
	push word ptr cs:[taskseg._Efl]
	mov eax, cs:[taskseg._Eax]
	popf
	jmp cs:[wRetAdrRm2]
rawjmp_rm_xms endp

_TEXT16 ends

end
