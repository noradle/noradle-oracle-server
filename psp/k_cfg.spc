create or replace package k_cfg is

	procedure server_control(p_cfg in out nocopy server_control_t%rowtype);

	function allow_cid_dbu return boolean;

	function allow_cid_sql return boolean;

end k_cfg;
/
