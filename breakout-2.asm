################ CSC258H1F Fall 2022 Assembly Final Project ##################
# This file contains our implementation of Breakout.
#
# Student 1: Ethan Ing, 1007331237
# Student 2: Luhan He, 1007857758
######################## Bitmap Display Configuration ########################
# - Unit width in pixels:       8
# - Unit height in pixels:      8
# - Display width in pixels:    512
# - Display height in pixels:   256
# - Base Address for Display:   0x10008000 ($gp)
##############################################################################

    .data 
##############################################################################
# Immutable Data
##############################################################################
# The address of the bitmap display. Don't forget to connect it!
ADDR_DSPL:
    .word 0x10008000
# The address of the keyboard. Don't forget to connect it!
ADDR_KBRD:
    .word 0xffff0000
##############################################################################
# Mutable Data
##############################################################################

PADDLE_POSITION:
	.word 29		# current x-coordinate of paddle (29 units places the paddle in the middle)
	.word 29 		# previous x-coordinate
	.word 6			# paddle width
    
BALL:
	.word 31 		# current x-coordinate of ball
	.word 31 		# current y-coordinate of ball
	
	# Vectors
	.word 0  		# current x direction
	.word -1  		# current y direction
	
#Colors
MY_COLORS:
	.word 0xff0000		# 0 red
	.word 0xffff00		# 4 yellow
	.word 0x0000ff		# 8 blue
	.word 0x00ff00		# 12 green
	.word 0xffa500		# 16 orange
	.word 0x808080		# 20 gray
	.word 0xffffff		# 24 white
	.word 0x000000		# 28 black
	.word 0x6C3483		# 32 purple
	.word 0xf708bd		# 36 pink

# Check if the ball has been launched
STARTED:
	.word 0
	
# Number of lives
LIVES: 
	.word 3
	
# Number of brick deleted
DELETED:
	.word 0
##############################################################################
# Code
##############################################################################
	.text
	.globl main

# Run the game
main:
    	# Initialize the game 
    	# --- Draw the display ---
	jal DRAW_DISPLAY
       
# Start loop
game_loop:
    
	# Check for brick collisions
	jal check_ball_brick_collision
    
# Skip the collision for the bricks that msut be hit twice
skip_collision:

	# Check if key has been pressed
	lw $s0, ADDR_KBRD
	lw $s1, 0($s0)			# contains input signal
	beq $s1, 1, keyboard_input	# key has been pressed
    
finished_keyboard:
	
	# Check if the ball has been launched
	lw $t1, STARTED
	beq $t1, 0, not_launched
	
	# Started, so launch ball
	jal launch_move_ball
    
# Ball has not been launched yet
not_launched:

	# Update the padde display
	jal UPDATE_DISPLAY

	# Check for collisions with paddle and walls
	jal check_bottom_collision
	jal check_paddle
	jal check_top_collision
	jal check_left_collision
	jal check_right_collision
    
	# SLEEP
	li $v0, 32
	li $a0, 300
	syscall
	#SLEEP
    
	b game_loop
	
# 1. -------------------- DRAW ORIGINAL DISPLAY -------------------- #
DRAW_DISPLAY:

	# Stack
	addi $sp, $sp, -4		# make space in stack to store $ra
	sw $ra, 0($sp) 	    		# store current $ra into stack
    
	# Load the address
	la $a0, ADDR_DSPL       	# temp = &ADDR_DSPL
	lw $a0, 0($a0)			# display = *temp
	la $a1, MY_COLORS
    
	jal draw_walls          	# begins drawing horiz line, then entire wall


	# --- Begin drawing brick rows --- 
	# Go back to top left of wall
	la $a0, ADDR_DSPL		# temp = &ADDR_DSPL
	lw $a0, 0($a0)			# display = *temp
	addi $a0, $a0, 2064		# start 8 rows down
    
	# Begin by loading in the first color (5 brick rows)
	la $a1, MY_COLORS
	lw $t1, 0($a1)	    		# $t1 = red color
	jal draw_brick_row	    	# draw the first brick row red
	addi $a1, $a1, 4	    	# load in the next color: $t1 = yellow
	lw $t1, 0($a1)	        
	addi $a0, $a0, 272
	jal draw_brick_row 
	addi $a1, $a1, 4	    	# load in the next color: $t1 = blue
	lw $t1, 0($a1)	        
	addi $a0, $a0, 240
	jal draw_brick_row
	addi $a1, $a1, 4	    	# load in the next color: $t1 = green
	lw $t1, 0($a1)	   
	addi $a0, $a0, 272     
	jal draw_brick_row         
	
	# Draw the display of lives remaining
	jal draw_lives
	
	# Draw the unbreakable blocks 
	jal draw_unbreakable
       
	# Draw the starting paddle position
	la $a0, PADDLE_POSITION
	lw $a0, 0($a0)	    		# $a0 = x-coord of paddle
	la $t0, MY_COLORS	    
	lw $a1, 8($t0)	    		# $a1 = blue (color of paddle)
	jal draw_paddle	    		# draw the blue paddle
    
	# Draw the starting ball position
	la $a0, BALL
	lw $a0, 0($a0)	    		# $a0 = x-coord of ball
	lw $a2, BALL + 4	    	# $a2 = y-coord of ball
	lw $a1 MY_COLORS + 24   	# $a1 = white (color of ball)
	jal draw_ball	    		# draw the white ball
  
	# Stack
	lw $ra, 0($sp)			# get the stored value of $ra from the stack
	addi $sp, $sp, 4		# move stack down again
	jr $ra

