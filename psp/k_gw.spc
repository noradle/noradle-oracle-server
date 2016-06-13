create or replace package k_gw authid current_user is

	procedure do;

	procedure link_schema(pspdbu varchar2);

end k_gw;
/
