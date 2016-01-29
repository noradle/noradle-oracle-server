create or replace package body fcgi is

	procedure read_request is
		v_bytes   pls_integer;
		v_raw8    raw(8);
		v_version raw(1);
		v_type    pls_integer;
		v_req_id  raw(2);
		v_clen    pls_integer;
		v_plen    pls_integer;
		v_blen    pls_integer;
		v_rbuf    raw(32767);
	
		procedure read_wrapper is
		begin
			/*
      typedef struct {
          unsigned char version;
          unsigned char type;
          unsigned char requestIdB1;
          unsigned char requestIdB0;
          unsigned char contentLengthB1;
          unsigned char contentLengthB0;
          unsigned char paddingLength;
          unsigned char reserved;
          unsigned char contentData[contentLength];
          unsigned char paddingData[paddingLength];
      } FCGI_Record;
      */
			v_bytes   := utl_tcp.read_raw(pv.c, v_raw8, 8, false);
			v_version := utl_raw.substr(v_raw8, 1, 1);
			v_type    := utl_raw.cast_to_binary_integer(utl_raw.substr(v_raw8, 2, 1));
			v_req_id  := utl_raw.substr(v_raw8, 3, 2);
			v_clen    := utl_raw.cast_to_binary_integer(utl_raw.substr(v_raw8, 5, 2));
			v_plen    := utl_raw.cast_to_binary_integer(utl_raw.substr(v_raw8, 7, 1));
			v_blen    := v_clen + v_plen;
			k_debug.trace(st('read_wrapper(slot,type,len)', v_req_id, v_type, v_clen), 'FCGI');
		end;
	begin
		k_debug.trace(st('read request begin'), 'FCGI');
		loop
			read_wrapper;
			if v_blen > 0 then
				v_bytes := utl_tcp.read_raw(pv.c, v_rbuf, v_blen, false);
			end if;
			case v_type
				when 1 then
					-- FCGI_BEGIN_REQUEST
					-- get role
					null;
				when 4 then
					-- FCGI_PARAMS
					if v_blen = 0 then
						continue;
					end if;
					-- read params
				when 5 then
					-- FCGI_STDIN
					if v_blen = 0 then
						exit;
					end if;
					-- read data into lob
			end case;
		end loop;
		r.setc('x$dbu', 'demo1');
		r.setc('x$prog', 'basic_io_b.req_info');
		k_debug.trace(st('read request complete'), 'FCGI');
	end;

	function get_len(len pls_integer) return varchar2 is
	begin
		if len < 256 then
			return chr(len);
		else
			return utl_raw.cast_to_varchar2(utl_raw.cast_from_binary_integer(len));
		end if;
	end;

end fcgi;
/
