[noradle][] core schema objects to be installed at oracle side

contents
============

install.sql will install noradle engine(objects as below) to oracle database

1. create engine schema and grant required privilege to it
2. configuration tables and views
  - server_control_t
  - client_control_t
  - dbms_hprof tables
  - ext_url_t / ext_url_v
3. framework plsql packages
  - k_pmon
  - kill
  - framework
  - k_gw
  - k_servlet
  - bios
  - http_server
  - data_server
  - k_init
  - output
  - k_sql
4. API packages(base)
  - st
  - nt
  - k_type_tool
  - e : error hande support
  - g : servlet execution flow control support
  - r - request info
  - h,hdr,k_resq_head : set response headers
  - b,bdy,k_resq_body : print response body
  - msg_pipe
  - cache : http cache support
  - k_debug : trace runtime info, mimic server env in IDE
5. API pakcages(for print only)
  - rs : results set output
  - l,url : support concise url coding
  - sty,style : support dynamic css printing, embed or link
  - o,ztag : print html/xml tags concisely, support dynamic switch and interpolate
  - m,multi : repeat template with substitute data repeatly
  - tr,tree : repeat template with substitute data repeatly, but print hierachical structure
  - tb,list : aid table print, for cols,thead...
6. some packages may be deprecated in future
  - kv
  - k_validator
  - k_auth
  - k_mapping

how to install
================

## Install NORADLE engine schema objects

use sqlplus to login into the target oracle database as sysdba,  
(note: only sys can grant execute right for sys owned packages, just DBA role cannot)
then execute install.sql script file. Example like this:

```
npm -g install noradle-oracle-server
cd `npm -g root`
cd noradle-oracle-server
sqlplus "sys/password@targetdb as sysdba"
start install.sql
```

Or if you are on the db server, simply run this.

```
cd noradle-oracle-server
sqlplus "/ as sysdba" @install.sql
```

or all-in-one way

```
cd noradle-oracle-server && sqlplus "sys/password@targetdb as sysdba" @install.sql
```

install from http works also, it's much simpler  
(note: by now, sqlplus do not support execute script from https, as github is，  
  the version at the address is usually old, not recommended)

```
sqlplus "/ as sysdba" @http://static.noradle.com/repo/noradle-oracle-server/install.sql
```

Note: noradle core objects will be installed into schema named 'PSP' by default.  
**PSP** is abbreviation for "PL/SQL Server Page", just like PHP, JSP does.  
"psp user" stand for noradle core schema name in noradle document.

How to upgrade
=================

* install into another db user, such as tmp, psp1, or psp_v0_15_2(version) or psp_eb34f8(git commit)
* at the middle of install.sql execution, it will show export is going and pause
* do not press enter to continue, press CTRL-C to abort it
* this way, no public synonym and other action that will ruin public space, only engine objects itself is installed
* use any oracle IDE(pl/sql developer) to compare schema difference and update the target engine schema

Grant right for oracle to NodeJS TCP/IP connection
==============================================================

  Oracle DB is able to make TCP/IP connection to outside world by `UTL_TCP` pl/sql API,
but by default,
oracle(11g and up) forbid to make connection to any address by network ACL rules,
you must use `DBMS_NETWORK_ACL_ADMIN` package to create a new ACL to allow access to nodejs(noradle listener).
NodeJS dispatcher server will manage all the connections made by oracle,
and use them as communication path for the nodejs clients.
The configuration script is as the following code:

Be sure to connect as sys or other privileged db users in SQLPlus(or other oracle clients), and execute the code below.

