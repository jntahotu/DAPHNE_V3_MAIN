-- trig.vhd
-- an EXAMPLE of a very simple trigger algorithm for the DAPHNE self triggered mode
--
-- baseline, threshold, din are UNSIGNED 
--
-- In this EXAMPLE the trigger algorithm is very simple and requires only a few clock cycles
-- however, this module adds extra pipeline stages so that the overall latency 
-- is 128 clocks. this is done to allow for more advanced triggers.
--
-- If a more advanced trigger is used in place of this module, the overall latency MUST
-- match this module, since the rest of the self-triggered sender logic depends on it.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

entity trig is
port(
    clock: in std_logic;
    din: in std_logic_vector(13 downto 0);        -- raw AFE data aligned to clock
    threshold: in std_logic_vector(13 downto 0);  -- trigger threshold relative to baseline
    baseline: in std_logic_vector(13 downto 0);   -- average signal level computed over past N samples
    triggered: out std_logic;
    trigsample: out std_logic_vector(13 downto 0) -- the sample that caused the trigger
);
end trig;

architecture trig_arch of trig is

    signal din0, din1, din2: std_logic_vector(13 downto 0) := "00000000000000";
    signal trig_thresh, trigsample_reg: std_logic_vector(13 downto 0) := (others=>'0');
    signal triggered_i, triggered_dly32_i, triggered_dly64_i, triggered_dly96_i: std_logic := '0';

begin

    trig_pipeline_proc: process(clock)
    begin
        if rising_edge(clock) then
            din0 <= din;  -- latest sample
            din1 <= din0; -- previous sample
            din2 <= din1; -- previous previous sample
        end if;
    end process trig_pipeline_proc;

    -- user-specified threshold is RELATIVE to the calculated average baseline level
    -- NOTE that the trigger pulse is NEGATIVE going! We want to SUBTRACT the relative 
    -- threshold from the calculated average baseline level.

    trig_thresh <= std_logic_vector( unsigned(baseline) - unsigned(threshold) );

    -- our super basic trigger condition is this: one sample ABOVE trig_thresh followed by two samples
    -- BELOW trig_thresh.

    triggered_i <= '1' when ( din2>trig_thresh and din1<trig_thresh and din0<trig_thresh ) else '0';

    -- add in some fake/synthetic latency, adjust it so total trigger latency is 128 clocks

    srlc32e_0_inst : srlc32e
    port map(
        clk => clock,
        ce  => '1',
        a   => "11111",
        d   => triggered_i,
        q   => open,
        q31 => triggered_dly32_i
    );

    srlc32e_1_inst : srlc32e
    port map(
        clk => clock,
        ce  => '1',
        a   => "11111",
        d   => triggered_dly32_i,
        q   => open,
        q31 => triggered_dly64_i
    );

    srlc32e_2_inst : srlc32e
    port map(
        clk => clock,
        ce  => '1',
        a   => "11111",
        d   => triggered_dly64_i,
        q   => open,
        q31 => triggered_dly96_i
    );

    srlc32e_3_inst : srlc32e
    port map(
        clk => clock,
        ce  => '1',
        a   => "11011",  -- fine tune this delay to make overall latency = 128
        d   => triggered_dly96_i,
        q   => triggered,
        q31 => open
    );

    -- capture the sample that caused the trigger 

    samplecap_proc: process(clock)
    begin
        if rising_edge(clock) then
            if (triggered_i='1') then
                trigsample_reg <= din0;
            end if;
        end if;    
    end process samplecap_proc;

    trigsample <= trigsample_reg;

end trig_arch;
