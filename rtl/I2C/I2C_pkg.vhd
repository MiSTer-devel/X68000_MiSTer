library ieee, work;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

package I2C_pkg is
	constant I2CSADR_WIDTH	:integer	:=7;
	constant SL_RD	:std_logic	:='1';
	constant SL_WR	:std_logic	:='0';
	constant I2CDAT_WIDTH	:integer	:=8;

	constant BIT_TXEMP	:integer	:=7;	-- TX buffer empty
	constant BIT_RXFULL :integer	:=6;	-- RX data full
	constant BIT_NOACK	:integer	:=5;	-- No ack detected
	constant BIT_COLL	:integer	:=4;	-- Collision detected
	constant BIT_READ	:integer	:=3;	-- next state is read
	constant BIT_RES	:integer	:=2;	-- Make re-start condition
	constant BIT_START	:integer	:=1;	-- Make start condition
	constant BIT_FIN	:integer	:=0;	-- Final data(make stop condition)

end I2C_pkg;
