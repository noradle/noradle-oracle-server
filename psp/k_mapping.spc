create or replace package k_mapping is

	procedure x$prog_at_tail;

	function route return boolean;

end k_mapping;
/
