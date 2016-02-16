create or replace package body framework is

	/* main functions
  0. establish connection to nodejs and listen for request
  1. (x) control lifetime by max requests and max runtime
  2. switch to target user current_schema
  3. collect request cpu/ellapsed time
  4. collect hprof statistics
  5. graceful quit, signal quit and accept quit control frame, then quit
  6. keep alive with dispatcher
  7. exit when ora-600 ora-7445 occurred
  */

	procedure entry
	(
		cfg_id  varchar2 := null,
		slot_id pls_integer := 1
	) is
		v_done    boolean := false;
		v_quit    boolean := false;
		v_qcode   pls_integer := -20526;
		v_clinfo  varchar2(64);
		v_timeout pls_integer := 3;
		v_maxwcnt pls_integer := 3;
		v_count   pls_integer;
		v_sts     number := -1;
		v_return  integer;
		v_res     varchar2(4000);
	
		v_svr_stime   date := sysdate;
		v_svr_req_cnt pls_integer := 0;
	
		v_cfg server_control_t%rowtype;
	
		-- private 
		procedure close_conn is
		begin
			if pv.c.remote_host is not null then
				utl_tcp.close_connection(pv.c);
				pv.c := null;
			end if;
		exception
			when utl_tcp.network_error then
				null;
			when others then
				k_debug.trace(st('close_conn_error', sqlcode, sqlerrm), 'keep_conn');
		end;
	
		-- private
		procedure make_conn is
			v_sid  pls_integer;
			v_seq  pls_integer;
			v_spid pls_integer;
			data   varchar2(1000);
			status varchar2(1000);
			procedure header(n varchar2) is
			begin
				pv.wlen := utl_tcp.write_line(pv.c, 'x-' || n || ': ' || sys_context('USERENV', n));
			end;
			procedure header
			(
				n varchar2,
				v varchar2
			) is
			begin
				pv.wlen := utl_tcp.write_line(pv.c, 'x-' || n || ': ' || v);
			end;
		begin
			pv.c := utl_tcp.open_connection(v_cfg.gw_host,
																			v_cfg.gw_port,
																			charset         => null,
																			in_buffer_size  => 32767,
																			out_buffer_size => 0,
																			tx_timeout      => v_timeout);
			select s.sid, s.serial#, p.spid
				into v_sid, v_seq, v_spid
				from v$session s, v$process p
			 where s.paddr = p.addr
				 and s.sid = sys_context('userenv', 'sid');
		
			-- write handshake request
			pv.wlen := utl_tcp.write_line(pv.c, 'GET / HTTP/1.1');
			pv.wlen := utl_tcp.write_line(pv.c, 'host: ' || v_cfg.gw_host || ':' || v_cfg.gw_port);
			pv.wlen := utl_tcp.write_line(pv.c, 'connection: upgrade');
			pv.wlen := utl_tcp.write_line(pv.c, 'upgrade: websocket');
			header('noradle-role', 'oracle');
			header('db_name');
			header('db_unique_name');
			header('database_role');
			header('instance');
			header('db_domain');
			header('cfg_id', pv.cfg_id);
			header('oslot_id', pv.in_seq);
			header('sid', v_sid);
			header('serial', v_seq);
			header('spid', v_spid);
			header('age', floor((sysdate - v_svr_stime) * 24 * 60));
			header('reqs', v_svr_req_cnt);
			header('idle_timeout', nvl(v_cfg.idle_timeout, 0));
			pv.wlen := utl_tcp.write_line(pv.c, '');
		
			-- read handshake response
			loop
				begin
					pv.wlen := utl_tcp.read_line(pv.c, data, true, false);
					if status is null then
						if data like 'HTTP/% 101 %' then
							-- receive response ok
							status := data;
						else
							raise utl_tcp.network_error;
						end if;
					elsif data is null then
						-- end of http response header
						return;
					end if;
				exception
					when utl_tcp.transfer_timeout then
						-- allow 3s for handshake response after handshake request write
						raise utl_tcp.network_error;
					when utl_tcp.end_of_input then
						raise utl_tcp.network_error;
				end;
			end loop;
		end;
	
		procedure get_cli_cfg is
			v_st st;
			v    client_control_t%rowtype;
		begin
			v.cid := r.getc('m$cid');
			select a.* into v from client_control_t a where a.cid = v.cid;
			v_st  := st('cid',
									v.cid,
									'cseq',
									r.getc('m$cseq'),
									'min_concurrency',
									nvl(v.min_concurrency, 0),
									'max_concurrency',
									nvl(v.max_concurrency, 0));
			v_res := t.join(v_st, chr(0));
		exception
			when no_data_found then
				null;
		end;
	
		function got_quit_signal return boolean is
		begin
			v_sts := dbms_pipe.receive_message(v_clinfo, 0);
			if v_sts not in (0, 1) then
				k_debug.trace(st(v_clinfo, 'got signal ' || v_sts), 'dispatcher');
			end if;
			return v_sts = 0;
		end;
	
		procedure signal_quit is
		begin
			-- only signal dispatcher to quit once
			if v_quit then
				return;
			end if;
			v_quit      := true;
			pv.cslot_id := 0;
			bios.write_frame(255);
		end;
	
		procedure do_quit is
		begin
			k_debug.trace(st(v_clinfo, 'call quit'), 'dispatcher');
			raise_application_error(v_qcode, '');
		end;
	
		procedure show_exception is
		begin
			k_debug.trace(st('system exception(url,cfg_id,sqlcode,sqlerrm,error_backtrace)',
											 r.url,
											 pv.cfg_id,
											 sqlcode,
											 sqlerrm,
											 dbms_utility.format_error_backtrace));
			h.status_line(500);
			h.content_type('text/plain');
			b.line(dbms_utility.format_error_stack);
		end;
	
	begin
		execute immediate 'alter session set nls_date_format="yyyy-mm-dd hh24:mi:ss"';
		if cfg_id is null then
			select a.job_name
				into v_clinfo
				from user_scheduler_running_jobs a
			 where a.session_id = sys_context('userenv', 'sid');
			pv.cfg_id := substr(v_clinfo, 9, lengthb(v_clinfo) - 8 - 5);
			pv.in_seq := to_number(substr(v_clinfo, -4));
		else
			pv.cfg_id := cfg_id;
			pv.in_seq := slot_id;
			v_clinfo  := 'Noradle-' || cfg_id || ':' || ltrim(to_char(slot_id, '0000'));
		end if;
	
		select count(*) into v_count from v$session a where a.client_info = v_clinfo;
		if v_count > 0 then
			dbms_output.put_line('Noradle Server Status:inuse. quit');
			dbms_application_info.set_client_info('');
			return;
		end if;
		dbms_application_info.set_client_info(v_clinfo);
		dbms_application_info.set_module('free', null);
		dbms_pipe.purge(v_clinfo);
		k_cfg.server_control(v_cfg);
		pv.entry := 'framework.entry';
	
		<<make_connection>>
		dbms_application_info.set_module('utl_tcp', 'open_connection');
		loop
			begin
				close_conn;
				k_debug.trace(st(v_clinfo, 'try connect to dispatcher'), 'dispatcher');
				make_conn;
				pv.prehead := null;
				exit;
				k_debug.trace(st(v_clinfo, 'connected to dispatcher'), 'dispatcher');
			exception
				when utl_tcp.network_error then
					if sysdate > v_svr_stime + v_cfg.max_lifetime then
						k_debug.trace(st(v_clinfo, 'max lifetime reached'), 'dispatcher');
						do_quit; -- quit immediately in disconnected state
					end if;
					if got_quit_signal then
						k_debug.trace(st(v_clinfo, 'quit signal received'), 'dispatcher');
						do_quit; -- quit immediately in disconnected state
					end if;
					pv.c := null;
					-- do not continuiously try connect to waste computing resource
					dbms_lock.sleep(1);
			end;
		end loop;
	
		loop
			dbms_application_info.set_module('utl_tcp', 'get_line');
			--k_debug.trace(st(v_clinfo, 'wait reqeust'), 'dispatcher');
		
			-- request quit when max requests reached
			v_svr_req_cnt := v_svr_req_cnt + 1;
			if v_svr_req_cnt > v_cfg.max_requests then
				k_debug.trace(st(v_clinfo, 'over max requests'), 'dispatcher');
				signal_quit;
			end if;
		
			v_count := 0;
			<<read_request>>
		
			-- request quit when max lifetime reached
			if sysdate > v_svr_stime + v_cfg.max_lifetime then
				k_debug.trace(st(v_clinfo, 'over max lifetime'), 'dispatcher');
				signal_quit;
			end if;
		
			-- request quit when quit pipe signal arrived
			if got_quit_signal then
				k_debug.trace(st(v_clinfo, 'got quit signal'), 'dispatcher');
				signal_quit;
			end if;
		
			-- accept arrival of new request
			begin
				v_count := v_count + 1;
				bios.read_request;
				pv.headers.delete;
				k_debug.time_header('after-read');
			exception
				when utl_tcp.transfer_timeout then
					if v_count > v_maxwcnt then
						-- after keep-alive time, no data arrived, think it as lost connection
						k_debug.trace(st(v_clinfo, 'over idle timeout'), 'dispatcher');
						do_quit;
					else
						goto read_request;
					end if;
				when utl_tcp.end_of_input then
					k_debug.trace(st(v_clinfo, 'end of tcp'), 'dispatcher');
					do_quit;
			end;
		
			if pv.cslot_id = 0 then
				case pv.protocol
					when 'QUIT' then
						k_debug.trace(st(v_clinfo, 'signaled QUIT'), 'dispatcher');
						do_quit;
					when 'KEEPALIVE' then
						v_maxwcnt := floor(r.getn('keepAliveInterval', 60) + 3 / v_timeout);
						k_debug.trace(st(v_clinfo, 'signaled KEEPALIVE', v_maxwcnt), 'dispatcher');
						v_count := 0;
					when 'ASK_OSP' then
						dbms_pipe.pack_message('ASK_OSP');
						dbms_pipe.pack_message(pv.cfg_id);
						dbms_pipe.pack_message(r.getn('queue_len'));
						dbms_pipe.pack_message(r.getn('oslot_cnt'));
						v_return := dbms_pipe.send_message('Noradle-PMON');
					when 'CLI_CFG' then
						get_cli_cfg;
						bios.write_frame(5, v_res);
					else
						null;
				end case;
				continue;
			end if;
		
			if pv.hp_flag then
				dbms_hprof.start_profiling('PLSHPROF_DIR', v_clinfo || '.trc');
				pv.hp_label := '';
			end if;
		
			-- read & parse request info and do init work
			pv.firstpg := true;
			begin
				-- further parse from env
				k_parser.parse_head;
				k_parser.parse_query;
				k_parser.parse_cookie;
				k_parser.parse_auth;
				if r.getb('U$proxy', false) then
					k_parser.parse_forwards;
				end if;
				case pv.disproto
					when 'NORADLE' then
						-- as http, http2, fast-cgi, spdy throuth noradle protocol
						if pv.protocol = 'HTTP' then
							http_server.serv;
						elsif pv.protocol in ('DATA', 'NDBC') then
							data_server.serv;
						else
							data_server.serv;
						end if;
					when 'HTTP' then
						http_server.serv;
						http.init;
					when 'SCGI' then
						http_server.serv;
					when 'FCGI' then
						http_server.serv;
					else
						begin
							execute immediate 'call ' || pv.protocol || '_server.serv()';
						exception
							when pv.ex_invalid_proc then
								any_server.serv;
						end;
				end case;
			exception
				when pv.ex_continue then
					continue; -- give up current request service
				when pv.ex_quit then
					do_quit;
				when others then
					k_debug.trace(st('page before exection',
													 pv.protocol,
													 r.url,
													 sqlcode,
													 sqlerrm,
													 dbms_utility.format_error_backtrace));
					do_quit;
			end;
		
			pv.firstpg := false;
			-- do all pv init beforehand, next call to page init will not be first page
		
			-- map requested url to target servlet as x$dbu.x$prog form
		
			if not k_mapping.route then
				goto skip_main;
			end if;
		
			k_debug.time_header('before-exec');
			v_done := false;
			<<re_call_servlet>>
			declare
				no_dad_db_user exception; -- servlet db user does not exist
				pragma exception_init(no_dad_db_user, -1435);
				no_dad_auth_entry1 exception; -- table or view does not exist
				pragma exception_init(no_dad_auth_entry1, -942);
				no_dad_auth_entry2 exception;
				pragma exception_init(no_dad_auth_entry2, -6576);
				no_dad_auth_entry_right exception; -- table or view does not exist
				pragma exception_init(no_dad_auth_entry_right, -01031);
				ora_600 exception; -- oracle internal error
				pragma exception_init(ora_600, -600);
				ora_7445 exception; -- oracle internal error
				pragma exception_init(ora_600, -7445);
			begin
				execute immediate 'call ' || r.dbu || '.dad_auth_entry()';
			exception
				when no_dad_auth_entry1 or no_dad_auth_entry2 or no_dad_auth_entry_right then
					if v_done then
						show_exception;
					else
						begin
							sys.pw.add_dad_auth_entry(r.dbu);
							v_done := true;
							goto re_call_servlet;
						exception
							when no_dad_db_user then
								show_exception;
						end;
					end if;
				when ora_600 or ora_7445 then
					-- todo: tell dispatcher unrecoverable error occured, and then quit
					-- todo: give all request info back to dispatcher to resend to another OSP
					-- todo: or dispatcher keep request info, prepare to resend to another OSP
					show_exception;
					do_quit;
				when others then
					-- system(not app level at k_gw) exception occurred        
					show_exception;
			end;
		
			<<skip_main>>
			output.finish;
			bios.write_session;
			bios.write_end;
			utl_tcp.flush(pv.c);
		
			if pv.hp_flag then
				dbms_hprof.stop_profiling;
				tmp.s := nvl(pv.hp_label, 'noradle://' || r.dbu || '/' || r.prog);
				tmp.n := dbms_hprof.analyze('PLSHPROF_DIR', v_clinfo || '.trc', run_comment => tmp.s);
			end if;
		
			if pv.disproto = 'HTTP' and h.header('Connection') = 'close' then
				close_conn;
				k_debug.trace('close connection', 'header');
				goto make_connection;
			end if;
		
		end loop;
	
	exception
		when others then
			dbms_application_info.set_client_info('');
			-- all quit will go here, normal quit or exception, to allow sqlplus based OPS
			close_conn;
			utl_tcp.close_all_connections;
			if v_sts = 0 then
				dbms_output.put_line('Noradle Server Status:kill.');
			else
				dbms_output.put_line('Noradle Server Status:restart.');
			end if;
			if sqlcode != v_qcode then
				k_debug.trace(st('gateway listen exception', pv.cfg_id, sqlcode, sqlerrm, dbms_utility.format_error_backtrace));
			end if;
	end;

end framework;
/