# --- Draw the horizontal and vertical walls gray --- 
draw_walls:

	addi $a1, $a1, 20	    	# load in the gray color
	lw $t1, 0($a1)	    		# $t1 = gray (color of walls)
  
	li $t2, 128		    	# $t2 = Unit count = 128 (2 rows of 64)
	li $t3, 0		    	# #t3 = i = 0
    
	addi $a0, $a0, 1280     	# Start drawing walls 5 rows down (256 * 5)
    
draw_horiz_line_loop:
    	beq $t3, $t2, end_horiz_line_loop	# if i == unit count, end loop
        
        	sw $t1, 0($a0)			# draw unit
        	addi $a0, $a0, 4		# go to next unit
        
        	addi $t3, $t3, 1		# i = i + 1
		b draw_horiz_line_loop
end_horiz_line_loop:

	li $t0, 0		    # i = 0
	li $t2, 24		    # $t2 = new unit count = 24 (draw for 24 different rows)
    
draw_vert_line_loop:
	beq $t0, $t2, end_vert_line_loop
        	sw $t1, 0($a0)	                # draw unit for first vert line
        	addi $a0, $a0, 4
        	sw $t1, 0($a0)		        # draw second unit for first vert line
        	addi $a0, $a0, 4
        	sw $t1, 0($a0)			# draw third unit for first vert line
        	addi $a0, $a0, 4
        	sw $t1, 0($a0)			# draw fourth unit for first vert line
        	addi $a0, $a0, 228	        # go to end to draw next line
        	sw $t1, 0($a0)	    	        # draw unit for the second vert line
        	addi $a0, $a0, 4	        # draw second unit for the second vert line
        	sw $t1, 0($a0)
        	addi $a0, $a0, 4
        	sw $t1, 0($a0)			# draw third unit for first vert line
        	addi $a0, $a0, 4
        	sw $t1, 0($a0)			# draw fourth unit for first vert line
        	addi $a0, $a0, 4	        # draw at the beginning again
        	addi $t0, $t0, 1	        # i = i + 1
    		b draw_vert_line_loop
    	
end_vert_line_loop:

	# Draw the last pixels of the the vertical walls blue
	la $a1, MY_COLORS
	addi $a1, $a1, 8	# load in the blue color
	lw $t1, 0($a1)	        # $t1 = blue color
	sw $t1, 0($a0)	        # draw unit for first vert line
	addi $a0, $a0, 4
	sw $t1, 0($a0)
	addi $a0, $a0, 4
	sw $t1, 0($a0)
	addi $a0, $a0, 4
	sw $t1, 0($a0)
	addi $a0, $a0, 228	# go to end to draw next line
	sw $t1, 0($a0)	    	# draw unit for the second vert line
	addi $a0, $a0, 4
	sw $t1, 0($a0)
	addi $a0, $a0, 4
	sw $t1, 0($a0)
	addi $a0, $a0, 4
	sw $t1, 0($a0)
    
	jr $ra

# --- Draw the brick rows ---
# Each brick is 4 units wide (or 32 pixels)
draw_brick_row:
    
	li $t0, 0		# i = 0
	li $t2, 7		# unit count = 7 (7 bricks per row)
 
