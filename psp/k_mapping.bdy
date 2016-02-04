create or replace package body k_mapping is

	procedure set is
		v_path varchar2(4000) := r.getc('u$pathname');
		b_host pls_integer := instrb(v_path, '//');
		b_path pls_integer := instrb(v_path, '/', b_host + 1);
		b_prog pls_integer := instrb(v_path, '/', -2);
		b_dbu  pls_integer := instrb(v_path, '/', b_prog - lengthb(v_path) - 2);
	begin
		r.setc('u$dir', substrb(v_path, b_path, b_prog - b_path + 1));
		if r.is_null('x$dbu') then
			r.setc('x$dbu', substrb(v_path, b_dbu + 1, b_prog - b_dbu - 1));
		end if;
		r.setc('x$prog', substrb(v_path, b_prog + 1));
	end;

end k_mapping;
/
