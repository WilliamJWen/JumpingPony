module ponyVGA
	(
		CLOCK_50,						//	On Board 50 MHz
		// Your inputs and outputs here
		KEY,							// On Board Keys
		// The ports below are for the VGA output.  Do not change.
		SW,
		HEX0,
		HEX2,
		VGA_CLK,   						//	VGA Clock
		VGA_HS,							//	VGA H_SYNC
		VGA_VS,							//	VGA V_SYNC
		VGA_BLANK_N,						//	VGA BLANK
		VGA_SYNC_N,						//	VGA SYNC
		VGA_R,   						//	VGA Red[9:0]
		VGA_G,	 						//	VGA Green[9:0]
		VGA_B,   						//	VGA Blue[9:0]
		PS2_CLK, PS2_DAT,
	);

	input			CLOCK_50;				//	50 MHz
	input	[8:0]	KEY;	
	input [9:0] SW;
	output [6:0] HEX0;
	output [6:0] HEX2;
	// Declare your inputs and outputs here
	// Do not change the following outputs
	output			VGA_CLK;   				//	VGA Clock
	output			VGA_HS;					//	VGA H_SYNC
	output			VGA_VS;					//	VGA V_SYNC
	output			VGA_BLANK_N;				//	VGA BLANK
	output			VGA_SYNC_N;				//	VGA SYNC
	output	[7:0]	VGA_R;   				//	VGA Red[7:0] Changed from 10 to 8-bit DAC
	output	[7:0]	VGA_G;	 				//	VGA Green[7:0]
	output	[7:0]	VGA_B;   				//	VGA Blue[7:0]
	
	// For keyboard input and output.
    inout PS2_CLK;
    inout PS2_DAT;
	
	wire resetn;
	assign resetn = SW[9];
	
	wire start;
	assign start = SW[0];
	wire go;
	assign go = SW[0];
	
	
	// Create the colour, x, y and writeEn wires that are inputs to the controller.

	wire [2:0] colour;
	wire [9:0] x;
	wire [8:0] y;
	wire writeEn, decrement, lost;

	// Create an Instance of a VGA controller - there can be only one!
	// Define the number of colours as well as the initial background
	// image file (.MIF) for the controller.
	vga_adapter VGA(
			.resetn(resetn),
			.clock(CLOCK_50),
			.colour(colour),
			.x(x),
			.y(y),
			.plot(writeEn),
			/* Signals for the DAC to drive the monitor. */
			.VGA_R(VGA_R),
			.VGA_G(VGA_G),
			.VGA_B(VGA_B),
			.VGA_HS(VGA_HS),
			.VGA_VS(VGA_VS),
			.VGA_BLANK(VGA_BLANK_N),
			.VGA_SYNC(VGA_SYNC_N),
			.VGA_CLK(VGA_CLK));
		defparam VGA.RESOLUTION = "320x240";
		defparam VGA.MONOCHROME = "FALSE";
		defparam VGA.BITS_PER_COLOUR_CHANNEL = 1;
		defparam VGA.BACKGROUND_IMAGE = "./graphics/black.mif";
			
	// Put your code here. Your code should produce signals x,y,colour and writeEn
	// for the VGA controller, in addition to any other functionality your design may require.
	
	
	// 
	// ps2
	//wire space, enter, move_up, move_down, move_left, move_right;
	
	/*keyboard_tracker #(.PULSE_OR_HOLD(1)) ps2(
         .clock(CLOCK_50),
          .reset(!reset),
          .PS2_CLK(PS2_CLK),
          .PS2_DAT(PS2_DAT),
          .left(move_left),
          .right(move_right),
          .up(move_up),
          .down(move_down),
          .space(space),
          .enter(enter)
       );*/
	
	reg move_up, move_down, move_left, move_right;
		always @(posedge CLOCK_50) begin
		if (!resetn) begin
			move_up <= 1'b0;
		end else begin
		   move_up <= ~KEY[0];
			move_left <= ~KEY[2];
			move_right <= ~KEY[1];
			move_down <= ~KEY[3];
		end
	
	end 
	
	
	wire StartPage, StartWait, GamePage, die_reset;
	wire [3:0]lives;
	wire [3:0] current_state;
	wire startDone, die, win, winPage;
	
	controlpath u0(.clk(CLOCK_50), .resetn(resetn), .go(go),.die(die),.startDone(startDone),
					.StartPage(StartPage), .StartWait(StartWait), .GamePage(GamePage), .writeEn(writeEn), .die_reset(die_reset), .lives(lives), .decrement(decrement), .current_state(current_state), .lost(lost), .win(win), .winPage(winPage));
	datapath data(.clk(CLOCK_50), .resetn(resetn), .writeEn(writeEn), .StartPage(StartPage), .StartWait(StartWait), .GamePage(GamePage), .move_up(move_up), .move_left(move_left), .move_right(move_right), .move_down(move_down),
					.X(x), .Y(y), .CLR(colour), .startDone(startDone), .die(die), .decrement(decrement), .lives(lives), .lost(lost), .win(win), .winPage(winPage));
	
	hex_decoder h0(.c(lives + 1), .display(HEX0[6:0]));
	hex_decoder h1(.c(current_state), .display(HEX2[6:0]));
	
