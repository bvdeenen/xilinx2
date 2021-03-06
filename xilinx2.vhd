
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_ARITH.all;
use IEEE.STD_LOGIC_UNSIGNED.all;
use IEEE.numeric_std.all;
--
-- The Unisim Library is used to define Xilinx primitives. It is also used during
-- simulation. The source can be viewed at %XILINX%\vhdl\src\unisims\unisim_VCOMP.vhd
--
library unisim;
use unisim.vcomponents.all;
--
--
------------------------------------------------------------------------------------
--
--
entity xilinx2 is
  port (led      : out std_logic_vector(7 downto 0);
        BTN_EAST : in  std_logic;
        BTN_WEST : in  std_logic;
        ROT_A    : in  std_logic;
        ROT_B    : in  std_logic;
        

        lcd_d  : inout std_logic_vector(7 downto 0);
        lcd_rs : out   std_logic;
        lcd_rw : out   std_logic;
        lcd_e  : out   std_logic;
        clk    : in    std_logic);
end xilinx2;
--
------------------------------------------------------------------------------------
--
-- Start of test architecture
--
architecture Behavioral of xilinx2 is

  constant F_CLK      : integer := 50000000; -- Hz
  constant F_IRQ      : integer := 20;       -- Hz
  constant F_DEBOUNCE : integer := 1000;     -- Hz
------------------------------------------------------------------------------------
--
-- declaration of KCPSM3
--
  component debounce is
    port ( sig_in  : in std_logic;
           clk     : in std_logic;
           sig_out : out std_logic);
  end component;

  component QDEC is 
    port ( clk : in std_logic;
           A : in std_logic;
           B : in std_logic;
           FWD : out std_logic;
           REV : out std_logic;
           MOV : out std_logic);
  end component;

  component kcpsm3
    port (address       : out std_logic_vector(9 downto 0);
          instruction   : in  std_logic_vector(17 downto 0);
          port_id       : out std_logic_vector(7 downto 0);
          write_strobe  : out std_logic;
          out_port      : out std_logic_vector(7 downto 0);
          read_strobe   : out std_logic;
          in_port       : in  std_logic_vector(7 downto 0);
          interrupt     : in  std_logic;
          interrupt_ack : out std_logic;
          reset         : in  std_logic;
          clk           : in  std_logic);
  end component;
--
-- declaration of program ROM
--
  component picocode
    port (address     : in  std_logic_vector(9 downto 0);
          instruction : out std_logic_vector(17 downto 0);
          proc_reset  : out std_logic;
          clk         : in  std_logic);
  end component;
--
------------------------------------------------------------------------------------
--
-- Signals used to connect KCPSM3 to program ROM and I/O logic
--
  signal address         : std_logic_vector(9 downto 0);
  signal instruction     : std_logic_vector(17 downto 0);
  signal port_id         : std_logic_vector(7 downto 0);
  signal out_port        : std_logic_vector(7 downto 0);
  signal in_port         : std_logic_vector(7 downto 0);
  signal write_strobe    : std_logic;
  signal read_strobe     : std_logic;
  signal interrupt       : std_logic                   := '0';
  signal interrupt_ack   : std_logic;
  signal reset           : std_logic;
--
--
-- Signals used to generate interrupt 
--
  signal int_count       : integer range 0 to 49999999 := 0;
  signal clk_count       : integer range 0 to 49999999 := 0;
  signal event_1hz       : std_logic;
  signal event_1kHz      : std_logic;
--
--
  signal lcd_rw_control  : std_logic;
  signal lcd_output_data : std_logic_vector(7 downto 0);
  
  signal ROT_A_CLEAN  : std_logic;
  signal ROT_B_CLEAN  : std_logic;
  
  signal FWD : std_logic;
  signal REV : std_logic;
  signal MOV : std_logic;
--
  signal pos : integer range 0 to 7 := 0;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--
-- Start of circuit description
--

  signal led_direction : std_logic := '0';
