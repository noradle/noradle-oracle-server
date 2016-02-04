create or replace package body k_parser is

	procedure parse_head is
	begin
		-- further parse params from request line
		-- u$url http://hostname:port/dir/prog?query
		-- utl_url.unescape(get('u$url'), pv.cs_req);
		declare
			v_url  varchar2(4000) := r.getc('u$url');
			b_host pls_integer := instrb(v_url, '//');
			b_path pls_integer := instrb(v_url, '/', b_host + 1);
			b_qstr pls_integer := instrb(v_url, '?', b_path + 1);
			v_host varchar2(200);
			b_port pls_integer;
			b_ver  pls_integer;
			v_prv  varchar2(30);
			v_path varchar2(4000);
			v_sect st;
			v_addr varchar2(30) := r.getc('a$saddr');
		begin
		
			v_prv := lower(r.getc('u$protov'));
			if v_prv is not null then
				b_ver := instrb(v_prv, '/');
				if b_ver > 0 then
					r.setc('u$proto', substrb(v_prv, 1, b_ver - 1));
				else
					r.setc('u$proto', v_prv);
				end if;
			else
				r.setc('u$proto', 'ndbc');
			end if;
		
			if r.is_null('h$host') then
				v_host := substrb(v_url, b_host + 2, b_path - b_host - 2);
			else
				v_host := r.getc('h$host');
			end if;
			r.setc('u$host', v_host);
			b_port := instrb(v_host, ':');
			if b_port = 0 then
				r.setc('u$hostname', v_host);
			else
				r.setc('u$hostname', substrb(v_host, 1, b_port - 1));
				r.setc('u$port', substrb(v_host, b_port + 1));
			end if;
		
			if b_qstr = 0 then
				v_path := substrb(v_url, b_path);
				r.setc('u$search', '');
				r.setc('u$qstr', '');
			else
				v_path := substrb(v_url, b_path, b_qstr - b_path);
				r.setc('u$search', substrb(v_url, b_qstr));
				r.setc('u$qstr', substrb(v_url, b_qstr + 1));
			end if;
			t.split(v_sect, substrb(v_path, 2), '/', false);
			ra.params('u$pathname') := st(v_path);
			ra.params('u$sect') := v_sect;
		
			-- address
			if v_addr like '%.%.%.%' then
				r.setc('a$sfami', 'IPv4');
			elsif instrb(v_addr, '/') > 0 then
				r.setc('a$sfami', 'PIPE');
			else
				r.setc('a$sfami', 'IPv6');
			end if;
		end;
	end parse_head;

	procedure parse_query is
		v_qry varchar2(32767) := r.qstr;
		v_nvs st;
		n     varchar2(4000);
		v     varchar2(4000);
	begin
		if instrb(v_qry, '=') = 0 then
			v_qry := '';
		end if;
		if r.method = 'POST' and rb.mime_type = 'application/x-www-form-urlencoded' then
			r.body2clob;
			v_qry := rb.clob_entity || '&' || v_qry;
		end if;
		t.split(v_nvs, v_qry, '&', false);
		for i in 1 .. v_nvs.count loop
			t.half(v_nvs(i), n, v, '=');
			n := trim(n);
			if n is null then
				continue;
			elsif not ra.params.exists(n) then
				ra.params(n) := st(trim(v));
			else
				ra.params(n).extend(1);
				ra.params(n)(ra.params(n).count) := v;
			end if;
		end loop;
	end;

	procedure parse_cookie is
		nvs st;
		n   varchar2(64);
		v   varchar2(4000);
	begin
		if r.is_null('h$cookie') then
			return;
		end if;
		t.split(nvs, r.header('cookie'), ';', false);
		for i in 1 .. nvs.count loop
			t.half(nvs(i), n, v, '=');
			if n is null then
				continue;
			end if;
			n := 'c$' || trim(n);
			if not ra.params.exists(n) then
				ra.params(n) := st(trim(v));
			else
				ra.params(n).extend(1);
				ra.params(n)(ra.params(n).count) := trim(v);
			end if;
		end loop;
	end;

	procedure parse_auth is
		v_credential varchar2(100);
		v_auth_type  varchar2(30);
		v_auth_data  varchar2(100);
		v_user       varchar2(60);
		v_pass       varchar2(30);
	begin
		v_credential := r.getc('h$authorization');
		if v_credential is null then
			return;
		end if;
		t.half(v_credential, v_auth_type, v_auth_data, ' ');
		if v_auth_type = 'Basic' then
			v_auth_data := utl_encode.text_decode(v_auth_data, encoding => utl_encode.base64);
			t.half(v_auth_data, v_user, v_pass, ':');
			r.setc('i$user', v_user);
			r.setc('i$pass', v_pass);
		end if;
	end;

	procedure parse_prog is
		v_prog varchar2(61);
		p_dot  pls_integer;
	begin
		v_prog := r.getc('x$prog');
		p_dot  := instrb(v_prog, '.');
		if p_dot >= 1 then
			r.setc('x$pack', substrb(v_prog, 1, p_dot - 1));
			r.setc('x$proc', substrb(v_prog, p_dot + 1));
		else
			r.setc('x$pack', '');
			r.setc('x$proc', v_prog);
		end if;
	end;

end k_parser;
/
