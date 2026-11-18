-- tb_counter.vhd - testbench for the cascaded counters
--
-- Wires moore_machine_up and moore_machine_down together exactly as
-- top_level.vhd does (o_dn -> i_go, and the same mux on the LEDs), with
-- MAX_COUNT = 4 so a tick is 4 clocks instead of 1 s. top_level itself fixes
-- MAX_COUNT at 50,000,000, which would take far too long to simulate.
--
-- It presses go for a single clock, records the value on the LEDs every clock,
-- and checks that the display reads 0, 1 ... 7, 6 ... 0 with every value in
-- between shown for exactly one tick: the short press is remembered, and no
-- value is shown twice at the handoff.
--
--   ghdl -a --std=08 moore_machine_up.vhd moore_machine_down.vhd tb_counter.vhd
--   ghdl -e --std=08 tb_counter
--   ghdl -r --std=08 tb_counter --vcd=tb_counter.vcd

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_counter is
end entity tb_counter;

architecture sim of tb_counter is

    constant M      : natural := 4;         -- clocks per tick
    constant T_CLK  : time    := 20 ns;

    signal clk      : std_logic := '0';
    signal rst      : std_logic := '0';     -- active low
    signal go       : std_logic := '1';     -- active low
    signal dn       : std_logic;
    signal chip_a   : std_logic_vector(2 downto 0);
    signal chip_b   : std_logic_vector(2 downto 0);
    signal led_bank : std_logic_vector(2 downto 0);
    signal running  : boolean := true;

    type int_array is array (natural range <>) of integer;
    constant EXPECTED : int_array(0 to 14) := (0, 1, 2, 3, 4, 5, 6, 7, 6, 5, 4, 3, 2, 1, 0);

begin

    clk <= not clk after T_CLK / 2 when running;

    counter_up : entity work.moore_machine_up
        generic map (MAX_COUNT => M)
        port map (i_clk => clk, i_rst => rst, i_go => go, o_dn => dn, o_led => chip_a);

    counter_down : entity work.moore_machine_down
        generic map (MAX_COUNT => M)
        port map (i_clk => clk, i_rst => rst, i_go => dn, o_led => chip_b);

    led_bank <= chip_a when dn = '0' else chip_b;

    stim : process
        variable values  : int_array(0 to 31);
        variable lengths : int_array(0 to 31);
        variable runs    : natural := 0;
        variable shown   : integer;
        variable errors  : natural := 0;
    begin
        for i in 1 to 3 loop
            wait until falling_edge(clk);
        end loop;
        rst <= '1';

        -- go pressed for one clock, shorter than a tick
        wait until falling_edge(clk);
        go <= '0';
        wait until falling_edge(clk);
        go <= '1';

        -- the LEDs are active low: the value shown is the inverse of led_bank
        values(0)  := to_integer(unsigned(not led_bank));
        lengths(0) := 1;
        for c in 1 to 20 * M loop
            wait until falling_edge(clk);
            shown := to_integer(unsigned(not led_bank));
            if shown = values(runs) then
                lengths(runs) := lengths(runs) + 1;
            elsif runs < 31 then
                runs := runs + 1;
                values(runs)  := shown;
                lengths(runs) := 1;
            end if;
        end loop;

        if runs /= EXPECTED'high then
            report "saw " & integer'image(runs + 1) & " values, expected 15" severity error;
            errors := errors + 1;
        end if;

        for i in 0 to EXPECTED'high loop
            exit when i > runs;
            if values(i) /= EXPECTED(i) then
                report "value " & integer'image(i) & " is " & integer'image(values(i))
                     & ", expected " & integer'image(EXPECTED(i)) severity error;
                errors := errors + 1;
            end if;
            -- the first 0 waits for the go tick and the last 0 stays; every other value lasts one tick
            if (i > 0) and (i < EXPECTED'high) and (lengths(i) /= M) then
                report "value " & integer'image(values(i)) & " (step " & integer'image(i)
                     & ") shown for " & integer'image(lengths(i)) & " clocks, expected "
                     & integer'image(M) severity error;
                errors := errors + 1;
            end if;
        end loop;

        if errors = 0 then
            report "PASS: 0, 1..7, 6..0, one tick each, short go press remembered" severity note;
        else
            report "FAIL: " & integer'image(errors) & " error(s)" severity failure;
        end if;

        running <= false;
        wait;
    end process;

end architecture sim;
