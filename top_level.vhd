library ieee;
use ieee.std_logic_1164.all;

entity top_level is
    Port (
        -- These are the actual physical pins assigned in Quartus
        sys_clk     :   in  std_logic;
        btn_reset   :   in  std_logic;
        btn_go      :   in  std_logic;
        led_bank    :   out std_logic_vector(2 downto 0));

end top_level;

architecture structural of top_level is

        signal done_cable   :   std_logic;                      -- differenciate between counter up and down. when up is finished it goes to 1.
        signal chip_a       :   std_logic_vector(2 downto 0);   -- this is just the output of each LED mapped to 2 variables, we use a mux in the end to select which one.
        signal chip_b       :   std_logic_vector(2 downto 0);   -- the selection criteria is also based off of the mux

begin

    counter_up : entity work.moore_machine_up
        generic map (
            MAX_COUNT => 50000000 
        )
        port map (
            i_clk => sys_clk,     -- connect every single one of these to the default ports that we made
            i_rst => btn_reset,
            i_go  => btn_go,
            o_dn  => done_cable,  -- here we generalize this cable for use by other entities. The done signal is used by the mux and the go signal for the other counter
            o_led => chip_a       
        );

    counter_down : entity work.moore_machine_down
        generic map (
            MAX_COUNT => 50000000 
        )
        port map (
            i_clk => sys_clk,     -- same here, more or less. except without the o_dn. no need for it here.
            i_rst => btn_reset,
            i_go  => done_cable,  -- basically, tie the "go" function to when the first counter is done.
            o_led => chip_b
        );
        led_bank <= chip_a when done_cable = '0' else chip_b;
        -- the led shows the first counter when done is 0, else it shows the second counter which also begins working when done is 1
    
end structural;
