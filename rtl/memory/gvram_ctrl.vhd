-- Lower 256 KiB of the canonical 512 KiB GVRAM image in BRAM.
-- Address bit 17 selects the owner: 0 = BRAM, 1 = SDRAM.
-- Each BRAM bank stores complete 16-bit words (even/odd interleave).

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity gvram_ctrl is
generic(awidth : integer := 24);
port(
	g00_addr : in std_logic_vector(awidth-1 downto 0); g00_rd : in std_logic; g00_rdat : out std_logic_vector(15 downto 0); g00_ack : out std_logic;
	g01_addr : in std_logic_vector(awidth-1 downto 0); g01_rd : in std_logic; g01_rdat : out std_logic_vector(15 downto 0); g01_ack : out std_logic;
	g02_addr : in std_logic_vector(awidth-1 downto 0); g02_rd : in std_logic; g02_rdat : out std_logic_vector(15 downto 0); g02_ack : out std_logic;
	g03_addr : in std_logic_vector(awidth-1 downto 0); g03_rd : in std_logic; g03_rdat : out std_logic_vector(15 downto 0); g03_ack : out std_logic;
	g10_addr : in std_logic_vector(awidth-1 downto 0); g10_rd : in std_logic; g10_rdat : out std_logic_vector(15 downto 0); g10_ack : out std_logic;
	g11_addr : in std_logic_vector(awidth-1 downto 0); g11_rd : in std_logic; g11_rdat : out std_logic_vector(15 downto 0); g11_ack : out std_logic;
	g12_addr : in std_logic_vector(awidth-1 downto 0); g12_rd : in std_logic; g12_rdat : out std_logic_vector(15 downto 0); g12_ack : out std_logic;
	g13_addr : in std_logic_vector(awidth-1 downto 0); g13_rd : in std_logic; g13_rdat : out std_logic_vector(15 downto 0); g13_ack : out std_logic;
	g0_caddr : in std_logic_vector(awidth-1 downto 8); g0_clear : in std_logic;
	g1_caddr : in std_logic_vector(awidth-1 downto 8); g1_clear : in std_logic;
	g2_caddr : in std_logic_vector(awidth-1 downto 8); g2_clear : in std_logic;
	g3_caddr : in std_logic_vector(awidth-1 downto 8); g3_clear : in std_logic;
	cpu_addr : in std_logic_vector(17 downto 0);
	cpu_wdat : in std_logic_vector(15 downto 0);
	cpu_rdat : out std_logic_vector(15 downto 0);
	cpu_wr : in std_logic_vector(1 downto 0);
	cpu_rd : in std_logic;
	cpu_rmw : in std_logic_vector(1 downto 0);
	cpu_rmwmask : in std_logic_vector(15 downto 0);
	cpu_ack : out std_logic;
	gmode : in std_logic_vector(1 downto 0);
	rclk : in std_logic; ram_ce : in std_logic := '1';
	vclk : in std_logic; vid_ce : in std_logic := '1';
	sclk : in std_logic; sys_ce : in std_logic := '1';
	rstn : in std_logic
);
end gvram_ctrl;

