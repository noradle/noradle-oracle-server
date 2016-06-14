select a.*, rowid from server_control_t a;
select a.*, rowid from client_control_t a;
select a.*, rowid from ext_url_t a;
select a.sid, a.serial#, a.client_info, a.module, a.action
	from v$session a
 where a.status = 'ACTIVE'
	 and a.schema# != 0
	 and a.client_info like 'Noradle-dispatcher:%';
select * from user_scheduler_jobs;
select * from user_scheduler_running_jobs;
begin k_pmon.run_job; end;
begin k_pmon.stop; end;
