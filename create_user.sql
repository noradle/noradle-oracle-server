whenever sqlerror continue
create user &pspdbu identified by psp default tablespace sysaux temporary tablespace temp;
alter user &pspdbu quota unlimited on sysaux;
whenever sqlerror exit