architecture rtl of gvram_ctrl is
	component gvram_bram
	port(
		c0_address_a : in std_logic_vector(15 downto 0); c0_data_a : in std_logic_vector(15 downto 0); c0_wren_a : in std_logic; c0_nibbleena_a : in std_logic_vector(3 downto 0); c0_q_a : out std_logic_vector(15 downto 0);
		c0_address_b : in std_logic_vector(15 downto 0); c0_q_b : out std_logic_vector(15 downto 0);
		c1_address_a : in std_logic_vector(15 downto 0); c1_data_a : in std_logic_vector(15 downto 0); c1_wren_a : in std_logic; c1_nibbleena_a : in std_logic_vector(3 downto 0); c1_q_a : out std_logic_vector(15 downto 0);
		c1_address_b : in std_logic_vector(15 downto 0); c1_q_b : out std_logic_vector(15 downto 0);
		clock_a : in std_logic; clock_b : in std_logic
	); end component;
	component vrcack
	generic(awidth : integer := 22; cwidth : integer := 8);
	port(rd : in std_logic; rdaddr : in std_logic_vector(awidth-1 downto 0); raddrh : in std_logic_vector(awidth-cwidth-1 downto 0);
		rcaddr : in std_logic_vector(cwidth-1 downto 0); de : in std_logic; ack : out std_logic;
		clk : in std_logic; ce : in std_logic := '1'; rstn : in std_logic); end component;
	component CACHEMEMWN
	generic(awidth : integer := 8; ramtype : string := "AUTO");
	port(data : in std_logic_vector(15 downto 0); rdaddress : in std_logic_vector(awidth-1 downto 0); rdclock : in std_logic;
		wraddress : in std_logic_vector(awidth-1 downto 0); wrclock : in std_logic := '1'; wren : in std_logic := '0'; q : out std_logic_vector(15 downto 0)); end component;

	constant TAG_WIDTH : integer := awidth-9;
	signal c0_addr_a,c0_addr_b,c1_addr_a,c1_addr_b : std_logic_vector(15 downto 0);
	signal c0_data_a,c0_q_a,c0_q_b,c1_data_a,c1_q_a,c1_q_b : std_logic_vector(15 downto 0);
	signal c0_wren_a,c1_wren_a : std_logic;
	signal c0_nibbleena_a,c1_nibbleena_a : std_logic_vector(3 downto 0);
	type op_state_t is (OP_IDLE,OP_ADDR,OP_READ,OP_WRITE);
	signal op_state : op_state_t;
	signal op_word_addr : std_logic_vector(16 downto 0);
	signal op_wdat,op_mask,op_old : std_logic_vector(15 downto 0);
	signal op_bank,op_is_clear : std_logic;
	signal rst_clr_active : std_logic;
	signal rst_clr_addr : std_logic_vector(15 downto 0);
	signal clr_count : std_logic_vector(7 downto 0);
	signal clr_page : std_logic_vector(8 downto 0);
	signal g0caddrh,g1caddrh,g2caddrh,g3caddrh : std_logic_vector(awidth-9 downto 0);
	signal clr_event_tog_s,clr_event_r1,clr_event_r2,clr_event_r3 : std_logic;
	type fill_state_t is (FS_IDLE,FS_PICK,FS_START,FS_FILL,FS_LAST,FS_DONE);
	signal fill_state : fill_state_t;
	signal fill_row : std_logic_vector(7 downto 0);
	signal fill_cnt,cache_wraddr_d : std_logic_vector(8 downto 0);
	signal fill_bank_d,cache_wren_d : std_logic;
	signal cache_wrdat : std_logic_vector(15 downto 0);
	signal fill_req : std_logic;
	signal miss_g00,miss_g01,miss_g02,miss_g03,miss_g10,miss_g11,miss_g12,miss_g13 : std_logic;
	signal req_v00,req_v01,req_v02,req_v03,req_v10,req_v11,req_v12,req_v13 : std_logic;
	signal req_tag00,req_tag01,req_tag02,req_tag03 : std_logic_vector(TAG_WIDTH-1 downto 0);
	signal req_tag10,req_tag11,req_tag12,req_tag13 : std_logic_vector(TAG_WIDTH-1 downto 0);
	signal pick_00_01_v,pick_02_03_v,pick_10_11_v : std_logic;
	signal pick_lo_v : std_logic;
	signal pick_00_01_tag,pick_02_03_tag,pick_10_11_tag,pick_12_13_tag : std_logic_vector(TAG_WIDTH-1 downto 0);
	signal pick_lo_tag,pick_hi_tag,pick_tag,fill_tag : std_logic_vector(TAG_WIDTH-1 downto 0);
	signal g00addrh,g01addrh,g02addrh,g03addrh : std_logic_vector(TAG_WIDTH-1 downto 0);
	signal g10addrh,g11addrh,g12addrh,g13addrh : std_logic_vector(TAG_WIDTH-1 downto 0);
	signal bfill_g00,bfill_g01,bfill_g02,bfill_g03,bfill_g10,bfill_g11,bfill_g12,bfill_g13 : std_logic;
	signal g00rwr,g01rwr,g02rwr,g03rwr,g10rwr,g11rwr,g12rwr,g13rwr : std_logic;
	signal cpu_inv_tog_s,cpu_inv_tog_r1,cpu_inv_tog_r2,cpu_inv_tog_r3 : std_logic;
	signal cpu_inv_row_s,cpu_inv_row_r : std_logic_vector(8 downto 0);
	signal cpu_req_prev,cpu_req : std_logic;
