LIBRARY	IEEE;
USE	IEEE.STD_LOGIC_1164.ALL;
USE	IEEE.STD_LOGIC_UNSIGNED.ALL;

entity vidcont is
generic(
	arange	:integer	:=22
	);
port(
	t_base	:in std_logic_vector(arange-1 downto 0);
	g_base	:in std_logic_vector(arange-1 downto 0);

	g00_addr	:out std_logic_vector(arange-1 downto 0);
	g00_rd		:out std_logic;
	g00_rdat	:in std_logic_vector(15 downto 0);

	g01_addr	:out std_logic_vector(arange-1 downto 0);
	g01_rd		:out std_logic;
	g01_rdat	:in std_logic_vector(15 downto 0);

	g02_addr	:out std_logic_vector(arange-1 downto 0);
	g02_rd		:out std_logic;
	g02_rdat	:in std_logic_vector(15 downto 0);

	g03_addr	:out std_logic_vector(arange-1 downto 0);
	g03_rd		:out std_logic;
	g03_rdat	:in std_logic_vector(15 downto 0);

	g10_addr	:out std_logic_vector(arange-1 downto 0);
	g10_rd		:out std_logic;
	g10_rdat	:in std_logic_vector(15 downto 0);

	g11_addr	:out std_logic_vector(arange-1 downto 0);
	g11_rd		:out std_logic;
	g11_rdat	:in std_logic_vector(15 downto 0);

	g12_addr	:out std_logic_vector(arange-1 downto 0);
	g12_rd		:out std_logic;
	g12_rdat	:in std_logic_vector(15 downto 0);

	g13_addr	:out std_logic_vector(arange-1 downto 0);
	g13_rd		:out std_logic;
	g13_rdat	:in std_logic_vector(15 downto 0);

	t0_addr		:out std_logic_vector(arange-3 downto 0);
	t0_rd		:out std_logic;
	t0_rdat0	:in std_logic_vector(15 downto 0);
	t0_rdat1	:in std_logic_vector(15 downto 0);
	t0_rdat2	:in std_logic_vector(15 downto 0);
	t0_rdat3	:in std_logic_vector(15 downto 0);
	
	t1_addr		:out std_logic_vector(arange-3 downto 0);
	t1_rd		:out std_logic;
	t1_rdat0	:in std_logic_vector(15 downto 0);
	t1_rdat1	:in std_logic_vector(15 downto 0);
	t1_rdat2	:in std_logic_vector(15 downto 0);
	t1_rdat3	:in std_logic_vector(15 downto 0);
	
	g0_caddr	:out std_logic_vector(arange-1 downto 7);
	g0_clear	:out std_logic;
	
	g1_caddr	:out std_logic_vector(arange-1 downto 7);
	g1_clear	:out std_logic;

	g2_caddr	:out std_logic_vector(arange-1 downto 7);
	g2_clear	:out std_logic;

	g3_caddr	:out std_logic_vector(arange-1 downto 7);
	g3_clear	:out std_logic;

	t_hoffset	:in std_logic_vector(9 downto 0);
	t_voffset	:in std_logic_vector(9 downto 0);
	
	g0_hoffset	:in std_logic_vector(9 downto 0);
	g0_voffset	:in std_logic_vector(9 downto 0);
	g1_hoffset	:in std_logic_vector(8 downto 0);
	g1_voffset	:in std_logic_vector(8 downto 0);
	g2_hoffset	:in std_logic_vector(8 downto 0);
	g2_voffset	:in std_logic_vector(8 downto 0);
	g3_hoffset	:in std_logic_vector(8 downto 0);
	g3_voffset	:in std_logic_vector(8 downto 0);

	gmode	:in std_logic_vector(1 downto 0);		--00:4bit color 01:8bit color 11/10:16bit color
	memres	:in std_logic;							--0:512x512 1:1024x1024
	hres	:in std_logic_vector(1 downto 0);		--00:256 01:512 10/11:768
	vres	:in std_logic;							--0:256 1:512
	txten	:in std_logic;
	grpen	:in std_logic;
	spren	:in std_logic;
	graphen	:in std_logic_vector(4 downto 0);
	grpri	:in std_logic_vector(7 downto 0);
	pri_sp	:in std_logic_vector(1 downto 0);
	pri_tx	:in std_logic_vector(1 downto 0);
	pri_gr	:in std_logic_vector(1 downto 0);
	
	lbaddr	:out std_logic_vector(9 downto 0);
	lbwdat	:out std_logic_vector(15 downto 0);
	lbwr	:out std_logic;
	
	hcomp	:in std_logic;
	vpstart	:in std_logic;
	hfreq	:in std_logic;
	htotal	:in std_logic_vector(7 downto 0);
	hvbgn	:in std_logic_vector(7 downto 0);
	hvend	:in std_logic_vector(7 downto 0);
	vtotal	:in std_logic_vector(9 downto 0);
	vvbgn	:in std_logic_vector(9 downto 0);
	vvend	:in std_logic_vector(9 downto 0);
	
	addrx	:out std_logic_vector(9 downto 0);
	addry	:out std_logic_vector(9 downto 0);
	sprite_in:in std_logic_vector(7 downto 0);
	
	palno	:out std_logic_vector(7 downto 0);
	palin	:in std_logic_vector(15 downto 0);
	
	gpal0no	:out std_logic_vector(7 downto 0);
	gpal1no	:out std_logic_vector(7 downto 0);
	gpalin	:in std_logic_vector(15 downto 0);
	
	rintline:in std_logic_vector(9 downto 0);
	rint	:out std_logic;
	
	gclrbgn	:in std_logic;
	gclrend	:in std_logic;
	gclrpage:in std_logic_vector(3 downto 0);
	gclrbusy:out std_logic;
	
	clk		:in std_logic;
	rstn	:in std_logic
);
end vidcont;