draw_brick_loop:   
    
    	# Draw brick (4 pixels wide)
	beq $t0, $t2, end_draw_brick_loop
        	sw $t1, 0($a0)	        # draw unit for first pixel of brick
        	addi $a0, $a0, 4	# go to next unit
        	sw $t1, 0($a0)
        	addi $a0, $a0, 4	        
        	sw $t1, 0($a0)	    	
        	addi $a0, $a0, 4
        	sw $t1, 0($a0)		# draw the final unit of the brick
        	addi $a0, $a0, 20	# go to beginning of next brick
        
        	addi $t0, $t0, 1        # i = i + 1
        	b draw_brick_loop
    
end_draw_brick_loop:
	addi $a0, $a0, 32       # add 16 pixels to get to next row for brick row
	jr $ra

# Draw the initial display of the number of lives the user has (3)
draw_lives:

	la $t0, ADDR_DSPL		# temp = &ADDR_DSPL
	lw $t0, 0($t0)			# display = *temp
	addi $t0, $t0, 264		# start 1 row down
	
	lw $t1, MY_COLORS		# Load in the red color
	sw $t1, 0($t0)
	addi $t0, $t0, 8		# go two units over
	sw $t1, 0($t0)
	addi $t0, $t0, 8		# go two units over
	sw $t1, 0($t0)
	
	jr $ra
	
# Draw the unbreakable bricks purple
draw_unbreakable:

	la $a0, ADDR_DSPL		# temp = &ADDR_DSPL
	lw $a0, 0($a0)			# display = *temp
	addi $a0, $a0, 4112		
    
	la $a1, MY_COLORS + 32
	lw $t1, 0($a1)	    		# $t1 = purple color
    
	li $t0, 0		# i = 0
	li $t2, 4		# unit count = 4 (4 unbreakable bricks for this row)
 
draw_unbreakable_loop:   
    
    	# Draw bricks
	beq $t0, $t2, end_draw_unbreakable_loop
        	sw $t1, 0($a0)	        # draw unit for first pixel of brick
        	addi $a0, $a0, 4	# go to next unit
        	sw $t1, 0($a0)
        	addi $a0, $a0, 4	        
        	sw $t1, 0($a0)	    	
        	addi $a0, $a0, 4
        	sw $t1, 0($a0)		# draw the final unit of the brick
        	addi $a0, $a0, 52	# go to beginning of next brick
        
        	addi $t0, $t0, 1        # i = i + 1
        	b draw_unbreakable_loop
    
end_draw_unbreakable_loop:
	jr $ra
	
# 1. -------------------- END DRAW SCENE -------------------- #

# 2. -------------------- LAUNCHING AND DRAWING THE BALL -------------------- #

# Initially launches the ball and moves the ball when called
launch_move_ball:

	# Stack
	addi $sp, $sp, -4	# make space in stack to store $ra
	sw $ra, 0($sp)		# store current $ra into stack

	# Erase the previous loc of ball and redraw the ball in next position
	jal erase_ball
	jal redraw_ball
	
# Erase the previous loc of the ball
erase_ball:
	la $a0, BALL					
	lw $a0, 0($a0)			# $a0 = curr x-coord of ball	
	lw $a2, BALL + 4		# $a2 = curr y-coord of ball
	lw $a1, MY_COLORS + 28		# Cover prev loc of ball with balck
	
	jal draw_ball
	
# Redraw the ball in the next location
redraw_ball:

	# Direction of X
	lw $t2, BALL			# $t2 = x-coord of ball
	lw $t3, BALL + 8		# $t3 = x direction
	add $t2, $t2, $t3
	sw $t2, BALL
	
	# Direction of Y
	lw $t4, BALL + 4		# $t4 = y-coord of ball
	lw $t5, BALL + 12		# $t5 = x direction
	add $t4, $t4, $t5
	sw $t4, BALL + 4

	# Redraw the ball in the next position including the vectors
	lw $a0, BALL
	lw $a2, BALL + 4		
	lw $a1, MY_COLORS + 24		# $a1 = white (color the ball)
	
	# Draw the ball in the next position
	jal draw_ball
	
	# Stack
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra

# --- Function to draw the ball (1 unit) ---
# $a0 = x-coord of ball
# $a2 = y-coord of ball
# $a1 = color of ball
draw_ball:

	# Use the stack to store the initial x-coord and y-coord 
	addi $sp $sp -12
	sw $a0, 8($sp)
	sw $a2, 4($sp)
	sw $ra, 0($sp)
	
	# Get the address to display the ball
        jal get_address
	
	# Obtain the stored values from the stack
	lw $a0, 8($sp)
	lw $a2, 4($sp)
	lw $ra, 0($sp)
	addi $sp $sp 12
	
	# Draw the pixel
	sw $a1, 0($v0)

	jr $ra	
	
