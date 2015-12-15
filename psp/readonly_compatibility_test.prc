create or replace procedure readonly_compatibility_test is
	c utl_tcp.connection;
begin
	null;
	dbms_output.put_line('dbms_output.put_line in readonly standby.');
	dbms_pipe.pack_message('hello');
	tmp.n := dbms_pipe.send_message('testpipe1');
	c     := utl_tcp.open_connection(remote_host     => '60.29.143.50',
																	 remote_port     => 8000,
																	 charset         => null,
																	 in_buffer_size  => 32767,
																	 out_buffer_size => 0,
																	 tx_timeout      => 3);
	tmp.n := utl_tcp.write_text(c, 'hello');
	utl_tcp.close_connection(c);
	dbms_lock.sleep(3);
	tmp.n := dbms_pipe.receive_message('testpipe1');
	dbms_pipe.unpack_message(tmp.s);
	dbms_output.put_line('data from pipe : ' || tmp.s);
end;
/
