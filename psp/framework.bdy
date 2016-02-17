create or replace package body framework is

	/* main functions
  0. establish connection to nodejs and listen for request
  1. (x) control lifetime by max requests and max runtime, quit signal
  2. switch to target user current_schema
  3. collect request cpu/ellapsed time
  4. collect hprof statistics
  5. graceful quit, signal quit and accept quit control frame, then quit
  6. keep alive with dispatcher
  7. exit when ora-600 ora-7445 occurred
  8. catch and handle all types of network exceptions 
  */

	procedure entry
	(
		cfg_id  varchar2 := null,
		slot_id pls_integer := 1
	) is
		v_quit  boolean := false;
		v_qcode pls_integer := -20526;
		v_count pls_integer;
		v_dtime pls_integer;
		v_sts   number := -1;
	
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
																			tx_timeout      => 3);
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
	
		function got_quit_signal return boolean is
		begin
			v_sts := dbms_pipe.receive_message(pv.clinfo, 0);
			if v_sts not in (0, 1) then
				k_debug.trace(st(pv.clinfo, 'got signal ' || v_sts), 'dispatcher');
			end if;
			return v_sts = 0;
		end;
	
		procedure signal_quit(reason varchar2) is
		begin
			-- only signal dispatcher to quit once
			if v_quit then
				return;
			end if;
			v_quit := true;
			k_debug.trace(st(pv.clinfo, reason), 'dispatcher');
			pv.cslot_id := 0;
			bios.write_frame(255);
		end;
	
		procedure do_quit(reason varchar2) is
		begin
			k_debug.trace(st(pv.clinfo, 'do quit: ' || reason), 'dispatcher');
			raise_application_error(v_qcode, reason);
		end;
	
	begin
		execute immediate 'alter session set nls_date_format="yyyy-mm-dd hh24:mi:ss"';
		if cfg_id is null then
			select a.job_name
				into pv.clinfo
				from user_scheduler_running_jobs a
			 where a.session_id = sys_context('userenv', 'sid');
			pv.cfg_id := substr(pv.clinfo, 9, lengthb(pv.clinfo) - 8 - 5);
			pv.in_seq := to_number(substr(pv.clinfo, -4));
		else
			pv.cfg_id := cfg_id;
			pv.in_seq := slot_id;
			pv.clinfo := 'Noradle-' || cfg_id || ':' || ltrim(to_char(slot_id, '0000'));
		end if;
	
		select count(*) into v_count from v$session a where a.client_info = pv.clinfo;
		if v_count > 0 then
			dbms_output.put_line('Noradle Server Status:inuse. quit');
			dbms_application_info.set_client_info('');
			return;
		end if;
		dbms_application_info.set_client_info(pv.clinfo);
		dbms_application_info.set_module('free', null);
		dbms_pipe.purge(pv.clinfo);
		k_cfg.server_control(v_cfg);
		pv.entry := 'framework.entry';
	
		<<make_connection>>
		dbms_application_info.set_module('utl_tcp', 'open_connection');
		loop
			begin
				close_conn;
				make_conn;
				pv.prehead := null;
				exit;
			exception
				when utl_tcp.network_error then
					if sysdate > v_svr_stime + v_cfg.max_lifetime then
						do_quit('max lifetime reached'); -- quit immediately in disconnected state
					elsif got_quit_signal then
						do_quit('quit signal received'); -- quit immediately in disconnected state
					end if;
					pv.c := null;
					-- do not continuiously try connect to waste computing resource
					dbms_lock.sleep(1);
			end;
		end loop;
	
		loop
			dbms_application_info.set_module('utl_tcp', 'get_line');
			v_dtime := dbms_utility.get_time + (pv.keep_alive + 3) * 100;
		
			<<read_request>>
		
			if v_svr_req_cnt > v_cfg.max_requests then
				signal_quit('over max requests');
			elsif sysdate > v_svr_stime + v_cfg.max_lifetime then
				signal_quit('over max lifetime');
			elsif got_quit_signal then
				signal_quit('got quit signal');
			end if;
		
			-- accept arrival of new request
			begin
				bios.read_request;
				k_cfg.client_control(pv.cc);
				k_debug.time_header('after-read');
			exception
				when utl_tcp.transfer_timeout then
					if dbms_utility.get_time > v_dtime then
						do_quit('idle timeout over keep-alive time, lost connection');
					end if;
					goto read_request;
				when utl_tcp.end_of_input then
					do_quit('end of tcp');
			end;
		
			if pv.cslot_id = 0 then
				if k_mgmt_frame.response then
					do_quit('dispatcher send');
				else
					continue;
				end if;
			end if;
			v_svr_req_cnt := v_svr_req_cnt + 1;
		
			if pv.hp_flag then
				dbms_hprof.start_profiling('PLSHPROF_DIR', pv.clinfo || '.trc');
				pv.hp_label := '';
			end if;
		
			-- read & parse request info and do init work
			pv.firstpg := true;
			begin
				pv.elpl := dbms_utility.get_time;
				k_init.by_response;
				k_init.by_request;
				dbms_session.set_identifier(r.bsid);
				if pv.disproto = 'HTTP' then
					http.init;
				end if;
			end;
		
			pv.firstpg := false;
			-- do all pv init beforehand, next call to page init will not be first page
		
			-- map requested url to target servlet as x$dbu.x$prog form
			-- or just print error page with request infomation
			k_debug.time_header('before-exec');
			if not k_mapping.route then
				h.status_line(404);
				k_debug.req_info;
			elsif k_servlet.run then
				do_quit('servlet exception');
			end if;
		
			output.finish;
			bios.write_session;
			bios.write_end;
			utl_tcp.flush(pv.c);
		
			if pv.hp_flag then
				dbms_hprof.stop_profiling;
				tmp.s := nvl(pv.hp_label, 'noradle://' || r.dbu || '/' || r.prog);
				tmp.n := dbms_hprof.analyze('PLSHPROF_DIR', pv.clinfo || '.trc', run_comment => tmp.s);
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
