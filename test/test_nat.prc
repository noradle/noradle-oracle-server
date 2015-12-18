create or replace procedure test_nat(timeout pls_integer := null) is
	c utl_tcp.connection;
begin
	c := utl_tcp.open_connection(remote_host     => '60.29.143.50',
															 remote_port     => 9003,
															 charset         => null,
															 in_buffer_size  => 32767,
															 out_buffer_size => 0,
															 tx_timeout      => 1);
	dbms_lock.sleep(nvl(timeout, 5 * 60));
	utl_tcp.close_connection(c);
end test_nat;
/
