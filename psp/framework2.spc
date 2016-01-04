create or replace package framework2 is

	procedure entry
	(
		cfg_id  varchar2 := null,
		slot_id pls_integer := 1
	);

end framework2;
/
