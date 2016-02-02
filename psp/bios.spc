create or replace package bios is

	-- Author  : ADMINISTRATOR
	-- Created : 2015-5-11 11:28:55
	-- Purpose : read request, write response

	procedure init_req_pv;

	procedure read_request;

	procedure getblob
	(
		p_len  in pls_integer,
		p_blob in out nocopy blob
	);

	procedure parse_head;
	procedure parse_query;
	procedure parse_cookie;

	procedure wpi(i binary_integer);

	procedure write_frame(ftype pls_integer);

	procedure write_frame
	(
		ftype pls_integer,
		len   pls_integer,
		plen  pls_integer := 0
	);

	procedure write_frame
	(
		ftype pls_integer,
		v     in out nocopy varchar2
	);

	procedure write_head;

	procedure write_session;

	procedure write_end;

end bios;
/