architecture rtl of vidcont is
signal	ramsel	:std_logic;
signal	nxt_g0addr	:std_logic_vector(17 downto 0);
signal	nxt_g1addr	:std_logic_vector(17 downto 0);
signal	nxt_g2addr	:std_logic_vector(17 downto 0);
signal	nxt_g3addr	:std_logic_vector(17 downto 0);
signal	nxt_taddr	:std_logic_vector(arange-3 downto 0);
signal	cur_g0addr	:std_logic_vector(17 downto 0);
signal	cur_g1addr	:std_logic_vector(17 downto 0);
signal	cur_g2addr	:std_logic_vector(17 downto 0);
signal	cur_g3addr	:std_logic_vector(17 downto 0);
signal	cur_taddr	:std_logic_vector(arange-3 downto 0);
signal	nxt_g0rd	:std_logic;
signal	nxt_g1rd	:std_logic;
signal	nxt_g2rd	:std_logic;
signal	nxt_g3rd	:std_logic;
signal	nxt_trd		:std_logic;
signal	cur_g0rd	:std_logic;
signal	cur_g1rd	:std_logic;
signal	cur_g2rd	:std_logic;
signal	cur_g3rd	:std_logic;
signal	cur_trd		:std_logic;
signal	ten			:std_logic;
signal	g0en		:std_logic;
signal	g1en		:std_logic;
signal	g2en		:std_logic;
signal	g3en		:std_logic;
signal	t_rdat0		:std_logic_vector(15 downto 0);
signal	t_rdat1		:std_logic_vector(15 downto 0);
signal	t_rdat2		:std_logic_vector(15 downto 0);
signal	t_rdat3		:std_logic_vector(15 downto 0);
signal	g0_rdat		:std_logic_vector(15 downto 0);
signal	g1_rdat		:std_logic_vector(15 downto 0);
signal	g2_rdat		:std_logic_vector(15 downto 0);
signal	g3_rdat		:std_logic_vector(15 downto 0);

signal	cur_taddrh	:std_logic_vector(arange-9 downto 0);

signal	haddr	:std_logic_vector(9 downto 0);
signal	vaddr	:std_logic_vector(9 downto 0);

signal	haddr256:std_logic_vector(9 downto 0);
signal	haddr512:std_logic_vector(9 downto 0);

signal	haddrmod:std_logic_vector(9 downto 0);
signal	vaddrmod:std_logic_vector(9 downto 0);
signal	h3count	:integer range 0 to 2;

signal	hadly2	:std_logic_vector(9 downto 0);
signal	hadly1	:std_logic_vector(9 downto 0);
signal	thodly1	:std_logic_vector(3 downto 0);
signal	g0hodly1:std_logic_vector(3 downto 0);
signal	g1hodly1:std_logic_vector(3 downto 0);
signal	g2hodly1:std_logic_vector(3 downto 0);
signal	g3hodly1:std_logic_vector(3 downto 0);
signal	datsel,datseld:std_logic_vector(1 downto 0);

signal	thaddr_offset	:std_logic_vector(9 downto 0);
signal	tvaddr_offset	:std_logic_vector(9 downto 0);
signal	t_ddat	:std_logic_vector(3 downto 0);

signal	g0haddr_offset	:std_logic_vector(9 downto 0);
signal	g1haddr_offset	:std_logic_vector(9 downto 0);
signal	g2haddr_offset	:std_logic_vector(9 downto 0);
signal	g3haddr_offset	:std_logic_vector(9 downto 0);
signal	g0vaddr_offset	:std_logic_vector(9 downto 0);
signal	g1vaddr_offset	:std_logic_vector(9 downto 0);
signal	g2vaddr_offset	:std_logic_vector(9 downto 0);
signal	g3vaddr_offset	:std_logic_vector(9 downto 0);
signal	g40_ddat	:std_logic_vector(3 downto 0);
signal	g41_ddat	:std_logic_vector(3 downto 0);
signal	g42_ddat	:std_logic_vector(3 downto 0);
signal	g43_ddat	:std_logic_vector(3 downto 0);
signal	g80_ddat	:std_logic_vector(7 downto 0);
signal	g81_ddat	:std_logic_vector(7 downto 0);
signal	g16_ddat	:std_logic_vector(15 downto 0);

signal	g4p1_ddat	:std_logic_vector(3 downto 0);
signal	g4p2_ddat	:std_logic_vector(3 downto 0);
signal	g4p3_ddat	:std_logic_vector(3 downto 0);
signal	g4p4_ddat	:std_logic_vector(3 downto 0);
signal	g4_ddat		:std_logic_vector(3 downto 0);
signal	g8p1_ddat	:std_logic_vector(7 downto 0);
signal	g8p2_ddat	:std_logic_vector(7 downto 0);
signal	g8_ddat		:std_logic_vector(7 downto 0);