# 2. -------------------- END LAUNCHING AND DRAWING THE BALL -------------------- #
	
# 3. -------------------- KEYBOARD INPUT -------------------- #

# Handle the keyboard input
keyboard_input:
	lw $s0, 4($s0)			 # $s0 contains hex with the input key
	beq $s0, 0x61, left_input	 # handle left input if "a" is pressed
	beq $s0, 0x64, right_input	 # handle right input if "d" is pressed
	beq $s0, 0x71, quit	 	 # quit game if "q" is pressed
	beq $s0, 0x70, pause		 # pause the game if "p" is pressed
	beq $s0, 0x20, initiate_ball	 # initially launch ball when spacebar is pressed
	
	j finished_keyboard

# Handle all inputs
left_input:
	# handle "a" (Left) input and update paddle coordinates	
	lw $t0, PADDLE_POSITION			# $t1 = current x-coord
	beq $t0, 2, reached_far_left	        # cannot go any further left (2 to account for wall)
		sw $t0, PADDLE_POSITION + 4	# set the prev x-coord to curr x-coord
		addi $t0, $t0, -1		# x-coord = prev x-coord - 1
		sw $t0, PADDLE_POSITION		# updated x-coord of paddle
	
	reached_far_left:
	j finished_keyboard

right_input:
	# Handle "d" (right) input and update paddle coordinates	
	lw $t1, PADDLE_POSITION
	beq $t1, 56, reached_far_right	        # cannot go any further right (account for wall and length of paddle)
		sw $t1, PADDLE_POSITION + 4	# set the prev x-coord to curr x-coord
		addi $t1, $t1, 1		# x-coord = prev x-coord + 1
		sw $t1, PADDLE_POSITION		# updated x-coord of paddle
	
	reached_far_right:
	j finished_keyboard
	
pause:
	# Handle "p" (pause) input and pause the screen
	lw $t0, ADDR_DSPL
	addi $t0, $t0, 636
	lw $t1, MY_COLORS + 16
	
	# Draw the display of the pause button
	sw $t1, 0($t0) 		
	addi $t0, $t0, 8
	sw $t1, 0($t0) 		
	addi $t0, $t0, 248
	sw $t1, 0($t0) 		
	addi $t0, $t0, 8
	sw $t1, 0($t0) 			
	
	# Check if user un-paused (pressed a button on the keyboard)
	lw $s0, ADDR_KBRD
	lw $s1, 0($s0)
	beq $s1, 1, un_paused
	j pause				# user did not unpause (pressed another button on keyboard)
	
un_paused:
	lw $s0, 4($s0)			 
	beq $s0, 0x70, user_unpaused
	
	# Button pressed was not "P"
	j pause
	
# The user un-paused the screen so resume the game
user_unpaused:

	# Load in the address to redraw the pause display black
	lw $t0, ADDR_DSPL 
	addi $t0, $t0, 636
	lw $t1, MY_COLORS + 28
	
	# Draw the display of the pause button black since it's unpaused
	sw $t1, 0($t0) 		
	addi $t0, $t0, 8
	sw $t1, 0($t0) 		
	addi $t0, $t0, 248
	sw $t1, 0($t0) 		
	addi $t0, $t0, 8
	sw $t1, 0($t0) 			
	
	j finished_keyboard
	
# Launch the ball
initiate_ball:
	li $t1, 1
	sw $t1, STARTED
	j finished_keyboard
	
# Terminate program if user presses "q" or if game is lost
quit:
	li $v0, 10                      # quit game
	syscall

# 3. -------------------- END KEYBOARD INPUT -------------------- #   
    
# 4. -------------------- UPDATE DISPLAY -------------------- # 
UPDATE_DISPLAY:

	# Update the walls
	lw $t1, MY_COLORS + 20
  
	li $t2, 128		    	# $t2 = Unit count = 128 (2 rows of 64)
	li $t3, 0		    	# #t3 = i = 0
    
	lw $t4, ADDR_DSPL    		
	addi $t4, $t4, 1280		# Start drawing walls 5 rows down (256 * 5)
    
draw_horiz_lines:
    	beq $t3, $t2, end_horiz_lines		# if i == unit count, end loop
        
        	sw $t1, 0($t4)			# draw unit
        	addi $t4, $t4, 4		# go to next unit
        
        	addi $t3, $t3, 1		# i = i + 1
		b draw_horiz_lines
