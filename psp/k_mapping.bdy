create or replace package body k_mapping is

	-- return false if can not determine x$dbu,x$prog
	function route return boolean is
		v      st;
		x$pos  varchar2(2);
		x$dbu  varchar2(30);
		x$prog varchar2(61);
		x$sect varchar2(60);
		v_pos  pls_integer; -- position for x$prog
		v_def  boolean; -- if use default dbu, and not extract from url path
		v_cnt  pls_integer; -- count of sections for REST url
	begin
		k_debug.trace(st('protocol,x$pos,x$dbu,x$prog', pv.protocol, r.getc('x$pos'), r.getc('x$dbu'), r.getc('x$prog')),
									'route');
	
		if pv.protocol != 'HTTP' then
			-- DATA|NDBC
			if r.is_null('x$dbu') then
				r.setc('x$dbu', pv.cc.dbu_default);
			end if;
			r.set_prog;
			return true;
		end if;
	
		t.split(v, substrb(r.pathname, 2), '/', false);
	
		x$pos := r.getc('x$pos');
		if x$pos is null then
			if pv.cc.dbu_default is null and r.is_null('x$dbu') then
				-- as /x$dbu/x$prog
				v_pos := 2;
				v_def := false;
			else
				-- as /x$prog
				v_pos := 1;
				v_def := true;
			end if;
		else
			v_pos := to_number(substrb(x$pos, 1, 1));
			v_def := substrb(x$pos, -1) != '+';
		end if;
	
		-- determine x$dbu, respect value from client
		if r.is_null('x$dbu') then
			if v_def then
				r.setc('x$dbu', pv.cc.dbu_default);
			elsif v_pos - 1 > 0 then
				r.setc('x$dbu', v(v_pos - 1));
			end if;
		end if;
	
		k_debug.trace(st('protocol,v_pos,x$dbu,x$prog', pv.protocol, v_pos, r.getc('x$dbu'), r.getc('x$prog')), 'route');
	
		-- todo: further dbu mapping
		-- map /path/prefix to dbu 
		-- according to config data or particular function
	
		-- check existence of x$dbu
		if r.is_null('x$dbu') then
			h.status_line(404);
			b.line('cannot determine x$dbu');
			k_debug.req_info;
			return false;
		end if;
	
		if r.getc('x$dbu') = 'public' then
			r.setc('x$dbu', lower(sys_context('userenv', 'CURRENT_USER')));
		end if;
	
		-- check access right for x$dbu
		if not k_cfg.allow_cid_dbu then
			h.status_line(500);
			h.content_type('text/plan');
			b.l('cid:' || r.cid || ' is not allowed to access dbu:' || r.dbu);
			return false;
		end if;
	
		if r.not_null('x$prog') then
			null; -- client has determined x$prog, just respect it
		elsif v_pos = 0 then
			null; -- x$dbu.x$before will determine x$prog
		elsif v.count = v_pos then
			r.setc('x$prog', nvl(v(v_pos), pv.cc.prog_default));
		elsif v.count > v_pos then
			-- REST URI as /type1/value1/type2/value2/... to type1_type2_h.service
			v_cnt := ceil((v.count - v_pos / 2));
			if v_cnt * 2 > v.count then
				-- as /area/022/sub/hexi/spot add trailing /
				v.extend;
			end if;
			for i in 1 .. v_cnt loop
				x$sect := v(v_pos + i * 2 - 2);
				r.setc(x$sect, v(i * 2 - 1));
				x$prog := x$prog || x$sect || '_';
			end loop;
			r.setc('x$prog', x$prog || 'h');
		else
			-- url path lack x$prog part, redirect is ok
			if v(v.count) is null then
				-- /dir redirect to /dir/
				h.redirect(r.pathname || '/', 302);
				return false;
			end if;
		end if;
	
		if r.not_null('x$prog') then
			r.set_prog;
		end if;
	
		return true;
	end;

end k_mapping;
/
