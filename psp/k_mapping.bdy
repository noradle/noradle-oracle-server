create or replace package body k_mapping is

	procedure x$prog_at_tail is
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

	function route return boolean is
		v      st;
		x$pos  pls_integer;
		x$prog varchar2(61);
		x$dbu  varchar2(30);
	begin
		t.split(v, substrb(r.pathname, 2), '/', false);
		x$pos := r.getn('x$pos');
		if x$pos is null then
			x$prog_at_tail;
		else
			x$prog := v(x$pos);
			if x$prog is not null then
				r.setc('x$prog', v(x$prog));
			end if;
			if r.is_null('x$dbu') then
				x$dbu := v(x$pos - 1);
				r.setc('x$dbu', v(x$dbu));
			end if;
		end if;
	
		if r.is_null('x$dbu') or r.is_null('x$prog') then
			h.status_line(404);
			k_debug.req_info;
			return false;
		end if;
	
		-- this is for become user
		-- check if cid can access dbu
		if r.getc('x$dbu') = 'public' then
			r.setc('x$dbu', lower(sys_context('userenv', 'CURRENT_USER')));
		end if;
		if not k_cfg.allow_cid_dbu then
			h.status_line(500);
			h.content_type('text/plan');
			b.l('cid:' || r.cid || ' is not allowed to access dbu:' || r.dbu);
			return false;
		end if;
		if substrb(r.getc('x$prog'), -2) in ('_t', '_v') then
			-- check if cid can direct access table/view directly
			if not k_cfg.allow_cid_sql then
				h.status_line(500);
				h.content_type('text/plan');
				b.l('cid:' || r.cid || ' is not allowed to access table/view/sql directly!');
				return false;
			end if;
			r.setc('x$prog', 'k_sql.get');
		else
			k_parser.parse_prog;
		end if;
		r."_after_map";
		dbms_application_info.set_module(r.dbu || '.' || nvl(r.pack, r.proc), t.tf(r.pack is null, 'standalone', r.proc));
	
		if false then
			r.setc('x$dbu_', r.getc('x$dbu'));
			r.setc('x$prog_', r.getc('x$prog'));
			r.setc('x$dbu', 'demo1');
			r.setc('x$prog', 'basic_io_b.req_info');
		end if;
	
		return true;
	end;

end k_mapping;
/
