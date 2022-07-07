;*****************************************************************************
;*
;*                            Open Watcom Project
;*
;*    Portions Copyright (c) 1983-2002 Sybase, Inc. All Rights Reserved.
;*
;*  ========================================================================
;*
;*    This file contains Original Code and/or Modifications of Original
;*    Code as defined in and that are subject to the Sybase Open Watcom
;*    Public License version 1.0 (the 'License'). You may not use this file
;*    except in compliance with the License. BY USING THIS FILE YOU AGREE TO
;*    ALL TERMS AND CONDITIONS OF THE LICENSE. A copy of the License is
;*    provided with the Original Code and Modifications, and is also
;*    available at www.sybase.com/developer/opensource.
;*
;*    The Original Code and all software distributed under the License are
;*    distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
;*    EXPRESS OR IMPLIED, AND SYBASE AND ALL CONTRIBUTORS HEREBY DISCLAIM
;*    ALL SUCH WARRANTIES, INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF
;*    MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, QUIET ENJOYMENT OR
;*    NON-INFRINGEMENT. Please see the License for the specific language
;*    governing rights and limitations under the License.
;*
;*  ========================================================================
;*
;* Description:  Win32 console startup code.
;*
;*****************************************************************************


;       This must be assembled using one of the following commands:
;               wasm cstrtwnt -bt=NT -ms -3r
;               wasm cstrtwnt -bt=NT -ms -3s
;
	name cstrtwnt
	.386p
	assume nothing

	extrn __NTMain: near
	extrn ___begtext: near

	extrn ___kernel32init@0:near
	extrn _g_bIntFl:byte

_TEXT segment use32 word public 'CODE'

	public _cstart_
	public mainCRTStartup

	assume cs:_TEXT

mainCRTStartup proc near c
mainCRTStartup endp
_cstart_ proc near
	or [_g_bIntFl],2
	mov eax,esi
	call ___kernel32init@0	; initialize KERNEL32
	jmp __NTMain
	dd ___begtext			; reference module with segment definitions
;
; copyright message
;
include msgrt32.inc
include msgcpyrt.inc

_cstart_ endp

_TEXT ends

	end _cstart_
