-----------------------------------------------------
-- all printing API (html/xml, data/json, call-out --
-----------------------------------------------------

set define off
set echo on

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
create or replace synonym l for url;

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
create or replace synonym x for tag;

prompt Creating package ZTAG
prompt ========================
prompt
@@ztag.spc
@@ztag.bdy
create or replace synonym o for ztag;

prompt Creating package STYLE
prompt ========================
prompt
@@style.spc
@@style.bdy
create or replace synonym sty for style;
create or replace synonym c for style;
create or replace synonym y for style;

prompt Creating package multi
prompt ========================
prompt
@@multi.spc
@@multi.bdy
create or replace synonym m for multi;

prompt Creating package tree
prompt ========================
prompt
@@tree.spc
@@tree.bdy
create or replace synonym tr for tree;

prompt Creating package list
prompt ========================
prompt
@@list.spc
@@list.bdy
create or replace synonym tb for list;

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
create or replace synonym mp for msg_pipe;
create or replace synonym mp_h for msg_pipe;

--------------------------------------------------------------------------------

set echo off
set define on
