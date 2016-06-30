create or replace package body k_init is

	procedure by_response is
	begin
		-- initialize output flow control pv   
		pv.msg_stream := false;
		pv.use_stream := null;
		pv.bom        := null;
	
		output."_init"(80526);
		style.init_by_request; --todo: none-core, may be removed
		pv.headers.delete;
		pv.cookies.delete;
		pv.caches.delete;
		pv.status_code   := 200;
		pv.header_writen := false;
		pv.etag_md5      := false;
		pv.max_lmt       := null;
		pv.max_scn       := null;
		pv.allow         := null;
		pv.nlbr          := chr(10);
	
		if pv.protocol = 'HTTP' then
			h.content_type;
		elsif pv.protocol in ('DATA', 'NDBC') then
			h.content_type('text/resultsets', 'UTF-8');
		else
			h.content_type;
		end if;
		--h.content_encoding_auto;
	end;

	procedure by_request is
	begin
		-- further parse from env
		k_parser.parse_auto;
		if pv.protocol = 'HTTP' then
			pv.bsid := r.get('c$BSID');
			pv.msid := r.get('c$MSID');
		end if;
	end;

end k_init;
/
