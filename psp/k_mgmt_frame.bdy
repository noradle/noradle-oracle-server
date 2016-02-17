create or replace package body k_mgmt_frame is

	procedure cli_cfg is
		v_st  st;
		v_res varchar2(4000);
	begin
		v_st  := st('cid',
								pv.cc.cid,
								'cseq',
								r.getc('b$cseq'),
								'min_concurrency',
								nvl(pv.cc.min_concurrency, 0),
								'max_concurrency',
								nvl(pv.cc.max_concurrency, 0));
		v_res := t.join(v_st, chr(0));
		bios.write_frame(5, v_res);
	exception
		when no_data_found then
			null;
	end;

	procedure ask_osp is
		v_return integer;
	begin
		dbms_pipe.pack_message('ASK_OSP');
		dbms_pipe.pack_message(pv.cfg_id);
		dbms_pipe.pack_message(r.getn('queue_len'));
		dbms_pipe.pack_message(r.getn('oslot_cnt'));
		v_return := dbms_pipe.send_message('Noradle-PMON');
	end;

	-- return true for quit, false for continue
	function response return boolean is
	begin
		case r.getc('b$mgmtype')
			when 'QUIT' then
				k_debug.trace(st(pv.clinfo, 'signaled QUIT'), 'dispatcher');
				return true;
			when 'KEEPALIVE' then
				pv.keep_alive := r.getn('keepAliveInterval', 60);
			when 'ASK_OSP' then
				ask_osp;
			when 'CLI_CFG' then
				cli_cfg;
			else
				null;
		end case;
		return false;
	end;

end k_mgmt_frame;
/
