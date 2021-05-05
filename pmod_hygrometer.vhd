

LIBRARY ieee;
USE ieee.std_logic_1164.all;
use IEEE.NUMERIC_STD.ALL;
ENTITY pmod_hygrometer IS
  GENERIC(
    sys_clk_freq            : INTEGER := 125_000_000;        
    humidity_resolution     : INTEGER RANGE 0 TO 14 := 14;  
    temperature_resolution  : INTEGER RANGE 0 TO 14 := 14); 
  PORT(
    clk               : IN    STD_LOGIC;                                           
    reset_n           : IN    STD_LOGIC;                                           
    scl               : INOUT STD_LOGIC;                                            
    sda               : INOUT STD_LOGIC;                                           
    i2c_ack_err       : OUT   STD_LOGIC;                                           
    relative_humidity : OUT   INTEGER;     
    temperature       : OUT   INTEGER); 
END pmod_hygrometer;

ARCHITECTURE behavior OF pmod_hygrometer IS
  CONSTANT hygrometer_addr : STD_LOGIC_VECTOR(6 DOWNTO 0) := "1000000";         
  TYPE machine IS(start, configure, initiate, pause, read_data, output_result); 
  SIGNAL state            : machine;                       
  SIGNAL i2c_ena          : STD_LOGIC;                     
  SIGNAL i2c_addr         : STD_LOGIC_VECTOR(6 DOWNTO 0);  
  SIGNAL i2c_rw           : STD_LOGIC;                     
  SIGNAL i2c_data_wr      : STD_LOGIC_VECTOR(7 DOWNTO 0);  
  SIGNAL i2c_data_rd      : STD_LOGIC_VECTOR(7 DOWNTO 0);  
  SIGNAL i2c_busy         : STD_LOGIC;                    
  SIGNAL busy_prev        : STD_LOGIC;                     
  SIGNAL rh_time          : INTEGER;                      
  SIGNAL temp_time        : INTEGER;                      
  SIGNAL rh_res_bits      : STD_LOGIC_VECTOR(1 DOWNTO 0);  
  SIGNAL temp_res_bit     : STD_LOGIC;                    
  SIGNAL humidity_data    : STD_LOGIC_VECTOR(15 DOWNTO 0); 
  SIGNAL temperature_data : STD_LOGIC_VECTOR(15 DOWNTO 0); 

  COMPONENT i2c_master IS
    GENERIC(
      input_clk : INTEGER; 
      bus_clk   : INTEGER); 
    PORT(
      clk       : IN     STD_LOGIC;                    
      reset_n   : IN     STD_LOGIC;                   
      ena       : IN     STD_LOGIC;                    
      addr      : IN     STD_LOGIC_VECTOR(6 DOWNTO 0); 
      rw        : IN     STD_LOGIC;                    
      data_wr   : IN     STD_LOGIC_VECTOR(7 DOWNTO 0); 
      busy      : OUT    STD_LOGIC;                    
      data_rd   : OUT    STD_LOGIC_VECTOR(7 DOWNTO 0); 
      ack_error : BUFFER STD_LOGIC;                    
      sda       : INOUT  STD_LOGIC;                    
      scl       : INOUT  STD_LOGIC);                   
  END COMPONENT;

