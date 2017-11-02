LIBRARY	IEEE;
	USE	IEEE.STD_LOGIC_1164.ALL;
	USE	IEEE.STD_LOGIC_UNSIGNED.ALL;
	use ieee.std_logic_arith.all;

entity OPM is
generic(
	res		:integer	:=9
);
port(
	DIN		:in std_logic_vector(7 downto 0);
	DOUT	:out std_logic_vector(7 downto 0);
	DOE		:out std_logic;
	CSn		:in std_logic;
	ADR0	:in std_logic;
	RDn		:in std_logic;
	WRn		:in std_logic;
	INTn	:out std_logic;
	
	sndL	:out std_logic_vector(res-1 downto 0);
	sndR	:out std_logic_vector(res-1 downto 0);
	
	CT1		:out std_logic;
	CT2		:out std_logic;
	
--	monout	:out std_logic_vector(15 downto 0);

	clk		:in std_logic;
	sft		:in std_logic;
	rstn	:in std_logic
);
end OPM;

architecture rtl of OPM is
component OPNREG
	PORT
	(
		address_a		: IN STD_LOGIC_VECTOR (7 DOWNTO 0);
		address_b		: IN STD_LOGIC_VECTOR (7 DOWNTO 0);
		clock		: IN STD_LOGIC  := '1';
		data_a		: IN STD_LOGIC_VECTOR (7 DOWNTO 0);
		data_b		: IN STD_LOGIC_VECTOR (7 DOWNTO 0);
		wren_a		: IN STD_LOGIC  := '0';
		wren_b		: IN STD_LOGIC  := '0';
		q_a		: OUT STD_LOGIC_VECTOR (7 DOWNTO 0);
		q_b		: OUT STD_LOGIC_VECTOR (7 DOWNTO 0)
	);
END component;

component sintbl
port(
	addr	:in std_logic_vector(15 downto 0);
	
	dat		:out std_logic_vector(15 downto 0);

	clk		:in std_logic
);
end component;

component TLtbl
	PORT
	(
		address		: IN STD_LOGIC_VECTOR (6 DOWNTO 0);
		clock		: IN STD_LOGIC  := '1';
		q		: OUT STD_LOGIC_VECTOR (15 DOWNTO 0)
	);
END component;

component muls16xu16
port(
	ins		:in std_logic_vector(15 downto 0);
	inu		:in std_logic_vector(15 downto 0);
	
	q		:out std_logic_vector(15 downto 0);
	
	clk		:in std_logic
);
end component;

component  FMreg
port(
	CH		:std_logic_vector(1 downto 0);
	SL		:std_logic_vector(1 downto 0);
	RDAT	:out std_logic_vector(15 downto 0);
	WDAT	:in std_logic_vector(15 downto 0);
	WR		:in std_logic;

	clk		:in std_logic
);
end component;

component noisegen
port(
	sft		:in std_logic;
	noise	:out std_logic;
	
	clk		:in std_logic;
	rstn	:in std_logic
);
end component;

signal	PSG_TUNN,PSG_TUN0,PSG_TUN1,PSG_TUN2
					:std_logic_vector(11 downto 0);
signal	PSG_TUNC	:std_logic_vector(11 downto 0);
signal	PSG_TENn	:std_logic_vector(2 downto 0);
signal	PSG_NENn	:std_logic_vector(2 downto 0);
signal	PSG_PDIR	:std_logic_vector(1 downto 0);
signal	PSG_AMP0,PSG_AMP1,PSG_AMP2
					:std_logic_vector(4 downto 0);
signal	PSG_AMPC	:std_logic_vector(4 downto 0);
signal	PSG_EPER	:std_logic_vector(15 downto 0);
signal	PSG_ESHAPE	:std_logic_vector(3 downto 0);
signal	PSG_PA		:std_logic_vector(7 downto 0);
signal	PSG_PB		:std_logic_vector(7 downto 0);

signal	CPU_RADR	:std_logic_vector(7 downto 0);
signal	CPU_WDAT	:std_logic_vector(7 downto 0);
signal	INT_RADR	:std_logic_vector(7 downto 0);
signal	INT_RDAT	:std_logic_vector(7 downto 0);
signal	INT_RWDAT	:std_logic_vector(7 downto 0);
signal	INT_RWR		:std_logic;
signal	CPU_RWR		:std_logic;

signal	STATUS		:std_logic_vector(7 downto 0);
signal	BUSY		:std_logic;
signal	FLAG		:std_logic_vector(1 downto 0);
signal	TARST,TBRST	:std_logic;
signal	TAEN,TBEN	:std_logic;
signal	TALD,TBLD	:std_logic;
signal	TARDAT,TACOUNT		:std_logic_vector(9 downto 0);
signal	TBRDAT,TBCOUNT		:std_logic_vector(7 downto 0);

constant fslength	:integer	:=160;
signal	fscount		:integer range 0 to fslength-1;

constant pslength	:integer	:=40;
signal	pscount		:integer range 0 to pslength-1;

signal	thitard,thitawd
					:std_logic_vector(15 downto 0);
signal	thitawr			:std_logic;
signal	elevrd,elevwd	:std_logic_vector(15 downto 0);
signal	elevwr			:std_logic;
signal	sin1a,sin2a,sin3a
					:std_logic_vector(15 downto 0);
signal	ooutrd,ooutwd
				:std_logic_vector(15 downto 0);
signal	ooutwr		:std_logic;
signal	toutxa,toutxb,toutxc,toutxd,
		toutc		:std_logic_vector(15 downto 0);
signal	coout		:std_logic_vector(15 downto 0);

signal	cout1,cout2,cout3
					:std_logic_vector(17 downto 0);
					
signal	fm_smix		:std_logic_vector(19 downto 0);

signal	channel		:std_logic_vector(1 downto 0);
signal	slot		:std_logic_vector(1 downto 0);

