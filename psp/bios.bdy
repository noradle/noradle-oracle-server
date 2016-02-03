create or replace package body bios is

	-- for unit test only
	procedure init_req_pv is
	begin
		ra.params.delete;
		rc.params.delete;
		rb.charset_http := null;
		rb.charset_db   := null;
		rb.blob_entity  := null;
		rb.clob_entity  := null;
		rb.nclob_entity := null;
	end;

	procedure getblob
	(
		p_len  in pls_integer,
		p_blob in out nocopy blob
	) is
		v_pos  pls_integer;
		v_raw  raw(32767);
		v_size pls_integer;
		v_read pls_integer := 0;
		v_rest pls_integer := p_len;
	begin
		rb.charset_http := null;
		rb.charset_db   := null;
		rb.blob_entity  := null;
		rb.clob_entity  := null;
		rb.nclob_entity := null;
	
		v_pos           := instrb(r.header('content-type'), '=');
		rb.charset_http := t.tf(v_pos > 0, trim(substr(r.header('content-type'), v_pos + 1)), 'UTF-8');
		rb.charset_db   := utl_i18n.map_charset(rb.charset_http, utl_i18n.generic_context, utl_i18n.iana_to_oracle);
		v_pos           := instrb(r.header('content-type') || ';', ';');
		rb.mime_type    := substrb(r.header('content-type'), 1, v_pos - 1);
		rb.length       := r.getn('h$content-length');
	
		dbms_lob.createtemporary(p_blob, cache => true, dur => dbms_lob.call);
		loop
			v_size := utl_tcp.read_raw(pv.c, v_raw, least(32767, v_rest));
			v_rest := v_rest - v_size;
			dbms_lob.writeappend(p_blob, v_size, v_raw);
			exit when v_rest = 0;
		end loop;
	end;

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
			b_prog pls_integer := instrb(v_url, '/', b_qstr - lengthb(v_url) - 2);
			b_dbu  pls_integer := instrb(v_url, '/', b_prog - lengthb(v_url) - 2);
			v_qstr varchar2(4000);
			v_host varchar2(200);
			b_port pls_integer;
			b_ver  pls_integer;
			v_prv  varchar2(30);
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
		
			r.setc('u$dir', substrb(v_url, b_path, b_prog - b_path + 1));
			if r.is_null('x$dbu') then
				r.setc('x$dbu', substrb(v_url, b_dbu + 1, b_prog - b_dbu - 1));
			end if;
			if b_qstr = 0 then
				r.setc('u$pathname', substrb(v_url, b_path));
				r.setc('u$search', '');
				r.setc('x$prog', substrb(v_url, b_prog + 1));
				v_qstr := '';
			else
				r.setc('u$pathname', substrb(v_url, b_path, b_qstr - b_path));
				r.setc('u$search', substrb(v_url, b_qstr));
				r.setc('x$prog', substrb(v_url, b_prog + 1, b_qstr - b_prog - 1));
				v_qstr := substrb(v_url, b_qstr + 1);
			end if;
			r.setc('u$qstr', v_qstr);
		
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

	/**
  for request header frame
  v_type(int8) must be 0 (head frame)
  v_len(int32) is just ignored 
  */
	procedure read_request is
		v_bytes pls_integer;
		v_raw4  raw(4);
		v_slot  pls_integer;
		v_type  raw(1);
		v_flag  raw(1);
		v_len   pls_integer;
		v_st    st;
		v_cbuf  varchar2(4000 byte);
		procedure read_wrapper is
		begin
			v_bytes := utl_tcp.read_raw(pv.c, v_raw4, 4, false);
			v_slot  := trunc(utl_raw.cast_to_binary_integer(v_raw4) / 65536);
			v_type  := utl_raw.substr(v_raw4, 3, 1);
			v_flag  := utl_raw.substr(v_raw4, 4, 1);
			v_bytes := utl_tcp.read_raw(pv.c, v_raw4, 4, false);
			v_len   := utl_raw.cast_to_binary_integer(v_raw4);
			k_debug.trace(st('read_wrapper(slot,type,flag,len)', v_slot, v_type, v_flag, v_len), 'bios');
		end;
	begin
		ra.params.delete;
		rc.params.delete;
	
		if false and pv.disproto = 'HTTP' then
			goto actual;
		end if;
	
		read_wrapper;
		pv.cslot_id := v_slot;
	
		if v_slot = 0 then
			-- it's management frame
			ncgi.read_nv;
			return;
		end if;
	
		-- a request prefix header, protocol,cid,cSlotID,
		k_debug.time_header_init;
		v_bytes := utl_tcp.read_text(pv.c, v_cbuf, v_len, false);
		k_debug.trace(st('read prehead', v_len, v_bytes, v_cbuf), 'bios');
		t.split(v_st, v_cbuf, ',');
		pv.disproto := v_st(1);
		ra.params('b$protocol') := st(v_st(1));
		ra.params('b$cid') := st(v_st(2));
		ra.params('b$cslot') := st(v_st(3));
	
		<<actual>>
	
		if pv.disproto != 'NORADLE' then
			pv.protocol := 'HTTP';
		end if;
	
		case pv.disproto
			when 'NORADLE' then
				-- read nv header
				read_wrapper;
				ncgi.read_nv;
				-- read body frames until met end frame
				loop
					read_wrapper;
					exit when v_len = 0;
					k_debug.trace(st('getblob', v_len), 'bios');
					getblob(v_len, rb.blob_entity);
				end loop;
			when 'HTTP' then
				http.read_request;
			when 'SCGI' then
				scgi.read_request;
			when 'FCGI' then
				fcgi.read_request;
			else
				null;
		end case;
	
	end;

	procedure wpi(i binary_integer) is
	begin
		pv.wlen := utl_tcp.write_raw(pv.c, utl_raw.cast_from_binary_integer(i));
	end;

	procedure write_frame(ftype pls_integer) is
	begin
		k_debug.trace(st('write(ftype,len)', ftype, 0), 'bios');
		wpi(pv.cslot_id * 256 * 256 + ftype * 256 + 0);
		wpi(0);
	end;

	procedure write_frame
	(
		ftype pls_integer,
		len   pls_integer,
		plen  pls_integer := 0
	) is
	begin
		k_debug.trace(st('write(ftype,len)', ftype, len), 'bios');
		wpi(pv.cslot_id * 256 * 256 + ftype * 256 + plen);
		wpi(len);
	end;

	procedure write_frame
	(
		ftype pls_integer,
		v     in out nocopy varchar2
	) is
		v_plen pls_integer := 0;
	begin
		if v is null then
			write_frame(ftype);
		else
			if pv.disproto = 'FCGI' then
				v_plen := 8 - mod(lengthb(v), 8);
				if v_plen = 8 then
					v_plen := 0;
				else
					v := v || rpad(' ', v_plen);
				end if;
			end if;
			write_frame(ftype, lengthb(v), v_plen);
			pv.wlen := utl_tcp.write_text(pv.c, v);
		end if;
		-- pv.wlen := utl_tcp.write_raw(pv.c, hextoraw(pv.bom));
	end;

	procedure write_end is
	begin
		if pv.disproto = 'FCGI' then
			write_frame(255, 8, 0);
			wpi(pv.status_code);
			wpi(0);
		else
			write_frame(255);
		end if;
	end;

	procedure write_head is
		v  varchar2(4000);
		nl varchar2(2) := chr(13) || chr(10);
		n  varchar2(30);
		cc varchar2(100) := '';
	begin
		if pv.disproto = 'FCGI' then
			pv.headers.delete('Content-Encoding');
		end if;
		v := r.getc('u$protov', 'HTTP/1.1') || ' ' || pv.status_code || nl || 'Date: ' || t.hdt2s(sysdate) || nl;
		n := pv.headers.first;
		while n is not null loop
			v := v || n || ': ' || pv.headers(n) || nl;
			n := pv.headers.next(n);
		end loop;
	
		n := pv.caches.first;
		while n is not null loop
			if pv.caches(n) = 'Y' then
				cc := cc || ', ' || n;
			else
				cc := cc || ', ' || n || '=' || pv.caches(n);
			end if;
			n := pv.caches.next(n);
		end loop;
		if cc is not null then
			v := v || 'Cache-Control: ' || substrb(cc, 3) || nl;
		end if;
	
		n := pv.cookies.first;
		while n is not null loop
			v := v || 'Set-Cookie: ' || pv.cookies(n) || nl;
			n := pv.cookies.next(n);
		end loop;
	
		v := v || nl;
		if pv.entry is null then
			dbms_output.put_line(v);
		else
			write_frame(0, v);
		end if;
	end;

	procedure write_session is
		nl varchar2(2) := chr(13) || chr(10);
		n  varchar2(30);
		v  varchar2(4000) := 'n: v' || nl;
	begin
		n := rc.params.first;
		while n is not null loop
			v := v || n || ': ' || t.join(rc.params(n), '~') || nl;
			n := rc.params.next(n);
		end loop;
		if rc.params.first is not null then
			write_frame(2, v);
		end if;
	end;

end bios;
/
