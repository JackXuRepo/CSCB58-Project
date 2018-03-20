// From: https://github.com/felixmo/Pong

/*
Pong clone for the Altera DE2.

Copyright (c) 2014 Felix Mo.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
*/

// horizontal 
`define ha 112		// duration of pulse to VGA_HSYNC signifying end of row of data
`define hb 248		// back porch
`define hc 1280		// horizontal screen size (px)
`define hd 48		// front porch

// vertical
`define va 3		// duration of pulse to VGA_HSYNC signifying end of row of data
`define vb 38		// back porch
`define vc 1024		// vertical screen size (px)
`define vd 1		// front porch

// Ball and bat size & speed parameters
`define ballsize   16
`define ballspeed  3
`define batwidth   16
`define batheight  128
`define batspeed   10
`define gap        10

// top level module of the program.
module AirPong(
	CLOCK_50,
	CLOCK2_50,
	KEY,
	SW,
	VGA_R,
	VGA_G,
	VGA_B,
	VGA_CLK,
	VGA_BLANK,
	VGA_HS,
	VGA_VS,
	VGA_SYNC,
	TD_RESET,
	LEDR,
	HEX0,
	HEX1,
	HEX2,
	HEX3,
	HEX4,
	HEX5,
	HEX6,
	HEX7);
	
	input CLOCK_50, CLOCK2_50;
	input [3:0] KEY;
	input [17:0] SW;
	output [9:0] VGA_R, VGA_G, VGA_B;
	output VGA_CLK, VGA_BLANK, VGA_HS, VGA_VS, VGA_SYNC;
	output TD_RESET;
	output [17:0] LEDR;
	output [6:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5, HEX6, HEX7;

	wire video_clock;

	// convert CLOCK2_50 to requred clock speed
	// modified 50 MHz PLL from: https://github.com/chiusin97525/Game-Console
	pll50MHz pll(.inclk0(CLOCK2_50), .c0(video_clock));

	assign VGA_CLK = video_clock;
	assign VGA_SYNC = 0;

	wire ball_on;

	// Location of pixel to draw
	wire [10:0] x;
	wire [10:0] y;
	// Bats locations
	wire [10:0] p1_y;
	wire [10:0] p2_y;
	// Ball location
	wire [10:0] ball_x;
	wire [10:0] ball_y;

	// Scores
	wire [3:0] p1_score;
	wire [3:0] p2_score;
	wire [1:0] winner;				// 0 = none, 1 = P1, 2 = P2
	assign LEDR[17] = (winner > 0);	// light up LEDR-17 to alert user to reset game

	// VGA output module
	vga v(
		.clk(video_clock),
		.vsync(VGA_VS),
		.hsync(VGA_HS),
		.x(x),
		.y(y),
		.can_draw(candraw),
		.start_of_frame(start)
		);

	// Module that renders graphics on-screen 
	graphics g(
		.clk(video_clock),
		.candraw(candraw),
		.x(x),
		.y(y),
		.p1_y(p1_y),
		.p2_y(p2_y),
		.ball_on(ball_on),
		.ball_x(ball_x),
		.ball_y(ball_y),
		.red(VGA_R),
		.green(VGA_G),
		.blue(VGA_B),
		.vga_blank(VGA_BLANK),
        .pause(SW[0])
		);
	
	// Game logic module
	gamelogic gl(
		.clock50(CLOCK_50),
		.video_clock(video_clock),
		.start(start),
		.reset(SW[17]),
		.p1_up(~KEY[3]),
		.p1_down(~KEY[2]),
		.p2_up(~KEY[1]),
		.p2_down(~KEY[0]),
		.p1_y(p1_y),
		.p2_y(p2_y),
		.ball_on(ball_on),
		.ball_x(ball_x),
		.ball_y(ball_y),
		.p1_score(p1_score),
		.p2_score(p2_score),
		.winner(winner),
        .pause(SW[0]),
        .powerup({SW[4], SW[3], SW[2], SW[1]})
		);

	// REPLACE THIS
	// Module to output info to the seven-segment displays
	sevenseg ss(
		.seg0(HEX0),
		.seg1(HEX1),
		.seg2(HEX2),
		.seg3(HEX3),
		.seg4(HEX4),
		.seg5(HEX5),
		.seg6(HEX6),
		.seg7(HEX7),
		.score_p1(p1_score),
		.score_p2(p2_score),
		.winner(winner)
		);

endmodule

// Module that renders graphics on-screen 
// Draws objects pixel by pixel
module graphics(
	clk,
	candraw,
	x,
	y,
	p1_y,
	p2_y,
	ball_on,
	ball_x,
	ball_y,
	red, 
	green, 
	blue,
	vga_blank,
    pause
	);

	input clk;
	input candraw;
	input ball_on;
    input pause;
	input [10:0] x, y, p1_y, p2_y, ball_x, ball_y;
	output reg [9:0] red, green, blue;
	output vga_blank;
	
	reg n_vga_blank;
	assign vga_blank = !n_vga_blank;
	
	always @(posedge clk) begin
		if (candraw) begin
			n_vga_blank <= 1'b0;
            
            // draw pause symbol when paused
            if (pause && x > 500 && x < 550 && y > 500 && y < 550) begin
                    // random square: FIX THIS
					red <= 10'b1111111111;
					green <= 10'b0000000000;
					blue <= 10'b0000000000;
			end
			// draw P1 (left) bat
			if (x < `batwidth + `batwidth+`gap && x > `batwidth+`gap &&  y > p1_y && y < p1_y + `batheight) begin
					// white bat
					red <= 10'b1111111111;
					green <= 10'b0000000000;
					blue <= 10'b0000000000;
			end
			// draw P2 (right) bat
			else if (x > `hc - (`batwidth + `batwidth + `gap) && x < `hc - (`batwidth + `gap) && y > p2_y && y < p2_y + `batheight) begin
					// white bat
					red <= 10'b0000000000;
					green <= 10'b0000000000;
					blue <= 10'b1111111111;
			end
			// draw ball
			else if (ball_on && x > ball_x && x < ball_x + `ballsize && y > ball_y && y < ball_y + `ballsize) begin
					// white ball
					red <= 10'b1111111111;
					green <= 10'b1111111111;
					blue <= 10'b1111111111;
			end
			// Draw upper left wall
			else if (x < `batwidth && y > 0 && y < `vc/3) begin
					// pink wall
					red <= 10'b1111111111;
					green <= 10'b0000000000;
					blue <= 10'b1111111111;
			end
			// Draw lower left wall
			else if (x < `batwidth && y > (`vc/3 + `vc/3) && y < `vc) begin
					// green wall
					red <= 10'b0000000000;
					green <= 10'b1111111111;
					blue <= 10'b0000000000;
			end
			// Draw upper right wall
			else if (x > `hc - `batwidth && y > 0 && y < `vc/3) begin
					// pink wall
					red <= 10'b1111111111;
					green <= 10'b0000000000;
					blue <= 10'b1111111111;
			end
			// Draw lower right wall
			else if (x > `hc - `batwidth && y > (`vc/3 + `vc/3) && y < `vc) begin
					// green wall
					red <= 10'b0000000000;
					green <= 10'b1111111111;
					blue <= 10'b0000000000;
			end
			// black background
			else begin
					red <= 10'b0000011111;
					green <= 10'b0000011111;
					blue <= 10'b0000011111;
			end
		end else begin
			// if we are not in the visible area, we must set the screen blank
			n_vga_blank <= 1'b1;
		end
	end