begin

  ----------------------------------------------------------------------------------------------------------------------------------
  -- KCPSM3 and the program memory 
  ----------------------------------------------------------------------------------------------------------------------------------
  --

  processor : kcpsm3
    port map(address       => address,
             instruction   => instruction,
             port_id       => port_id,
             write_strobe  => write_strobe,
             out_port      => out_port,
             read_strobe   => read_strobe,
             in_port       => in_port,
             interrupt     => interrupt,
             interrupt_ack => interrupt_ack,
             reset         => reset,
             clk           => clk);

  program_rom : picocode
    port map(address     => address,
             instruction => instruction,
             proc_reset  => reset,
             clk         => clk);


  encoder_a: debounce
    port map(clk => event_1kHz,
             sig_in => ROT_A,
             sig_out => ROT_A_CLEAN);
  
  encoder_b: debounce
    port map(clk => event_1kHz,
             sig_in => ROT_B,
             sig_out => ROT_B_CLEAN);
  
  qdec_a: QDEC port map(
    clk => clk,
    A => ROT_A_CLEAN,
    B => ROT_B_CLEAN,
    FWD => FWD,
    REV => REV,
    MOV => MOV);

  one_ms : process(clk)
  begin
    if clk'event and clk = '1' then

      -- 1 kHz
      if clk_count = (F_CLK/F_DEBOUNCE-1) then
        clk_count <= 0;
        event_1kHz <= '1';
      else
        clk_count <= clk_count + 1;
        event_1kHz <= '0';
      end if;
    end if;
  end process one_ms;


  interrupt_control : process(clk)
  begin
    if clk'event and clk = '1' then

      --20Hz pulses
      if int_count =  (F_CLK/F_IRQ-1) then
        int_count <= 0;
        event_1hz <= '1';
      else
        int_count <= int_count + 1;
        event_1hz <= '0';
      end if;

      -- processor interrupt waits for an acknowledgement
      if interrupt_ack = '1' then
        interrupt <= '0';
      elsif event_1hz = '1' then
        interrupt <= '1';
      else
        interrupt <= interrupt;
      end if;

    end if;
  end process interrupt_control;


  
  update_position : process(clk)
  begin
    if rising_edge(clk) then
      if ( FWD='1' ) then
        if (pos = 7) then
          pos <= 0;
        else
          pos <= pos + 1;
        end if;
      elsif ( REV='1') then
        if (pos = 0) then
          pos <= 7;
        else
          pos <= pos - 1;
        end if;
      end if;

    end if;
  end process update_position;

  set_led: process(clk)
    variable l   : std_logic_vector(7 downto 0) := "00000001";
  begin
    if rising_edge(clk) then
      l      := "00000000";
      l(pos) := '1';
      led    <= l;
    end if;
  end process set_led;


  --
  ----------------------------------------------------------------------------------------------------------------------------------
  -- KCPSM3 input ports 
  ----------------------------------------------------------------------------------------------------------------------------------
  --
  --
  -- The inputs connect via a pipelined multiplexer
  --

  input_ports : process(clk)
  begin
    if clk'event and clk = '1' then

      case port_id is

        when "00000100" => in_port <= std_logic_vector(to_unsigned(pos, in_port'length));


                    -- read 8-bit LCD data at address 01 hex
        when "00000001" => in_port <= lcd_d;

                    -- Don't care used for all other addresses to ensure minimum logic implementation
        when others => in_port <= "XXXXXXXX";

      end case;

    end if;

  end process input_ports;


  --
  ----------------------------------------------------------------------------------------------------------------------------------
  -- KCPSM3 output ports 
  ----------------------------------------------------------------------------------------------------------------------------------
  --
  -- adding the output registers to the processor
  --

  output_ports : process(clk)
  begin

    if clk'event and clk = '1' then
      if write_strobe = '1' then

        if port_id(6) = '1' then
          lcd_output_data <= out_port;
        end if;

        -- LCD controls at address 20 hex.

        if port_id(5) = '1' then
          lcd_rs         <= out_port(2);
          lcd_rw_control <= out_port(1);
          lcd_e          <= out_port(0);
        end if;

      end if;

    end if;

  end process output_ports;

  --
  ----------------------------------------------------------------------------------------------------------------------------------
  -- LCD interface  
  ----------------------------------------------------------------------------------------------------------------------------------
  --
  -- The LCD will be accessed using the 8-bit mode.  
  -- lcd_rw is '1' for read and '0' for write 
  --
  -- Control of read and write signal
  lcd_rw <= lcd_rw_control;

  -- use read/write control to enable output buffers.
  lcd_d <= lcd_output_data when lcd_rw_control = '0' else "ZZZZZZZZ";


end Behavioral;


-- vim:tw=120:ts=2:expandtab

