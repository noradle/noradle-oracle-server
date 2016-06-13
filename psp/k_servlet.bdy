create or replace package body k_servlet is

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

	procedure show_need_link_schema is
	begin
		h.status_line(500);
		h.content_type('text/plain');
		b.l('noradle will access database user : ' || r.dbu);
		b.l('but have not grant noradle execute path and right');
		b.l('login in sqlplus as db user ' || r.dbu);
		b.l('execute the following code to make it done');
		b.l('exec k_gw.link_schema(pspdbu)');
	end;

	function run return boolean is
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
		<<re_call_servlet>>
		begin
			execute immediate 'call ' || r.dbu || '.dad_auth_entry()';
		exception
			when no_dad_auth_entry1 or no_dad_auth_entry2 or no_dad_auth_entry_right then
				show_need_link_schema;
			when ora_600 or ora_7445 then
				-- todo: tell dispatcher unrecoverable error occured, and then quit
				-- todo: give all request info back to dispatcher to resend to another OSP
				-- todo: or dispatcher keep request info, prepare to resend to another OSP
				show_exception;
				return true;
			when others then
				-- system(not app level at k_gw) exception occurred        
				show_exception;
		end;
		return false;
	end;

end k_servlet;
/
