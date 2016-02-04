create or replace package body http is

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
		ra.params('u$protov') := st(v_st(3));
		k_debug.trace(st('read request line end'), 'HTTP');
	
		-- step 2: read header name-value pairs
		loop
			v_buf := lower(trim(utl_tcp.get_line(pv.c, true)));
			exit when v_buf is null;
			v_pos := instrb(v_buf, ':');
			v_name := 'h$' || lower(trim(substrb(v_buf, 1, v_pos - 1)));
			v_value := lower(trim(substrb(v_buf, v_pos + 1)));
			ra.params(v_name) := st(v_value);
			k_debug.trace(st('read header', v_name, v_value), 'HTTP');
		end loop;
		k_debug.trace(st('read request headers end'), 'HTTP');
	
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
	end;

	procedure init is
	begin
		case r.header('Connection')
			when 'close' then
				h.header('Connection', 'close');
			when 'keep-alive' then
				h.header('Connection', 'keep-alive');
			else
				h.header('Connection', 'close');
		end case;
	end;

end http;
/
