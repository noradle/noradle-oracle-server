-----------------------------------------------------
-- all printing API (html/xml, data/json, call-out --
-----------------------------------------------------

set define off
set echo on

whenever sqlerror continue
prompt Notice: all the drop objects errors can be ignored, do not care about it
create table EXT_URL_BAK as select * from EXT_URL_T;
drop table EXT_URL_T cascade constraints;
whenever sqlerror exit

prompt
prompt Creating table EXT_URL_T
prompt ========================
prompt
@@ext_url_t.tab
prompt
prompt Creating view EXT_URL_V
prompt =======================
prompt
@@ext_url_v.vw
prompt Creating function url
prompt ========================
prompt
@@url.fnc

--------------------------------------------------------------------------------

prompt
prompt Creating package STS
prompt ========================
prompt
@@sts.spc

prompt Creating package TAG
prompt ========================
prompt
@@tag.spc
@@tag.bdy

prompt Creating package ZTAG
prompt ========================
prompt
@@ztag.spc
@@ztag.bdy

prompt Creating package STYLE
prompt ========================
prompt
@@style.spc
@@style.bdy

prompt Creating package multi
prompt ========================
prompt
@@multi.spc
@@multi.bdy

prompt Creating package tree
prompt ========================
prompt
@@tree.spc
@@tree.bdy

prompt Creating package list
prompt ========================
prompt
@@list.spc
@@list.bdy

--------------------------------------------------------------------------------

prompt
prompt Creating package RS
prompt ===================
prompt
@@rs.spc
@@rs.bdy

prompt Creating package K_SQL
prompt ========================
prompt
@@k_sql.spc
@@k_sql.bdy

prompt Creating package MSG_PIPE
prompt ========================
prompt
@@msg_pipe.spc
@@msg_pipe.bdy

--------------------------------------------------------------------------------

whenever sqlerror continue
prompt Notice: restore old config data
insert into EXT_URL_T select * from EXT_URL_BAK;
drop table EXT_URL_BAK cascade constraints;
commit;
whenever sqlerror exit

set echo off
set define on