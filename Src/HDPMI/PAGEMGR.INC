
pm_createvm 		proto near		;create a virtual machine
pm_exit_pm			proto near		;page mgr server exit protected-mode
pm_exitclient		proto near		;client termination cleanup
pm_CloneGroup32 	proto near		;copy GROUP32 to new address context
pm_CommitRegion		proto near		;commit region EAX, size ECX
pm_UncommitRegion 	proto near		;uncommit region EAX, size ECX
pm_CommitRegionZeroFill proto near	;commit region EAX, size ECX and clear it
pm_Linear2PT		proto near		;get page table addr of linear addr
pm_getpageattributes proto near		;get page flags for a region
pm_setpageattributes proto near		;set page flags for a region
pm_MovePTEs			proto near		;move PTEs between address spaces
pm_AllocSysPages	proto near		;alloc memory in sysreg 0 (user,r/w)
pm_AllocSysPagesX	proto near		;alloc memory in sysreg 0 (system,r/w)
pm_AllocSysPagesDn	proto near		;alloc memory in sysreg 0 down (system,r/w)
pm_FreeSysPagesDn	proto near		;free memory in sysreg 0 down
pm_GetNumPhysPages	proto near		;get free/total physical pages
pm_AllocUserSpace	proto near		;allocate user address space
pm_FreeUserSpace	proto near		;free user address space
pm_AllocSysAddrSpace proto near		;allocate system address space
pm_getaddrspace		proto near		;get free/total user address space
pm_searchphysregion	proto near		;search a mapped physical region
pm_mapphysregion	proto near		;map physical address to user space
pm_CopyPTEs			proto near
ifdef ?PE
pm_makeregionreadonly proto near	;make region readonly
endif

pm_init_rm			proto near16	;page mgr server init real-mode
pm_init2_rm			proto near16	;page mgr cleanup after prot-mode init
pm_exit_rm			proto near16	;page mgr server exit real-mode
pm_int15rm			proto near16	;Int 15h, ah=88h and ax=e801h handler

;--- obsolete
;pm_setregionattributes proto near	;set PTE bits for a region
;pm_freeI15mem		proto near		;free some mem for Int 15h in raw mode
;pm_restoreI15mem	proto near		;restore the mem in raw mode
;pm_AllocSysPagesRo	proto near		;alloc memory in sysreg 0 (user,r/o)
;pm_AllocUserPages	proto near		;alloc memory in user address region
;pm_SetPage 		proto near		;set PTE for a linear address
;pm_seti15pages		proto near16

