create or replace package body http is

	-- parse as http://tools.ietf.org/html/rfc2616

	procedure parse_url(url varchar2) is
		v_slash pls_integer;
		v_quest pls_integer;
		v_lasts pls_integer;
	begin
		-- http://host:port/pathname?query
		v_slash := instrb(url, '/');
		v_lasts := instrb(url, '/', -1);
		v_quest := instrb(url, '?', v_slash + 1);
	
		ra.params('u$site') := st(substrb(1, v_slash - 1));
		ra.params('u$dir') := st(substrb(url, v_slash, v_lasts - v_slash + 1));
		if v_quest > 0 then
			ra.params('u$pathname') := st(substrb(url, v_slash, v_quest - v_slash));
			ra.params('u$prog') := st(substrb(url, v_lasts + 1, v_quest - v_lasts - 1));
			ra.params('u$qstr') := st(substrb(url, v_quest + 1));
		else
			ra.params('u$pathname') := st(substrb(url, v_slash));
			ra.params('u$prog') := st(substrb(url, v_lasts + 1));
			ra.params('u$qstr') := st('');
		end if;
	end;

	procedure parse_host is
		v_host  varchar2(100);
		v_colon pls_integer;
	begin
		v_host := r.getc('h$host');
		if v_host is null then
			null; -- extract from u$site or u$url;
		end if;
		v_colon := instrb(v_host, ':');
		if v_colon > 0 then
			ra.params('u$hostname') := st(substr(v_host, 1, v_colon - 1));
			ra.params('u$port') := st(substr(v_host, v_colon + 1));
		else
			ra.params('u$hostname') := st(v_host);
			ra.params('u$port') := st('');
		end if;
	end;

	procedure read_request is
		v_buf   varchar2(4000);
		v_pos   pls_integer;
		v_name  varchar2(1000);
		v_value varchar2(32000);
		v_blen  pls_integer;
		v_st    st;
	begin
		-- to parse raw HTTP request completely
		k_debug.trace(st('read request begin'), 'HTTP');
		pv.protocol := 'HTTP';
		pv.hp_flag  := false;
	
		-- step 1: read request line
		v_buf := utl_tcp.get_line(pv.c, true);
		t.split(v_st, v_buf, ' ');
		ra.params('u$method') := st(v_st(1));
		ra.params('u$url') := st(v_st(2));
		ra.params('u$proto') := st(v_st(3));
		parse_url(v_st(2));
		k_debug.trace(st('read request line end'), 'HTTP');
	
		-- step 2: read header name-value pairs
		loop
			v_buf := lower(trim(utl_tcp.get_line(pv.c, true)));
			exit when v_buf is null;
			v_pos := instrb(v_buf, ':');
			v_name := 'h$' || lower(trim(substrb(v_buf, 1, v_pos - 1)));
			v_value := lower(trim(substrb(v_buf, v_pos + 1)));
			ra.params('h$' || v_name) := st(v_value);
			k_debug.trace(st('read header', v_name, v_value), 'HTTP');
		end loop;
		k_debug.trace(st('read request headers end'), 'HTTP');
	
		-- step 3: parse raw name-value pairs to detail
		parse_host;
		k_debug.trace(st('parse request host end'), 'HTTP');
	
		-- step 3: get body
		v_blen := r.getn('content-length', 0);
		k_debug.trace(st('body_len', v_blen), 'HTTP');
		if v_blen > 0 then
			-- todo: process header ahead
			bios.getblob(v_blen, rb.blob_entity);
			k_debug.trace(st('read body complete'), 'HTTP');
		else
			k_debug.trace(st('read complete'), 'HTTP');
		end if;
	
		r.setc('x$dbu', 'demo1');
		r.setc('x$prog', 'basic_io_b.req_info');
		return;
	
		-- mapping  
		declare
			v_path varchar2(4000) := r.getc('DOCUMENT_URI');
			v_pos  pls_integer := instrb(v_path, '/', -1);
		begin
			r.setc('u$proto', lower(t.left(r.getc('SERVER_PROTOCOL'), '/')));
			r.setc('x$method', r.getc('REQUEST_METHOD'));
			r.setc('u$url', r.getc('REQUEST_URI'));
			r.setc('u$qstr', r.getc('QUERY_STRING'));
			r.setc('u$hostname', r.getc('SERVER_NAME'));
			r.setc('u$port', r.getc('SERVER_PORT'));
			r.setc('a$caddr', r.getc('REMOTE_ADDR'));
			r.setc('a$cport', r.getc('REMOTE_PORT'));
			r.setc('u$pathname', v_path);
			r.setc('u$dir', substrb(v_path, 1, v_pos - 1));
			r.setc('x$prog', substrb(v_path, v_pos + 1));
		
			r.setc('x$dbu', substrb(2, v_pos - 2));
			--r.setc('x$prog', 'basic_io_b.req_info');
		end;
	
	end;

	procedure init is
	begin
		h.header('connection', 'close');
	end;

end http;
/