endmodule 


// VGA output module
// Controls the output parameters
// Credit: https://www.cl.cam.ac.uk/teaching/1011/ECAD+Arch/files/params.sv
module vga(
	clk,
	vsync,
	hsync,
	x,
	y,
	can_draw,
	start_of_frame
	); 
	
	input clk;
	output vsync, hsync;
	output [10:0] x, y;
	output can_draw;
	output start_of_frame;

	assign x = h - `ha - `hb;
	assign y = v - `va - `vb;
	assign can_draw = (h >= (`ha + `hb)) && (h < (`ha + `hb + `hc))
				   && (v >= (`va + `vb)) && (v < (`va + `vb + `vc));
	assign vsync = vga_vsync;
	assign hsync = vga_hsync;
	assign start_of_frame = startframe;

	// horizontal and vertical counts
	reg [10:0] h;
	reg [10:0] v;
	reg vga_vsync;
	reg vga_hsync;
	reg startframe;
	
	always @(posedge clk) begin
	    // if we are not at the end of a row, increment h
		if (h < (`ha + `hb + `hc + `hd)) begin
			h <= h + 11'd1;
		// otherwise set h = 0 and increment v (unless we are at the bottom of the screen)
		end else begin
			h <= 11'd0;
			v <= (v < (`va + `vb + `vc + `vd)) ? v + 11'd1 : 11'd0;
		end
		vga_hsync <= h > `ha;
		vga_vsync <= v > `va;
		
		startframe <= (h == 11'd0) && (v == 11'd0);
	end
