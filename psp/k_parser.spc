create or replace package k_parser is

	procedure parse_head;
	procedure parse_query;
	procedure parse_cookie;
	procedure parse_auth;
	procedure parse_prog;
	procedure parse_forwards;

end k_parser;
/
