accept pspdbu char default 'psp' prompt 'Enter the schema/User(must already exist) for noradle software (psp) : '
prompt export Noradle(psp.web) engine software (grant, public synonym ...),
pause press enter to continue ...
alter session set current_schema = &pspdbu;

@@exp_grant_api.sql
@@exp_pub_synonym.sql
prompt grant network access, for oracle to reach to dispatcher
@@grant_network.sql
exec k_pmon.run_job