type FMSTATE_t is (
	FS_IDLE,
	FS_TIMER,
	FS_C1Oa,
	FS_C1Ob,
	FS_C1Oc,
	FS_C1Od,
	FS_C2Oa,
	FS_C2Ob,
	FS_C2Oc,
	FS_C2Od,
	FS_C3Oa,
	FS_C3Ob,
	FS_C3Oc,
	FS_C3Od,
	FS_MIX
);
signal	FMSTATE	:FMSTATE_t;
signal	fmsft	:std_logic;
signal	psgsft	:std_logic;
signal	intbgn	:std_logic;
signal	intend	:std_logic;
signal	thita	:std_logic_vector(15 downto 0);
signal	sinthita:std_logic_vector(15 downto 0);

type INTST_t is(
	IS_IDLE,
	IS_INIT,
	IS_READF2,
	IS_READF1,
	IS_READALGFB,
	IS_SETDETMUL,
	IS_READDETMUL,
	IS_CALCTHITA,
	IS_READKSAR,
	IS_READDR,
	IS_READSR,
	IS_READSLRR,
	IS_READTL,
	IS_CALCENV,
	IS_CALCTL,
	IS_CMIX
);
signal	INTST	:INTST_t;
signal	TBPS	:integer range 0 to 15;

signal	Key1,Key2,Key3	:std_logic_vector(3 downto 0);
signal	keyc	:std_logic;

--frequency parameter
signal	C3mode,C3M	:std_logic_vector(1 downto 0);
signal	Algo	:std_logic_vector(2 downto 0);
signal	FdBck	:std_logic_vector(2 downto 0);
signal	Blk		:std_logic_vector(2 downto 0);
signal	Fnum	:std_logic_vector(10 downto 0);
signal	Note	:std_logic_vector(1 downto 0);
signal	Mult	:std_logic_vector(3 downto 0);
signal	Detune	:std_logic_vector(2 downto 0);
signal	SFnum	:std_logic_vector(15 downto 0);
signal	MSFnum	:std_logic_vector(15 downto 0);
signal	FBsrc	:std_logic_vector(15 downto 0);
signal	addfb	:std_logic_vector(15 downto 0);
signal	addfbm	:std_logic_vector(4 downto 0);
signal	outa,outb,outc	:std_logic_vector(15 downto 0);

--enverope parameter
signal	AR		:std_logic_vector(4 downto 0);
signal	KS		:std_logic_vector(1 downto 0);
signal	DR		:std_logic_vector(4 downto 0);
signal	SL		:std_logic_vector(3 downto 0);
signal	RR		:std_logic_vector(3 downto 0);
signal	SR		:std_logic_vector(4 downto 0);
signal	SLEV	:std_logic_vector(15 downto 0);
signal	TL		:std_logic_vector(6 downto 0);
signal	TLEV	:std_logic_vector(15 downto 0);
signal	envcalc	:std_logic;

type envstate_t is(
	es_OFF,
	es_Atk,
	es_Dec,
	es_Sus,
	es_Rel
);
signal	envst_1a,envst_1b,envst_1c,envst_1d,
		envst_2a,envst_2b,envst_2c,envst_2d,
		envst_3a,envst_3b,envst_3c,envst_3d,
		cenvst,nenvst	:envstate_t;
		
signal	psgch	:integer range 0 to 3;
signal	psglog	:std_logic_vector(2 downto 0);
signal	noiselog	:std_logic;
signal	noisesft	:std_logic;
signal	psgcountn,psgcount0,psgcount1,psgcount2,psgcountc,psgcountwd	:std_logic_vector(11 downto 0);
constant psgczero	:std_logic_vector(11 downto 0)	:=(others=>'0');
signal	psgcountwr	:std_logic;
signal	psgenvcount	:std_logic_vector(15 downto 0);
type PSGST_t is (
	PST_IDLE,
	PST_NF,
	PST_C0F,
	PST_C0L,
	PST_C1F,
	PST_C1L,
	PST_C2F,
	PST_C2L,
	PST_MIX
);
signal	PSGST	:PSGST_t;

signal	PSG_LEV	:std_logic_vector(3 downto 0);
signal	PSG_VAL	:std_logic_vector(15 downto 0);

