
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.NUMERIC_STD.ALL;



entity DisplayController is
    Port ( 
			  
			  clk:in std_logic;
			  DispVal : in  STD_LOGIC_VECTOR (3 downto 0);
			  
			  anode: out std_logic;
			  
              segOut : out  STD_LOGIC_VECTOR (6 downto 0); 
              
              lightdata:in STD_LOGIC_VECTOR (7 downto 0);
              
              tempdata:in INTEGER;
              
              humiddata:in INTEGER);
              
end DisplayController;

architecture Behavioral of DisplayController is

begin
	
	
	anode<='1'; 

	
process(clk)

begin

if rising_edge(clk)then

    
      if DispVal="0011" and lightdata>"00010001" then
      segOut<="0000110";
      elsif DispVal="0011" and lightdata<"00010010" then
      segOut<="0111111";
     

      elsif DispVal="0001" and tempdata>700 then
      segOut<="1110111";
      
      elsif DispVal="0001" and  tempdata=0 then
      segOut<="0000110";
      
       
      elsif DispVal="0001" and tempdata>18 and tempdata<24 then
      segOut<="1101101";
       
    
       
      elsif DispVal="0010" and humiddata>50 then
      segOut<="1101111";
        
      elsif DispVal="0010" and humiddata<0 then
      segOut<="0000110"; 
       
      elsif DispVal="0010" and humiddata<50 and humiddata>1  then
      segOut<="1101101";
        
      else 
      segOut<="1110001";
      
      end if;
       
	
   end if;
end process;
end Behavioral;

