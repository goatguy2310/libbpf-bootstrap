SECTIONS
{

	my_pid = 0xfffffffffffffffa;

	. = 0x400000;
	.text : { *(.text) }
	.rodata 0xffffffff00000000 : { *(.rodata*) }

	/DISCARD/ :
	{
		*(.eh_frame*)
		
		*(.interp)
		*(.dynamic)
		*(.dynsym)
		*(.dynstr)
		*(.hash)
		*(.gnu.hash)

		*(.comment)
		*(.note*)
	}
}