```plsql
begin
	/* view current noradle network ACL configuration with this SQL:
	select a.res.getclobval() from resource_view a where equals_path(res, '/sys/acls/noradle.xml') > 0;
	*/
	/* uncomment this when you want existing ACL "noradle.xml" to be removed first
	dbms_network_acl_admin.drop_acl(
		acl => 'noradle.xml'
	);
	*/
	dbms_network_acl_admin.create_acl(
		acl            => 'noradle.xml',
		description    => 'oracle2nodejs',
		principal      => 'PSP',
		is_grant       => true,
		privilege      => 'connect'
	);
	/* when ACL "noradle.xml" exists, execute .add_privilege is ok,
		for example, when you reinstall psp schema
	dbms_network_acl_admin.add_privilege(
		acl       => 'noradle.xml',
		principal => 'PSP',
		is_grant  => true,
		privilege => 'connect'
	);
	*/
	-- for each record in server_control_t, call assign_acl to grant network access right from oracle to nodejs
	dbms_network_acl_admin.assign_acl(
		acl => 'noradle.xml',
		host => '127.0.0.1'
	);
	-- or call assign_acl to grant network access to all ip address
	dbms_network_acl_admin.assign_acl(
		acl => 'noradle.xml',
		host => '*'
	);
	commit;
end;
/
```

Note:

* "install.sql" will setup net ACL by default configuration, you may bypass this step.
* read http://oradoc.noradle.com/appdev.112/e10577/d_networkacl_adm.htm for reference
* "principal" must specify the schema(case sensitive, def to PSP) that hold the noradle core schema.
* "dbms_network_acl_admin.add_privilege" will grant right to other db user that act as NORADLE engine user.
* Notice: normally you will install only one version of NORADLE, so ".add_privilege"can be bypassed.
* "host" in "dbms_network_acl_admin.assign_acl" specify where(dns/ip) the NORADLE dispatcher is.
* if you have multiple NORADLE dispatcher in multiple address, repeat ".assign_acl" with each of the addresses.

After done, oracle background scheduler processes (as Noradle server processes) have the right to make connection to
all your nodejs NORADLE dispatcher sever process who listen for oracle connection.

Note: you must be sure that oracle XML-DB is installed, see rem code in install.sql if XML-DB is not installed,

```sql
prompt xmldb must be installed already
prompt see and run $ORACLE_HOME/rdbms/admin/catqm.sql
Rem    NAME
Rem      catqm.sql - CAtalog script for sQl xMl management
Rem
Rem    DESCRIPTION
Rem      Creates the tables and views needed to run the XDB system
Rem      Run this script like this:
Rem        catqm.sql <XDB_PASSWD> <TABLESPACE> <TEMP_TABLESPACE> <SECURE_FILES_REPO>
Rem          -- XDB_PASSWD: password for XDB user
Rem          -- TABLESPACE: tablespace for XDB
Rem          -- TEMP_TABLESPACE: temporary tablespace for XDB
Rem          -- SECURE_FILES_REPO: if YES and compatibility is at least 11.2,
Rem               then XDB repository will be stored as secure files;
Rem               otherwise, old LOBS are used. There is no default value for
Rem               this parameter, the caller must pass either YES or NO.
@@grant_network.sql
```

reference:

