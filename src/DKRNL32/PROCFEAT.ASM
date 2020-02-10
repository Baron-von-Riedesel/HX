
;--- implements IsProcessorFeaturePresent
;--- this function is not supported by Win9x!

	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:none
	option proc:private

	include winbase.inc
	include dkrnl32.inc
	include macros.inc

if ?PROCFEAT

;--- cpuid feature flags (edx)
;       1 FPU:  FPU is integrated
;       2 VME:  supports CR4 VME/PVI, EFL VIF/VIP
;       4 DE:   supports i/o breakpoints + CR4 DE
;       8 PSE:  4MB page size supported + CR4 PSE
;      10 TSC:  support for RDTSC + CR4 TSD
;      20 MSR:  support for RDMSR/WRMSR
;      40 PAE:  physical address extension + CR4 PAE
;      80 MCE:  machine check exceptions + CR4 MCE
;     100 CX8:  CMPXCHG8B supported
;     200 APIC: on chip APIC exists and enabled
;     400 ---:  unused
;     800 SEP:  SYSENTER and SYSEXIT supported
;    1000 MTRR: memory type range registers supported
;    2000 PGE:  support for CR4 PGE
;    4000 MCA:  MCA_GAP MSR supported
;    8000 CMOV: CMOV + FCMOV/FCOMI supported
;   10000 PAT:  Page Attribute Table supported
;   20000 PSE-36: Page Size Extension supported
;   40000 PSN:  Processor Serial Number supported
;   80000 CLFSH: CFLUSH instruction supported
;  100000 ---:  unused
;  200000 DS:   Debug Store
;  400000 ACPI: Thermal Monitor and Clock Control
;  800000 MMX:  MMX supported
; 1000000 FXSR: FXSAVE/FXRSTOR supported, also CR4 OSFXSR
; 2000000 SSE:  SSE supported
; 4000000 SSE2: SSE2 supported
; 8000000 SS:   Self Snoop
;10000000 HTT:  Multithreading
;20000000 TM:   Thermal Monitor
;40000000 ---:  unused
;80000000 PBE:  Pending Break Enable

;--- cpuid feature flags (ecx)
;       1 SSE3:       SSE3 supported
;       2 PCLMULQDQ:  Carryless Multiplication
;       4 ---:        unused
;       8 MONITOR:    MONITOR/MWAIT supported
;      10 DS_CPL:     CS Qualified Debug Store
;      20 VMX:        Virtual Machine Extensions
;      40 SMX:        Safer Mode Extensions
;      80 EST:        Enhanced SpeedStep Technology
;     100 TM2:        Thermal Monitor 2
;     200 SSSE3:      SSSE3 supported
;     400 CNXT-ID::   L1 Context ID
;     800 ---:        unused
;    1000 FMA:        Fused Multiply Add
;    2000 CMPXCHG16B: instruction supported
;    4000 xTPR:       Update Control
;    8000 PDCM:       Perf/Debug Capability MSR
;   10000 ---:        unused
;   20000 ---:        unused
;   40000 DCA:        Direct Cache Access
;   80000 SSE4_1:     SSE 4.1
;  100000 SSE4_2:     SSE 4.2
;  200000 x2APIC: 
;  400000 ---:        unused
;  800000 POPCNT:     POPCNT supported
; 1000000 ---:        unused
; 2000000 AES: 
; 4000000 XSAVE:
; 8000000 OSXSAVE:
;10000000 AVX: 
;20000000 ---:        unused
;40000000 ---:        unused
;80000000 0:

CPUID_RDTSC_SUPP	equ 0000010h
CPUID_CX8_SUPP		equ 0000100h
CPUID_MMX_SUPP		equ 0800000h
CPUID_SSE_SUPP		equ 2000000h

	option dotname

.BASE$IA SEGMENT dword public 'DATA'
	DD offset Install
.BASE$IA      ENDS

	.data

g_flags	dd 0
g_cpu	db 0
g_step	db 0

	.code

checkcpuid proc uses ebx

	pushfd
	push 200000h		;push ID flag
	popfd
	pushfd
	pop  eax
	test eax,200000h	;is it set now?
	mov  al,00
	jz checkcpuid_ex
	push 1
	pop eax
	.586
	cpuid				;returns cpu in AH, step in AL, flags in EDX
	.386
	popfd
	mov [g_cpu],ah		;cpu
	mov [g_step],al 	;mask/stepping
	mov [g_flags],edx	;feature flags
	clc
	ret
checkcpuid_ex:
	popfd
	stc
	ret
	align 4

checkcpuid endp

Install proc
	@noints
	invoke checkcpuid
	@restoreints
	ret
	align 4
Install endp

IsProcessorFeaturePresent proc public dwFeature:dword

	mov ecx, dwFeature
	xor eax, eax
	.if (ecx == PF_COMPARE_EXCHANGE_DOUBLE)
		test g_flags, CPUID_CX8_SUPP
		setnz al
	.elseif (ecx == PF_MMX_INSTRUCTIONS_AVAILABLE)
		test g_flags, CPUID_MMX_SUPP
		setnz al
	.elseif (ecx == PF_XMMI_INSTRUCTIONS_AVAILABLE)
		test g_flags, CPUID_SSE_SUPP
		setnz al
	.elseif (ecx == PF_RDTSC_INSTRUCTION_AVAILABLE)
		test g_flags, CPUID_RDTSC_SUPP
		setnz al
	.endif
	@strace <"IsProcessorFeaturePresent(", dwFeature, ")=", eax>
	ret

IsProcessorFeaturePresent endp

endif

	end
