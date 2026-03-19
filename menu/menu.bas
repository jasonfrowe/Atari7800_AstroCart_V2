 set romsize 32k
 displaymode 320A
 set zoneheight 8
 set screenheight 192
 
 BACKGRND=$00
 
 incgraphic gfx/menufont.png 320A
 
 P0C1=$0F : P0C2=$3F : P0C3=$6F
 P1C1=$0F : P1C2=$1F : P1C3=$4F
 
 characterset menufont
 alphachars ASCII
 
 ;
 ; Variables - using longer names to avoid conflicts
 ;
 dim game_count = a
 dim selected_game = b
 dim joy_delay = c
 dim temp_y = d
 dim flash_count = e
 dim status_temp = f
 
 ;
 ; FPGA trigger address - just accessing this address triggers FPGA detection
 ;
 dim fpga_trigger = $2200
 
 ;
 ; Initialize variables
 ;
 game_count = 5  
 selected_game = 0
 joy_delay = 0
 
 ;
 ; Draw initial screen once and save it
 ;
 clearscreen
 gosub draw_title
 gosub draw_game_list
 savescreen
 
main_loop
 ;
 ; Restore background, then draw dynamic elements
 ;
 restorescreen
 gosub draw_cursor
 gosub draw_hud
 
 ;
 ; Countdown input delay
 ;
 if joy_delay > 0 then joy_delay = joy_delay - 1
 
 ;
 ; Check for joystick input only when not delayed
 ;
 if joy_delay = 0 then gosub check_input
 
 drawscreen
 goto main_loop

draw_title
 ;
 ; Draw title and instructions
 ;
 plotchars 'GAME LOADER' 0 60 0
 plotchars 'SELECT A GAME' 1 56 2
 return

draw_game_list
 ;
 ; Display available games
 ;
 ; plotchars 'ASTRO WING'       0 10 4
 ; plotchars 'DONKEY KONG'       0 10 6
 ; plotchars 'GALAGA'           0 10 8
 ; plotchars 'MS PAC-MAN'       0 10 10
 ; plotchars 'DEFENDER'         0 10 12
  plotchars $6000 0 10 4
  plotchars $6020 0 10 5
  plotchars $6040 0 10 6
  plotchars $6060 0 10 7
  plotchars $6080 0 10 8
  plotchars $60A0 0 10 9
  plotchars $60C0 0 10 10
  plotchars $60E0 0 10 11
  plotchars $6100 0 10 12

 return

draw_hud
 ; plotchars $7F00 1 10 13 14
 ; plotchars $7F10 1 80 13 14
 ; plotchars $7F20 1 10 14 14
 ; plotchars $7F30 1 80 14 14
 ; plotchars $7F40 1 10 15 14
 ; plotchars $7F50 1 80 15 14
 ; plotchars $7F60 1 10 16 14
 ; plotchars $7F70 1 80 16 14
 ; plotchars $7F80 1 10 17 14
 ; plotchars $7F90 1 80 17 14
 ; plotchars $7FA0 1 10 18 14
 ; plotchars $7FB0 1 80 18 14
 ; plotchars $7FC0 1 10 19 14
 ; plotchars $7FD0 1 80 19 14
 return


draw_cursor
 ;
 ; Clear all cursor positions first
 ;
 plotchars ' ' 0 0 4
 plotchars ' ' 0 0 5
 plotchars ' ' 0 0 6
 plotchars ' ' 0 0 7
 plotchars ' ' 0 0 8
 plotchars ' ' 0 0 9
 plotchars ' ' 0 0 10
 plotchars ' ' 0 0 11
 plotchars ' ' 0 0 12
 
 ;
 ; Calculate and draw cursor at current selection
 ;
 temp_y = selected_game * 1 + 4
 plotchars '>' 0 0 temp_y
 return

check_input
 ;
 ; Simple joystick check - delay prevents rapid repeats
 ;
 if joy0up then selected_game = selected_game - 1 : joy_delay = 15
 if joy0down then selected_game = selected_game + 1 : joy_delay = 15
 
 ; Trigger Reload (Right + Fire)
 if joy0fire0 && joy0right then fpga_trigger = 64 : joy_delay = 30 : goto select_game_end
 
 if joy0fire0 then gosub select_game : joy_delay = 15
 
select_game_end
 
 ;
 ; Keep selected_game in bounds
 ;
 if selected_game > 7 then selected_game = 0
 if selected_game > 127 then selected_game = 7
 return

move_up
 ;
 ; This is no longer used but kept for compatibility
 ;
 return

move_down
 ;
 ; This is no longer used but kept for compatibility
 ;
 return

select_game
 ;
 ; Visual feedback: flash background briefly
 ;
 flash_count = 8
flash_loop
 BACKGRND=$22
 drawscreen
 BACKGRND=$00
 drawscreen
 flash_count = flash_count - 1
 if flash_count > 0 then goto flash_loop
 
 ;
 ; Trigger FPGA: write selected game + 128 to $2200
 ; This sets bit 7, allowing FPGA to distinguish from initialization (0).
 ;
 fpga_trigger = selected_game + 128

 ; Wait for load to finish (poll $7FF0)
wait_loop
 restorescreen
 gosub draw_hud
 drawscreen
 asm
   lda $7FF0
   bpl .keep_waiting
   lda #$A5
   sta $2200
   jmp ($FFFC)
.keep_waiting
end
 goto wait_loop
