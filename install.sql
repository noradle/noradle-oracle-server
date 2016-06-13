set echo off
spool install.log replace
prompt install log will write to "install.log", please check it after the script run
pause press enter to continue

prompt Are you sure that you are in the project directory,
prompt cd `npm -g root`/noradle-oracle-server
pause if not, break(CTRL-C) and cd it and retry ...
whenever sqlerror exit

set define on

remark start $ORACLE_HOME/rdbms/admin/dbmshptab.sql
remark create directory in SYS, grant read to psp
remark grant read, write on directory SYS.PLSHPROF_DIR to psp;
prompt Warning: PLSHPROF_DIR is set to '', if use oracle's hprof, set it to valid path afterward.
whenever sqlerror continue
CREATE DIRECTORY PLSHPROF_DIR AS '';
whenever sqlerror exit

prompt xmldb must be installed already
prompt if not, see and run $ORACLE_HOME/rdbms/admin/catqm.sql
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
Rem @@grant_network.sql

--------------------------------------------------------------------------------

prompt
prompt Noradle's core units(tables,plsql,...) in oracle will be installed to the schema
prompt schema user will be created if not exist
prompt or the schema is kept but its content/objects will be override if exist
prompt You can try the sql scripts below to achieve the preparation required above.
prompt exec psp.k_pmon.stop;;
prompt drop user psp cascade;;
prompt create user psp identified by psp default tablespace sysaux temporary tablespace temp;;
prompt alter user psp quota unlimited on sysaux;;
pause if not, create empty PSP db user beforehand, and then press enter to continue
accept pspdbu char default 'psp' prompt 'Enter the schema/User(must already exist) for noradle software (psp) : '

@@preinstall.sql
@@objinstall.sql
prompt Noradle bundle in oracle db part have been installed successfully!

prompt Please follow the steps below to learn from demo
prompt 0. grant network access to the address of dispatcher, for psp user (optional, did by default in this script)
prompt 1. config server_config_t, let oracle known where to reverse connect to dispatcher
prompt 2. start dispatcher
prompt 3. in oracle psp schema, exec k_pmon.run_job to start oracle server processes
prompt 4. install and run noradle-demo app to check if server is running properly

prompt about to export API (abourt public grant/synonym)
prompt if install for real deployment, press <ENTER> to continue
pause if install to a temporary schema for comparison/upgrade, press break(CTRL-C) to ignore export
@@export.sql
spool off
exit
