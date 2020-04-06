
;--- implements SetCurrentDirectoryA/SetCurrentDirectoryW

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

extern __CHECKOS:abs

	.CODE

SetCurrentDirectoryA proc public uses ebx esi newdir:ptr BYTE

local   tmpbuf[MAXPATH]:byte

	mov edx,newdir
	lea esi,tmpbuf
	cmp byte ptr [edx+1],':'
	jnz nodrivechange
if 0
	mov bl,[edx]
	or bl,20h
	sub bl,'a'-1
	push ebx
	mov ax,4409h		;cannot check if read from FD
	int 21h 			;is possible
	pop edx
	jc chdir_er
endif
	mov al,[edx]
	or al,20h
	sub al,'a'-1			;A:=1,B:=2,...
	cmp byte ptr [edx+2],0	;is it just a drive letter without path?
	mov dl,al
	jnz @F					;if just "X:" has been entered then
	mov ah,47h				;a int 21h, AH=0E won't make a disk access;
	int 21h					;therefore read cur dir to DS:ESI
	jc chdir_er
@@:
	dec dl    				;here it is A:=0,B:=1,C:=2
	mov ah,0Eh
	int 21h
	mov edx,newdir
	cmp byte ptr [edx+2],0	;path behind drive?
	jz chdir_ok
nodrivechange:
;--- skip a trailing '\'. This must be done in a buffer
	mov ecx,MAX_PATH
@@:        
	mov al,[edx]
	mov [esi],al
	inc edx
	inc esi
	and al,al
	loopnz @B
	cmp byte ptr [edx-2],'\'
	jnz @F
	cmp byte ptr [edx-3],':'
	jz @F
	mov byte ptr [esi-2],0
@@:        
	lea edx,tmpbuf
	mov ax,713Bh
	stc
	int 21h
	jnc chdir_ok
	cmp ax,7100h
	jnz chdir_er
	mov ah,3Bh
	int 21h
	jnc chdir_ok
chdir_er:
	movzx eax,ax
	invoke SetLastError, eax
	xor eax,eax 			;eax=0 is error
	jmp exit
chdir_ok:
	@mov eax,1				;eax<>0 is ok
exit:
	@strace <"SetCurrentDirectoryA(", &newdir, ")=", eax>
	ret
	align 4
        
SetCurrentDirectoryA endp

SetCurrentDirectoryW proc public newdir:ptr WORD

	mov eax,newdir
	call ConvertWStr
	invoke SetCurrentDirectoryA, eax
	@strace <"SetCurrentDirectoryW(", newdir, ")=", eax>
	ret
	align 4
        
SetCurrentDirectoryW endp

	end