end_horiz_lines:

	# --- Update the paddle display ---
	
	# Stack
	addi $sp, $sp, -4		# make space in stack to store $ra
	sw $ra, 0($sp)			# store current $ra into stack
	
	# Draw black over the previous paddle
	lw $a0, PADDLE_POSITION + 4	# $a0 = previous x-coord of paddle
	lw $a1, MY_COLORS + 28		# $a1 = black (color of background)
	jal draw_paddle
	
	# Draw the paddle blue again in the new position
	lw $a0, PADDLE_POSITION		# $a0 = x-coord of paddle
	lw $a1, MY_COLORS + 8		# $a1 = blue (color of paddle)
	jal draw_paddle
	
	# Stack
	lw $ra, 0($sp)
	add $sp, $sp, 4
	jr $ra

# --- Function to draw the paddle ---
# $a0 = starting x-coord of paddle
# $a1 = color of paddle
draw_paddle:

	# Stack
	addi $sp, $sp, -4		# make space in stack to store $ra		
	sw $ra, 0($sp)			# store current $ra into stack
    
	# Get the display address of the paddle
	li $a2, 31			# 31 is the y-coord of the paddle
	jal get_address
	addi $a0, $v0, 0		# $a0 is the starting address of the paddle

	# Draw paddle 6 units wide
	li $t0, 0			# i = 0
	li $t2, 6	            	# unit count = 6 (paddle width)

draw_paddle_loop:

	beq $t0, $t2, end_draw_paddle_loop
        	sw $a1, 0($a0)	        # draw unit for first pixel of the paddle
        	addi $a0, $a0, 4	# go to the next unit
        	addi $t0, $t0, 1	# i = i + 1
        	b draw_paddle_loop
        
end_draw_paddle_loop:

	# Stack
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra
	
	
# Update the number of lives
lost_one_life:

	# Load the address to draw over the first life
	la $t0, ADDR_DSPL		# temp = &ADDR_DSPL
	lw $t0, 0($t0)			# display = *temp
	addi $t0, $t0, 280		
	
	lw $t1, MY_COLORS + 28		# load in the black color
	sw $t1, 0($t0)
	
	# Make ball go back to original position
	li $t2, 31			# ball x-coord
	sw $t2, BALL
	li $t3, 31			# ball y-coord
	sw $t3, BALL + 4
	li $t4, 0			# ball x-vector
	sw $t4, BALL + 8
	li $t5, -1			# ball y-vector
	sw $t5, BALL + 12
	
	# Do not resume game until player launches ball again
	li $t6, 0
	sw $t6, STARTED
	
	j game_loop

lost_two_lives:

	# Load the address to draw over the second life
	la $t0, ADDR_DSPL		# temp = &ADDR_DSPL
	lw $t0, 0($t0)			# display = *temp
	addi $t0, $t0, 272		
	
	lw $t1, MY_COLORS + 28		# load in the black color
	sw $t1, 0($t0)
	
	# Make ball go back to original position
	li $t2, 31			# ball x-coord
	sw $t2, BALL
	li $t3, 31			# ball y-coord
	sw $t3, BALL + 4
	li $t4, 0			# ball x-vector
	sw $t4, BALL + 8
	li $t5, -1			# ball y-vector
	sw $t5, BALL + 12
	
	# Do not resume game until player launches ball again
	li $t6, 0
	sw $t6, STARTED
	
	j game_loop

lost_three_lives:

	# Load the address to draw over the third life
	la $t0, ADDR_DSPL		# temp = &ADDR_DSPL
	lw $t0, 0($t0)			# display = *temp
	addi $t0, $t0, 264		
	
	lw $t1, MY_COLORS + 28		# load in the black color
	sw $t1, 0($t0)
	
	# Play the losing sound when three lives are lost
	li $a0, 48
	li $a1, 500
	li $a2, 80
	li $a3, 60
	li $v0, 33
	syscall
	
	li $a0, 52
	li $a1, 500
	li $a2, 80
	li $a3, 60
	li $v0, 33
	syscall
	
	li $a0, 56
	li $a1, 500
	li $a2, 80
	li $a3, 60
	li $v0, 33
	syscall
	
	j quit

# 4. -------------------- END UPDATE DISPLAY -------------------- # 
 
# 5. -------------------- COLLISION CHECKING -------------------- # 

