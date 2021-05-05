
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity PmodKYPD is
    Port ( 
			  clk : in  STD_LOGIC;
			  JA : inout  STD_LOGIC_VECTOR (7 downto 0); 
              an : out  STD_LOGIC;  
              seg : out  STD_LOGIC_VECTOR (6 downto 0); 
              cs:BUFFER  STD_LOGIC_VECTOR(0 DOWNTO 0);
              sck:BUFFER STD_LOGIC;
              sdo:in std_logic;
              scl,sda:inout std_logic);
              
              
end PmodKYPD;

architecture Behavioral of PmodKYPD is

component Decoder is
	Port (
			 clk : in  STD_LOGIC;
          Row : in  STD_LOGIC_VECTOR (3 downto 0);
			 Col : out  STD_LOGIC_VECTOR (3 downto 0);
          DecodeOut : out  STD_LOGIC_VECTOR (3 downto 0));
	end component;

component DisplayController is
	Port (  clk:in std_logic;
			DispVal : in  STD_LOGIC_VECTOR (3 downto 0);
            anode: out std_logic;
            segOut : out  STD_LOGIC_VECTOR (6 downto 0);
            lightdata:in STD_LOGIC_VECTOR (7 downto 0);
            tempdata:in INTEGER;
            humiddata:in INTEGER);
	end component;

component ambient_light_sensor
     PORT(
            clk         :   IN      STD_LOGIC;                          
            reset_n     :   IN      STD_LOGIC;                          
            miso        :   IN      STD_LOGIC;                          
            sclk        :   BUFFER  STD_LOGIC;                          
            ss_n        :   BUFFER  STD_LOGIC_VECTOR(0 DOWNTO 0);       
            als_data    :   OUT     STD_LOGIC_VECTOR(7 DOWNTO 0));      
    end component;
    
    
 component pmod_hygrometer
 PORT(
     clk               : IN    STD_LOGIC;                                            
     reset_n           : IN    STD_LOGIC;                                            
     scl               : INOUT STD_LOGIC;                                            
     sda               : INOUT STD_LOGIC;                                            
     i2c_ack_err       : OUT   STD_LOGIC;                                            
     relative_humidity : OUT   INTEGER;     
     temperature       : OUT   INTEGER); 
    
     end component;
     
signal Decode: STD_LOGIC_VECTOR (3 downto 0);
signal sdo_seg:std_logic:=sdo;
signal data:STD_LOGIC_VECTOR (7 downto 0);
signal humid_data:INTEGER;
signal temp_data:INTEGER;
begin

	C0: Decoder port map (clk=>clk, Row =>JA(7 downto 4), Col=>JA(3 downto 0), DecodeOut=> Decode);
	C1: DisplayController port map (clk=>clk,DispVal=>Decode, anode=>an, segOut=>seg,lightdata=>data,tempdata=>temp_data,humiddata=>humid_data);
    AL: ambient_light_sensor port map(clk=>clk,reset_n=>'1',miso=>sdo_seg,sclk=>sck,ss_n=>cs,als_data=>data);
    PH:pmod_hygrometer port map(clk=>clk,reset_n=>'1',scl=>scl,sda=>sda,relative_humidity=>humid_data,temperature=>temp_data);
    
end Behavioral;
