

LIBRARY ieee;
USE ieee.std_logic_1164.all;

ENTITY ambient_light_sensor IS
    GENERIC(
        spi_clk_div :   INTEGER := 16); 
    PORT(
        clk         :   IN      STD_LOGIC;                          
        reset_n     :   IN      STD_LOGIC;                         
        miso        :   IN      STD_LOGIC;                         
        sclk        :   BUFFER  STD_LOGIC;                         
        ss_n        :   BUFFER  STD_LOGIC_VECTOR(0 DOWNTO 0);      
        als_data    :   OUT     STD_LOGIC_VECTOR(7 DOWNTO 0));      
END ambient_light_sensor;

ARCHITECTURE behavior OF ambient_light_sensor IS
    SIGNAL   spi_rx_data    : STD_LOGIC_VECTOR(15 DOWNTO 0);   
    --declare SPI Master component
    COMPONENT spi_master IS
        GENERIC(
            slaves  : INTEGER := 1;  
            d_width : INTEGER := 16); 
        PORT(
            clock   : IN     STD_LOGIC;                           
            reset_n : IN     STD_LOGIC;                            
            enable  : IN     STD_LOGIC;                      
            cpol    : IN     STD_LOGIC;    
            cpha    : IN     STD_LOGIC;                 
            cont    : IN     STD_LOGIC;                             
            clk_div : IN     INTEGER;                               
            addr    : IN     INTEGER;                               
            tx_data : IN     STD_LOGIC_VECTOR(d_width-1 DOWNTO 0);  
            miso    : IN     STD_LOGIC;                            
            sclk    : BUFFER STD_LOGIC;                             
            ss_n    : BUFFER STD_LOGIC_VECTOR(slaves-1 DOWNTO 0);   
            mosi    : OUT    STD_LOGIC;                            
            busy    : OUT    STD_LOGIC;                             
            rx_data : OUT    STD_LOGIC_VECTOR(d_width-1 DOWNTO 0)); 
    END COMPONENT spi_master;

BEGIN

  
  spi_master_0:  spi_master
     GENERIC MAP(slaves => 1, d_width => 16)
     PORT MAP(clock => clk, reset_n => reset_n, enable => '1', cpol => '1',
           cpha => '1', cont => '0', clk_div => spi_clk_div, addr => 0,
           tx_data => (OTHERS => '0'), miso => miso, sclk => sclk, ss_n => ss_n,
           mosi => open, busy => open, rx_data => spi_rx_data);

    als_data <= spi_rx_data(12 DOWNTO 5);   
   
END behavior;