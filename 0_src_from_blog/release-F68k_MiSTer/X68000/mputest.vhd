library IEEE,work;
use IEEE.std_logic_1164.all;

entity mputest is
port(
		clk           : in std_logic;
		rstn          : in std_logic;
        clkena_in     : in std_logic:='1';
        m_data	      : out std_logic_vector(15 downto 0);
        m_dtack       : out std_logic;
        m_addr        : out std_logic_vector(31 downto 0);
        m_as          : out std_logic;
        m_uds         : out std_logic;
        m_lds         : out std_logic;
        m_rw          : out std_logic;
		int7	:in std_logic;
		vect7	:in std_logic_vector(7 downto 0);
		
		int6	:in std_logic;
		vect6	:in std_logic_vector(7 downto 0);
		
		int5	:in std_logic;
		vect5	:in std_logic_vector(7 downto 0);
		
		int4	:in std_logic;
		vect4	:in std_logic_vector(7 downto 0);
		
		int3	:in std_logic;
		vect3	:in std_logic_vector(7 downto 0);
		
		int2	:in std_logic;
		vect2	:in std_logic_vector(7 downto 0);
		
		int1	:in std_logic;
		vect1	:in std_logic_vector(7 downto 0);
        m_drive		  : out std_logic				--enable for data_out driver
);
end mputest;

architecture rtl of mputest is
signal	m_address:std_logic_vector(31 downto 0);
signal	address	:std_logic_vector(31 downto 0);
signal	data	:std_logic_vector(15 downto 0);
signal	mpudo	:std_logic_vector(15 downto 0);
signal	mpuoe	:std_logic;
signal	romdo	:std_logic_vector(15 downto 0);
signal	ramdoh	:std_logic_vector(7 downto 0);
signal	ramdol	:std_logic_vector(7 downto 0);
signal	ramdo	:std_logic_vector(15 downto 0);
signal	romoe	:std_logic;	
signal	ramoe	:std_logic;
signal	ramweh	:std_logic;
signal	ramwel	:std_logic;
signal	dtack	:std_logic;
signal	as,las	:std_logic;
signal	rw		:std_logic;
signal	uds		:std_logic;
signal	lds		:std_logic;
signal	iplen	:std_logic;
signal	IPL		:std_logic_vector(2 downto 0);
signal	lclkena	:std_logic;

component TG68
   port(        
		clk           : in std_logic;
		reset         : in std_logic;
        clkena_in     : in std_logic:='1';
        data_in       : in std_logic_vector(15 downto 0);
        IPL           : in std_logic_vector(2 downto 0):="111";
        dtack         : in std_logic;
        addr          : out std_logic_vector(31 downto 0);
        data_out      : out std_logic_vector(15 downto 0);
        as            : out std_logic;
        uds           : out std_logic;
        lds           : out std_logic;
        rw            : out std_logic;
        drive_data    : out std_logic				--enable for data_out driver
        );
end component;

component testrom
	PORT
	(
		address		: IN STD_LOGIC_VECTOR (11 DOWNTO 0);
		clock		: IN STD_LOGIC  := '1';
		q		: OUT STD_LOGIC_VECTOR (15 DOWNTO 0)
	);
END component;

component testram
	PORT
	(
		address		: IN STD_LOGIC_VECTOR (11 DOWNTO 0);
		clock		: IN STD_LOGIC  := '1';
		data		: IN STD_LOGIC_VECTOR (7 DOWNTO 0);
		wren		: IN STD_LOGIC ;
		q		: OUT STD_LOGIC_VECTOR (7 DOWNTO 0)
	);
END component;

component INTcont
port(
	int7	:in std_logic;
	vect7	:in std_logic_vector(7 downto 0);
	
	int6	:in std_logic;
	vect6	:in std_logic_vector(7 downto 0);
	
	int5	:in std_logic;
	vect5	:in std_logic_vector(7 downto 0);
	
	int4	:in std_logic;
	vect4	:in std_logic_vector(7 downto 0);
	
	int3	:in std_logic;
	vect3	:in std_logic_vector(7 downto 0);
	
	int2	:in std_logic;
	vect2	:in std_logic_vector(7 downto 0);
	
	int1	:in std_logic;
	vect1	:in std_logic_vector(7 downto 0);
	
	IPL		:out std_logic_vector(2 downto 0);
	addrin	:in std_logic_vector(23 downto 0);
	addrout	:out std_logic_vector(23 downto 0);
	rw		:in std_logic;
	
	clk		:in std_logic;
	rstn	:in std_logic
);
end component;