signal	nxt_g0r0c4addrh	:std_logic_vector(17 downto 7);
signal	cur_g0r0c4addrh	:std_logic_vector(17 downto 7);
signal	cur_g0r0c4addrl	:std_logic_vector(6 downto 0);
signal	nxt_g1r0c4addrh	:std_logic_vector(17 downto 7);
signal	cur_g1r0c4addrh	:std_logic_vector(17 downto 7);
signal	cur_g1r0c4addrl	:std_logic_vector(6 downto 0);
signal	nxt_g2r0c4addrh	:std_logic_vector(17 downto 7);
signal	cur_g2r0c4addrh	:std_logic_vector(17 downto 7);
signal	cur_g2r0c4addrl	:std_logic_vector(6 downto 0);
signal	nxt_g3r0c4addrh	:std_logic_vector(17 downto 7);
signal	cur_g3r0c4addrh	:std_logic_vector(17 downto 7);
signal	cur_g3r0c4addrl	:std_logic_vector(6 downto 0);

signal	nxt_g0r1c4addrh	:std_logic_vector(17 downto 8);
signal	cur_g0r1c4addrh	:std_logic_vector(17 downto 8);
signal	cur_g0r1c4addrl	:std_logic_vector(7 downto 0);

signal	nxt_g0r0c8addrh	:std_logic_vector(17 downto 8);
signal	cur_g0r0c8addrh	:std_logic_vector(17 downto 8);
signal	cur_g0r0c8addrl	:std_logic_vector(7 downto 0);
signal	nxt_g1r0c8addrh	:std_logic_vector(17 downto 8);
signal	cur_g1r0c8addrh	:std_logic_vector(17 downto 8);
signal	cur_g1r0c8addrl	:std_logic_vector(7 downto 0);

signal	nxt_g0r0c16addrh:std_logic_vector(17 downto 9);
signal	cur_g0r0c16addrh:std_logic_vector(17 downto 9);
signal	cur_g0r0c16addrl:std_logic_vector(8 downto 0);

signal	gdoten		:std_logic;
signal	tdoten		:std_logic;
signal	sdoten		:std_logic;
signal	xhtotal		:std_logic_vector(7 downto 0);
signal	xhvbgn		:std_logic_vector(7 downto 0);
signal	xhvend		:std_logic_vector(7 downto 0);
signal	xvtotal		:std_logic_vector(9 downto 0);
signal	xvvbgn		:std_logic_vector(9 downto 0);
signal	xvvend		:std_logic_vector(9 downto 0);
signal	xrintline	:std_logic_vector(9 downto 0);
signal	ivaddr		:std_logic_vector(9 downto 0);
signal	vviden,lvviden	:std_logic;
signal	hviden,lhviden	:std_logic;

signal	tpalpr0		:std_logic_vector(7 downto 0);
signal	tpalpr1		:std_logic_vector(7 downto 0);
signal	tenpr0		:std_logic;
signal	tenpr1		:std_logic;

signal	wdatpr0		:std_logic_vector(15 downto 0);
signal	wdatpr1		:std_logic_vector(15 downto 0);
signal	wdatpr2		:std_logic_vector(15 downto 0);

signal	wenpr0,wenpr0d	:std_logic;
signal	wenpr1,wenpr1d	:std_logic;
signal	wenpr2,wenpr2d	:std_logic;

signal	gclrrast	:std_logic_vector(9 downto 0);
signal	gclrbgnrq	:std_logic;
signal	gclrendrq	:std_logic;
signal	gclrbusyb	:std_logic;

signal	inter		:std_logic;

