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
				if n like 'HTTP_%' then
					n := 'h$' || replace(lower(substrb(n, 6)), '_', '-');
				end if;
				ra.params(n) := st(v);
				pos := pos + nlen + vlen;
				if pos > maxl then
					exit;
				end if;
			end loop;
		end;
	
		procedure init_request_body is
			v_pos pls_integer;
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
		
			dbms_lob.createtemporary(rb.blob_entity, cache => true, dur => dbms_lob.call);
		end;
	
	begin
		k_debug.trace(st('read request begin'), 'FCGI');
		rb.length := null;
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
						if rb.length is null then
							init_request_body;
						end if;
						v_bytes := utl_tcp.read_raw(pv.c, v_rbuf, v_blen, false);
						dbms_lob.writeappend(rb.blob_entity, v_clen, v_rbuf);
					else
						exit;
					end if;
			end case;
		end loop;
	
		bios.parse_head;
		bios.parse_query;
	
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
