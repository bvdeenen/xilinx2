--------------------------------------------------------------------------------
-- SubModule QDEC
-- Created   30/09/2010 9:42:12 PM
-- Ben Jordan, Altium Limited.
--------------------------------------------------------------------------------
Library IEEE;
Use IEEE.Std_Logic_1164.all;

entity QDEC is port
   (
     CLK : in    std_logic;
     A   : in    std_logic;
     B   : in    std_logic;
     FWD : out   std_logic;
     REV : out   std_logic;
     MOV : out   std_logic
   );
end QDEC;
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
--
--  Typical rotary encoders output a quadrature encoded 2-bit signal as follows:
--
--  Clockwise motion:
--               ____      ____      ____      ____      ____
--  Signal A: __|    |____|    |____|    |____|    |____|     ...
--             ____      ____      ____      ____      ____
--  Signal B: |    |____|    |____|    |____|    |____|    |_ ...
--
--  Anti-Clockwise motion:
--             ____      ____      ____      ____      ____
--  Signal A: |    |____|    |____|    |____|    |____|    |_ ...
--               ____      ____      ____      ____      ____
--  Signal B: __|    |____|    |____|    |____|    |____|     ...
--
--  From this you can see that if there is a rising edge on A while B is high
--  then this indicates a unit turn of the encoder in the clockwise direction.
--  The converse is true for anti-clockwise rotation.
--
--  Most snippets of code (C or VHDL) you might discover only look at these two
--  states - rising edge of A with B high, rising edge of B with A high - to
--  determine a unit arc in either direction. However looking at the waveforms
--  above you can see that is only one quater of the possible resolution.
--
--  This decoder in VHDL samples the signals using all four available edges of
--  A and B. E.g. sample(B) on rising(A), sample(A) on falling(B), sample(B) on
--  falling(A), and sample(A) on rising(B).
--
--  Using this method uses more FPGA flip flops, but not too many in the grand
--  scheme of things. The net result is you get 80 counts per revolution versus
--  the usual 20.
--
--------------------------------------------------------------------------------

architecture Structure of QDEC is

-- Signal Declarations
signal code      : std_logic_vector(1 downto 0) := B"00";
signal code_prev : std_logic_vector(1 downto 0) := B"00";
signal MOV_del   : std_logic := '0';

begin
    main:process(CLK) is
    begin
       if rising_edge(CLK) then
          code_prev <= code;
          code(0) <= A;
          code(1) <= B;
          MOV <= MOV_del;
          if (code(0) = '1' and code_prev(0) = '0') then -- A rising edge
              if (B='0') then -- forward
                 FWD <= '1';
                 MOV_del <= '1';
                 REV <= '0';
              elsif (B='1') then -- reverse
                 FWD <= '0';
                 MOV_del <= '1';
                 REV <= '1';
              end if;
          elsif (code(1) = '1' and code_prev(1) = '0') then -- B rising edge
              if (A='1') then -- forward
                 FWD <= '1';
                 MOV_del <= '1';
                 REV <= '0';
              elsif (A='0') then -- reverse
                 FWD <= '0';
                 MOV_del <= '1';
                 REV <= '1';
              end if;
          elsif (code(0) = '0' and code_prev(0) = '1') then -- A falling edge
              if (B='1') then -- forward
                 FWD <= '1';
                 MOV_del <= '1';
                 REV <= '0';
              elsif (B='0') then -- reverse
                 FWD <= '0';
                 MOV_del <= '1';
                 REV <= '1';
              end if;
          elsif (code(1) = '0' and code_prev(1) = '1') then -- B falling edge
              if (A='0') then -- forward
                 FWD <= '1';
                 MOV_del <= '1';
                 REV <= '0';
              elsif (A='1') then -- reverse
                 FWD <= '0';
                 MOV_del <= '1';
                 REV <= '1';
              end if;
          else
              FWD <= '0';
              REV <= '0';
              MOV_del <= '0';
          end if;
       end if;
    end process;
end Structure;
--------------------------------------------------------------------------------
