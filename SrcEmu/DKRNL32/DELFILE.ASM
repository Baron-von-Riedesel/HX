
;--- implements DeleteFileA()

	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option proc:private
	option casemap:none

	include winbase.inc
	include macros.inc
	include dkrnl32.inc

?SAVEEBX	equ 1	;makes it FreeDOS + MS-DOS 5/6 compatible

extern __CHECKOS:abs	;workaround for win NT/2K/XP bug

	.CODE

if ?SAVEEBX
DeleteFileA proc public uses ebx esi fname:dword
else
DeleteFileA proc public uses esi fname:dword
endif

	xor esi,esi			;--- no wildcards are allowed here
	xor ecx,ecx			;
	mov edx,fname
	mov ax,7141h
	stc
	int 21h
	jnc success
	cmp ax,7100h
	jnz error
	mov cl,00			;just to be sure
	mov ah,41h
	int 21h
	jc error
success:
	@mov	eax, 1
done:
	@strace <"DeleteFileA(", &fname, ")=", eax>
	ret
error:
	movzx eax, ax
	invoke SetLastError, eax
	xor eax, eax
	jmp done
	align 4

DeleteFileA endp

	end