endmodule

module controlpath(input clk, resetn, go, die, startDone, win, input [3:0] lives, output reg lost, winPage, StartPage, StartWait, GamePage, writeEn, die_reset, decrement, output reg [3:0]current_state);

	 
   localparam START_PAGE = 4'b000,
			START_PAGE_WAIT = 4'b001,
			GAME_PAGE = 4'b010,
			WIN = 4'b011,
			DIE = 4'b100,
		   LOSE = 4'b101,
			DECREMENT = 4'b110;
			
			
	reg [3:0] next_state;

 
// Next state logic
	always@(*)
	begin: state_table
        	case (current_state)
				START_PAGE: next_state = (go) ? START_PAGE_WAIT : START_PAGE;
				START_PAGE_WAIT:  next_state = (!go) ? GAME_PAGE : START_PAGE_WAIT;
				GAME_PAGE: begin 
					/*if (win) 
						begin 
						next_state = WIN;
					end else */if (die)
						begin
						next_state = DIE;
					end else if(win)
					begin
						next_state = WIN;
					end
					else
						begin
						next_state = GAME_PAGE;
					end		
				end 
				DIE: next_state = (lives > 4'd0 ) ? GAME_PAGE: LOSE;
				LOSE: next_state = LOSE;
				WIN: next_state = WIN;
				
        	default: next_state = START_PAGE;
			endcase
	end
	// state table end
	
	// Output logic aka all of our datapath control signals
	
	always @(*)
	begin: writeEn_signals
	// By default make all our signals 0
    	//ld_x = 1'b0;
        writeEn = 1'b0; 
		  StartPage = 1'b0;
		  StartWait = 1'b0;
		  die_reset = 1'b0;
		  decrement = 1'b0;
		  lost = 1'b0;
		  winPage = 1'b0;
		  
		//ld_y_c = 1'b0;
		//clearEn = 1'b0;
  
 
		case (current_state)
		   START_PAGE: begin
				StartPage = 1'b1;
				writeEn = 1'b1;
	
			end
			
			START_PAGE_WAIT: begin
				StartWait = 1'b1;
			end
			
			GAME_PAGE: begin
			   writeEn = 1'b1;
				GamePage = 1'b1;
			
			end
			DIE: begin
				decrement = 1'b1;
				end
			
			LOSE: begin
				lost = 1'b1;
				writeEn = 1'b1;
			end
			
			WIN: begin
				winPage = 1'b1;
				writeEn = 1'b1;
			end
			
			
		endcase
	end
// current_state registers
	always@(posedge clk)
	begin: state_FFs
		if(!resetn) begin
			current_state <= START_PAGE;
			//lives <= 4'd5;
			//done <= 1'b0;
				end
		else begin
		 /*if (current_state == DECREMENT) begin
		 lives <= lives-1;
		 end*/
			current_state <= next_state;
		end
	end // state_FFS
		
  
endmodule

module datapath(input clk, resetn, writeEn, StartPage, StartWait, GamePage, move_up, move_left, move_right, move_down, die_reset, decrement, lost, winPage,
 output reg [9:0]X, output reg [8:0]Y, output reg [2:0]CLR, output reg startDone = 1'b0, output reg die = 1'b0, output reg [3:0]lives=4'd5, output reg win = 1'b0);

	reg [9:0] x_bg;
	reg [8:0] y_bg;
	
	wire [16:0] bg_address;
	wire [2:0] color_data, color_gamebg, color_pony, color_log, color_lost, color_win;
	wire enable, enable2;
	reg [2:0] color;
	reg [11:0] pony_address = 0;
	reg [10:0] log_address = 0;
	reg [9:0] x_pony_initial = 10'd50;
	reg [8:0] y_pony_initial = 9'd190;
	reg [9:0] x_log_initial = 10'd0;
	reg [8:0] y_log_initial =  9'd105;
	
	
	vga_address_translator startbg(x_bg, y_bg, bg_address);
	
	
	startbg startbg_inst (
        .address(bg_address),
        .clock(clk),
        .q(color_data)
    );
	 
	gamebg gamebg_inst(
		.address(bg_address),
		.clock(clk),
		.q(color_gamebg)
	);
	
	smallpony1 pony_inst(
		.address(pony_address),
		.clock(clk),
		.q(color_pony)
	);

	log log_inst(
		.address(log_address),
		.clock(clk),
		.q(color_log)
	);
	
	gamelost lost_inst(
		.address(bg_address),
		.clock(clk),
		.q(color_lost)
	);
	
	gameWin win_inst(
		.address(bg_address),
		.clock(clk),
		.q(color_win)
	);
	
	
	//color
	always @(*)
		begin

			if(StartPage)
				begin
					color <= color_data;
				end
			else if(lost)
				begin
					color <= color_lost;
				end
			else if(winPage)
				begin
					color <= color_win;
				end
			else if (x_bg >= x_pony_initial && y_bg >= y_pony_initial && x_bg <= (x_pony_initial + 26) && y_bg <= (y_pony_initial + 28))
			   begin
				   pony_address <= (y_bg - y_pony_initial)*27 + (x_bg - x_pony_initial);
					if (color_pony != 3'b010) begin
					color <= color_pony;
					end
					else if(x_bg >= x_log_initial && y_bg >= y_log_initial && x_bg <= (x_log_initial + 59) && y_bg <= (y_log_initial + 29))begin
					color <= color_log;
					end
					else begin
					color <= color_gamebg;
					end
				end
			else if (x_bg >= x_log_initial && y_bg >= y_log_initial && x_bg <= (x_log_initial + 59) && y_bg <= (y_log_initial + 29))
			   begin
				   log_address <= (y_bg - y_log_initial)*60 + (x_bg - x_log_initial);
					color <= color_log;
				end
			else
				begin
					color <= color_gamebg;
				end
		end
	
	RateDivider #(.CLOCK_FREQUENCY(50000000),.SPEED(0.23)) RD_PONY(.ClockIn(clk), .Enable(enable));
	RateDivider #(.CLOCK_FREQUENCY(50000000), .SPEED(0.17)) RD_LOG(.ClockIn(clk), .Enable(enable2));


	always @(posedge enable)
	   begin
			if (!resetn || die) begin
			x_pony_initial <= 10'd50;
			y_pony_initial <= 9'd175;
			end else begin
				if (move_up && y_pony_initial > 79) begin
					y_pony_initial <= y_pony_initial - 80;
				end
				else if (move_left && x_pony_initial > 10) begin
					x_pony_initial <= x_pony_initial - 10;
				end
				else if (move_right && x_pony_initial < 290) begin
					x_pony_initial <= x_pony_initial + 10;
				end
				else if (move_down && y_pony_initial < 160) begin
					y_pony_initial <= y_pony_initial + 80;
				end
			end
		end
		
	
	always @(posedge enable2)
	   begin
			if (!resetn || die || x_log_initial >= 9'd260) begin
			x_log_initial <= 10'd0;
			y_log_initial <= 9'd105;
			end else begin
			x_log_initial <= x_log_initial + 1;
			end
		end

	
	always @(posedge clk)
		begin
			if(!resetn || StartWait || die_reset)
				begin
					x_bg <= 0;
					y_bg <= 0;
					//lives <= 4'd5;
				end
			else if 
			(StartPage || GamePage || lost || winPage) begin
				if (x_bg == 10'd320 && y_bg != 9'd240) begin
					x_bg <= 0;
					y_bg <= y_bg + 1;
				end
				else if (x_bg == 10'd320 && y_bg == 9'd240) begin
					startDone <= 1'b1;
					x_bg <= 0;
					y_bg <= 0;
				end
				else begin
					x_bg <= x_bg + 1;
				end 
				if (writeEn) begin
				X <= x_bg;
				Y <= y_bg;
				CLR <= color;
				end
				
			end
			
		end
	// GAME LOGIC
		always @(posedge enable)
		begin
			if(!resetn)
				begin
					lives <= 4'd5;
					die <= 0;
					win <= 0;
				end
			else if (66<= y_pony_initial+27 && y_pony_initial + 27 <= 169 && !(x_log_initial <= x_pony_initial+15 && x_pony_initial + 15 <= x_log_initial + 59)) begin
				die <= 1;	
			end
			else if(y_pony_initial + 26 < 66 && x_pony_initial >= 200) begin
				win <= 1;
			end
			else if(decrement) begin
				lives <= lives - 1;
				die <= 1'b0;
			end
		end
endmodule


