
@proto pm_createvm				;create a virtual machine
@proto pm_exitserver_pm			;page mgr server exit protected-mode
@proto pm_exitclient			;client termination cleanup
@proto pm_CloneGroup32 			;copy GROUP32 to new address context
@proto _CommitRegion			;commit region EAX, size ECX
@proto _UncommitRegion 			;uncommit region EAX, size ECX
@proto _CommitRegionZeroFill	;commit region EAX, size ECX and clear it
@proto _Linear2PT				;get page table addr of linear addr
@proto _getpageattributes		;get page flags for a region
@proto _setpageattributes		;set page flags for a region
@proto _MovePTEs				;move PTEs between address spaces
@proto _AllocUserPages			;alloc memory in user address region
@proto _AllocSysPages			;alloc memory in system region 1 (U)
@proto _AllocSysPagesX			;alloc memory in system region 1 (S)
@proto _AllocSysPagesRo			;alloc memory in system region 1 (R)
@proto _AllocSysPages2			;alloc memory in system region 2
@proto _FreeSysPages2			;free memory in system region 2
@proto _GetNumPhysPages			;get free/total physical pages
@proto _freephysmem				;free some mem in raw mode
@proto _restorephysmem			;restore the mem in raw mode
@proto _AllocUserSpace			;allocate user address space
@proto _FreeUserSpace			;free user address space
@proto _AllocSysAddrSpace		;allocate system address space
@proto _getaddrspace			;get free/total user address space
@proto _searchphysregion     	;search a mapped physical region
@proto _mapphysregion  	    	;map physical address to user space
@proto _ClonePage				;clone a page
@proto _SetPage					;set PTE for a linear address
@proto _setregionattributes		;set PTE bits for a region

;@proto seti15pages, near16
@proto pm_initserver_rm, near16 ;page mgr server init real-mode
@proto pm_initserver2_rm, near16;page mgr cleanup after prot-mode init
@proto pm_exitserver_rm, near16	;page mgr server exit real-mode
@proto pm_int15rm, near16

