
;--- implements GetDiskFreeSpaceA, GetDiskFreeSpaceW

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
	include fat32.inc

	.DATA

	.CODE

;--- pRoot may be NULL

GetDiskFreeSpaceA proc public uses ebx edi pRoot:ptr BYTE,
                               pSectorPerCluster:ptr dword,
                               pBytesPerSector:ptr dword,
                               pFreeClusters:ptr dword,
                               pTotalClusters:ptr dword


local	egdfs:ExtGetDskFreSpcStruc
local	szDrv[4]:byte

	lea edi,egdfs						;output: es:edi -> buffer
	mov ecx,sizeof ExtGetDskFreSpcStruc	;input: ecx = sizeof buffer
	mov edx,pRoot						;input: ds:edx -> filename
	and edx, edx
	jz @F
	mov eax,[edx]
	cmp ax,'\'		;just a '\'?
	jz @F
	cmp ah,':'
	jnz rootok
	jmp roottmp
@@:        
	mov ah,19h
	int 21h
	add al,'A'
	mov ah,':'
roottmp:        
	lea edx,szDrv
rootok:
	mov dword ptr szDrv,eax
	mov word ptr [szDrv+2],'\'
	mov egdfs.level,0		;MS-DOS seems to need this
	mov ax,7303h
	int 21h
	jc @F
	cmp ax,7300h
	jnz lab0
@@:
	mov ah,36h				;use FAT16 method
	mov dl,szDrv
	or dl,20h
	sub dl,'a'-1
	int 21h
	cmp ax,0FFFFh
	jz error
	movzx eax,ax
	movzx ecx,cx
	movzx edx,dx
	movzx ebx,bx
	jmp lab1
lab0:
	assume edi:ptr ExtGetDskFreSpcStruc
	mov eax,[edi].sectorspercluster
	mov ecx,[edi].bytespersector
	mov ebx,[edi].availableclusters
	mov edx,[edi].totalclusters
	assume edi:nothing
lab1:
	mov edi,pSectorPerCluster
	mov [edi],eax
	mov edi,pBytesPerSector
	mov [edi],ecx
	mov edi,pFreeClusters
	mov [edi],ebx
	mov edi,pTotalClusters
	mov [edi],edx
	@mov eax,1
exit:        
	@strace <"GetDiskFreeSpaceA(", pRoot, ", ", pSectorPerCluster, ", ", pBytesPerSector, ", ", pFreeClusters, ", ", pTotalClusters, ")=", eax>
	ret
error:
	invoke SetLastError, ERROR_PATH_NOT_FOUND
	xor eax,eax
	jmp exit
	align 4

GetDiskFreeSpaceA endp

GetDiskFreeSpaceW proc public pRoot:ptr WORD,
                               pSectorPerCluster:ptr dword,
                               pBytesPerSector:ptr dword,
                               pFreeClusters:ptr dword,
                               pTotalClusters:ptr dword
	mov eax, pRoot
	.if (eax)
		call ConvertWStr
	.endif
	invoke GetDiskFreeSpaceA, eax, pSectorPerCluster, pBytesPerSector, pFreeClusters, pTotalClusters
	@strace <"GetDiskFreeSpaceW(", pRoot, ", ", pSectorPerCluster, ", ", pBytesPerSector, ", ", pFreeClusters, ", ", pTotalClusters, ")=", eax>
	ret
	align 4

GetDiskFreeSpaceW endp

end

