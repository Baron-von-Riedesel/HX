
Regression tests for HDPMI16

I310102 : test int 31h, ax=0102h (fails for 16-bit only)
I310102a: test int 31h, ax=0102h (selector tiling)
mouevnt:  test int 33h, ax=000Ch (set mouse event proc)
int251:   test int 21h, ax=7305h (read FAT32 disk)
rawjmp7:  exc 0D in pm code that was "raw jumped" (didn't work in v3.18-3.19)
