
	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option proc:private
	option casemap:none

	include winbase.inc

?USETIMER	equ 1	;user timer 2 for sound

	.CODE

;--- frequence in hertz, duration in ms

Beep proc public frequence:dword, dwDuration:dword

	mov eax,frequence
	cmp eax, 37
	jb done
	cmp eax, 7FFFh
	ja done
ife ?USETIMER
	mov ecx, 37
	xor edx, edx
	div ecx
	mov ecx, 886
	sub ecx, eax
	shr ecx,2
	inc ecx
	mov frequenz, ecx
	mov edx,dwDuration
	shr edx, 4
	inc edx
	in AL,061h
	push eax
	.while (edx)
		and AL,0FCh
		out 061h,AL
		mov ecx, frequence
L35:	in al,61h
		and al,10h
		cmp al,ah
		mov ah,al
		jz L35
		loop L35
		or AL,2
		out 061h,AL
		mov ecx, frequence
L3D:	in al,61h
		and al,10h
		cmp al,ah
		mov ah,al
		jz L3D
		loop L3D
		dec edx
	.endw
	pop eax
	out 061h,AL
else
	mov ecx, eax
	mov eax,1193180 ;clock frequence = 1,193 MHz
	sub edx,edx
	div ecx
	mov ecx, eax

	mov ax,0900h	;disable interrupts
	int 31h
	push eax
        
	mov al,0B6h		;80h = select timer2, 30=read/write 2 bytes comes
					;06h = hardware triggered strobe 
	out 43h,al
	mov al,cl
	out 42h,al
	mov al,ch
	out 42h,al
	in al,61h
	push eax
	or al,3		;enable speaker and attach timer2 to speaker
	out 61h,al

	sti

	invoke	Sleep, dwDuration

	pop eax
	out 61h,al		;disable speaker

	pop eax
	int 31h			;restore interrupt state
endif
done:
	ret
Beep endp

end
