
LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.std_logic_unsigned.all;

ENTITY i2c_master IS
  GENERIC(
    input_clk : INTEGER := 125_000_000; 
    bus_clk   : INTEGER := 400_000);   
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
END i2c_master;

ARCHITECTURE logic OF i2c_master IS
  CONSTANT divider  :  INTEGER := (input_clk/bus_clk)/4; 
  TYPE machine IS(ready, start, command, slv_ack1, wr, rd, slv_ack2, mstr_ack, stop); 
  SIGNAL state         : machine;                       
  SIGNAL data_clk      : STD_LOGIC;                      
  SIGNAL data_clk_prev : STD_LOGIC;                      
  SIGNAL scl_clk       : STD_LOGIC;                      
  SIGNAL scl_ena       : STD_LOGIC := '0';              
  SIGNAL sda_int       : STD_LOGIC := '1';             
  SIGNAL sda_ena_n     : STD_LOGIC;                      
  SIGNAL addr_rw       : STD_LOGIC_VECTOR(7 DOWNTO 0);   
  SIGNAL data_tx       : STD_LOGIC_VECTOR(7 DOWNTO 0);   
  SIGNAL data_rx       : STD_LOGIC_VECTOR(7 DOWNTO 0);   
  SIGNAL bit_cnt       : INTEGER RANGE 0 TO 7 := 7;      
  SIGNAL stretch       : STD_LOGIC := '0';               
BEGIN

 
  PROCESS(clk, reset_n)
    VARIABLE count  :  INTEGER RANGE 0 TO divider*4; 
  BEGIN
    IF(reset_n = '0') THEN               
      stretch <= '0';
      count := 0;
    ELSIF(clk'EVENT AND clk = '1') THEN
      data_clk_prev <= data_clk;          
      IF(count = divider*4-1) THEN        
        count := 0;                      
      ELSIF(stretch = '0') THEN          
        count := count + 1;              
      END IF;
      CASE count IS
        WHEN 0 TO divider-1 =>            
          scl_clk <= '0';
          data_clk <= '0';
        WHEN divider TO divider*2-1 =>    
          scl_clk <= '0';
          data_clk <= '1';
        WHEN divider*2 TO divider*3-1 =>  
          scl_clk <= '1';             
          IF(scl = '0') THEN             
            stretch <= '1';
          ELSE
            stretch <= '0';
          END IF;
          data_clk <= '1';
        WHEN OTHERS =>                
          scl_clk <= '1';
          data_clk <= '0';
      END CASE;
    END IF;
  END PROCESS;

 
  PROCESS(clk, reset_n)
  BEGIN
    IF(reset_n = '0') THEN                 
      state <= ready;                     
      busy <= '1';                       
      scl_ena <= '0';                     
      sda_int <= '1';                   
      ack_error <= '0';                   
      bit_cnt <= 7;                        
      data_rd <= "00000000";              
    ELSIF(clk'EVENT AND clk = '1') THEN
      IF(data_clk = '1' AND data_clk_prev = '0') THEN  
        CASE state IS
          WHEN ready =>                     
            IF(ena = '1') THEN              
              busy <= '1';                   
              addr_rw <= addr & rw;          
              data_tx <= data_wr;           
              state <= start;               
            ELSE                           
              busy <= '0';                   
              state <= ready;             
            END IF;
          WHEN start =>                     
            busy <= '1';                    
            sda_int <= addr_rw(bit_cnt);     
            state <= command;                
          WHEN command =>                    
            IF(bit_cnt = 0) THEN           
              sda_int <= '1';                
              bit_cnt <= 7;                
              state <= slv_ack1;            
            ELSE                            
              bit_cnt <= bit_cnt - 1;        
              sda_int <= addr_rw(bit_cnt-1); 
              state <= command;              
            END IF;
          WHEN slv_ack1 =>                  
            IF(addr_rw(0) = '0') THEN        
              sda_int <= data_tx(bit_cnt);   
              state <= wr;                   
            ELSE                          
              sda_int <= '1';               
              state <= rd;                
            END IF;
          WHEN wr =>                         
            busy <= '1';                     
            IF(bit_cnt = 0) THEN            
              sda_int <= '1';               
              bit_cnt <= 7;                 
              state <= slv_ack2;           
            ELSE                             
              bit_cnt <= bit_cnt - 1;      
              sda_int <= data_tx(bit_cnt-1);
              state <= wr;                  
            END IF;
          WHEN rd =>                         
            busy <= '1';                    
            IF(bit_cnt = 0) THEN             
              IF(ena = '1' AND addr_rw = addr & rw) THEN  
                sda_int <= '0';             
              ELSE                           
                sda_int <= '1';              
              END IF;
              bit_cnt <= 7;                 
              data_rd <= data_rx;          
              state <= mstr_ack;            
            ELSE                             
              bit_cnt <= bit_cnt - 1;        
              state <= rd;                  
            END IF;
          WHEN slv_ack2 =>                   
            IF(ena = '1') THEN               
              busy <= '0';                 
              addr_rw <= addr & rw;        
              data_tx <= data_wr;          
              IF(addr_rw = addr & rw) THEN   
                sda_int <= data_wr(bit_cnt); 
                state <= wr;                 
              ELSE                         
                state <= start;              
              END IF;
            ELSE                             
              state <= stop;                 
            END IF;
          WHEN mstr_ack =>                  
            IF(ena = '1') THEN              
              busy <= '0';                  
              addr_rw <= addr & rw;         
              data_tx <= data_wr;            
              IF(addr_rw = addr & rw) THEN   
                sda_int <= '1';              
                state <= rd;               
              ELSE                           
                state <= start;              
              END IF;    
            ELSE                            
              state <= stop;                
            END IF;
          WHEN stop =>                       
            busy <= '0';                   
            state <= ready;                  
        END CASE;    
      ELSIF(data_clk = '0' AND data_clk_prev = '1') THEN  
        CASE state IS
          WHEN start =>                  
            IF(scl_ena = '0') THEN                  
              scl_ena <= '1';                      
              ack_error <= '0';                     
            END IF;
          WHEN slv_ack1 =>                          
            IF(sda /= '0' OR ack_error = '1') THEN  
              ack_error <= '1';                     
            END IF;
          WHEN rd =>                                
            data_rx(bit_cnt) <= sda;             
          WHEN slv_ack2 =>                         
            IF(sda /= '0' OR ack_error = '1') THEN  
              ack_error <= '1';                     
            END IF;
          WHEN stop =>
            scl_ena <= '0';                      
          WHEN OTHERS =>
            NULL;
        END CASE;
      END IF;
    END IF;
  END PROCESS;  

 
  WITH state SELECT
    sda_ena_n <= data_clk WHEN start,     
                 NOT data_clk WHEN stop,  
                 sda_int WHEN OTHERS;          
      
 
  scl <= '0' WHEN (scl_ena = '1' AND scl_clk = '0') ELSE 'Z';
  sda <= '0' WHEN sda_ena_n = '0' ELSE 'Z';
  
END logic;