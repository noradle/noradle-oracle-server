create or replace package body k_validator is

	function gen_hash
	(
		rand varchar2,
		salt varchar2
	) return varchar2 is
	begin
		return null;
	end;

	function check_rand
	(
		rand varchar2,
		salt varchar2,
		hash varchar2
	) return boolean is
	begin
		return gen_hash(rand, salt) = hash;
	end;

	function gen_hash_bsid(rand varchar2) return varchar2 is
	begin
		return gen_hash(rand, r.bsid);
	end;

	function check_rand_bsid
	(
		rand varchar2,
		hash varchar2
	) return boolean is
	begin
		return gen_hash(rand, r.bsid) = hash;
	end;

	function gen_hash_secret(rand varchar2) return varchar2 is
	begin
		return gen_hash(rand, r.getc('s$secret2'));
	end;

	function check_rand_secret
	(
		rand varchar2,
		hash varchar2
	) return boolean is
	begin
		return gen_hash(rand, r.getc('s$secret1')) = hash or gen_hash(rand, r.getc('s$secret2')) = hash;
	end;

end k_validator;
/
