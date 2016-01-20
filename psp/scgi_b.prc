create or replace procedure scgi_b is
begin
	k_debug.trace(st('SCGI start'), 'SCGI');
	h.header('x-scgi-service', 'ok');
	b.line('SCGI response body');
	k_debug.trace(st('SCGI finish'), 'SCGI');
end scgi_b;
/
