
pm_createvm proto near			;create a virtual machine
pm_exit_pm proto near			;page mgr server exit protected-mode
pm_exitclient proto near		;client termination cleanup
pm_CloneGroup32 proto near		;copy GROUP32 to new address context
_CommitRegion proto near		;commit region EAX, size ECX
_UncommitRegion proto near		;uncommit region EAX, size ECX
_CommitRegionZeroFill proto near;commit region EAX, size ECX and clear it
_Linear2PT proto near			;get page table addr of linear addr
_getpageattributes proto near	;get page flags for a region
_setpageattributes proto near	;set page flags for a region
_MovePTEs proto near			;move PTEs between address spaces
_AllocUserPages proto near		;alloc memory in user address region
_AllocSysPages proto near		;alloc memory in system region 1 (U)
_AllocSysPagesX proto near		;alloc memory in system region 1 (S)
_AllocSysPagesRo proto near		;alloc memory in system region 1 (R)
_AllocSysPages2 proto near		;alloc memory in system region 2
_FreeSysPages2 proto near		;free memory in system region 2
_GetNumPhysPages proto near		;get free/total physical pages
_freeI15mem proto near			;free some mem for Int 15h in raw mode
_restoreI15mem proto near		;restore the mem in raw mode
_AllocUserSpace proto near		;allocate user address space
_FreeUserSpace proto near		;free user address space
_AllocSysAddrSpace proto near	;allocate system address space
_getaddrspace proto near		;get free/total user address space
_searchphysregion proto near	;search a mapped physical region
_mapphysregion proto near		;map physical address to user space
_ClonePage proto near			;clone a page
_SetPage proto near				;set PTE for a linear address
_setregionattributes proto near	;set PTE bits for a region

pm_init_rm proto near16		;page mgr server init real-mode
pm_init2_rm proto near16	;page mgr cleanup after prot-mode init
pm_exit_rm proto near16		;page mgr server exit real-mode
pm_int15rm proto near16		;Int 15h, ah=88h and ax=e801h handler
;seti15pages proto near16