# Checks collision with the bottom (not on paddle)
check_bottom_collision:

	lw $t1, BALL + 4		# Load in the y-coordinate of the ball
	
	# If y is less than 32 than the game continues
	blt $t1, 32, no_collision
	
	# Play lost life sound
	li $a0, 60
	li $a1, 50
	li $a2, 6
	li $a3, 60
	li $v0, 33
	syscall
	
	li $a0, 59
	li $a1, 50
	li $a2, 6
	li $a3, 60
	li $v0, 33
	syscall
	
	li $a0, 58
	li $a1, 50
	li $a2, 6
	li $a3, 60
	li $v0, 33
	syscall
	
	# User loses one life (3 lives) and resume or end game
	lw $t2, LIVES
	addi $t2, $t2, -1
	sw $t2, LIVES
	
	# Check if user has zero, one, or two lives left
	beq $t2, 2, lost_one_life
	beq $t2, 1, lost_two_lives
	beq $t2, 0, lost_three_lives
	
# Checks collision with the top (bricks)
check_top_collision:

	lw $t1, BALL + 4		# load in the y-coordinate of the ball
	
	# If y is greater than 7, then there is no collision
	bgt $t1, 7, no_collision
	
	# Produce sound when the ball collides with the wall
	li $a0, 81
 	li $a1, 50
 	li $a2, 25
 	li $a3, 30
 	li $v0, 31
 	syscall
 	
	# Change the direction of the y-vector to 1 (down) since wall is hit
	li $t2, 1
	sw $t2, BALL + 12
	
	jr $ra

# Checks collision with the right wall
check_right_collision:

	la $t1, BALL
	lw $t1, 0($t1)			# load the x-coordinate of the ball
	
	# If x is less than 59, then there is no collision with right wall
	blt $t1, 59, no_collision
	
	# Produce sound when the ball collides with the wall
	li $a0, 81
 	li $a1, 50
 	li $a2, 25
 	li $a3, 30
 	li $v0, 31
 	syscall
 	
 	
	# Change the direction of the x to left (-1) after hitting right wall
	li $t1, -1
	sw $t1, BALL + 8
	
	jr $ra
	
# Checks collision with the left wall
check_left_collision:

	la $t1, BALL
	lw $t1, 0($t1)			# Load the x-coordinate of the ball
	
	# If x is greater than 4, than there is no collision with left wall
	bgt $t1, 4, no_collision
	
	# Produce sound when the ball collides with the wall
	li $a0, 81
 	li $a1, 50
 	li $a2, 25
 	li $a3, 60
 	li $v0, 31
 	syscall
 	
	
	# If collision with left wall, change x direction to 1 (right)
	li $t1, 1 
	sw $t1, BALL + 8
	
	jr $ra	
	
# --- Check if the ball is on the paddle and decide on direction when hit ---
check_paddle:

	lw $s0, BALL			# load in the x-coordinate of the ball			
	lw $s1, BALL + 4		# load in the y-coordinate of the ball
	
	# Load the paddle dimensions
	lw $s2, PADDLE_POSITION		# load in the paddle x-coordinate
	li $s3, 30 	   	    	# load in the pre-set paddle y-coordinate (set at 30 units)
	
	lw $s4 PADDLE_POSITION + 8  	# load in the paddle length
	addi $s4, $s4, -1		# subtract 1 since the length is off by 1
	
	# Paddle end = paddle starting position + length
	add $s4, $s4, $s2       
	
	# Get the middle of the paddle which is the third unit
	li $s5, 3
	add $s5, $s5, $s2		# second middle point of paddle
	addi $t7, $s5, -1		# subtract 1 to get first middle point of paddle
		
	# Check if the ball is on the paddle and if the y-coord are equal
	bne $s1, $s3, no_collision 
	
	# Check if the ball is on one of the middle points of the paddle
	beq $s0, $s5, ball_middle
	beq $s0, $t7, ball_middle
	
        # Check that the ball is on the left side of the paddle (less than middle, but greater than starting position)
	bgt $s0, $s4, check_ball_left 
	blt $s0, $s5, check_ball_left 
	
		
	# Produce sound when the ball hits the paddle
	li $a0, 69
 	li $a1, 100
 	li $a2, 5
 	li $a3, 30
 	li $v0, 31
 	syscall
 	
	# Ball is on right side of paddle so change vector to go to the right 
	li $t0, 1
	sw $t0, BALL + 8
	li $t1, -1
	sw $t1, BALL + 12
	
	jr $ra
	
# Ball is on the middle of the paddle
ball_middle:
	
	# Produce sound when the ball hits the paddle
	li $a0, 69
 	li $a1, 100
 	li $a2, 5
 	li $a3, 60
 	li $v0, 31
 	syscall

	# Change the vector so the ball goes directly up (x-direction is 0)
	li $t0, 0
	sw $t0, BALL + 8
	li $t1, -1
	sw $t1, BALL + 12
	
	jr $ra
	
