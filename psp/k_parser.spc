create or replace package k_parser is

	procedure parse_head;
	procedure parse_query;
	procedure parse_cookie;
	procedure parse_auth;
	procedure parse_prog;
	procedure parse_forwards;
	function parse_qvalue(v varchar2) return st;
	procedure parse_accept(name varchar2);
	procedure parse_accepts;

	procedure parse_auto;

end k_parser;
/
