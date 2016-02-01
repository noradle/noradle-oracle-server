create or replace package body fcgi is

	procedure read_request is
		v_bytes   pls_integer;
		v_raw8    raw(8);
		v_chr8    varchar2(8);
		v_version raw(1);
		v_type    pls_integer;
		v_req_id  raw(2);
		v_clen    pls_integer;
		v_plen    pls_integer;
		v_blen    pls_integer;
		v_cbuf    varchar2(32767 byte);
		v_rbuf    raw(32767);
		v_params  varchar2(32767 byte);
	
		procedure read_header is
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
	
		procedure read_params is
			nlen pls_integer;
			vlen pls_integer;
			c    char(1);
			n    varchar2(256);
			v    varchar2(8000);
			pos  pls_integer := 1;
			maxl pls_integer := lengthb(v_params);
		begin
			loop
				c := substrb(v_params, pos, 1);
				if c < chr(128) then
					nlen := ascii(c);
					pos  := pos + 1;
				else
					nlen := utl_raw.cast_to_binary_integer(utl_raw.cast_to_raw(substrb(v_params, pos, 4)));
					pos  := pos + 4;
				end if;
				c := substrb(v_params, pos, 1);
				if c < chr(128) then
					vlen := ascii(c);
					pos  := pos + 1;
				else
					vlen := utl_raw.cast_to_binary_integer(utl_raw.cast_to_raw(substrb(v_params, pos, 4)));
					pos  := pos + 4;
				end if;
				n := substrb(v_params, pos, nlen);
				v := substrb(v_params, pos + nlen, vlen);
				k_debug.trace(st('nv', n, v), 'FCGI');
				if n like 'HTTP%' then
					n := 'h$' || lower(substrb(n, 6));
				end if;
				ra.params(n) := st(v);
				pos := pos + nlen + vlen;
				if pos > maxl then
					exit;
				end if;
			end loop;
		end;
	
	begin
		k_debug.trace(st('read request begin'), 'FCGI');
		loop
			read_header;
			case v_type
				when 1 then
					-- FCGI_BEGIN_REQUEST
					-- get role
					v_bytes := utl_tcp.read_raw(pv.c, v_rbuf, v_blen, false);
				when 4 then
					-- FCGI_PARAMS
					if v_blen > 0 then
						-- read params (set or append)
						v_bytes := utl_tcp.read_text(pv.c, v_cbuf, v_clen, false);
						if v_plen > 0 then
							v_bytes := utl_tcp.read_text(pv.c, v_chr8, v_plen, false);
						end if;
						if v_params is null then
							v_params := v_cbuf;
						else
							v_params := v_params || v_cbuf;
						end if;
					else
						read_params;
					end if;
				when 5 then
					-- FCGI_STDIN
					k_debug.trace(st('read FCGI_STDIN', v_blen), 'FCGI');
					if v_blen > 0 then
						v_bytes := utl_tcp.read_raw(pv.c, v_rbuf, v_blen, false);
					else
						exit;
					end if;
					-- read data into lob
			end case;
		end loop;
		r.setc('x$dbu', 'demo1');
		r.setc('x$prog', 'basic_io_b.req_info');
	
		-- further parse params
		-- u$url http://hostname:port/dir/prog?query
		-- utl_url.unescape(get('u$url'), pv.cs_req);
		declare
			v_url  varchar2(4000) := r.getc('u$url');
			b_host pls_integer := instrb(v_url, '//');
			b_path pls_integer := instrb(v_url, '/', b_host + 1);
			b_prog pls_integer := instrb(v_url, '/', -1);
			b_dbu  pls_integer := instrb(v_url, '/', -1, 2);
			b_qstr pls_integer := instrb(v_url, '?', b_path + 1);
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