BEGIN

  --instantiate the i2c master
  i2c_master_0:  i2c_master
    GENERIC MAP(input_clk => sys_clk_freq, bus_clk => 400_000)
    PORT MAP(clk => clk, reset_n => reset_n, ena => i2c_ena, addr => i2c_addr,
             rw => i2c_rw, data_wr => i2c_data_wr, busy => i2c_busy,
             data_rd => i2c_data_rd, ack_error => i2c_ack_err, sda => sda,
             scl => scl);
               
 
  WITH humidity_resolution SELECT
    rh_res_bits <= "10" WHEN 8,
                   "01" WHEN 11,
                   "00" WHEN OTHERS;             

  
  WITH humidity_resolution SELECT
    rh_time <= sys_clk_freq/400 WHEN 8,      
               sys_clk_freq/259 WHEN 11,     
               sys_clk_freq/153 WHEN OTHERS; 
           
  
  WITH temperature_resolution SELECT
    temp_res_bit <= '1' WHEN 11,
                    '0' WHEN OTHERS;
              

  WITH temperature_resolution SELECT
    temp_time <= sys_clk_freq/273 WHEN 11,     
                 sys_clk_freq/157 WHEN OTHERS;        
             
  PROCESS(clk, reset_n)
    VARIABLE busy_cnt   : INTEGER RANGE 0 TO 4 := 0;               
    VARIABLE pwr_up_cnt : INTEGER RANGE 0 TO sys_clk_freq/10 := 0; 
    VARIABLE pause_cnt  : INTEGER;                                 
  BEGIN
  
    IF(reset_n = '0') THEN               
      pwr_up_cnt := 0;                      
      i2c_ena <= '0';                       
      busy_cnt := 0;                        
      pause_cnt := 0;                       
      relative_humidity <= 0; 
      temperature <= 0;       
      state <= start;                       

    ELSIF(clk'EVENT AND clk = '1') THEN  
      CASE state IS                        
      
        
        WHEN start =>
          IF(pwr_up_cnt < sys_clk_freq/10) THEN  
            pwr_up_cnt := pwr_up_cnt + 1;         
          ELSE                                   
            pwr_up_cnt := 0;                    
            state <= configure;                    
          END IF;
        
        
        WHEN configure =>
          busy_prev <= i2c_busy;                        
          IF(busy_prev = '0' AND i2c_busy = '1') THEN 
            busy_cnt := busy_cnt + 1;                     
          END IF;
          CASE busy_cnt IS                             
            WHEN 0 =>                                   
              i2c_ena <= '1';                             
              i2c_addr <= hygrometer_addr;                
              i2c_rw <= '0';                              
              i2c_data_wr <= "00000010";                    
            WHEN 1 =>                                     
              i2c_data_wr <= "00010" & temp_res_bit & rh_res_bits; 
            WHEN 2 =>                                   
              i2c_data_wr <= "00000000";                    
            WHEN 3 =>                                     
              i2c_ena <= '0';                              
              IF(i2c_busy = '0') THEN                      
                busy_cnt := 0;                               
                state <= initiate;                            
              END IF;
            WHEN OTHERS => NULL;
          END CASE;
       
        --initiate the measurements
        WHEN initiate =>
          busy_prev <= i2c_busy;                       
          IF(busy_prev = '0' AND i2c_busy = '1') THEN   
            busy_cnt := busy_cnt + 1;                     
          END IF;
          CASE busy_cnt IS                             
            WHEN 0 =>                                     
              i2c_ena <= '1';                              
              i2c_addr <= hygrometer_addr;                 
              i2c_rw <= '0';                                
              i2c_data_wr <= "00000000";                   
            WHEN 1 =>                                    
              i2c_ena <= '0';                               
              IF(i2c_busy = '0') THEN                       
                busy_cnt := 0;                               
                state <= pause;                               
              END IF;
            WHEN OTHERS => NULL;
          END CASE;   
      
        
        WHEN pause =>
          IF(pause_cnt < rh_time + temp_time) THEN  
            pause_cnt := pause_cnt + 1;               
          ELSE                                    
            pause_cnt := 0;                          
            state <= read_data;                      
          END IF;
       
        
        WHEN read_data =>
          busy_prev <= i2c_busy;                          
          IF(busy_prev = '0' AND i2c_busy = '1') THEN     
            busy_cnt := busy_cnt + 1;                      
          END IF;
          CASE busy_cnt IS                               
            WHEN 0 =>                                      
              i2c_ena <= '1';                                
              i2c_addr <= hygrometer_addr;                   
              i2c_rw <= '1';                                  
            WHEN 1 =>                                       
              IF(i2c_busy = '0') THEN                         
                temperature_data(15 DOWNTO 8) <= i2c_data_rd;   
              END IF;
            WHEN 2 =>                                       
              IF(i2c_busy = '0') THEN                         
                temperature_data(7 DOWNTO 0) <= i2c_data_rd;    
              END IF;
            WHEN 3 =>                                     
              IF(i2c_busy = '0') THEN                        
                humidity_data(15 DOWNTO 8) <= i2c_data_rd;      
              END IF;
            WHEN 4 =>                                      
              i2c_ena <= '0';                                 
              IF(i2c_busy = '0') THEN                         
                humidity_data(7 DOWNTO 0) <= i2c_data_rd;      
                busy_cnt := 0;                                 
                state <= output_result;                       
              END IF;
            WHEN OTHERS => NULL;
          END CASE;
  
        
        WHEN output_result =>
          temperature <= (((to_integer(unsigned(humidity_data(15 DOWNTO 2))))/16384)*(165))-40;  
          relative_humidity <= (((to_integer(unsigned(temperature_data(15 DOWNTO 2))))/16384)*(100));  
          state <= initiate;                                                    

       
        WHEN OTHERS =>
          state <= start;

      END CASE;
    END IF;
  END PROCESS;  
END behavior;

        