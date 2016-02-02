create or replace package body scgi is

	procedure read_request is
		v_buf       varchar2(4000);
		v_start_pos pls_integer;
		v_head_len  pls_integer;
		v_body_len  pls_integer;
		v_nv_arr    st;
		i           pls_integer := 1;
	begin
		-- parse raw SCGI request completed
	
		-- step 1: get head length
		v_buf       := utl_tcp.get_text(pv.c, 8, true);
		v_start_pos := instrb(v_buf, ':');
		v_head_len  := to_number(substrb(v_buf, 1, v_start_pos - 1));
		k_debug.trace(st('start_pos,head_len', v_start_pos, v_head_len), 'SCGI');
		v_buf := utl_tcp.get_text(pv.c, v_start_pos + 1, false);
		v_buf := utl_tcp.get_text(pv.c, v_head_len, false);
	
		v_buf := translate(v_buf, chr(0), chr(30));
		t.split(v_nv_arr, v_buf, chr(30), false);
		loop
			v_buf := v_nv_arr(i);
			exit when v_buf = ',';
			if v_buf like 'HTTP_%' then
				v_buf := 'h$' || replace(lower(substrb(v_buf, 6)), '_', '-');
			end if;
			ra.params(v_buf) := st(v_nv_arr(i + 1));
			i := i + 2;
		end loop;
		-- assert i must equal to v_nv_arr.count
	
		-- step 2: get body
		v_body_len := to_number(v_nv_arr(2));
		k_debug.trace(st('body_len', v_body_len), 'SCGI');
		if v_body_len > 0 then
			-- todo: process header ahead
			bios.getblob(v_body_len, rb.blob_entity);
		end if;
		k_debug.trace(st('read complete'), 'SCGI');
	
		bios.parse_head;
		bios.parse_query;
		bios.parse_cookie;
	end;

end scgi;
/