endmodule 


// Counter for incrementing/decrementing bat position within bounds of screen
module batpos(
	clk,
	up,
	down,
	reset,
	speed,
	value,
	mode,
    pause
	);

	input clk;
	input up, down;				// signal for counting up/down
	input [4:0] speed;			// # of px to increment bats by
	input reset, mode, pause;
	output [10:0] value;		// max value is 1024 (px), 11 bits wide
	
	reg [10:0] value;
	
	initial begin
		value <= `vc / 2;
	end
	
	always @ (posedge clk or posedge reset or posedge mode) begin
		if (reset || mode) begin
			// go back to the middle
			value <= `vc / 2;
		end
		else if (! pause) begin
			if (up) begin
				// prevent bat from going beyond upper bound of the screen
				if ((value - speed) > `va) begin
					// move bat up the screen
					value <= value - speed;
				end
			end
			else if (down) begin
				// prevent bat from going beyond lower bound of the screen
				if ((value + speed) < (`vc - `batheight)) begin
					// move bat down the screen
					value <= value + speed;
				end
			end
		end
	end

endmodule


// Module with counters that determine the ball position
module ballpos(
	clk,
	reset,
	speed,
	dir_x,		// 0 = LEFT, 1 = RIGHT
	dir_y,		// 0 = UP, 1 = DOWN
	value_x,
	value_y,
	mode,
    pause,
    powerup,
	powerup_x,
	powerup_y
	);

	input clk;
	input [4:0] speed;					// # of px to increment bat by
	input reset, mode, pause, powerup, powerup_x, powerup_y;
	input dir_x, dir_y;
	output [10:0] value_x, value_y;		// max value is 1024 (px), 11 bits wide
	
	reg [10:0] value_x, value_y;
	reg [10:0] multiplier_x, multiplier_y;
		
	
	
	// the initial position of the ball is at the top of the screen, in the middle,
	initial begin
		value_x <= `hc / 2 - (`ballsize / 2);
		value_y <= `va + 7;
	end
	
	always @ (posedge clk or posedge reset or posedge mode) begin	
		if (reset || mode) begin
			value_x <= `hc / 2 - (`ballsize / 2);
			value_y <= `va + 7;
			multiplier_x <= 0;
			multiplier_y <= 0;
			
		end
		else if (! pause) begin
			// increment x
//			if(powerup == 4'b0001) begin
//				multiplier = 10'b0000000001;
//			end
//			else begin
//				multiplier = 10'b0000000000;
//			end

			// Increase horizontal speed
			if(powerup_x == 1) begin
				multiplier_x = 10'b0000000010;
			end
			else begin
				multiplier_x = 10'b0000000000;
			end
			
			// increase vertical speed
			if(powerup_y == 1) begin
				multiplier_y = 10'b0000000010;
			end
			else begin
				multiplier_y = 10'b0000000000;
			end
			
			if (dir_x) begin
				// right 
				value_x <= value_x + speed + multiplier_x;
			end
			else begin
				// left
				value_x <= value_x - speed - multiplier_x;
			end
			
			// increment y
			if (dir_y) begin
				// down
				value_y <= value_y + speed + multiplier_y;
			end
			else begin
				// up
				value_y <= value_y - speed - multiplier_y;
			end
		end
	end

endmodule

// Ball collision detection module
// Detects collisions between the ball and the bats and walls and
// determines what direction the ball should go
module ballcollisions(
	clk,
	reset,
	p1_y,
	p2_y,
	ball_x,
	ball_y,
	dir_x,
	dir_y,
	oob,// whether ball is out of bounds
	powerup_x_active,
	powerup_y_active
	);
	
	input clk, reset;
	input [10:0] p1_y, p2_y, ball_x, ball_y;
	output dir_x, dir_y, oob, powerup_x_active, powerup_y_active;
		
	reg dir_x, dir_y, oob, powerup_x_active, powerup_y_active;
	initial begin
		dir_x <= 0;
		dir_y <= 1;
		oob <= 0;
		powerup_x_active <= 0;
		powerup_y_active <= 0;
	end
		
	always @ (posedge clk) begin
		if (reset) begin
			dir_x <= ~dir_x;	// alternate starting direction every round
			dir_y <= 1;
			oob <= 0;
		end
		else begin
			// out of bounds (i.e. one of the players missed the ball)
			if (ball_x <= 0 || ball_x >= `hc) begin
				oob = 1;
			end
			else begin
				oob = 0;
			end
			
			// collision with top & bottom walls
			if (ball_y <= `va + 5) begin
				dir_y = 1;
			end
			if (ball_y >= `vc - `ballsize) begin
				dir_y = 0;
				//powerup_y_active = 1;
			end
			
			// collision with P1 bat
			if (ball_x <= `batwidth + `batwidth + `gap && ball_y + `ballsize >= p1_y && ball_y <= p1_y + `batheight) begin
			
				dir_x = 1;	// reverse direction
				powerup_x_active = 0;
				if (ball_y + `ballsize <= p1_y + (`batheight / 2)) begin
					// collision with top half of p1 bat, go up
					dir_y = 0;
				end
				else begin
					// collision with bottom half of p1 bat, go down
					dir_y = 1;
				end
			end
			// collision with P2 bat
			else if (ball_x >= `hc - `batwidth - `batwidth- `gap -`ballsize && ball_y + `ballsize <= p2_y + `batheight && ball_y >= p2_y) begin
				
				dir_x = 0;	// reverse direction
				powerup_x_active = 0;
				if (ball_y + `ballsize <= p2_y + (`batheight / 2)) begin
					// collision with top half of p2 bat, go up
					dir_y = 0;
				end
				else begin
					// collision with bottom half of p bat, go down
					dir_y = 1;
				end
			end
			// collision with left upper wall
			else if (ball_x <= `batwidth && ball_y + `ballsize <= `vc/3) begin
			
				dir_x = 1;	// reverse direction
				powerup_x_active = 1;
				if (ball_y + `ballsize <= `vc/6) begin
					// collision with top half of p1 bat, go up
					dir_y = 0;
				end
				else begin
					// collision with bottom half of p1 bat, go down
					dir_y = 1;
				end
			end
			// collision with left lower wall
			else if (ball_x <= `batwidth && ball_y + `ballsize <= `vc && ball_y + `ballsize >= `vc * 2/3) begin
			
				dir_x = 1;	// reverse direction
				powerup_x_active = 1;
				if (ball_y + `ballsize <= `vc * 5/6 && ball_y + `ballsize >= `vc * 4/6) begin
					// collision with top half of p1 bat, go up
					dir_y = 0;
				end
				else begin
					// collision with bottom half of p1 bat, go down
					dir_y = 1;
				end
			end
			// collision with right upper wall
			else if (ball_x + `ballsize >= `hc - `batwidth && ball_y + `ballsize <= `vc/3) begin
			
				dir_x = 0;	// reverse direction
				powerup_x_active = 1;
				if (ball_y + `ballsize <= `vc/6) begin
					// collision with top half of p1 bat, go up
					dir_y = 0;
				end
				else begin
					// collision with bottom half of p1 bat, go down
					dir_y = 1;
				end
			end
			// collision with right lower wall
			else if (ball_x + `ballsize >= `hc - `batwidth && ball_y + `ballsize <= `vc && ball_y + `ballsize >= `vc * 2/3) begin
			
				dir_x = 0;	// reverse direction
				powerup_x_active = 1;
				if (ball_y + `ballsize <= `vc * 5/6 && ball_y + `ballsize >= `vc * 4/6) begin
					// collision with top half of p1 bat, go up
					dir_y = 0;
				end
				else begin
					// collision with bottom half of p1 bat, go down
					dir_y = 1;
				end
			end
		end
	end
	
endmodule

// Game logic module
// Produces the data for output (VGA & HEX) given our inputs
module gamelogic(
	clock50,
	video_clock,
	start,
	reset,	
	p1_up,
	p1_down,
	p2_up,
	p2_down,
	p1_y,
	p2_y,
	ball_on,
	ball_x,
	ball_y,
	p1_score,
	p2_score,
	winner,
    pause,
    powerup
	);
	
	input clock50;
	input reset;
	input video_clock;
	input start;
	input p1_up, p1_down, p2_up, p2_down;
    input pause;
    input powerup;
	output [10:0] p1_y, p2_y;
	output [10:0] ball_x, ball_y;
	output ball_on;
	output [3:0] p1_score, p2_score;
	output [1:0] winner;
	
	reg [3:0] p1_score, p2_score;	// 0 - 10
	initial begin
		p1_score <= 4'b0;
		p2_score <= 4'b0;
	end
	
	reg [1:0] winner;	// 0 = none, 1 = P1, 2 = P2
	initial begin
		winner <= 0;
	end
	
	reg ball_on;
	initial begin
		ball_on <= 1;
	end
	
	wire dir_x;		// 0 = LEFT, 1 = RIGHT
	wire dir_y;		// 0 = UP, 1 = DOWN
	wire powerup_x;
	wire powerup_y;
	wire outofbounds;
	reg newround;
	
	reg [25:0] count_sec;
	reg [1:0] count_secs;
	always @ (posedge clock50) begin
		if (outofbounds) begin
			ball_on = 0;
			
			// Second counter
			if (count_sec == 26'd49_999_999) begin
				// 50,000,000 clock cycles per second since we're using CLOCK_50 (50 MHz)
				count_sec = 26'd0;
				count_secs = count_secs + 1;
			end
			else begin
				// Increment every clock cycle
				count_sec = count_sec + 1;
			end
			
			// 3 secs after ball is out of bounds
			if (count_secs == 3) begin
			
				// Increment the score on the first clock cycle
				// We need to check for this so the score is only incremented ONCE
				if (count_sec == 26'd1) begin
					if (dir_x) begin
						// Out of bounds on the right
						p1_score = p1_score + 1;
					end
					else begin
						// Out of bounds on the left
						p2_score = p2_score + 1;
					end	
				end
				
				// Check if someone has won
				if (p1_score == 4'd10) begin
					winner = 1;
				end
				else if (p2_score == 4'd10) begin
					winner = 2;
				end
				
				// New round
				ball_on = 1;
				newround = 1;
			end
		end
		else begin
			if (newround) begin
				newround = 0;
			end
			count_secs = 1'b0;
			count_sec = 26'd0;
			
			if (reset) begin
				p1_score = 0;
				p2_score = 0;
				winner = 0;
			end
		end
	end
	
	// Module for controlling player 1's bat
	batpos b1 (
		.clk(video_clock && start),
		.up(p1_up),
		.down(p1_down),
		.reset(reset),
		.speed(`batspeed),
		.value(p1_y),
        .pause(pause)
		);
		
	// Module for controlling player 2's bat
	batpos b2 (
		.clk(video_clock && start),
		.up(p2_up),
		.down(p2_down),
		.reset(reset),
		.speed(`batspeed),
		.value(p2_y),
        .pause(pause)
		);
		
	// Ball collision detection module
	ballcollisions bcs (
		.clk(video_clock && start && ball_on),
		.reset(reset || newround),
		.p1_y(p1_y),
		.p2_y(p2_y),
		.ball_x(ball_x),
		.ball_y(ball_y),
		.dir_x(dir_x),
		.dir_y(dir_y),
		.oob(outofbounds),
		.powerup_x_active(powerup_x),
		.powerup_y_active(powerup_y)
		);
	
	// Module with counters that determining the ball position
	ballpos bp (
		.clk(video_clock && start && ball_on),
		.reset(reset || newround || (winner > 0)),
		.speed(`ballspeed),
		.dir_x(dir_x),
		.dir_y(dir_y),
		.value_x(ball_x),
		.value_y(ball_y),
        .pause(pause),
        .powerup(powerup),
		.powerup_x(powerup_x),
		.powerup_y(powerup_y)
		);

