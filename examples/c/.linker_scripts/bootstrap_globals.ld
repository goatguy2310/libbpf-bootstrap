SECTIONS
{
	exec_start = 0xfffffffffffffffa;
	rb = 0xfffffffffffffffb;
	min_duration_ns = 0xfffffffffffffffc;

	.rodata : { *(.rodata*)} :writable_data
}

PHDRS
{
	writable_data PT_LOAD FLAGS(6);
}