begin
	process(clk,rstn)begin
		if(rstn='0')then
			iplen<='1';
		elsif(clk' event and clk='1')then
			if(address(23)='1' and as='0')then
				iplen<='0';
			end if;
		end if;
	end process;
	
	process(clk,rstn)begin
		if(rstn='0')then
			lclkena<='0';
		elsif(clk' event and clk='1')then
			lclkena<=clkena_in;
		end if;
	end process;
	
	process(clk,rstn)
	variable nxtack	:std_logic;
	begin
		if(rstn='0')then
			dtack<='1';
			nxtack:='0';
			las<='1';
		elsif(clk' event and clk='1')then
			if(as='0' and (uds='0' or lds='0'))then
				nxtack:='1';
			end if;
			if(clkena_in='1')then
				if(nxtack='1')then
					dtack<='0';
					nxtack:='0';
				else
					dtack<='1';
				end if;
			end if;
			las<=as;
		end if;
	end process;
	
	mpu	:TG68 port map(
		clk           =>clk,
		reset         =>rstn,
        clkena_in     =>clkena_in,
        data_in       =>data,
        IPL           =>IPL,
        dtack         =>dtack,
        addr          =>m_address,
        data_out      =>mpudo,
        as            =>as,
        uds           =>uds,
        lds           =>lds,
        rw            =>rw,
        drive_data    =>mpuoe
	);
	
	int:INTcont port map(
		int7	=>int7,
		vect7	=>vect7,
		
		int6	=>int6,
		vect6	=>vect6,
		
		int5	=>int5,
		vect5	=>vect5,
		
		int4	=>int4,
		vect4	=>vect4,
		
		int3	=>int3,
		vect3	=>vect3,
		
		int2	=>int2,
		vect2	=>vect2,
		
		int1	=>int1,
		vect1	=>vect1,
		
		
		IPL		=>IPL,
		addrin	=>m_address(23 downto 0),
		addrout	=>address(23 downto 0),
		rw		=>rw,
		
		clk		=>clk,
		rstn	=>rstn
	);
	address(31 downto 24)<=(others=>'0');
	
	ROM		:testrom port map(
		address	=>address(12 downto 1),
		clock	=>clk,
		q		=>romdo
	);
	
	RAMH	:testram port map(
		address =>address(12 downto 1),
		clock	=>clk,
		data	=>data(15 downto 8),
		wren	=>ramweh,
		q		=>ramdoh
	);
	
	RAML	:testram port map(
		address =>address(12 downto 1),
		clock	=>clk,
		data	=>data(7 downto 0),
		wren	=>ramwel,
		q		=>ramdol
	);
	
	data(15 downto 8)<=
		mpudo(15 downto 8) when mpuoe='1' and uds='0' else
		romdo(15 downto 8) when romoe='1' and uds='0' else
		ramdoh	when ramoe='1' and uds='0' else
		x"ff";
		
	data(7 downto 0)<=
		mpudo(7 downto 0) when mpuoe='1' and lds='0' else
		romdo(7 downto 0) when romoe='1' and lds='0' else
		ramdol	when ramoe='1' and lds='0' else
		x"ff";
	
	romoe<='1' when as='0' and rw='1' and (address(23 downto 20)=x"f" or iplen='1') else '0';
	ramoe<='1' when as='0' and rw='1' and address(23 downto 20)=x"0" else '0';
	
	ramwel<='1' when as='0' and rw='0' and address(23 downto 20)=x"0" else '0';
	
	
	m_data<=data;
	m_dtack<=dtack;
	m_addr<=address;
	m_as<=as;
	m_uds<=uds;
	m_lds<=lds;
	m_rw<=rw;
	m_drive<=mpuoe;
	
end rtl;