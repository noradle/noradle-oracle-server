create or replace package body k_mapping is

	procedure set is
		v_url  varchar2(4000) := r.getc('u$url');
		b_host pls_integer := instrb(v_url, '//');
		b_path pls_integer := instrb(v_url, '/', b_host + 1);
		b_qstr pls_integer := instrb(v_url, '?', b_path + 1);
		b_prog pls_integer := instrb(v_url, '/', b_qstr - lengthb(v_url) - 2);
		b_dbu  pls_integer := instrb(v_url, '/', b_prog - lengthb(v_url) - 2);
	begin
		r.setc('u$dir', substrb(v_url, b_path, b_prog - b_path + 1));
		if r.is_null('x$dbu') then
			r.setc('x$dbu', substrb(v_url, b_dbu + 1, b_prog - b_dbu - 1));
		end if;
		if b_qstr = 0 then
			r.setc('x$prog', substrb(v_url, b_prog + 1));
		else
			r.setc('x$prog', substrb(v_url, b_prog + 1, b_qstr - b_prog - 1));
		end if;
	end;

end k_mapping;
/