# Check if ball is on the left of the paddle
check_ball_left:
	
	# Make sure ball is on the left side of the paddle
	bge $s0, $s4, no_collision
	blt $s0, $s2, no_collision
	
		
	# Produce sound when the ball hits the paddle
	li $a0, 69
 	li $a1, 100
 	li $a2, 5
 	li $a3, 60
 	li $v0, 31
 	syscall
	
	# Change the vector of the y so it goes up (-1) and x so it goes left (-1)
	li $t0, -1
	sw $t0, BALL + 8
	li $t1, -1
	sw $t1, BALL + 12
	
	jr $ra
	
# No collision 
no_collision:
    jr $ra
	
# 5. -------------------- END COLLISION CHECKING -------------------- # 

# 6. -------------------- BRICK COLLISION CHECKING -------------------- #
check_ball_brick_collision:

	# Stack 
	addi $sp, $sp, -12
	sw $s0, 0($sp)	
	sw $s1, 4($sp)
	sw $ra, 8($sp) 

	lw $s0, BALL	        # load in the x-coord
	lw $t0, BALL + 8	# load in the x-direction
	add $a0, $s0, $t0	# $a0 = x-coord + x-direction
	
	lw $t1, BALL + 12	# load in the y-direction
	lw $s1, BALL + 4        # load in the y-coord
	add $a2, $s1, $t1 	# $a2 = y-coord + y-direction
	
	# Obtain the address and store it in $a0 
	jal get_address
	lw $t3, 0($v0)
        move $a0, $t3
 
	# Check if the next position is a brick so we know to change it
	beq $t3, 0x00ff00, brick_hit 
	beq $t3, 0xff0000, brick_hit
	beq $t3, 0xffff00, brick_hit
	beq $t3, 0x0000ff, brick_hit_once	# blue bricks must be hit twice
	beq $t3, 0x6C3483, unbreakable		# unbreakable brick

# If no brick, or unbreakable brick was hit, do nothing
finished_unbreakable:

	# Stack
	lw $s0, 0($sp)
	lw $s1, 4($sp)
	lw $ra, 8($sp)
	addi $sp, $sp, 12
	jr $ra
     
# --- Function to delete bricks ---
# $a0 = x coordinate of the brick
# $a1 = color of brick
# $a2 = y coordinate of the brick
delete_brick:

	# Stack
	addi $sp, $sp -4
	sw $ra, 0($sp)
	
	# Get the display location
	jal get_address
	addi $a0, $v0, 0		# $a0 = address
	
	# Bricks are 4 units wide
	li $t0, 0			# i = 0
	li $t1, 4			# $t1 = 4
	lw $t3, MY_COLORS + 36		# load in pink for the animation
	
	addi $s7, $a0, 0
	
	# Draw the brick pink to start
	draw_bricks_loop:
	beq $t0, $t1, end_animation	
		sw $t3, 0($s7)	     # draw the unit of the brick
		addi $s7, $s7, 4     # go to the next unit
		addi $t0, $t0, 1
		b draw_bricks_loop
		
# Delete (draw brick black)
end_animation:

	# Stack
	addi $sp, $sp -4
	sw $v0, 0($sp)
	
	# SLEEP (so animation can be seen)
	li $v0, 32
	li $a0, 35
	syscall
	#SLEEP
	
	lw $v0, 0($sp)
	addi $sp, $sp, 4
	
	li $t0, 0 		     # i = 0
	
	# Redraw the brick black
	addi $t2, $s7, -16
	
	redraw_brick_loop:
	beq $t0, $t1, draw_brick_end	
		sw $a1, 0($t2)	     # draw the unit of the brick
		addi $t2, $t2, 4     # go to the next unit
		addi $t0, $t0, 1
		b redraw_brick_loop
	
draw_brick_end:

	# Stack
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra

# Brick has been hit so delete it and change the position of the ball
brick_hit:

	# Stack
        addi $sp, $sp -4
        sw $ra, 0($sp)
        
        # Add the sound when a brick is hit
        li $a0, 57
	li $a1, 100
	li $a2, 114
	li $a3, 80
	li $v0, 31
	syscall
	
	# Calculate the next position of the ball
	lw $t5, BALL	        # load in the x-coordinate
	lw $t7, BALL + 8	# load in the x direction of the ball 
	add $a0, $t5, $t7	# $a0 = x-coord + x-direction
	
	lw $t8, BALL + 12	# load in the y-direction
	lw $t6, BALL + 4        # load in the y-coordinate
	add $a2, $t6, $t8 	# $a2 = y-coord + y-direction
	
	# Change the last two digits to 0 so the deleted brick address is correct
	srl $a0, $a0, 2
	sll $a0, $a0, 2
		
	lw $a1, MY_COLORS + 28	# load in black to delete the brick
	
	jal delete_brick
	
	# Increase the number of bricks deleted by 1 and check if all bricks have been removed
	lw $t8, DELETED
	addi $t8, $t8, 1
	sw $t8, DELETED
	li $t7, 28
	beq $t8, $t7, victory_sound
	
	# Check current direction of the ball to change it to either up or down
        lw $t1, BALL + 12
        beq $t1, -1, going_up
        beq $t1, 1, going_down
        