endmodule


// Module to output info to the seven-segement displays
module sevenseg(seg0, seg1, seg2, seg3, seg4, seg5, seg6, seg7, score_p1, score_p2, winner);
	input [3:0] score_p1, score_p2;								
	input [1:0] winner;												// 0 = none, 1 = P1, 2 = P2
	output [6:0] seg0, seg1, seg2, seg3, seg4, seg5, seg6, seg7;
	
	reg [6:0] seg0, seg1, seg2, seg3, seg4, seg5, seg6, seg7;
	
	always @ (score_p1 or winner) begin
	
		if (winner > 0) begin
			// Show the winner on HEX7 and HEX6 (i.e. P1 or P2)
			seg7 = 7'b0001100;				// P
			case (winner)
				2'h1: seg6 = 7'b1111001;	// 1
				2'h2: seg6 = 7'b0100100;	// 2
				default: seg6 = 7'b1111111;
			endcase
		end
		else begin
			seg7 = 7'b1111111;
			case (score_p1)
					4'h0: seg6 = 7'b1000000;
					4'h1: seg6 = 7'b1111001; 
					4'h2: seg6 = 7'b0100100; 
					4'h3: seg6 = 7'b0110000; 
					4'h4: seg6 = 7'b0011001; 	
					4'h5: seg6 = 7'b0010010; 
					4'h6: seg6 = 7'b0000010; 
					4'h7: seg6 = 7'b1111000; 
					4'h8: seg6 = 7'b0000000; 
					4'h9: seg6 = 7'b0011000; 
					default: seg6 = 7'b1111111; 
			endcase
		end
	end
	
	always @ (score_p2 or winner) begin
		if (winner > 0) begin
			// Unused; blank out
			seg5 = 7'b1111111;
			seg4 = 7'b1111111;
		end
		else begin
			seg5 = 7'b1111111;
			case (score_p2)
					4'h0: seg4 = 7'b1000000; 
					4'h1: seg4 = 7'b1111001; 
					4'h2: seg4 = 7'b0100100; 
					4'h3: seg4 = 7'b0110000; 
					4'h4: seg4 = 7'b0011001; 	
					4'h5: seg4 = 7'b0010010; 
					4'h6: seg4 = 7'b0000010; 
					4'h7: seg4 = 7'b1111000; 
					4'h8: seg4 = 7'b0000000; 
					4'h9: seg4 = 7'b0011000; 
					default: seg4 = 7'b1111111; 
			endcase
		end
	end
	
	// Blank out unused displays
	always begin
		seg3 = 7'b1111111;
		seg2 = 7'b1111111;
		seg1 = 7'b1111111;
		seg0 = 7'b1111111;
	end

endmodule
