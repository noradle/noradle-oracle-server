create or replace package body k_gw is

	ex_package_state_invalid exception;
	pragma exception_init(ex_package_state_invalid, -04061);
	-- ORA-04061: existing state of package has been invalidated
	-- Cause: Attempt to resume the execution of a stored procedure using the existing state which has become invalid or inconsistent with the stored procedure because the procedure has been altered or dropped. 
	-- Action: Try again; this error should have caused the existing state of all packages to be re-initialized. 

	procedure error_not_bch is
	begin
		h.allow_get_post;
		h.status_line(403);
		h.content_type('text/plain');
		h.header_close;
		b.line('The requested program unit is "' || r.prog || '" , only _b/_c/_h named unit can be called from http');
	end;

	procedure error_forbid_tv is
	begin
		h.allow_get_post;
		h.status_line(403);
		h.content_type('text/plan');
		b.line('cid:' || r.cid || ' is not allowed to access table/view/sql directly!');
	end;

	procedure error_not_exist is
	begin
		h.status_line(404);
		h.content_type;
		h.header_close;
		b.line('The program unit "' || r.prog || '" is not exist');
	end;

	procedure error_no_subprog is
	begin
		if not pv.msg_stream then
			h.status_line(404);
			h.content_type;
			h.header_close;
		end if;
		b.line('The package "' || r.pack || '" exists but the sub procedure "' || r.proc || '" in it' || ' is not exist');
	end;

	procedure error_execute
	(
		ecode      varchar2,
		emsg       varchar2,
		ebacktrace varchar2,
		estack     varchar2
	) is
	begin
		if not pv.msg_stream then
			h.status_line(500);
			h.content_type('text/html');
			h.header_close;
			x.p('<title>', emsg);
			x.p('<h3>', '[WARNING] execute with error');
			x.o('<pre>');
			b.line(estack);
			b.line(ebacktrace);
			x.c('</pre>');
			-- x.a('<a>', 'refresh', 'javascript:window.location.reload();');
		else
			b.line('[WARNING] execute with error');
			b.line(estack);
			b.line(ebacktrace);
		end if;
	end;

	procedure do is
		v_sql    varchar2(100);
		v_tried  boolean;
		v_before varchar2(60) := r.getc('x$before', '');
		v_after  varchar2(60) := r.getc('x$after', '');
		v_last2  char(2);
	begin
		v_tried := false;
		<<retry_filter>>
		begin
			if v_before is not null then
				execute immediate 'call ' || v_before || '()';
			end if;
		exception
			when ex_package_state_invalid then
				if v_tried then
					error_execute(sqlcode, sqlerrm, dbms_utility.format_error_backtrace, dbms_utility.format_error_stack);
					rollback;
					return;
				else
					v_sql := regexp_replace(dbms_utility.format_error_stack,
																	'^.*ORA-04061:( package (body )?"(\w+\.\w+)" ).*$',
																	'alter package \3 compile \2',
																	modifier => 'n');
					execute immediate v_sql;
					v_tried := true;
					goto retry_filter;
				end if;
			when pv.ex_no_filter or pv.ex_invalid_proc then
				null;
			when pv.ex_resp_done then
				goto after;
			when others then
				error_execute(sqlcode, sqlerrm, dbms_utility.format_error_backtrace, dbms_utility.format_error_stack);
				rollback;
				return;
		end;
	
		v_last2 := substrb(nvl(r.pack, r.proc), -2);
		if v_last2 in ('_c', '_b', '_h') then
			null;
		elsif v_last2 in ('_t', '_v') then
			if not k_cfg.allow_cid_sql then
				error_forbid_tv;
				return;
			end if;
			r.setc('x$prog', 'k_sql.get');
		else
			error_not_bch;
			return;
		end if;
	
		v_tried := false;
		dbms_application_info.set_module(r.dbu, r.prog);
		<<retry_prog>>
		begin
			execute immediate 'call ' || r.prog || '()';
		exception
			when ex_package_state_invalid then
				if v_tried then
					error_execute(sqlcode, sqlerrm, dbms_utility.format_error_backtrace, dbms_utility.format_error_stack);
					rollback;
					return;
				else
					v_sql := regexp_replace(dbms_utility.format_error_stack,
																	'^.*ORA-04061:( package (body )?"(\w+\.\w+)" ).*$',
																	'alter package \3 compile \2',
																	modifier => 'n');
					execute immediate v_sql;
					v_tried := true;
					goto retry_prog;
				end if;
			when pv.ex_no_prog or pv.ex_invalid_proc then
				error_not_exist;
			when pv.ex_no_subprog then
				error_no_subprog;
			when pv.ex_resp_done then
				goto after;
			when others then
				k_debug.trace(st('k_gw.do core', sqlcode, sqlerrm, dbms_utility.format_error_backtrace));
				error_execute(sqlcode, sqlerrm, dbms_utility.format_error_backtrace, dbms_utility.format_error_stack);
				rollback;
		end;
	
		<<after>>
		begin
			if v_after is not null then
				execute immediate 'call ' || v_after || '()';
			end if;
		exception
			when pv.ex_no_filter or pv.ex_invalid_proc then
				null;
			when pv.ex_resp_done then
				null;
			when others then
				error_execute(sqlcode, sqlerrm, dbms_utility.format_error_backtrace, dbms_utility.format_error_stack);
				rollback;
				return;
		end;
	
		if sts.stack is not null then
			output.line(sts.stack, '');
		end if;
	
		commit;
	end;

	procedure link_schema(pspdbu varchar2) is
	begin
		execute immediate 'create or replace procedure dad_auth_entry is begin k_gw.do; end;';
		execute immediate 'grant execute on dad_auth_entry to ' || pspdbu;
	end;

end k_gw;
/
