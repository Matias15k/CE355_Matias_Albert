library ieee;
use ieee.std_logic_1164.all;

entity digit_display is
port(
	din  : in std_logic_vector(3 downto 0);
	dout : out std_logic_vector(6 downto 0)
);
end entity digit_display;         

architecture data_flow of digit_display is
begin
    ----------------------------------------------------------------
    -- Dataflow description of the 7-segment display
    -- The 7-segment display is active low, so a '0' turns on
    -- the corresponding segment.
    --
    -- TODO: Complete the dataflow description of the 7-segment display
    -- using a WHEN-ELSE statement to map the 4-bit binary input to 
    -- the 7-segment output.
    -- ---------------------------------------------------------------      
	dout <= "1111111"; -- blank
    
end architecture data_flow;            