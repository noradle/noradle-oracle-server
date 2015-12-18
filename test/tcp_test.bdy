create or replace package body tcp_test is

	procedure t1 is
		c utl_tcp.connection;
		s varchar2(30) := '李勇';
	begin
		c := utl_tcp.open_connection(remote_host     => '60.29.143.50',
																 remote_port     => 8999,
																 charset         => '',
																 in_buffer_size  => 32767,
																 out_buffer_size => 0,
																 tx_timeout      => 3,
																 newline         => chr(10));
	
		pv.wlen := utl_tcp.write_line(c, s);
		dbms_output.put_line(pv.wlen);
		s       := convert(s, 'AL32UTF8','AL16UTF16');
		s       := convert(s, 'AL16UTF16','AL32UTF8');
		pv.wlen := utl_tcp.write_line(c, s);
		dbms_output.put_line(pv.wlen);
		--pv.wlen := utl_tcp.write_line(c, convert(convert(n'李勇', 'AL32UTF8'), 'AL16UTF16'));
		--dbms_output.put_line(pv.wlen);
		utl_tcp.close_connection(c);
	end;

end tcp_test;
/
