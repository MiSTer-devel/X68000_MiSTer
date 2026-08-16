library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity sasidev is
port(
	IDAT		:in std_logic_vector(7 downto 0);
	ODAT		:out std_logic_vector(7 downto 0);
	SEL		:in std_logic;
	BSY		:out std_logic;
	REQ		:out std_logic;
	ACK		:in std_logic;
	IO			:out std_logic;
	CD			:out std_logic;
	MSG		:out std_logic;
	RST		:in std_logic;
	idsel		:in std_logic_vector(7 downto 0);
	id			:out std_logic_vector(2 downto 0);
	unit		:out std_logic_vector(2 downto 0);
	capacity	:in std_logic_vector(63 downto 0);
	lba		:out std_logic_vector(31 downto 0);
	rdreq		:out std_logic;
	wrreq		:out std_logic;
	syncreq	:out std_logic;
	sectaddr	:out std_logic_vector(8 downto 0);
	rddat		:in std_logic_vector(7 downto 0);
	wrdat		:out std_logic_vector(7 downto 0);
	sectbusy	:in std_logic;
	mode_scsi	:in std_logic := '0';
	clk		:in std_logic;
	ce      :in std_logic := '1';
	rstn		:in std_logic
);
end sasidev;

architecture rtl of sasidev is
type state_t is(
	st_idle,
	st_sel,
	st_cmd,
	st_cmd0,
	st_cmd0w,
	st_cmd1,
	st_cmd1w,
	st_cmd2,
	st_cmd2w,
	st_cmd3,
	st_cmd3w,
	st_cmd4,
	st_cmd4w,
	st_cmd5,
	st_cmd5w,
	st_cmdb,
	st_cmdbw,
	st_dispatch,
	st_data,
	st_dataw,
	st_dataw2,
	st_status,
	st_statusw,
	st_statusw2,
	st_message,
	st_messagew,
	st_messagew2,
	st_end,
	st_free
);
signal	state	:state_t;

type cdb_t is array(0 to 9) of std_logic_vector(7 downto 0);
signal	cdb		:cdb_t;
signal	cdbidx	:integer range 0 to 10;
signal	cdblen	:integer range 0 to 10;