type PENV_t is (
	PEM_NOP,
	PEM_INC,
	PEM_DEC
);
signal	PENVM		:PENV_t;
signal	lPSGON		:std_logic;
signal	PENV_LEV	:std_logic_vector(3 downto 0);
signal	psg_sgn0,psg_sgn1,psg_sgn2	:std_logic_vector(15 downto 0);
signal	psg_smix	:std_logic_vector(17 downto 0);
signal	sndmix		:std_logic_vector(20 downto 0);
begin
	STATUS<=BUSY & "00000" & FLAG;
	
	process(clk,rstn)begin
		if(rstn='0')then
			fmsft<='0';
			fscount<=fslength-1;
		elsif(clk' event and clk='1')then
			if(sft='1')then
				fmsft<='0';
				if(fscount>0)then
					fscount<=fscount-1;
				else
					fmsft<='1';
					fscount<=fslength-1;
				end if;
			end if;
		end if;
	end process;

	process(clk,rstn)begin
		if(rstn='0')then
			psgsft<='0';
			pscount<=pslength-1;
		elsif(clk' event and clk='1')then
			if(sft='1')then
				psgsft<='0';
				if(pscount>0)then
					pscount<=pscount-1;
				else
					psgsft<='1';
					pscount<=pslength-1;
				end if;
			end if;
		end if;
	end process;

	process(clk,rstn)begin
		if(rstn='0')then
			CPU_RADR<=(others=>'0');
			BUSY<='1';
			PSG_TUN0<=(others=>'0');
			PSG_TUN1<=(others=>'0');
			PSG_TUN2<=(others=>'0');
			PSG_TUNN<=(others=>'0');
			PSG_TENn<=(others=>'0');
			PSG_NENn<=(others=>'0');
			PSG_AMP0<=(others=>'0');
			PSG_AMP1<=(others=>'0');
			PSG_AMP2<=(others=>'0');
			PSG_EPER<=(others=>'0');
			PSG_ESHAPE<=(others=>'0');
			CPU_RWR<='0';
			TALD<='0';
			TBLD<='0';
			TAEN<='0';
			TBEN<='0';
			TARST<='0';
			TBRST<='0';
			C3M<=(others=>'0');
			TARDAT<=(others=>'0');
			TBRDAT<=(others=>'0');
			CT1<='0';
			CT2<='0';
			Key1<=(others=>'0');
			Key2<=(others=>'0');
			Key3<=(others=>'0');
		elsif(clk' event and clk='1')then
			CPU_RWR<='0';
			TARST<='0';
			TBRST<='0';
			if(BUSY='1')then
				if(CPU_RADR/=x"ff")then
					CPU_RADR<=CPU_RADR+x"01";
					CPU_RWR<='1';
				else
					CPU_RADR<=(others=>'0');
					BUSY<='0';
				end if;
			else
				if(CSn='0' and WRn='0')then
					if(ADR0='0')then
						CPU_RADR<=DIN;
					else
						CPU_RWR<='1';
						case CPU_RADR is
						when x"00" =>
							PSG_TUN0(7 downto 0)<=DIN;
						when x"01" =>
							PSG_TUN0(11 downto 8)<=DIN(3 downto 0);
						when x"02" =>
							PSG_TUN1(7 downto 0)<=DIN;
						when x"03" =>
							PSG_TUN1(11 downto 8)<=DIN(3 downto 0);
						when x"04" =>
							PSG_TUN2(7 downto 0)<=DIN;
						when x"05" =>
							PSG_TUN2(11 downto 8)<=DIN(3 downto 0);
						when x"06" =>
							PSG_TUNN<="0000000" & DIN(4 downto 0);
						when x"07" =>
							PSG_TENn<=DIN(2 downto 0);
							PSG_NENn<=DIN(5 downto 3);
							PSG_PDIR<=DIN(7 downto 6);
						when x"08" =>
							PSG_AMP0<=DIN(4 downto 0);
						when x"09" =>
							PSG_AMP1<=DIN(4 downto 0);
						when x"0a" =>
							PSG_AMP2<=DIN(4 downto 0);
						when x"0b" =>
							PSG_EPER(7 downto 0)<=DIN;
						when x"0c" =>
							PSG_EPER(15 downto 8)<=DIN;
						when x"0d" =>
							PSG_ESHAPE<=DIN(3 downto 0);
						when x"1b" =>
							CT1<=DIN(7);
							CT2<=DIN(6);
						when x"10" =>
							TARDAT(9 downto 2)<=DIN;
						when x"11" =>
							TARDAT(1 downto 0)<=DIN(1 downto 0);
						when x"12" =>
							TBRDAT<=DIN;
						when x"14"=>
							TALD<=DIN(0);
							TBLD<=DIN(1);
							TAEN<=DIN(2);
							TBEN<=DIN(3);
							TARST<=DIN(4);
							TBRST<=DIN(5);
							C3M<=DIN(7 downto 6);
						when x"28" =>
							case DIN(1 downto 0) is
							when "00" =>
								Key1<=DIN(7 downto 4);
							when "01" =>
								Key2<=DIN(7 downto 4);
							when "10" =>
								Key3<=DIN(7 downto 4);
							when others =>
							end case;
						when others=>
						end case;
					end if;
				end if;
			end if;
		end if;
	end process;
	
	CPU_WDAT<=x"00" when BUSY='1' else DIN;

	DOUT<=STATUS;

	DOE<='1' when CSn='0' and RDn='0' else '0';
	
	process(clk,rstn)begin
		if(rstn='0')then
			FMSTATE<=FS_IDLE;
			intbgn<='0';
		elsif(clk' event and clk='1')then
			if(BUSY='0' and sft='1')then
				intbgn<='0';
				case FMSTATE is
				when FS_IDLE =>
					if(fmsft='1')then
						FMSTATE<=FS_TIMER;
						intbgn<='1';
					end if;
				when FS_TIMER =>
					if(intend='1')then
						FMSTATE<=FS_C1Oa;
						INTBGN<='1';
					end if;
				when FS_C1Oa =>
					if(intend='1')then
						FMSTATE<=FS_C1Ob;
						INTBGN<='1';
					end if;
				when FS_C1Ob =>
					if(intend='1')then
						FMSTATE<=FS_C1Oc;
						INTBGN<='1';
					end if;
				when FS_C1Oc =>
					if(intend='1')then
						FMSTATE<=FS_C1Od;
						INTBGN<='1';
					end if;
				when FS_C1Od =>
					if(intend='1')then
						FMSTATE<=FS_C2Oa;
						INTBGN<='1';
					end if;
				when FS_C2Oa =>
					if(intend='1')then
						FMSTATE<=FS_C2Ob;
						INTBGN<='1';
					end if;
				when FS_C2Ob =>
					if(intend='1')then
						FMSTATE<=FS_C2Oc;
						INTBGN<='1';
					end if;
				when FS_C2Oc =>
					if(intend='1')then
						FMSTATE<=FS_C2Od;
						INTBGN<='1';
					end if;
				when FS_C2Od =>
					if(intend='1')then
						FMSTATE<=FS_C3Oa;
						INTBGN<='1';
					end if;
				when FS_C3Oa =>
					if(intend='1')then
						FMSTATE<=FS_C3Ob;
						INTBGN<='1';
					end if;
				when FS_C3Ob =>
					if(intend='1')then
						FMSTATE<=FS_C3Oc;
						INTBGN<='1';
					end if;
				when FS_C3Oc =>
					if(intend='1')then
						FMSTATE<=FS_C3Od;
						INTBGN<='1';
					end if;
				when FS_C3Od =>
					if(intend='1')then
						FMSTATE<=FS_MIX;
						INTBGN<='1';
					end if;
				when FS_MIX =>
					if(intend='1')then
						FMSTATE<=FS_IDLE;
					end if;
				when others=>
					FMSTATE<=FS_IDLE;
				end case;
			end if;
		end if;
	end process;
	
	process(FMSTATE)begin
		case FMSTATE is
		when FS_C1Oa | FS_C1Ob | FS_C1Oc | FS_C1Od =>
			channel<="00";
		when FS_C2Oa | FS_C2Ob | FS_C2Oc | FS_C2Od =>
			channel<="01";
		when FS_C3Oa | FS_C3Ob | FS_C3Oc | FS_C3Od =>
			channel<="10";
		when others =>
			channel<="11";
		end case;
		case FMSTATE is
		when FS_C1Oa | FS_C2Oa | FS_C3Oa =>
			slot<="00";
		when FS_C1Ob | FS_C2Ob | FS_C3Ob =>
			slot<="01";
		when FS_C1Oc | FS_C2Oc | FS_C3Oc =>
			slot<="10";
		when FS_C1Od | FS_C2Od | FS_C3Od =>
			slot<="11";
		when others =>
			slot<="00";
		end case;
	end process;
	
	thitareg	:FMreg port map(channel,slot,thitard,thitawd,thitawr,clk);
	elevreg		:FMreg port map(channel,slot,elevrd,elevwd,elevwr,clk);
--	ooutreg		:FMreg port map(channel,slot,ooutrd,ooutwd,ooutwr,clk);
	
	process(clk,rstn)
	variable vthita	:std_logic_vector(15 downto 0);
	variable addthita:std_logic_vector(15 downto 0);
	variable coutc	:std_logic_vector(17 downto 0);
	variable wtoutxa,wtoutxb,wtoutxc,wtoutxd	:std_logic_vector(17 downto 0);
	begin
		if(rstn='0')then
			INT_RADR<=(others=>'0');
			INTST<=IS_IDLE;
			TBPS<=0;
			INT_RWDAT<=(others=>'0');
			INT_RWR<='0';
			intend<='0';
			TACOUNT<=(others=>'0');
			TBCOUNT<=(others=>'0');
			FLAG<=(others=>'0');
			envst_1a<=es_OFF;
			envst_1b<=es_OFF;
			envst_1c<=es_OFF;
			envst_1d<=es_OFF;
			envst_2a<=es_OFF;
			envst_2b<=es_OFF;
			envst_2c<=es_OFF;
			envst_2d<=es_OFF;
			envst_3a<=es_OFF;
			envst_3b<=es_OFF;
			envst_3c<=es_OFF;
			envst_3d<=es_OFF;
			envcalc<='0';
			thitawd<=(others=>'0');
			ooutwd<=(others=>'0');
			thitawr<='0';
			elevwr<='0';
			ooutwr<='0';
			sin1a<=(others=>'0');
			sin2a<=(others=>'0');
			sin3a<=(others=>'0');
		elsif(clk' event and clk='1')then
			if(BUSY='0' and sft='1')then
				thitawr<='0';
				elevwr<='0';
				ooutwr<='0';
				intend<='0';
				envcalc<='0';
				if(TARST='1')then
					FLAG(1)<='0';
				end if;
				if(TBRST='1')then
					FLAG(0)<='0';
				end if;
				INT_RWR<='0';
				intend<='0';
				case FMSTATE is
				when FS_TIMER =>
					if(intbgn='1')then
						C3mode<=C3M;
						if(TALD='0')then
							TACOUNT<=TARDAT;
						else
							if(TACOUNT="1111111111")then
								if(TAEN='1')then
									FLAG(1)<='1';
								end if;
								TACOUNT<=TARDAT;
							else
								TACOUNT<=TACOUNT+"0000000001";
							end if;
						end if;
						
						if(TBPS/=0)then
							TBPS<=TBPS-1;
						else
							TBPS<=15;
							if(TBLD='0')then
								TBCOUNT<=TBRDAT;
							else
								if(TBCOUNT=x"ff")then
									if(TBEN='1')then
										FLAG(0)<='1';
									end if;
									TBCOUNT<=TBRDAT;
								else
									TBCOUNT<=TBCOUNT+x"01";
								end if;
							end if;
						end if;
						intend<='1';
					end if;
				when FS_C1Oa | FS_C1Ob | FS_C1Oc | FS_C1Od |
					 FS_C2Oa | FS_C2Ob | FS_C2Oc | FS_C2Od |
					 FS_C3Oa | FS_C3Ob | FS_C3Oc | FS_C3Od =>
					if(intbgn='1')then
						INTST<=IS_INIT;
					else
						case INTST is
						when IS_INIT =>
							if(slot="00" or ((C3mode="01" or C3mode="10") and (channel="10")))then
								case FMSTATE is
								when FS_C1Oa =>
									INT_RADR<=x"a4";
								when FS_C2Oa =>
									INT_RADR<=x"a5";
								when FS_C3Oa =>
									INT_RADR<=x"a6";
								when FS_C3Ob =>
									INT_RADR<=x"ac";
								when FS_C3Oc =>
									INT_RADR<=x"ad";
								when FS_C3Od =>
									INT_RADR<=x"ae";
								when others =>
									INT_RADR<=x"00";
								end case;
								INTST<=IS_READF2;
							else
								INTST<=IS_SETDETMUL;
							end if;
						when IS_READF2 =>
							Blk<=INT_RDAT(5 downto 3);
							Fnum(10 downto 8)<=INT_RDAT(2 downto 0);
							INT_RADR<=INT_RADR-x"04";
							INTST<=IS_READF1;
						when IS_READF1 =>
							Fnum(7 downto 0)<=INT_RDAT;
							INTST<=IS_READALGFB;
							case FMSTATE is
							when FS_C1Oa =>
								INT_RADR<=x"b0";
							when FS_C2Oa =>
								INT_RADR<=x"b1";
							when FS_C3Oa =>
								INT_RADR<=x"b2";
							when others =>
								INTST<=IS_SETDETMUL;
							end case;
						when IS_READALGFB =>
							Algo<=INT_RDAT(2 downto 0);
							FdBck<=INT_RDAT(5 downto 3);
							INTST<=IS_SETDETMUL;
						when IS_SETDETMUL =>
							case FMSTATE is
							when FS_C1Oa =>
								INT_RADR<=x"30";
							when FS_C1Ob =>
								INT_RADR<=x"34";
							when FS_C1Oc =>
								INT_RADR<=x"38";
							when FS_C1Od =>
								INT_RADR<=x"3c";
							when FS_C2Oa =>
								INT_RADR<=x"31";
							when FS_C2Ob =>
								INT_RADR<=x"35";
							when FS_C2Oc =>
								INT_RADR<=x"39";
							when FS_C2Od =>
								INT_RADR<=x"3d";
							when FS_C3Oa =>
								INT_RADR<=x"32";
							when FS_C3Ob =>
								INT_RADR<=x"36";
							when FS_C3Oc =>
								INT_RADR<=x"3a";
							when FS_C3Od =>
								INT_RADR<=x"3e";
							when others =>
							end case;
							INTST<=IS_READDETMUL;
						when IS_READDETMUL =>
							Detune<=INT_RDAT(6 downto 4);
							Mult<=INT_RDAT(3 downto 0);
							INTST<=IS_CALCTHITA;
						when IS_CALCTHITA =>	--with set AR
							vthita:=thitard+MSFnum;
							case slot is
							when "00" =>
								vthita:=vthita+addfb;
							when "01" =>
								case Algo is
								when "000" | "011" | "100" | "101" | "110"=>
									vthita:=vthita+toutxa;
								when others =>
								end case;
							when "10" =>
								case Algo is
								when "000" | "010" =>
									vthita:=vthita+toutxb;
								when "001" =>
									vthita:=vthita+toutxa+toutxb;
								when "101" =>
									vthita:=vthita+toutxa;
								when others =>
								end case;
							when "11" =>
								case Algo is
								when "000" | "001" | "100" =>
									vthita:=vthita+toutxc;
								when "010" =>
									vthita:=vthita+toutxa+toutxc;
								when "011" =>
									vthita:=vthita+toutxb+toutxc;
								when "101" =>
									vthita:=vthita+toutxa;
								when others =>
								end case;
							when others =>
							end case;
							thitawd<=vthita;
							thitawr<='1';
							INT_RADR<=INT_RADR+x"20";
							thita<=vthita;
							INTST<=IS_READKSAR;
						when IS_READKSAR =>
							KS<=INT_RDAT(7 downto 6);
							AR<=INT_RDAT(4 downto 0);
							INT_RADR<=INT_RADR+x"10";
							INTST<=IS_READDR;
						when IS_READDR =>
							DR<=INT_RDAT(4 downto 0);
							INT_RADR<=INT_RADR+x"10";
							INTST<=IS_READSR;
						when IS_READSR =>
							SR<=INT_RDAT(4 downto 0);
							INT_RADR<=INT_RADR+x"10";
							INTST<=IS_READSLRR;
						when IS_READSLRR =>
							SL<=INT_RDAT(7 downto 4);
							RR<=INT_RDAT(3 downto 0);
							envcalc<='1';
							INT_RADR<=INT_RADR-x"40";
							INTST<=IS_READTL;
						when IS_READTL =>
							TL<=INT_RDAT(6 downto 0);
							INTST<=IS_CALCENV;
						when IS_CALCENV =>
							elevwr<='1';
							ooutwd<=coout;
							ooutwr<='1';
							case FMSTATE is
							when FS_C1Oa =>
								envst_1a<=nenvst;
								sin1a<=sinthita;
							when FS_C1Ob =>
								envst_1b<=nenvst;
							when FS_C1Oc =>
								envst_1c<=nenvst;
							when FS_C1Od =>
								envst_1d<=nenvst;
							when FS_C2Oa =>
								envst_2a<=nenvst;
								sin2a<=sinthita;
							when FS_C2Ob =>
								envst_2b<=nenvst;
							when FS_C2Oc =>
								envst_2c<=nenvst;
							when FS_C2Od =>
								envst_2d<=nenvst;
							when FS_C3Oa =>
								envst_3a<=nenvst;
								sin3a<=sinthita;
							when FS_C3Ob =>
								envst_3b<=nenvst;
							when FS_C3Oc =>
								envst_3c<=nenvst;
							when FS_C3Od =>
								envst_3d<=nenvst;
							when others =>
							end case;
							INTST<=IS_CALCTL;
						when IS_CALCTL =>
							case slot is
							when "00" =>
								toutxa<=toutc;
							when "01" =>
								toutxb<=toutc;
							when "10" =>
								toutxc<=toutc;
							when "11" =>
								toutxd<=toutc;
							when others =>
							end case;
							case slot is
							when "11" =>
								INTST<=IS_CMIX;
							when others =>
								INTST<=IS_IDLE;
								intend<='1';
							end case;
						when IS_CMIX =>
							wtoutxa:=toutxa(15) & toutxa(15) & toutxa;
							wtoutxb:=toutxb(15) & toutxb(15) & toutxb;
							wtoutxc:=toutxc(15) & toutxc(15) & toutxc;
							wtoutxd:=toutxd(15) & toutxd(15) & toutxd;
							case Algo is
							when "000" | "001" | "010" | "011" =>
								coutc:= wtoutxd + wtoutxd + wtoutxd + wtoutxd;
							when "100" =>
								coutc:=wtoutxb + wtoutxd + wtoutxb + wtoutxd;
							when "101" | "110" =>
								coutc:=wtoutxb + wtoutxc + wtoutxd;
							when "111" =>
								coutc:=wtoutxa + wtoutxb + wtoutxc + wtoutxd;
							when others=>
							end case;
							case FMSTATE is
							when FS_C1Od =>
								cout1<=coutc;
							when FS_C2Od =>
								cout2<=coutc;
							when FS_C3Od =>
								cout3<=coutc;
							when others =>
							end case;
							INTST<=IS_IDLE;
							intend<='1';
						when others =>
							INTST<=IS_IDLE;
						end case;
					end if;
				when FS_MIX =>
					fm_smix<=(cout1(17) & cout1(17) & cout1) + (cout2(17) & cout2(17) & cout2) + (cout3(17) & cout3(17) & cout3);
					intend<='1';
				when others =>
					INTST<=IS_IDLE;
				end case;
			end if;
		end if;
	end process;
	
	SFnum<=	"00" & Fnum & "000"				when Blk="111" else
			"000" & Fnum & "00" 			when Blk="110" else
			"0000" & Fnum & '0' 			when Blk="101" else
			"00000" & Fnum 					when Blk="100" else
			"000000" & Fnum(10 downto 1)	when Blk="011" else
			"0000000" & Fnum(10 downto 2) 	when Blk="010" else
			"00000000" & Fnum(10 downto 3) 	when Blk="001" else
			"000000000" & Fnum(10 downto 4);
	
	process(SFnum,Mult)
	variable SUM	:std_logic_vector(15 downto 0);
	begin
		if(Mult=x"0")then
			SUM:='0' & SFnum(15 downto 1);
		else
			SUM:=(others=>'0');
			if(Mult(0)='1')then
				SUM:=SUM+SFnum;
			end if;
			if(Mult(1)='1')then
				SUM:=SUM+(SFnum(14 downto 0) & '0');
			end if;
			if(Mult(2)='1')then
				SUM:=SUM+(SFnum(13 downto 0) & "00");
			end if;
			if(Mult(3)='1')then
				SUM:=SUM+(SFnum(12 downto 0) & "000");
			end if;
		end if;
		MSFnum<=SUM;
	end process;
	
	FBsrc<=	sin1a when channel="00" else
			sin2a when channel="01" else
			sin3a when channel="10" else
			(others=>'0');
	
	addfbm<=(others=>FBsrc(15));
	addfb<=	addfbm(4 downto 0) & FBsrc(15 downto 5)		when FdBck="001" else
			addfbm(3 downto 0) & FBsrc(15 downto 4)		when FdBck="010" else
			addfbm(2 downto 0) & FBsrc(15 downto 3)		when FdBck="011" else
			addfbm(1 downto 0) & FBsrc(15 downto 2)		when FdBck="100" else
			addfbm(0) & FBsrc(15 downto 1)				when FdBck="101" else
			FBsrc										when FdBck="110" else
			FBsrc(14 downto 0) & '0'					when FdBck="111" else
			(others=>'0');

	reg	:OPNREG port map(
		address_a	=>CPU_RADR,
		address_b	=>INT_RADR,
		clock		=>clk,
		data_a		=>CPU_WDAT,
		data_b		=>INT_RWDAT,
		wren_a		=>CPU_RWR,
		wren_b		=>INT_RWR,
		q_a			=>open,
		q_b			=>INT_RDAT
	);

	INTn<=not(FLAG(1) or FLAG(0)) ;
	
	cenvst<=envst_1a	when FMSTATE=FS_C1Oa else
			envst_1b	when FMSTATE=FS_C1Ob else
			envst_1c	when FMSTATE=FS_C1Oc else
			envst_1d	when FMSTATE=FS_C1Od else
			envst_2a	when FMSTATE=FS_C2Oa else
			envst_2b	when FMSTATE=FS_C2Ob else
			envst_2c	when FMSTATE=FS_C2Oc else
			envst_2d	when FMSTATE=FS_C2Od else
			envst_3a	when FMSTATE=FS_C3Oa else
			envst_3b	when FMSTATE=FS_C3Ob else
			envst_3c	when FMSTATE=FS_C3Oc else
			envst_3d	when FMSTATE=FS_C3Od else
			es_OFF;
			
	keyc<=	key1(0)	when FMSTATE=FS_C1Oa else
			key1(1)	when FMSTATE=FS_C1Ob else
			key1(2)	when FMSTATE=FS_C1Oc else
			key1(3)	when FMSTATE=FS_C1Od else
			key2(0)	when FMSTATE=FS_C2Oa else
			key2(1)	when FMSTATE=FS_C2Ob else
			key2(2)	when FMSTATE=FS_C2Oc else
			key2(3)	when FMSTATE=FS_C2Od else
			key3(0)	when FMSTATE=FS_C3Oa else
			key3(1)	when FMSTATE=FS_C3Ob else
			key3(2)	when FMSTATE=FS_C3Oc else
			key3(3)	when FMSTATE=FS_C3Od else
			'0';
	
	SLEV<=	x"ffff" when SL=x"0" else
			x"b503" when SL=x"1" else
			x"7fff" when SL=x"2" else
			x"5a81" when SL=x"3" else
			x"3fff" when SL=x"4" else
			x"2d41" when SL=x"5" else
			x"1fff" when SL=x"6" else
			x"169f" when SL=x"7" else
			x"0fff" when SL=x"8" else
			x"0b4f" when SL=x"9" else
			x"07ff" when SL=x"a" else
			x"05a7" when SL=x"b" else
			x"03ff" when SL=x"c" else
			x"02d3" when SL=x"d" else
			x"01ff" when SL=x"e" else
			x"0001" when SL=x"f" else
			x"0000";
			
	sint	:sintbl port map(thita,sinthita,clk);
	
	process(clk,rstn)
	variable	venvlev	:std_logic_vector(16 downto 0);
	begin
		if(rstn='0')then
			nenvst<=es_OFF;
			elevwd<=(others=>'0');
		elsif(clk' event and clk='1')then
			if(sft='1')then
				if(envcalc='1')then
					nenvst<=cenvst;
					if(keyc='1')then
						case cenvst is
						when es_OFF | es_Rel =>
							nenvst<=es_Atk;
							elevwd<=(others=>'0');
						when es_Atk =>
							venvlev:=('0' & elevrd) + ("000000000000" & AR);
							if(venvlev(16)='1')then
								elevwd<=(others=>'1');
								nenvst<=es_Dec;
							else
								elevwd<=venvlev(15 downto 0);
							end if;
						when es_Dec =>
							venvlev:=('0' & elevrd) - ("000000000000" & DR);
							if(venvlev(16)='1' or venvlev<('0' & SLEV))then
								elevwd<=SLEV;
								nenvst<=es_Sus;
							else
								elevwd<=venvlev(15 downto 0);
							end if;
						when es_Sus =>
							venvlev:=('0' & elevrd) - ("000000000000" & SR);
							if(venvlev(16)='1')then
								elevwd<=(others=>'0');
							else
								elevwd<=venvlev(15 downto 0);
							end if;
						when others =>
							elevwd<=(others=>'0');
							nenvst<=es_OFF;
						end case;
					else
						case cenvst is
						when es_OFF =>
							elevwd<=(others=>'0');
						when others =>
							venvlev:=('0' & elevrd) - ("000000000000" & RR & '1');
							if(venvlev(16)='1')then
								elevwd<=(others=>'0');
								nenvst<=es_OFF;
							else
								elevwd<=venvlev(15 downto 0);
								nenvst<=es_Rel;
							end if;
						end case;
					end if;
				end if;
			end if;
		end if;
	end process;
	
	envm	:muls16xu16 port map(sinthita,elevwd,coout,clk);
	
	TLC	:TLtbl port map(TL,clk,TLEV);
	
	tlm		:muls16xu16 port map(coout,TLEV,toutc,clk);
	
	process(clk,rstn)begin
		if(rstn='0')then
			psgcount0<=(others=>'0');
			psgcount1<=(others=>'0');
			psgcount2<=(others=>'0');
		elsif(clk' event and clk='1')then
			if(psgcountwr='1')then
				case psgch is
				when 0 =>
					psgcount0<=psgcountwd;
				when 1 =>
					psgcount1<=psgcountwd;
				when 2 =>
					psgcount2<=psgcountwd;
				when others =>
					psgcountn<=psgcountwd;
				end case;
			end if;
		end if;
	end process;
	
	process(PSGST)begin
		case PSGST is
		when PST_C0F | PST_C0L =>
			psgch<=0;
		when PST_C1F | PST_C1L =>
			psgch<=1;
		when PST_C2F | PST_C2L =>
			psgch<=2;
		when others =>
			psgch<=3;
		end case;
	end process;
	
	psgcountc<=	psgcount0 when psgch=0 else
				psgcount1 when psgch=1 else
				psgcount2 when psgch=2 else
				psgcountn;

	PSG_TUNC<=	PSG_TUN0 when psgch=0 else
				PSG_TUN1 when psgch=1 else
				PSG_TUN2 when psgch=2 else
				PSG_TUNN;
				
	PSG_AMPC<=	PSG_AMP0 when psgch=0 else
				PSG_AMP1 when psgch=1 else
				PSG_AMP2 when psgch=2 else
				(others=>'0');
	
	PSG_VAL<=	x"7fff" when PSG_LEV=x"f" else
				x"5a81" when PSG_LEV=x"e" else
				x"3fff" when PSG_LEV=x"d" else
				x"2d40" when PSG_LEV=x"c" else
				x"1fff" when PSG_LEV=x"b" else
				x"16a0" when PSG_LEV=x"a" else
				x"0fff" when PSG_LEV=x"9" else
				x"0b50" when PSG_LEV=x"8" else
				x"07ff" when PSG_LEV=x"7" else
				x"05a8" when PSG_LEV=x"6" else
				x"03ff" when PSG_LEV=x"5" else
				x"02d4" when PSG_LEV=x"4" else
				x"01ff" when PSG_LEV=x"3" else
				x"016a" when PSG_LEV=x"2" else
				x"00ff" when PSG_LEV=x"1" else
				x"0000";

--PSG pulse control	
	process(clk,rstn)
	variable vsign	:std_logic_vector(15 downto 0);
	begin
		if(rstn='0')then
			PSGST<=PST_IDLE;
			psgcountwr<='0';
			psgcountwd<=(others=>'0');
			psg_sgn0<=(others=>'0');
			psg_sgn1<=(others=>'0');
			psg_sgn2<=(others=>'0');
			psglog<=(others=>'0');
			noisesft<='0';
		elsif(clk' event and clk='1')then
			noisesft<='0';
			if(sft='1')then
				psgcountwr<='0';
				case PSGST is
				when PST_IDLE =>
					if(psgsft='1')then
						PSGST<=PST_NF;
					end if;
				when PST_NF | PST_C0F | PST_C1F | PST_C2F =>
					if(psgcountc=psgczero)then
						psgcountwd<=PSG_TUNC;
						if(PSG_TUNC/=psgczero)then
							if(PSGST=PST_NF)then
								noisesft<='1';
							else
								psglog(psgch)<=not psglog(psgch);
							end if;
						end if;
					else
						psgcountwd<=psgcountc-x"001";
					end if;
					psgcountwr<='1';
					case PSGST is
					when PST_NF =>
						PSGST<=PST_C0F;
					when PST_C0F =>
						PSGST<=PST_C0L;
					when PST_C1F =>
						PSGST<=PST_C1L;
					when PST_C2F =>
						PSGST<=PST_C2L;
					when others =>
						PSGST<=PST_IDLE;
					end case;
				when PST_C0L =>
					if(PSG_TENn(0)='1')then
						vsign:=(others=>'0');
					elsif(psglog(0)='1')then
						vsign:='1' & not PSG_VAL(15 downto 1);
					else
						vsign:='0' & PSG_VAL(15 downto 1);
					end if;
					if(PSG_NENn(0)='0')then
						if(noiselog='1')then
							vsign:=vsign+('1' & not (PSG_VAL(15 downto 1)));
						else
							vsign:=vsign+('0' & PSG_VAL(15 downto 1));
						end if;
					end if;
					psg_sgn0<=vsign;
					PSGST<=PST_C1F;
				when PST_C1L =>
					if(PSG_TENn(1)='1')then
						vsign:=(others=>'0');
					elsif(psglog(1)='1')then
						vsign:='1' & not PSG_VAL(15 downto 1);
					else
						vsign:='0' & PSG_VAL(15 downto 1);
					end if;
					if(PSG_NENn(1)='0')then
						if(noiselog='1')then
							vsign:=vsign+('1' & not (PSG_VAL(15 downto 1)));
						else
							vsign:=vsign+('0' & PSG_VAL(15 downto 1));
						end if;
					end if;
					psg_sgn1<=vsign;
					PSGST<=PST_C2F;
				when PST_C2L =>
					if(PSG_TENn(2)='1')then
						vsign:=(others=>'0');
					elsif(psglog(2)='1')then
						vsign:='1' & not PSG_VAL(15 downto 1);
					else
						vsign:='0' & PSG_VAL(15 downto 1);
					end if;
					if(PSG_NENn(2)='0')then
						if(noiselog='1')then
							vsign:=vsign+('1' & not (PSG_VAL(15 downto 1)));
						else
							vsign:=vsign+('0' & PSG_VAL(15 downto 1));
						end if;
					end if;
					psg_sgn2<=vsign;
					PSGST<=PST_MIX;
				when PST_MIX =>
					psg_smix<=(psg_sgn0(15) & psg_sgn0(15) & psg_sgn0) + (psg_sgn1(15) & psg_sgn1(15) & psg_sgn1) + (psg_sgn2(15) & psg_sgn2(15) & psg_sgn2);
					PSGST<=PST_IDLE;
				when others =>
					PSGST<=PST_IDLE;
				end case;
			end if;
		end if;
	end process;

	NG	:noisegen port map(noisesft,noiselog,clk,rstn);

	PSG_LEV<=PENV_LEV when PSG_AMPC(4)='1' else PSG_AMPC(3 downto 0);

--PSG envelope control
	process(clk,rstn)	
	variable PSGON	:std_logic;
	begin
		if(rstn='0')then
			lPSGON<='0';
			PENV_LEV<=x"0";
			psgenvcount<=(others=>'0');
			PENVM<=PEM_NOP;
		elsif(clk' event and clk='1')then
			if(sft='1')then
				PSGON:=PSG_AMP0(4) or PSG_AMP1(4) or PSG_AMP2(4);
				lPSGON<=PSGON;
				if(PSGON='1' and lPSGON='0')then
					if(PSG_ESHAPE(2)='0')then
						PENV_LEV<=x"f";
						PENVM<=PEM_DEC;
					else
						PENV_LEV<=x"0";
						PENVM<=PEM_INC;
					end if;
					psgenvcount<=(others=>'0');
				elsif(psgsft='1')then
					if(psgenvcount>x"0000")then
						psgenvcount<=psgenvcount-x"0001";
					else
						psgenvcount<=PSG_EPER;
						case PSG_ESHAPE is
						when x"0" | x"1" | x"2" | x"3" =>
							if(PENV_LEV>x"0")then
								PENV_LEV<=PENV_LEV-x"1";
							else
								PENV_LEV<=x"0";
								PENVM<=PEM_NOP;
							end if;
						when x"4" | x"5" | x"6" | x"7" =>
							if(PENVM=PEM_INC)then
								if(PENV_LEV=x"f")then
									PENV_LEV<=x"0";
									PENVM<=PEM_NOP;
								else
									PENV_LEV<=PENV_LEV+x"1";
								end if;
							else
								PENV_LEV<=x"0";
							end if;
						when x"8" =>
							if(PENV_LEV>x"0")then
								PENV_LEV<=PENV_LEV-x"1";
							else
								PENV_LEV<=x"f";
							end if;
						when x"9" =>
							if(PENVM=PEM_DEC)then
								if(PENV_LEV>x"0")then
									PENV_LEV<=PENV_LEV-x"1";
								else
									PENVM<=PEM_NOP;
									PENV_LEV<=x"0";
								end if;
							else
								PENV_LEV<=x"0";
							end if;
						when x"a" | x"e" =>
							if(PENVM=PEM_DEC)then
								if(PENV_LEV>x"0")then
									PENV_LEV<=PENV_LEV-x"1";
								else
									PENV_LEV<=x"1";
									PENVM<=PEM_INC;
								end if;
							else
								if(PENV_LEV<x"f")then
									PENV_LEV<=PENV_LEV+x"1";
								else
									PENV_LEV<=x"e";
									PENVM<=PEM_DEC;
								end if;
							end if;
						when x"b" =>
							if(PENVM=PEM_DEC)then
								if(PENV_LEV>x"0")then
									PENV_LEV<=PENV_LEV-x"1";
								else
									PENV_LEV<=x"f";
									PENVM<=PEM_NOP;
								end if;
							else
								PENV_LEV<=x"f";
							end if;
						when x"c" =>
							if(PENVM=PEM_INC)then
								if(PENV_LEV<x"f")then
									PENV_LEV<=PENV_LEV+x"1";
								else
									PENV_LEV<=x"f";
									PENVM<=PEM_NOP;
								end if;
							else
								PENV_LEV<=x"f";
							end if;
						when x"d" =>
							if(PENVM=PEM_INC)then
								if(PENV_LEV<x"f")then
									PENV_LEV<=PENV_LEV+x"1";
								else
									PENV_LEV<=x"f";
									PENVM<=PEM_NOP;
								end if;
							else
								PENV_LEV<=x"f";
							end if;
						when x"f" =>
							if(PENVM=PEM_INC)then
								if(PENV_LEV<x"f")then
									PENV_LEV<=PENV_LEV+x"1";
								else
									PENV_LEV<=x"0";
									PENVM<=PEM_NOP;
								end if;
							else
								PENV_LEV<=x"0";
							end if;
						when others =>
						end case;
					end if;
				end if;
			end if;
		end if;
	end process;

	sndmix<=(fm_smix(19) & fm_smix) + (psg_smix(17) & psg_smix & "00");

	sndL<=sndmix(20 downto 21-res);
	sndR<=sndmix(20 downto 21-res);
	
--	monout<=thita;
	
end rtl;