begin
	GVRAM:gvram_bram port map(c0_addr_a,c0_data_a,c0_wren_a,c0_nibbleena_a,c0_q_a,c0_addr_b,c0_q_b,c1_addr_a,c1_data_a,c1_wren_a,c1_nibbleena_a,c1_q_a,c1_addr_b,c1_q_b,sclk,rclk);
	c0_addr_b<=fill_row&fill_cnt(8 downto 1);
	c1_addr_b<=fill_row&fill_cnt(8 downto 1);
	cache_wrdat<=c0_q_b when fill_bank_d='0' else c1_q_b;
	cpu_req<='1' when cpu_wr/="00" or cpu_rmw/="00" else '0';
	cpu_rdat<=c0_q_a when cpu_addr(0)='0' else c1_q_a;

	process(sclk,rstn)
		variable vmask:std_logic_vector(15 downto 0);
		variable vaddr:std_logic_vector(awidth-1 downto 8);
	begin
		if rstn='0' then
			rst_clr_active<='1'; rst_clr_addr<=(others=>'0'); op_state<=OP_IDLE; clr_count<=(others=>'0');
			g0caddrh<=(others=>'1'); g1caddrh<=(others=>'1'); g2caddrh<=(others=>'1'); g3caddrh<=(others=>'1');
			cpu_ack<='0'; cpu_req_prev<='0'; cpu_inv_tog_s<='0'; cpu_inv_row_s<=(others=>'0'); clr_event_tog_s<='0'; op_is_clear<='0';
		elsif rising_edge(sclk) then
			if rst_clr_active='1' then
				if rst_clr_addr=x"FFFF" then rst_clr_active<='0'; else rst_clr_addr<=rst_clr_addr+1; end if;
			elsif op_state=OP_WRITE and op_is_clear='1' then
				if clr_count/=x"FF" then
					clr_count<=clr_count+1; op_word_addr<=clr_page(7 downto 0)&(clr_count+1)&'0';
				else op_state<=OP_IDLE; end if;
			elsif sys_ce='1' then
				cpu_ack<='0'; cpu_req_prev<=cpu_req;
				if op_state=OP_IDLE then
					if g0_clear='1' and g0_caddr/=g0caddrh then vaddr:=g0_caddr;
					elsif g1_clear='1' and g1_caddr/=g1caddrh then vaddr:=g1_caddr;
					elsif g2_clear='1' and g2_caddr/=g2caddrh then vaddr:=g2_caddr;
					elsif g3_clear='1' and g3_caddr/=g3caddrh then vaddr:=g3_caddr;
					else vaddr:=(others=>'0'); end if;
					if (g0_clear='1' and g0_caddr/=g0caddrh) or (g1_clear='1' and g1_caddr/=g1caddrh) or
					   (g2_clear='1' and g2_caddr/=g2caddrh) or (g3_clear='1' and g3_caddr/=g3caddrh) then
						vmask:=x"0000";
						if g0_clear='1' and g0_caddr/=g0caddrh and g0_caddr(awidth-1 downto 9)=vaddr(awidth-1 downto 9) then g0caddrh<=g0_caddr; vmask:=vmask or x"000F"; end if;
						if g1_clear='1' and g1_caddr/=g1caddrh and g1_caddr(awidth-1 downto 9)=vaddr(awidth-1 downto 9) then g1caddrh<=g1_caddr; vmask:=vmask or x"00F0"; end if;
						if g2_clear='1' and g2_caddr/=g2caddrh and g2_caddr(awidth-1 downto 9)=vaddr(awidth-1 downto 9) then g2caddrh<=g2_caddr; vmask:=vmask or x"0F00"; end if;
						if g3_clear='1' and g3_caddr/=g3caddrh and g3_caddr(awidth-1 downto 9)=vaddr(awidth-1 downto 9) then g3caddrh<=g3_caddr; vmask:=vmask or x"F000"; end if;

						clr_page<=vaddr(17 downto 9); clr_count<=(others=>'0');
						op_word_addr<=vaddr(16 downto 9)&"000000000"; op_bank<='0';
						op_mask<=vmask; op_wdat<=(others=>'0'); op_is_clear<='1'; op_state<=OP_WRITE;
						clr_event_tog_s<=not clr_event_tog_s;
					elsif cpu_req='1' then
						op_word_addr<=cpu_addr(16 downto 0); op_bank<=cpu_addr(0); op_wdat<=cpu_wdat;
						if cpu_rmw/="00" then op_mask<=cpu_rmwmask; elsif cpu_wr="11" then op_mask<=x"FFFF";
						elsif cpu_wr(1)='1' then op_mask<=x"FF00"; else op_mask<=x"00FF"; end if;
						op_is_clear<='0'; op_state<=OP_ADDR;
						if cpu_req_prev='0' then cpu_inv_tog_s<=not cpu_inv_tog_s; cpu_inv_row_s<=cpu_addr(17 downto 9); end if;
					elsif cpu_rd='1' then cpu_ack<='1'; end if;
				elsif op_state=OP_ADDR then op_state<=OP_READ;
				elsif op_state=OP_READ then if op_bank='0' then op_old<=c0_q_a; else op_old<=c1_q_a; end if; op_state<=OP_WRITE;
				else cpu_ack<='1'; op_state<=OP_IDLE; end if;
			end if;
		end if;
	end process;

	process(rst_clr_active,rst_clr_addr,op_state,op_word_addr,op_bank,op_old,op_wdat,op_mask,op_is_clear,cpu_addr)
		variable merged:std_logic_vector(15 downto 0);
	begin
		merged:=(op_old and (not op_mask)) or (op_wdat and op_mask);
		c0_addr_a<=cpu_addr(16 downto 1); c1_addr_a<=cpu_addr(16 downto 1); c0_data_a<=(others=>'0'); c1_data_a<=(others=>'0');
		c0_wren_a<='0'; c1_wren_a<='0'; c0_nibbleena_a<="1111"; c1_nibbleena_a<="1111";
		if rst_clr_active='1' then c0_addr_a<=rst_clr_addr; c1_addr_a<=rst_clr_addr; c0_wren_a<='1'; c1_wren_a<='1';
		elsif op_state/=OP_IDLE then
			c0_addr_a<=op_word_addr(16 downto 1); c1_addr_a<=op_word_addr(16 downto 1);
			if op_is_clear='1' then
				c0_data_a<=(others=>'0'); c1_data_a<=(others=>'0');
				c0_nibbleena_a<=op_mask(12) & op_mask(8) & op_mask(4) & op_mask(0);
				c1_nibbleena_a<=op_mask(12) & op_mask(8) & op_mask(4) & op_mask(0);
			else c0_data_a<=merged; c1_data_a<=merged; end if;
			if op_state=OP_WRITE then
				if op_is_clear='1' then c0_wren_a<='1'; c1_wren_a<='1'; elsif op_bank='0' then c0_wren_a<='1'; else c1_wren_a<='1'; end if;
			end if;
		end if;
	end process;

	process(rclk,rstn) begin
		if rstn='0' then
			cpu_inv_tog_r1<='0'; cpu_inv_tog_r2<='0'; cpu_inv_tog_r3<='0'; cpu_inv_row_r<=(others=>'0'); clr_event_r1<='0'; clr_event_r2<='0'; clr_event_r3<='0';
		elsif rising_edge(rclk) then if ram_ce='1' then
			cpu_inv_tog_r1<=cpu_inv_tog_s; cpu_inv_tog_r2<=cpu_inv_tog_r1; cpu_inv_tog_r3<=cpu_inv_tog_r2;
			if (cpu_inv_tog_r2 xor cpu_inv_tog_r3)='1' then cpu_inv_row_r<=cpu_inv_row_s; end if;
			clr_event_r1<=clr_event_tog_s; clr_event_r2<=clr_event_r1; clr_event_r3<=clr_event_r2;
		end if; end if;
	end process;

	-- Capture the eight miss candidates in parallel.  Selection is performed
	-- from these local registers in a balanced tree on the following cycle;
	-- this removes the old input -> 8-way priority mux -> compare -> tag path.
	miss_g00<='1' when g00_rd='1' and g00_addr(awidth-1 downto 9)/=g00addrh else '0';
	miss_g01<='1' when g01_rd='1' and g01_addr(awidth-1 downto 9)/=g01addrh else '0';
	miss_g02<='1' when g02_rd='1' and g02_addr(awidth-1 downto 9)/=g02addrh else '0';
	miss_g03<='1' when g03_rd='1' and g03_addr(awidth-1 downto 9)/=g03addrh else '0';
	miss_g10<='1' when g10_rd='1' and g10_addr(awidth-1 downto 9)/=g10addrh else '0';
	miss_g11<='1' when g11_rd='1' and g11_addr(awidth-1 downto 9)/=g11addrh else '0';
	miss_g12<='1' when g12_rd='1' and g12_addr(awidth-1 downto 9)/=g12addrh else '0';
	miss_g13<='1' when g13_rd='1' and g13_addr(awidth-1 downto 9)/=g13addrh else '0';
	fill_req<=miss_g00 or miss_g01 or miss_g02 or miss_g03 or miss_g10 or miss_g11 or miss_g12 or miss_g13;

	pick_00_01_v<=req_v00 or req_v01;
	pick_02_03_v<=req_v02 or req_v03;
	pick_10_11_v<=req_v10 or req_v11;
	pick_00_01_tag<=req_tag00 when req_v00='1' else req_tag01;
	pick_02_03_tag<=req_tag02 when req_v02='1' else req_tag03;
	pick_10_11_tag<=req_tag10 when req_v10='1' else req_tag11;
	pick_12_13_tag<=req_tag12 when req_v12='1' else req_tag13;
	pick_lo_v<=pick_00_01_v or pick_02_03_v;
	pick_lo_tag<=pick_00_01_tag when pick_00_01_v='1' else pick_02_03_tag;
	pick_hi_tag<=pick_10_11_tag when pick_10_11_v='1' else pick_12_13_tag;
	pick_tag<=pick_lo_tag when pick_lo_v='1' else pick_hi_tag;

	process(rclk,rstn) begin
		if rstn='0' then
			fill_state<=FS_IDLE; fill_cnt<=(others=>'0'); cache_wraddr_d<=(others=>'0'); cache_wren_d<='0'; fill_bank_d<='0'; fill_tag<=(others=>'0');
			req_v00<='0'; req_v01<='0'; req_v02<='0'; req_v03<='0'; req_v10<='0'; req_v11<='0'; req_v12<='0'; req_v13<='0';
			req_tag00<=(others=>'0'); req_tag01<=(others=>'0'); req_tag02<=(others=>'0'); req_tag03<=(others=>'0');
			req_tag10<=(others=>'0'); req_tag11<=(others=>'0'); req_tag12<=(others=>'0'); req_tag13<=(others=>'0');
			g00addrh<=(others=>'1'); g01addrh<=(others=>'1'); g02addrh<=(others=>'1'); g03addrh<=(others=>'1'); g10addrh<=(others=>'1'); g11addrh<=(others=>'1'); g12addrh<=(others=>'1'); g13addrh<=(others=>'1');
			bfill_g00<='0'; bfill_g01<='0'; bfill_g02<='0'; bfill_g03<='0'; bfill_g10<='0'; bfill_g11<='0'; bfill_g12<='0'; bfill_g13<='0';
		elsif rising_edge(rclk) then if ram_ce='1' then
			cache_wraddr_d<=fill_cnt; fill_bank_d<=fill_cnt(0); if fill_state=FS_FILL then cache_wren_d<='1'; else cache_wren_d<='0'; end if;
			case fill_state is
			when FS_IDLE=>if fill_req='1' then
				req_v00<=miss_g00; req_v01<=miss_g01; req_v02<=miss_g02; req_v03<=miss_g03;
				req_v10<=miss_g10; req_v11<=miss_g11; req_v12<=miss_g12; req_v13<=miss_g13;
				req_tag00<=g00_addr(awidth-1 downto 9); req_tag01<=g01_addr(awidth-1 downto 9);
				req_tag02<=g02_addr(awidth-1 downto 9); req_tag03<=g03_addr(awidth-1 downto 9);
				req_tag10<=g10_addr(awidth-1 downto 9); req_tag11<=g11_addr(awidth-1 downto 9);
				req_tag12<=g12_addr(awidth-1 downto 9); req_tag13<=g13_addr(awidth-1 downto 9);
				fill_state<=FS_PICK;
			end if;
			when FS_PICK=>
				fill_tag<=pick_tag; fill_state<=FS_START;
			when FS_START=>
				fill_row<=fill_tag(7 downto 0); fill_cnt<=(others=>'0'); fill_state<=FS_FILL;
				if req_v00='1' and req_tag00=fill_tag then g00addrh<=fill_tag; bfill_g00<='1'; else bfill_g00<='0'; end if;
				if req_v01='1' and req_tag01=fill_tag then g01addrh<=fill_tag; bfill_g01<='1'; else bfill_g01<='0'; end if;
				if req_v02='1' and req_tag02=fill_tag then g02addrh<=fill_tag; bfill_g02<='1'; else bfill_g02<='0'; end if;
				if req_v03='1' and req_tag03=fill_tag then g03addrh<=fill_tag; bfill_g03<='1'; else bfill_g03<='0'; end if;
				if req_v10='1' and req_tag10=fill_tag then g10addrh<=fill_tag; bfill_g10<='1'; else bfill_g10<='0'; end if;
				if req_v11='1' and req_tag11=fill_tag then g11addrh<=fill_tag; bfill_g11<='1'; else bfill_g11<='0'; end if;
				if req_v12='1' and req_tag12=fill_tag then g12addrh<=fill_tag; bfill_g12<='1'; else bfill_g12<='0'; end if;
				if req_v13='1' and req_tag13=fill_tag then g13addrh<=fill_tag; bfill_g13<='1'; else bfill_g13<='0'; end if;
			when FS_FILL=>if fill_cnt="111111111" then fill_state<=FS_LAST; else fill_cnt<=fill_cnt+1; end if;
			when FS_LAST=>fill_state<=FS_DONE; when FS_DONE=>fill_state<=FS_IDLE; end case;
			if (cpu_inv_tog_r2 xor cpu_inv_tog_r3)='1' then
				if g00addrh(8 downto 0)=cpu_inv_row_r then g00addrh<=(others=>'1'); end if; if g01addrh(8 downto 0)=cpu_inv_row_r then g01addrh<=(others=>'1'); end if;
				if g02addrh(8 downto 0)=cpu_inv_row_r then g02addrh<=(others=>'1'); end if; if g03addrh(8 downto 0)=cpu_inv_row_r then g03addrh<=(others=>'1'); end if;
				if g10addrh(8 downto 0)=cpu_inv_row_r then g10addrh<=(others=>'1'); end if; if g11addrh(8 downto 0)=cpu_inv_row_r then g11addrh<=(others=>'1'); end if;
				if g12addrh(8 downto 0)=cpu_inv_row_r then g12addrh<=(others=>'1'); end if; if g13addrh(8 downto 0)=cpu_inv_row_r then g13addrh<=(others=>'1'); end if;
			end if;
			if (clr_event_r2 xor clr_event_r3)='1' then
				g00addrh<=(others=>'1'); g01addrh<=(others=>'1'); g02addrh<=(others=>'1'); g03addrh<=(others=>'1'); g10addrh<=(others=>'1'); g11addrh<=(others=>'1'); g12addrh<=(others=>'1'); g13addrh<=(others=>'1');
			end if;
		end if; end if;
	end process;

	g00rwr<=cache_wren_d and bfill_g00; g01rwr<=cache_wren_d and bfill_g01; g02rwr<=cache_wren_d and bfill_g02; g03rwr<=cache_wren_d and bfill_g03;
	g10rwr<=cache_wren_d and bfill_g10; g11rwr<=cache_wren_d and bfill_g11; g12rwr<=cache_wren_d and bfill_g12; g13rwr<=cache_wren_d and bfill_g13;
	g00_cache:CACHEMEMWN generic map(9) port map(cache_wrdat,g00_addr(8 downto 0),vclk,cache_wraddr_d,rclk,g00rwr and ram_ce,g00_rdat);
	g01_cache:CACHEMEMWN generic map(9) port map(cache_wrdat,g01_addr(8 downto 0),vclk,cache_wraddr_d,rclk,g01rwr and ram_ce,g01_rdat);
	g02_cache:CACHEMEMWN generic map(9) port map(cache_wrdat,g02_addr(8 downto 0),vclk,cache_wraddr_d,rclk,g02rwr and ram_ce,g02_rdat);
	g03_cache:CACHEMEMWN generic map(9) port map(cache_wrdat,g03_addr(8 downto 0),vclk,cache_wraddr_d,rclk,g03rwr and ram_ce,g03_rdat);
	g10_cache:CACHEMEMWN generic map(9) port map(cache_wrdat,g10_addr(8 downto 0),vclk,cache_wraddr_d,rclk,g10rwr and ram_ce,g10_rdat);
	g11_cache:CACHEMEMWN generic map(9) port map(cache_wrdat,g11_addr(8 downto 0),vclk,cache_wraddr_d,rclk,g11rwr and ram_ce,g11_rdat);
	g12_cache:CACHEMEMWN generic map(9) port map(cache_wrdat,g12_addr(8 downto 0),vclk,cache_wraddr_d,rclk,g12rwr and ram_ce,g12_rdat);
	g13_cache:CACHEMEMWN generic map(9) port map(cache_wrdat,g13_addr(8 downto 0),vclk,cache_wraddr_d,rclk,g13rwr and ram_ce,g13_rdat);
	g00_ack_i:vrcack generic map(awidth,9) port map(g00_rd,g00_addr,g00addrh,cache_wraddr_d,g00rwr,g00_ack,vclk,vid_ce,rstn);
	g01_ack_i:vrcack generic map(awidth,9) port map(g01_rd,g01_addr,g01addrh,cache_wraddr_d,g01rwr,g01_ack,vclk,vid_ce,rstn);
	g02_ack_i:vrcack generic map(awidth,9) port map(g02_rd,g02_addr,g02addrh,cache_wraddr_d,g02rwr,g02_ack,vclk,vid_ce,rstn);
	g03_ack_i:vrcack generic map(awidth,9) port map(g03_rd,g03_addr,g03addrh,cache_wraddr_d,g03rwr,g03_ack,vclk,vid_ce,rstn);
	g10_ack_i:vrcack generic map(awidth,9) port map(g10_rd,g10_addr,g10addrh,cache_wraddr_d,g10rwr,g10_ack,vclk,vid_ce,rstn);
	g11_ack_i:vrcack generic map(awidth,9) port map(g11_rd,g11_addr,g11addrh,cache_wraddr_d,g11rwr,g11_ack,vclk,vid_ce,rstn);
	g12_ack_i:vrcack generic map(awidth,9) port map(g12_rd,g12_addr,g12addrh,cache_wraddr_d,g12rwr,g12_ack,vclk,vid_ce,rstn);
	g13_ack_i:vrcack generic map(awidth,9) port map(g13_rd,g13_addr,g13addrh,cache_wraddr_d,g13rwr,g13_ack,vclk,vid_ce,rstn);
end rtl;
