library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;                               -- the standard library (std_logic_unsigned isn't IEEE)

entity moore_machine_up is
        generic ( MAX_COUNT : natural := 50000000 );
        Port (
        i_clk   :       in      std_logic;
        i_rst   :       in      std_logic;
        i_go    :       in      std_logic;
        o_dn    :       out     std_logic;
        o_led   :       out     std_logic_vector (2 downto 0));

end moore_machine_up;

architecture behavior of moore_machine_up is

        -- define the states
        type state_type is (
                IDLE,
                COUNT,
                DONE);                                  -- declare types (states)
        signal current_state : state_type := IDLE;      -- declares a current state and places its default value at IDLE.
        --

        -- define variables
        signal          w_clk_tk        :       std_logic                       := '0';
        signal          w_cntr          :       unsigned (2 downto 0)           := "000";
        signal          r_go            :       std_logic                       := '0';  -- remembers a go press until the next tick
        --

begin
        process (i_clk)
        variable tick_count : natural range 0 to MAX_COUNT := 0;
        begin
                if rising_edge(i_clk) then
                        if tick_count < (MAX_COUNT-1) then
                                tick_count      := tick_count + 1;
                                w_clk_tk        <= '0';
                        else
                                tick_count      := 0;
                                w_clk_tk        <= '1';
                        end if;
                end if;

        end process;


        process (i_clk, i_rst)
        begin
                if (i_rst = '0') then
                        current_state   <= IDLE;
                        w_cntr          <= "000";
                        r_go            <= '0';


                elsif rising_edge(i_clk) then
                        -- i_go is watched on every clock, so a press shorter than a tick isn't lost
                        if (current_state = IDLE) and (i_go = '0') then
                                r_go    <= '1';
                        end if;

                        if w_clk_tk = '1' then
                                case current_state is
                                        when IDLE =>

                                                w_cntr                  <= "000";
                                                if (r_go = '1') or (i_go = '0') then
                                                        r_go            <= '0';
                                                        w_cntr          <= "001";       -- IDLE already shows 0, so the go tick shows 1
                                                        current_state   <= COUNT;
                                                end if;

                                        when COUNT =>

                                                w_cntr                  <= w_cntr + 1;
                                                if w_cntr = "110" then                  -- 7 lands on the same tick DONE starts
                                                        current_state   <= DONE;
                                                end if;

                                        when DONE =>

                                                        current_state   <= DONE;

                                        when others =>

                                                current_state           <= IDLE;
                                end case;
                        end if;
                end if;
        end process;

        -- Moore output: straight from the state, so it rises the moment DONE starts instead of a tick later
        o_dn  <= '1' when current_state = DONE else '0';
        o_led <= not std_logic_vector(w_cntr);

end behavior;