* [DBMS_NETWORK_ACL_ADMIN](http://oradoc.noradle.com/appdev.112/e10577/d_networkacl_adm.htm)
* [Managing Fine-Grained Access in PL/SQL Network Utility Packages](http://oradoc.noradle.com/network.112/e10574/authorization.htm#DBSEG40012)

configure, start, stop server processes
========================================

Configure `server_config_t` table for Noradle server processes
--------------------------------------------------------------

After installation script runs, The `server_control_t` table is configured by the following insert statements.

```sql
insert into SERVER_CONTROL_T (CFG_ID, GW_HOST, GW_PORT, MIN_SERVERS, MAX_SERVERS, MAX_REQUESTS, MAX_LIFETIME,IDLE_TIMEOUT)
values ('demo', '127.0.0.1', 1522, 4, 12, 1000, '+0001 00:00:00', 300);
```

To let NORADLE known where the dispatcher is, You must specify `gw_host` and `gw_port` columns for `server_control_t`.  
The dispatcher is listening for oracle connection at tcp address of `gw_host:gw_port`.

* `cfg_id` configuration name
* `gw_host` must match ip of the NORADLE dispatcher listening address.
* `gw_port` must match `noradle.DBDriver.connect([port, host],option)`, the dispatcher listening port
* `min_servers` keep this amount of oracle background server processes for this config record
* `max_servers` not used yet
* `max_requests` when a job process handle this amount of servlet request, process will quit and restart to release resource.
* `max_lifetime` when a job process live over this amount of time, process  will quit and restart to release resource.
* `idle_timeout` when a job process can not receive any incoming request data over this amount of time,
job process will treat it as connection lost, so disconnect and reconnect to nodejs.
For nodejs and oracle behind NAT, this setting should be set to avoid endless waiting on a lost NAT state connection.
* `disabled` when not null or set to 'Y', this config is ignored by K_PMON

The above insert will create configuration records,
you can create additional configuration by insert multiple records of `server_config_table`,
and specify column `cfg_id` as the name of the new configuration.
That way, you can allow multiple dispatchers as pathways to access one oracle database.

For every records of `server_control_t`, call `dbms_network_acl_admin.assign_acl` for every different `gw_host`(or
add `gw_port`), to allow oracle server process make connection to the corresponding dispatcher.


Make sure there is enough processes/sessions and background job process for PSP.WEB service.
-----------------------------------------------------------------------------------------------

  The value in `server_control_t.min_servers` control how many server processes 
a NORADLE dispatcher use it to service its clients, 
but NORADLE server process is just oracle's background processes,
the actual number of them is limited under the following oracle init parameters,
so ensure it's set big enough to run the amount of oracle server processes required.

<dl>
<dt> `JOB_QUEUE_PROCESSES` </dt>
<dd>specifies the maximum number of processes that can be created for the execution of jobs.
<dd>It specifies the number of job queue processes per instance (J000, ... J999).
<dt> `PROCESSES` </dt>
	<dd>specifies the maximum number of operating system user processes that can simultaneously connect to Oracle.
	<dd>Its value should allow for all background processes such as locks, job queue processes,	and parallel execution processes.
<dt> `SESSIONS` </dt>
<dd>specifies the maximum number of database sessions that can be created in the system. Because every login requires a session,
 <dd> this parameter effectively determines the maximum number of concurrent users in the system.
</dl>

Note:

* To get the current value of the parameters above, use "show parameters {parameter-name}"
* To change the setting., use "alter system set {parameter-name}={value}"
	
Start oracle server processes for noradle request
---------------------------------------------------------

Start and Stop NORADLE OSPs on oracle side

  NORADLE OSPs is just a bunch of background job processes managed by oracle dbms_scheduler , 
They run as the NORADLE engine software database user, normally is "PSP".
NORADLE provide `K_PMON` package to manager the server processes.

<dl>
<dt> `K_PMON.RUN_JOB`</dt>
<dd> It will run NORADLE's pmon as a deamon and start all the parallel server job processes
<dd> ".run_job" will check server_config_t, for each config record,  
start up ".min_servers" number of servers.
<dd> if any server quit for the reason of exception, ".max_requests" reached, or ".max_lifetime" reached,  
the monitor deamon will re-spawn new servers,  
try keep server quantity to ".min_servers'.
<dt> `K_PMON.STOP`
<dd> It will send signal to NORADLE'S pmon and all server processes to tell them to quit
</dl>

To start/stop NORADLE OSPs, just login as NORADLE engine user (normally "PSP") in sqlplus,  
and execute `k_pmon.run_job/k_pmon.stop`.  
Then check State on the Oracle side.

check if oracle background job processes is running by the SQLs below (login as PSP user)

```sql
select * from user_scheduler_jobs a where a.job_name like 'Noradle-%';
select * from user_scheduler_running_jobs a where a.job_name like 'Noradle-%';

select a.client_info, a.module, a.action, a.*
  from v$session a
 where a.status = 'ACTIVE'
   and a.client_info like 'Noradle-%'
 order by a.client_info asc;
```

Read pipe named "node2psp" for any exception the Noradle servers encounters.  
For example, if you use "PL/SQL Developer" IDE, you can go to menu "tools -> event monitor",  
set "Event Type" to "pipe", "Event Name" to "node2psp",  
press "Start" button to catch all the trace log info in the oracle side. 	

  [noradle]: https://github.com/kaven276/noradle