done_brick_hit:   
 
	# Stack
        lw $ra, 0($sp)
        addi $sp, $sp, 4
	jr $ra

# Ball was previosuly going up
going_up:

	# Change its vector to going down
	li $t0, 1
	sw $t0, BALL + 12
	j done_brick_hit
	
# Ball was previously going down
going_down:

	# Change its vector to going up
        li $t0, -1
	sw $t0, BALL + 12
	j done_brick_hit
	
# Unbreakable brick has been hit
unbreakable: 

	# Check current direction of the ball to change it to either up or down
        lw $t0, BALL + 12
        beq $t0, -1, unbreakable_going_up
        beq $t0, 1, unbreakable_going_down
        
unbreakable_going_up:

	# The ball was previously going up, so change its vector to going down
	li $t0, 1
	sw $t0, BALL + 12
	j finished_unbreakable
	
unbreakable_going_down:

	# The ball was previously going down, so change its vector to going up
        li $t0, -1
	sw $t0, BALL + 12
	j finished_unbreakable
	
hit_once_going_up:

	# The ball was previously going up, so change its vector to going down
	li $t0, 1
	sw $t0, BALL + 12
	j done_hit_once
	
hit_once_going_down:

	# The ball was previously going down, so change its vector to going up
        li $t0, -1
	sw $t0, BALL + 12
	j done_hit_once
       
# If the blue bricks are hit, change color of brick to yellow
brick_hit_once:

	# Stack
        addi $sp, $sp -4
        sw $ra, 0($sp)
        
        # Sound for when bricks are hit
        li $a0, 57
	li $a1, 100
	li $a2, 114
	li $a3, 80
	li $v0, 31
	syscall
	
	# Calculate the next position of the ball
	lw $t5, BALL	        # load in the x-coordinate
	lw $t7, BALL + 8	# load in the x direction of the ball 
	add $a0, $t5, $t7	# $a0 = x-coord + x-direction
	
	lw $t8, BALL + 12	# load in the y-direction
	lw $t6, BALL + 4        # load in the y-coordinate
	add $a2, $t6, $t8 	# $a2 = y-coord + y-direction
	
	# Change the last two digits to 0 so the deleted brick address is correct
	srl $a0, $a0, 2
	sll $a0, $a0, 2
		
	lw $a1, MY_COLORS + 4	# load in yellow
        
	jal delete_brick
	
	# Check current direction of the ball to change it to either up or down
        lw $t1, BALL + 12
        beq $t1, -1, hit_once_going_up
        beq $t1, 1, hit_once_going_down
	
done_hit_once:
	# Stack
        lw $ra, 0($sp)
        addi $sp, $sp, 4
	j skip_collision
	
# 6. -------------------- END BRICK COLLISION CHECKING -------------------- #

# Get the address of the unit to display (x, y) and return it as $v0
# a0 = x-coord (in units)
# a2 = y-coord (in units)
get_address:

	sll $a0, $a0, 2		# multiply by 4 for x-bytes
	sll $a2, $a2, 8		# multiply by 256 for y-bytes since 64 units = 64 * 4 = 256 bytes
	
	lw $v0, ADDR_DSPL
	add $v0, $v0, $a0	# add x-bytes to base address
	add $v0, $v0, $a2	# add y-bytes to base adress and x-bytes
	
    jr $ra		
    
    
# Sound that plays when the player wins
victory_sound:

	li $a0, 60
 	li $a1, 500
 	li $a2, 80
 	li $a3, 30
 	li $v0, 33
 	syscall
 
 	li $a0, 64
 	li $a1, 500
 	li $a2, 80
 	li $a3, 30
 	li $v0, 33
 	syscall
 
 	li $a0, 67
 	li $a1, 500
 	li $a2, 80
 	li $a3, 30
 	li $v0, 33
 	syscall
 	
 	j quit
