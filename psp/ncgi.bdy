create or replace package body ncgi is

	procedure read_nv is
		v_name  varchar2(1000);
		v_value varchar2(32000);
		v_count pls_integer;
		v_hprof varchar2(30);
		v_st    st;
	begin
		loop
			v_name  := trim(utl_tcp.get_line(pv.c, true));
			v_value := utl_tcp.get_line(pv.c, true);
			exit when v_name is null;
			if v_name like '*%' then
				v_name  := substrb(v_name, 2);
				v_count := to_number(v_value);
				v_st    := st();
				v_st.extend(v_count);
				for i in 1 .. v_count loop
					v_st(i) := utl_tcp.get_line(pv.c, true);
				end loop;
			else
				v_st := st(v_value);
			end if;
			ra.params(v_name) := v_st;
		end loop;
	end;

end ncgi;
/