constant azero	:std_logic_vector(arange-1 downto 0)	:=(others=>'0');
begin

	xhtotal<=	htotal	when hfreq='1' else htotal(6 downto 0) & '0';
	xhvbgn<=	hvbgn	when hfreq='1' else hvbgn(6 downto 0) & '0';
	xhvend<=	hvend	when hfreq='1' else hvend(6 downto 0) & '0';
	xvtotal<=	vtotal	when hfreq='1' else vtotal(8 downto 0) & '0';
	xvvbgn<=	vvbgn	when hfreq='1' else vvbgn(8 downto 0) & '0';
	xvvend<=	vvend	when hfreq='1' else vvend(8 downto 0) & '0';

	process(clk)begin
		if(clk' event and clk='1')then
			hadly2<=hadly1;
			hadly1<=haddr;
			thodly1<=thaddr_offset(3 downto 0);
			g0hodly1<=g0haddr_offset(3 downto 0);
			g1hodly1<=g1haddr_offset(3 downto 0);
			g2hodly1<=g2haddr_offset(3 downto 0);
			g3hodly1<=g3haddr_offset(3 downto 0);
			datseld<=datsel;
			wenpr0d<=wenpr0;
			wenpr1d<=wenpr1;
			wenpr2d<=wenpr2;
			lhviden<=hviden;
		end if;
	end process;
	
	haddrmod<=	haddr256	when hres="00" else
				haddr512 when hres="01" else
				haddr;

	vaddrmod<=	'0' & vaddr(9 downto 1)	when vres='0' else
				vaddr;
				
	thaddr_offset<=t_hoffset+haddrmod;
	tvaddr_offset<=t_voffset+vaddrmod;
	nxt_taddr<=t_base(arange-1 downto 2)+(azero(arange-1 downto 19) & tvaddr_offset & "000000");
	cur_taddr<=cur_taddrh & thaddr_offset(9 downto 4);
	
	t_ddat<=t_rdat3(15) & t_rdat2(15) & t_rdat1(15) & t_rdat0(15) when thodly1(3 downto 0)=x"0" else
			t_rdat3(14) & t_rdat2(14) & t_rdat1(14) & t_rdat0(14) when thodly1(3 downto 0)=x"1" else
			t_rdat3(13) & t_rdat2(13) & t_rdat1(13) & t_rdat0(13) when thodly1(3 downto 0)=x"2" else
			t_rdat3(12) & t_rdat2(12) & t_rdat1(12) & t_rdat0(12) when thodly1(3 downto 0)=x"3" else
			t_rdat3(11) & t_rdat2(11) & t_rdat1(11) & t_rdat0(11) when thodly1(3 downto 0)=x"4" else
			t_rdat3(10) & t_rdat2(10) & t_rdat1(10) & t_rdat0(10) when thodly1(3 downto 0)=x"5" else
			t_rdat3( 9) & t_rdat2( 9) & t_rdat1( 9) & t_rdat0( 9) when thodly1(3 downto 0)=x"6" else
			t_rdat3( 8) & t_rdat2( 8) & t_rdat1( 8) & t_rdat0( 8) when thodly1(3 downto 0)=x"7" else
			t_rdat3( 7) & t_rdat2( 7) & t_rdat1( 7) & t_rdat0( 7) when thodly1(3 downto 0)=x"8" else
			t_rdat3( 6) & t_rdat2( 6) & t_rdat1( 6) & t_rdat0( 6) when thodly1(3 downto 0)=x"9" else
			t_rdat3( 5) & t_rdat2( 5) & t_rdat1( 5) & t_rdat0( 5) when thodly1(3 downto 0)=x"a" else
			t_rdat3( 4) & t_rdat2( 4) & t_rdat1( 4) & t_rdat0( 4) when thodly1(3 downto 0)=x"b" else
			t_rdat3( 3) & t_rdat2( 3) & t_rdat1( 3) & t_rdat0( 3) when thodly1(3 downto 0)=x"c" else
			t_rdat3( 2) & t_rdat2( 2) & t_rdat1( 2) & t_rdat0( 2) when thodly1(3 downto 0)=x"d" else
			t_rdat3( 1) & t_rdat2( 1) & t_rdat1( 1) & t_rdat0( 1) when thodly1(3 downto 0)=x"e" else
			t_rdat3( 0) & t_rdat2( 0) & t_rdat1( 0) & t_rdat0( 0) when thodly1(3 downto 0)=x"f" else
			x"0";
	
	g0haddr_offset<=	g0_hoffset+haddrmod when memres='1' else
						'0' & (g0_hoffset(8 downto 0)+haddrmod(8 downto 0));
	g0vaddr_offset<=	g0_voffset+vaddrmod when memres='1' else
						'0' & (g0_voffset(8 downto 0)+vaddrmod(8 downto 0));
	g1haddr_offset<='0' & (g1_hoffset+haddrmod(8 downto 0));
	g1vaddr_offset<='0' & (g1_voffset+vaddrmod(8 downto 0));
	g2haddr_offset<='0' & (g2_hoffset+haddrmod(8 downto 0));
	g2vaddr_offset<='0' & (g2_voffset+vaddrmod(8 downto 0));
	g3haddr_offset<='0' & (g3_hoffset+haddrmod(8 downto 0));
	g3vaddr_offset<='0' & (g3_voffset+vaddrmod(8 downto 0));
	
	nxt_g0r0c4addrh<="00" & g0vaddr_offset(8 downto 0);
	cur_g0r0c4addrl<=g0haddr_offset(8 downto 2);
	nxt_g1r0c4addrh<="01" & g1vaddr_offset(8 downto 0);
	cur_g1r0c4addrl<=g1haddr_offset(8 downto 2);
	nxt_g2r0c4addrh<="10" & g2vaddr_offset(8 downto 0);
	cur_g2r0c4addrl<=g2haddr_offset(8 downto 2);
	nxt_g3r0c4addrh<="11" & g3vaddr_offset(8 downto 0);
	cur_g3r0c4addrl<=g3haddr_offset(8 downto 2);

	nxt_g0r0c8addrh<='0' & g0vaddr_offset(8 downto 0);
	cur_g0r0c8addrl<=g0haddr_offset(8 downto 1);
	nxt_g1r0c8addrh<='1' & g2vaddr_offset(8 downto 0);
	cur_g1r0c8addrl<=g2haddr_offset(8 downto 1);

	nxt_g0r0c16addrh<=g0vaddr_offset(8 downto 0);
	cur_g0r0c16addrl<=g0haddr_offset(8 downto 0);

	nxt_g0r1c4addrh<=g0vaddr_offset(9 downto 0);
	cur_g0r1c4addrl<=g0haddr_offset(9 downto 2);
	
	nxt_g0addr<=	nxt_g0r0c4addrh & "0000000"		when memres='0' and gmode="00" else
					nxt_g0r0c8addrh & "00000000"	when memres='0' and gmode="01" else
					nxt_g0r0c16addrh & "000000000"	when memres='0' and gmode(1)='1' else
					nxt_g0r1c4addrh & "00000000"	when memres='1' else
					(others=>'0'); 
	nxt_g1addr<=	nxt_g1r0c4addrh & "0000000"		when memres='0' and gmode="00" else
					nxt_g0r0c8addrh & "10000000"	when memres='0' and gmode="01" else
					nxt_g0r0c16addrh & "010000000"	when memres='0' and gmode(1)='1' else
					nxt_g0r1c4addrh & "10000000"	when memres='1' else
					(others=>'0');
	nxt_g2addr<=	nxt_g2r0c4addrh & "0000000"		when memres='0' and gmode="00" else
					nxt_g1r0c8addrh & "00000000"	when memres='0' and gmode="01" else
					nxt_g0r0c16addrh & "100000000"	when memres='0' and gmode(1)='1' else
					(others=>'0');
	nxt_g3addr<=	nxt_g3r0c4addrh & "0000000"		when memres='0' and gmode="00" else
					nxt_g1r0c8addrh & "10000000"	when memres='0' and gmode="01" else
					nxt_g0r0c16addrh & "110000000"	when memres='0' and gmode(1)='1' else
					(others=>'0');
					
	cur_g0addr<=	cur_g0r0c4addrh & cur_g0r0c4addrl 						when memres='0' and gmode="00" else
					cur_g0r0c8addrh & '0' & cur_g0r0c8addrl(6 downto 0) 	when memres='0' and gmode="01" else
					cur_g0r0c16addrh & "00" & cur_g0r0c16addrl(6 downto 0)	when memres='0' and gmode(1)='1' else
					cur_g0r1c4addrh & '0' & cur_g0r1c4addrl(6 downto 0)		when memres='1' else
					(others=>'0');
	cur_g1addr<=	cur_g1r0c4addrh & cur_g1r0c4addrl 						when memres='0' and gmode="00" else
					cur_g0r0c8addrh & '1' & cur_g0r0c8addrl(6 downto 0) 	when memres='0' and gmode="01" else
					cur_g0r0c16addrh & "01" & cur_g0r0c16addrl(6 downto 0)	when memres='0' and gmode(1)='1' else
					cur_g0r1c4addrh & '1' & cur_g0r1c4addrl(6 downto 0)		when memres='1' else
					(others=>'0');
	cur_g2addr<=	cur_g2r0c4addrh & cur_g2r0c4addrl 						when memres='0' and gmode="00" else
					cur_g1r0c8addrh & '0' & cur_g1r0c8addrl(6 downto 0) 	when memres='0' and gmode="01" else
					cur_g0r0c16addrh & "10" & cur_g0r0c16addrl(6 downto 0)	when memres='0' and gmode(1)='1' else
					(others=>'0');
	cur_g3addr<=	cur_g3r0c4addrh & cur_g3r0c4addrl 						when memres='0' and gmode="00" else
					cur_g1r0c8addrh & '1' & cur_g1r0c8addrl(6 downto 0) 	when memres='0' and gmode="01" else
					cur_g0r0c16addrh & "11" & cur_g0r0c16addrl(6 downto 0)	when memres='0' and gmode(1)='1' else
					(others=>'0');

	datsel<=		cur_g1r0c8addrl(7) & cur_g0r0c8addrl(7) when memres='0' and gmode="01" else
					cur_g0r0c16addrl(8 downto 7) when memres='0' and gmode(1)='1' else
					'0' & cur_g0r1c4addrl(7) when memres='1' else
					(others=>'0');
	
	g40_ddat<=	g1_rdat(15 downto 12) when g0hodly1(1 downto 0)="00" and memres='1' and datseld(0)='1' else
				g1_rdat(11 downto  8) when g0hodly1(1 downto 0)="01" and memres='1' and datseld(0)='1' else
				g1_rdat( 7 downto  4) when g0hodly1(1 downto 0)="10" and memres='1' and datseld(0)='1' else
				g1_rdat( 3 downto  0) when g0hodly1(1 downto 0)="11" and memres='1' and datseld(0)='1' else
				g0_rdat(15 downto 12) when g0hodly1(1 downto 0)="00" else
				g0_rdat(11 downto  8) when g0hodly1(1 downto 0)="01" else
				g0_rdat( 7 downto  4) when g0hodly1(1 downto 0)="10" else
				g0_rdat( 3 downto  0) when g0hodly1(1 downto 0)="11" else
				x"0";
	g41_ddat<=	g1_rdat(15 downto 12) when g1hodly1(1 downto 0)="00" else
				g1_rdat(11 downto  8) when g1hodly1(1 downto 0)="01" else
				g1_rdat( 7 downto  4) when g1hodly1(1 downto 0)="10" else
				g1_rdat( 3 downto  0) when g1hodly1(1 downto 0)="11" else
				x"0";
	g42_ddat<=	g2_rdat(15 downto 12) when g2hodly1(1 downto 0)="00" else
				g2_rdat(11 downto  8) when g2hodly1(1 downto 0)="01" else
				g2_rdat( 7 downto  4) when g2hodly1(1 downto 0)="10" else
				g2_rdat( 3 downto  0) when g2hodly1(1 downto 0)="11" else
				x"0";
	g43_ddat<=	g3_rdat(15 downto 12) when g3hodly1(1 downto 0)="00" else
				g3_rdat(11 downto  8) when g3hodly1(1 downto 0)="01" else
				g3_rdat( 7 downto  4) when g3hodly1(1 downto 0)="10" else
				g3_rdat( 3 downto  0) when g3hodly1(1 downto 0)="11" else
				x"0";
	
	g80_ddat<=	g0_rdat(15 downto 8) when g0hodly1(0)='0' and datseld(0)='0' else
				g0_rdat( 7 downto 0) when g0hodly1(0)='1' and datseld(0)='0' else
				g1_rdat(15 downto 8) when g0hodly1(0)='0' and datseld(0)='1' else
				g1_rdat( 7 downto 0) when g0hodly1(0)='1' and datseld(0)='1' else
				x"00";
	g81_ddat<=	g2_rdat(15 downto 8) when g2hodly1(0)='0' and datseld(1)='0' else
				g2_rdat( 7 downto 0) when g2hodly1(0)='1' and datseld(1)='0' else
				g3_rdat(15 downto 8) when g2hodly1(0)='0' and datseld(1)='1' else
				g3_rdat( 7 downto 0) when g2hodly1(0)='1' and datseld(1)='1' else
				x"00";
	
	g16_ddat<=	g0_rdat when datseld="00" else
				g1_rdat when datseld="01" else
				g2_rdat when datseld="10" else
				g3_rdat when datseld="11" else
				x"0000";
	
	g4p1_ddat<=	g40_ddat when grpri(1 downto 0)="00" else
				g41_ddat when grpri(1 downto 0)="01" else
				g42_ddat when grpri(1 downto 0)="10" else
				g43_ddat when grpri(1 downto 0)="11" else
				x"0";
	g4p2_ddat<=	g40_ddat when grpri(3 downto 2)="00" else
				g41_ddat when grpri(3 downto 2)="01" else
				g42_ddat when grpri(3 downto 2)="10" else
				g43_ddat when grpri(3 downto 2)="11" else
				x"0";
	g4p3_ddat<=	g40_ddat when grpri(5 downto 4)="00" else
				g41_ddat when grpri(5 downto 4)="01" else
				g42_ddat when grpri(5 downto 4)="10" else
				g43_ddat when grpri(5 downto 4)="11" else
				x"0";
	g4p4_ddat<=	g40_ddat when grpri(7 downto 6)="00" else
				g41_ddat when grpri(7 downto 6)="01" else
				g42_ddat when grpri(7 downto 6)="10" else
				g43_ddat when grpri(7 downto 6)="11" else
				x"0";
	
	g4_ddat<=	g4p1_ddat when memres='0' and  g4p1_ddat/=x"0" and graphen(0)='1' else
				g4p2_ddat when memres='0' and  g4p2_ddat/=x"0" and graphen(1)='1' else
				g4p3_ddat when memres='0' and  g4p3_ddat/=x"0" and graphen(2)='1' else
				g4p4_ddat when memres='0' and g4p4_ddat/=x"0" and graphen(3)='1' else
				g40_ddat when memres='1' and graphen(4)='1' else
				x"0";
	
	g8p1_ddat<=	g80_ddat	when grpri(1)='0' else
				g81_ddat	when grpri(1)='1' else
				x"00";
	g8p2_ddat<=	g80_ddat	when grpri(5)='0' else
				g81_ddat	when grpri(5)='1' else
				x"00";

	g8_ddat<=	g8p1_ddat when g8p1_ddat/=x"00" and graphen(0)='1' else
				g8p2_ddat when g8p2_ddat/=x"00" and graphen(3)='1' else
				x"00";
	
	gpal0no<=	x"0" & g4_ddat when gmode="00" else
				g8_ddat when gmode="01" else
				g16_ddat(7 downto 0);
	gpal1no<=	x"0" & g4_ddat when gmode="00" else
				g8_ddat when gmode="01" else
				g16_ddat(15 downto 8);


	process(clk,rstn)
	variable hvwidth	:std_logic_vector(9 downto 0);
	begin
		if(rstn='0')then
			haddr<=(others=>'0');
			vaddr<=(others=>'0');
			haddr256<=(others=>'0');
			haddr512<=(others=>'0');
			h3count<=0;
			lbwr<='0';
			nxt_trd<='0';
			nxt_g0rd<='0';
			nxt_g1rd<='0';
			nxt_g2rd<='0';
			nxt_g3rd<='0';
			cur_trd<='0';
			cur_g0rd<='0';
			cur_g1rd<='0';
			cur_g2rd<='0';
			cur_g3rd<='0';
			ramsel<='0';
			cur_taddrh<=(others=>'0');
			cur_g0r0c4addrh<=(others=>'0');
			cur_g1r0c4addrh<=(others=>'0');
			cur_g2r0c4addrh<=(others=>'0');
			cur_g3r0c4addrh<=(others=>'0');
			cur_g0r1c4addrh<=(others=>'0');
			cur_g0r0c8addrh<=(others=>'0');
			cur_g1r0c8addrh<=(others=>'0');
			cur_g0r0c16addrh<=(others=>'0');
			vviden<='0';
			lvviden<='0';
			hviden<='0';
			gclrbusyb<='0';
			gclrrast<=(others=>'0');
			gclrbgnrq<='0';
			gclrendrq<='0';
		elsif(clk' event and clk='1')then
			lbwr<='0';
			if(gclrbgn='1' and gclrbusyb='0')then
				gclrbusyb<='1';
				gclrbgnrq<='1';
			elsif(gclrend='1')then
				gclrendrq<='1';
			end if;
			if(hcomp='1')then
				if(gclrbgnrq='1')then
					gclrrast<=haddr;
					gclrbgnrq<='0';
				elsif(gclrendrq='1' or gclrrast=haddr)then
					gclrendrq<='0';
					gclrbusyb<='0';
				end if;
			end if;
			if(vpstart='1')then
				haddr<=(others=>'0');
				haddr256<=(others=>'0');
				haddr512<=(others=>'0');
				vaddr<=(others=>'0');
				h3count<=0;
				g0_clear<=	gclrpage(0) and gclrbusyb;
				g1_clear<=	gclrpage(1) and gclrbusyb;
				g2_clear<=	gclrpage(2) and gclrbusyb;
				g3_clear<=	gclrpage(3) and gclrbusyb;
				nxt_trd<=	ten;
				nxt_g0rd<=	g0en and (not (gclrpage(0) and gclrbusyb));
				nxt_g1rd<=	g1en and (not (gclrpage(1) and gclrbusyb));
				nxt_g2rd<=	g2en and (not (gclrpage(2) and gclrbusyb));
				nxt_g3rd<=	g3en and (not (gclrpage(3) and gclrbusyb));
				cur_trd<=	'0';
				cur_g0rd<=	'0';
				cur_g1rd<=	'0';
				cur_g2rd<=	'0';
				cur_g3rd<=	'0';
				ramsel<=not ramsel;
				vviden<='1';
				hviden<='1';
			elsif(hcomp='1')then
				cur_taddrh<=nxt_taddr(arange-3 downto 6);
				cur_g0r0c4addrh<=nxt_g0r0c4addrh;
				cur_g1r0c4addrh<=nxt_g1r0c4addrh;
				cur_g2r0c4addrh<=nxt_g2r0c4addrh;
				cur_g3r0c4addrh<=nxt_g3r0c4addrh;
				cur_g0r1c4addrh<=nxt_g0r1c4addrh;
				cur_g0r0c8addrh<=nxt_g0r0c8addrh;
				cur_g1r0c8addrh<=nxt_g1r0c8addrh;
				cur_g0r0c16addrh<=nxt_g0r0c16addrh;
				haddr<=(others=>'0');
				haddr256<=(others=>'0');
				haddr512<=(others=>'0');
				h3count<=0;
				lvviden<=vviden;
				vaddr<=vaddr+"0000000001";
				hviden<='1';
				if(vaddr<(xvvend-xvvbgn-"0000000001"))then
					g0_clear<=	gclrpage(0) and gclrbusyb;
					g1_clear<=	gclrpage(1) and gclrbusyb;
					g2_clear<=	gclrpage(2) and gclrbusyb;
					g3_clear<=	gclrpage(3) and gclrbusyb;
					nxt_trd<=	ten;
					nxt_g0rd<=	g0en and (not (gclrpage(0) and gclrbusyb));
					nxt_g1rd<=	g1en and (not (gclrpage(1) and gclrbusyb));
					nxt_g2rd<=	g2en and (not (gclrpage(2) and gclrbusyb));
					nxt_g3rd<=	g3en and (not (gclrpage(3) and gclrbusyb));
					vviden<='1';
				else
					g0_clear<=	'0';
					g1_clear<=	'0';
					g2_clear<=	'0';
					g3_clear<=	'0';
					nxt_trd<=	'0';
					nxt_g0rd<=	'0';
					nxt_g1rd<=	'0';
					nxt_g2rd<=	'0';
					nxt_g3rd<=	'0';
					vviden<='0';
				end if;
				cur_trd<=nxt_trd;
				cur_g0rd<=nxt_g0rd;
				cur_g1rd<=nxt_g1rd;
				cur_g2rd<=nxt_g2rd;
				cur_g3rd<=nxt_g3rd;
				ramsel<=not ramsel;
			else
				if(haddr<"1111111111")then
					hvwidth:=(hvend(6 downto 0)-hvbgn(6 downto 0)-"0000001") & "111";
					haddr<=haddr+"0000000001";
					lbwr<='1';
					if(hres(1)='1' and haddr=hvwidth)then
						hviden<='0';
					end if;
					if(h3count<2)then
						h3count<=h3count+1;
					else
						h3count<=0;
						haddr256<=haddr256+"0000000001";
						if(hres="00" and haddr256=hvwidth)then
							hviden<='0';
						end if;
					end if;
					if(h3count=1 or h3count=2)then
						haddr512<=haddr512+"0000000001";
						if(hres="01" and haddr512=hvwidth)then
							hviden<='0';
						end if;
					end if;
				else
					cur_trd<=	'0';
					cur_g0rd<=	'0';
					cur_g1rd<=	'0';
					cur_g2rd<=	'0';
					cur_g3rd<=	'0';
				end if;
			end if;
		end if;
	end process;
	
	process(clk,rstn)begin
		if(rstn='0')then
			inter<='0';
		elsif(clk' event and clk='1')then
			if(vpstart='1')then
				inter<=not inter;
			end if;
		end if;
	end process;
	
	xrintline<=	rintline when hfreq='1' else rintline(8 downto 0) & '0';
	ivaddr<=	xrintline-xvvbgn when xrintline>xvvbgn else
				xrintline+xvvend;
	rint<=	'1' when vaddr=ivaddr else '0';
	
	addrx<=haddrmod(9 downto 0);
	addry<=vaddrmod(9 downto 0);
	tdoten<='0' when t_ddat="0000" or txten='0' else '1';
	sdoten<='0' when sprite_in(3 downto 0)="0000" or spren='0' else '1';
	gdoten<='0' when grpen='0' else
			'0' when g4_ddat="0000" and gmode="00" else
			'0' when g8_ddat=x"00" and gmode="01" else
			'0' when g16_ddat=x"0000" and gmode(1)='1' else
			'1';
	
	tpalpr0<=	"0000" & t_ddat	when pri_tx<pri_sp else
				sprite_in;
	tpalpr1<=	sprite_in		when pri_tx<pri_sp else
				"0000" & t_ddat;
	tenpr0<=	tdoten	when pri_tx<pri_sp else
				sdoten;
	tenpr1<=	sdoten	when pri_tx<pri_sp else
				tdoten;
				
	palno<=	tpalpr0 when tenpr0='1' else
			tpalpr1;
	
	
	wdatpr0<=	palin	when pri_tx="00" else
				palin	when pri_sp="00" else
				gpalin	when pri_gr="00" else
				(others=>'0');
	wdatpr1<=	palin	when pri_tx="01" else
				palin	when pri_sp="01" else
				gpalin	when pri_gr="01" else
				(others=>'0');
	wdatpr2<=	palin	when pri_tx="10" else
				palin	when pri_sp="10" else
				gpalin	when pri_gr="10" else
				(others=>'0');
	wenpr0<=	tdoten	when pri_tx="00" else
				sdoten	when pri_sp="00" else
				gdoten	when pri_gr="00" else
				'0';
	wenpr1<=	tdoten	when pri_tx="01" else
				sdoten	when pri_sp="01" else
				gdoten	when pri_gr="01" else
				'0';
	wenpr2<=	tdoten	when pri_tx="10" else
				sdoten	when pri_sp="10" else
				gdoten	when pri_gr="10" else
				'0';

	lbwdat<=	(others=>'0') when lvviden='0' or lhviden='0' else
				wdatpr0 when wenpr0d='1' else
				wdatpr1 when wenpr1d='1' else
				wdatpr2 when wenpr2d='1' else
				(others=>'0');
				
	lbaddr<=hadly2;
	
	g00_addr<=	g_base(arange-1 downto 18) & nxt_g0addr	when ramsel='0' else
				g_base(arange-1 downto 18) & cur_g0addr;
	g10_addr<=	g_base(arange-1 downto 18) & nxt_g0addr	when ramsel='1' else
				g_base(arange-1 downto 18) & cur_g0addr;
	g01_addr<=	g_base(arange-1 downto 18) & nxt_g1addr	when ramsel='0' else
				g_base(arange-1 downto 18) & cur_g1addr;
	g11_addr<=	g_base(arange-1 downto 18) & nxt_g1addr	when ramsel='1' else
				g_base(arange-1 downto 18) & cur_g1addr;
	g02_addr<=	g_base(arange-1 downto 18) & nxt_g2addr	when ramsel='0' else
				g_base(arange-1 downto 18) & cur_g2addr;
	g12_addr<=	g_base(arange-1 downto 18) & nxt_g2addr	when ramsel='1' else
				g_base(arange-1 downto 18) & cur_g2addr;
	g03_addr<=	g_base(arange-1 downto 18) & nxt_g3addr	when ramsel='0' else
				g_base(arange-1 downto 18) & cur_g3addr;
	g13_addr<=	g_base(arange-1 downto 18) & nxt_g3addr	when ramsel='1' else
				g_base(arange-1 downto 18) & cur_g3addr;
	t0_addr<=	nxt_taddr	when ramsel='0' else
				cur_taddr;
	t1_addr<=	nxt_taddr	when ramsel='1' else
				cur_taddr;
	g0_caddr<=	g_base(arange-1 downto 18) & nxt_g0addr(17 downto 7);
	g1_caddr<=	g_base(arange-1 downto 18) & nxt_g1addr(17 downto 7);
	g2_caddr<=	g_base(arange-1 downto 18) & nxt_g2addr(17 downto 7);
	g3_caddr<=	g_base(arange-1 downto 18) & nxt_g3addr(17 downto 7);
	g0_rdat<=	(others=>'0') when cur_g0rd='0' else
				g10_rdat	when ramsel='0' else
				g00_rdat;
	g1_rdat<=	(others=>'0') when cur_g1rd='0' else
				g11_rdat	when ramsel='0' else
				g01_rdat;
	g2_rdat<=	(others=>'0') when cur_g2rd='0' else
				g12_rdat	when ramsel='0' else
				g02_rdat;
	g3_rdat<=	(others=>'0') when cur_g3rd='0' else
				g13_rdat	when ramsel='0' else
				g03_rdat;
	t_rdat0<=	t1_rdat0	when ramsel='0' else
				t0_rdat0;
	t_rdat1<=	t1_rdat1	when ramsel='0' else
				t0_rdat1;
	t_rdat2<=	t1_rdat2	when ramsel='0' else
				t0_rdat2;
	t_rdat3<=	t1_rdat3	when ramsel='0' else
				t0_rdat3;
	g00_rd<=	nxt_g0rd	when ramsel='0' else
				cur_g0rd;
	g10_rd<=	nxt_g0rd	when ramsel='1' else
				cur_g0rd;
	g01_rd<=	nxt_g1rd	when ramsel='0' else
				cur_g1rd;
	g11_rd<=	nxt_g1rd	when ramsel='1' else
				cur_g1rd;
	g02_rd<=	nxt_g2rd	when ramsel='0' else
				cur_g2rd;
	g12_rd<=	nxt_g2rd	when ramsel='1' else
				cur_g2rd;
	g03_rd<=	nxt_g3rd	when ramsel='0' else
				cur_g3rd;
	g13_rd<=	nxt_g3rd	when ramsel='1' else
				cur_g3rd;
	t0_rd<=		nxt_trd		when ramsel='0' else
				cur_trd;
	t1_rd<=		nxt_trd		when ramsel='1' else
				cur_trd;
	
	g0en<=	'0' when grpen='0' else
			'1';
	g1en<=	'0' when grpen='0' else
			'1';
	g2en<=	'0' when grpen='0' else
			'0' when memres='1' else
			'1';
	g3en<=	'0' when grpen='0' else
			'0' when memres='1' else
			'1';
	ten<=	'0' when txten='0' else
			'1';
	
	gclrbusy<=gclrbusyb;
	
end rtl;
				
			