signal	command		:std_logic_vector(7 downto 0);
signal	ssel		:std_logic;
signal	sack		:std_logic;
signal	bytecount	:std_logic_vector(8 downto 0);
signal	bytemax		:std_logic_vector(8 downto 0);
signal	sectcount	:std_logic_vector(15 downto 0);
signal	status		:std_logic_vector(7 downto 0);
signal	message		:std_logic_vector(7 downto 0);
signal	lbab		:std_logic_vector(31 downto 0);
signal	max_lba		:std_logic_vector(31 downto 0);
begin

	bytemax <= "111111111" when mode_scsi='1' else "011111111";

	process(capacity, mode_scsi)
	variable tmp : std_logic_vector(31 downto 0);
	begin
		if mode_scsi='1' then
			tmp := capacity(40 downto 9);	-- bytes / 512
		else
			tmp := capacity(39 downto 8);	-- bytes / 256
		end if;
		if tmp = x"00000000" then
			max_lba <= (others=>'0');
		else
			max_lba <= tmp - 1;
		end if;
	end process;

	process(clk,rstn)begin
		if rising_edge(clk) then
			if(rstn='0')then
				ssel<='0';
				sack<='0';
			elsif(ce = '1')then
				ssel<=SEL;
				sack<=ACK;
			end if;
		end if;
	end process;

	process(clk,rstn)
	variable selid	:integer range 0 to 8;
	variable swait	:integer range 0 to 3;
	variable opc	:std_logic_vector(2 downto 0);
	begin
		if rising_edge(clk) then
			if(rstn='0')then
				state<=st_idle;
				bytecount<=(others=>'0');
				sectcount<=(others=>'0');
				ODAT<=(others=>'0');
				BSY<='0';
				REQ<='0';
				IO<='0';
				CD<='0';
				MSG<='0';
				command<=(others=>'0');
				id<=(others=>'0');
				unit<=(others=>'0');
				lbab<=(others=>'0');
				message<=(others=>'0');
				status<=(others=>'0');
				wrreq<='0';
				rdreq<='0';
				syncreq<='0';
				cdbidx<=0;
				cdblen<=6;
				swait:=0;
			elsif(ce = '1')then
				wrreq<='0';
				rdreq<='0';
				syncreq<='0';
				if(RST='1' and
				   not(state=st_dataw and sack='1' and bytecount=bytemax))then
					state<=st_idle;
					BSY<='0';
					REQ<='0';
					IO<='0';
					CD<='0';
					MSG<='0';
					ODAT<=(others=>'0');
					command<=x"00";
				elsif(swait>0)then
					swait:=swait-1;
				else
					case state is
					when st_idle =>
						if(ssel='1')then
							selid:=8;
							for i in 7 downto 0 loop
								if(IDAT(i)='1' and idsel(i)='1')then
									selid:=i;
								end if;
							end loop;
							if(selid/=8)then
								BSY<='1';
								id<=conv_std_logic_vector(selid,3);
								state<=st_sel;
							else
								BSY<='0';
							end if;
						end if;
					when st_sel =>
						if(ssel='0')then
							CD<='1';
							cdbidx<=0;
							cdblen<=6;
							state<=st_cmd;
						end if;
					when st_cmd =>
						REQ<='1';
						if(mode_scsi='0')then
							state<=st_cmd0;
						else
							cdbidx<=0;
							cdblen<=6;
							state<=st_cmdb;
						end if;
					when st_cmd0 =>
						if(sack='1')then
							command<=IDAT;
							REQ<='0';
							state<=st_cmd0w;
						end if;
					when st_cmd0w =>
						if(sack='0')then
							REQ<='1';
							state<=st_cmd1;
						end if;
					when st_cmd1 =>
						if(sack='1')then
							unit<=IDAT(7 downto 5);
							lbab(31 downto 21)<=(others=>'0');
							lbab(20 downto 16)<=IDAT(4 downto 0);
							REQ<='0';
							state<=st_cmd1w;
						end if;
					when st_cmd1w =>
						if(sack='0')then
							REQ<='1';
							state<=st_cmd2;
						end if;
					when st_cmd2 =>
						if(sack='1')then
							lbab(15 downto 8)<=IDAT;
							REQ<='0';
							state<=st_cmd2w;
						end if;
					when st_cmd2w =>
						if(sack='0')then
							REQ<='1';
							state<=st_cmd3;
						end if;
					when st_cmd3 =>
						if(sack='1')then
							lbab(7 downto 0)<=IDAT;
							REQ<='0';
							state<=st_cmd3w;
						end if;
					when st_cmd3w =>
						if(sack='0')then
							REQ<='1';
							state<=st_cmd4;
						end if;
					when st_cmd4 =>
						if(sack='1')then
							sectcount(15 downto 8)<=(others=>'0');
							sectcount(7 downto 0)<=IDAT;
							REQ<='0';
							state<=st_cmd4w;
						end if;
					when st_cmd4w =>
						if(sack='0')then
							REQ<='1';
							state<=st_cmd5;
						end if;
					when st_cmd5 =>
						if(sack='1')then
							REQ<='0';
							state<=st_cmd5w;
						end if;
					when st_cmd5w =>
						if(sack='0')then
							CD<='0';
							case command is
							when x"00" =>
								if(capacity=x"0000000000000000")then
									status<=x"ff";
								else
									status<=x"00";
								end if;
								state<=st_status;
							when x"01" =>
								status<=x"00";
								state<=st_status;
							when x"03" =>
								IO<='1';
								bytecount<="000000100";
								state<=st_data;
							when x"04" =>
								if(capacity(63 downto 8)>lbab)then
									status<=x"00";
								else
									status<=x"ff";
								end if;
								state<=st_status;
							when x"08" =>
								if(sectcount(7 downto 0)=x"00")then
									status<=x"00";
									state<=st_status;
								else
									IO<='1';
									bytecount<=(others=>'0');
									rdreq<='1';
									swait:=2;
									state<=st_data;
								end if;
							when x"0a" =>
								if(sectcount(7 downto 0)=x"00")then
									status<=x"00";
									state<=st_status;
								else
									IO<='0';
									bytecount<=(others=>'0');
									swait:=2;
									state<=st_data;
								end if;
							when x"c2" =>
								IO<='0';
								bytecount<="000001010";
								state<=st_data;
							when others =>
								status<=x"00";
								state<=st_status;
							end case;
						end if;

					when st_cmdb =>
						if(sack='1')then
							cdb(cdbidx)<=IDAT;
							if(cdbidx=0)then
								command<=IDAT;
								opc := IDAT(7 downto 5);
								case opc is
								when "001" | "010" => cdblen<=10;
								when others        => cdblen<=6;
								end case;
							end if;
							REQ<='0';
							state<=st_cmdbw;
						end if;
					when st_cmdbw =>
						if(sack='0')then
							if(cdbidx+1 < cdblen)then
								cdbidx<=cdbidx+1;
								REQ<='1';
								state<=st_cmdb;
							else
								CD<='0';
								state<=st_dispatch;
							end if;
						end if;
					when st_dispatch =>
						if(cdblen=6)then
							unit<=cdb(1)(7 downto 5);
							lbab(31 downto 21)<=(others=>'0');
							lbab(20 downto 16)<=cdb(1)(4 downto 0);
							lbab(15 downto 8)<=cdb(2);
							lbab(7 downto 0)<=cdb(3);
							sectcount(15 downto 8)<=(others=>'0');
							sectcount(7 downto 0)<=cdb(4);
						else
							unit<=cdb(1)(7 downto 5);
							lbab(31 downto 24)<=cdb(2);
							lbab(23 downto 16)<=cdb(3);
							lbab(15 downto 8)<=cdb(4);
							lbab(7 downto 0)<=cdb(5);
							sectcount(15 downto 8)<=cdb(7);
							sectcount(7 downto 0)<=cdb(8);
						end if;

						case cdb(0) is
						when x"00" =>
							if(capacity=x"0000000000000000")then
								status<=x"ff";
							else
								status<=x"00";
							end if;
							state<=st_status;
						when x"01" =>
							status<=x"00";
							state<=st_status;
						when x"03" =>
							IO<='1';
							bytecount<="000000100";
							state<=st_data;
						when x"04" =>
							status<=x"00";
							state<=st_status;
						when x"12" =>
							IO<='1';
							bytecount<="000100100";
							state<=st_data;
						when x"25" =>
							IO<='1';
							bytecount<="000001000";
							state<=st_data;
						when x"08" =>
							if(cdb(4)=x"00")then
								sectcount(15 downto 8)<=x"01";
								sectcount(7 downto 0)<=x"00";
							end if;
							IO<='1';
							bytecount<=(others=>'0');
							rdreq<='1';
							swait:=2;
							state<=st_data;
						when x"0a" =>
							if(cdb(4)=x"00")then
								sectcount(15 downto 8)<=x"01";
								sectcount(7 downto 0)<=x"00";
							end if;
							IO<='0';
							bytecount<=(others=>'0');
							swait:=2;
							state<=st_data;
						when x"28" =>
							if(sectcount=x"0000")then
								status<=x"00";
								state<=st_status;
							else
								IO<='1';
								bytecount<=(others=>'0');
								rdreq<='1';
								swait:=2;
								state<=st_data;
							end if;
						when x"2a" =>
							if(sectcount=x"0000")then
								status<=x"00";
								state<=st_status;
							else
								IO<='0';
								bytecount<=(others=>'0');
								swait:=2;
								state<=st_data;
							end if;
						when x"c2" =>
							IO<='0';
							bytecount<="000001010";
							state<=st_data;
						when others =>
							status<=x"00";
							state<=st_status;
						end case;
					when st_data =>
						if(sack='0')then
							case command is
							when x"03" =>
								ODAT<=(others=>'0');
								REQ<='1';
								state<=st_dataw;
							when x"12" =>
								case (conv_integer("000100100" - bytecount)) is
								when 0 => ODAT<=x"00";
								when 1 => ODAT<=x"00";
								when 2 => ODAT<=x"01";
								when 3 => ODAT<=x"01";
								when 4 => ODAT<=x"1f";
								when 8  => ODAT<=x"4d";
								when 9  => ODAT<=x"69";
								when 10 => ODAT<=x"53";
								when 11 => ODAT<=x"54";
								when 12 => ODAT<=x"65";
								when 13 => ODAT<=x"72";
								when 16 => ODAT<=x"58";
								when 17 => ODAT<=x"36";
								when 18 => ODAT<=x"38";
								when 19 => ODAT<=x"30";
								when 20 => ODAT<=x"30";
								when 21 => ODAT<=x"30";
								when 32 => ODAT<=x"31";
								when 33 => ODAT<=x"2e";
								when 34 => ODAT<=x"30";
								when 35 => ODAT<=x"30";
								when others => ODAT<=x"00";
								end case;
								REQ<='1';
								state<=st_dataw;
							when x"25" =>
								case (conv_integer("000001000" - bytecount)) is
								when 0 => ODAT<=max_lba(31 downto 24);
								when 1 => ODAT<=max_lba(23 downto 16);
								when 2 => ODAT<=max_lba(15 downto 8);
								when 3 => ODAT<=max_lba(7 downto 0);
								when 4 => ODAT<=x"00";
								when 5 => ODAT<=x"00";
								when 6 => ODAT<=x"02";
								when 7 => ODAT<=x"00";
								when others => ODAT<=x"00";
								end case;
								REQ<='1';
								state<=st_dataw;
							when x"08" | x"28" =>
								if(sectbusy='0')then
									ODAT<=rddat;
									REQ<='1';
									state<=st_dataw;
								end if;
							when x"0a" | x"2a" =>
								REQ<='1';
								state<=st_dataw;
							when x"c2" =>
								REQ<='1';
								state<=st_dataw;
							when others =>
								state<=st_idle;
							end case;
						end if;
					when st_dataw =>
						if(sack='1')then
							REQ<='0';
							case command is
							when x"03" | x"c2" | x"12" | x"25" =>
								if(bytecount>"000000001")then
									bytecount<=bytecount-1;
									state<=st_data;
								else
									status<=x"00";
									state<=st_status;
								end if;
							when x"08" | x"28" =>
								if(bytecount/=bytemax)then
									bytecount<=bytecount+1;
									rdreq<='1';
									swait:=2;
									state<=st_data;
								else
									if(sectcount>x"0001")then
										sectcount<=sectcount-1;
										lbab<=lbab+1;
										bytecount<=(others=>'0');
										rdreq<='1';
										swait:=2;
										state<=st_data;
									else
										status<=x"00";
										state<=st_status;
									end if;
								end if;
							when x"0a" | x"2a" =>
								wrdat<=IDAT;
								wrreq<='1';
								swait:=2;
								state<=st_dataw2;
							when others =>
								state<=st_idle;
							end case;
						end if;
					when st_dataw2 =>
						if(sectbusy='0')then
							if(bytecount/=bytemax)then
								bytecount<=bytecount+1;
								state<=st_data;
							else
								if(sectcount>x"0001")then
									sectcount<=sectcount-1;
									lbab<=lbab+1;
									bytecount<=(others=>'0');
									state<=st_data;
								else
									status<=x"00";
									state<=st_status;
								end if;
							end if;
						end if;
					when st_status =>
						if(sack='0')then
							IO<='1';
							CD<='1';
							ODAT<=status;
							state<=st_statusw;
						end if;
					when st_statusw =>
						REQ<='1';
						state<=st_statusw2;
					when st_statusw2 =>
						if(sack='1')then
							REQ<='0';
							message<=x"00";
							state<=st_message;
						end if;
					when st_message =>
						if(sack='0')then
							ODAT<=message;
							MSG<='1';
							state<=st_messagew;
						end if;
					when st_messagew =>
						REQ<='1';
						state<=st_messagew2;
					when st_messagew2 =>
						if(sack='1')then
							REQ<='0';
							state<=st_end;
						end if;
					when st_end =>
						if(sack='0')then
							IO<='0';
							CD<='0';
							MSG<='0';
							state<=st_free;
							syncreq<='1';
							swait:=2;
						end if;
					when st_free =>
						BSY<='0';
						state<=st_idle;
					when others =>
						state<=st_idle;
					end case;
				end if;
			end if;
		end if;
	end process;
	
	lba<=lbab;
	sectaddr<=bytecount;

end rtl;
