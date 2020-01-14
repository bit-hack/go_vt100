`default_nettype none
`timescale 1ns / 1ps


// VT100 character rom
module vt100_rom(input [6:0] i_char,
                 input [2:0] i_x,
                 input [3:0] i_y,
                 output reg o_bit);

  reg [7:0] rom_chr [1280];
  initial $readmemh("../vt100_chr.txt", rom_chr);

  wire [10:0] rom_addr = i_y * 128 + i_char; 
  wire [7:0] rom_cell = rom_chr[ rom_addr ];

  always @* begin
    o_bit = rom_cell[ ~i_x ];
  end
endmodule


// 640x480 vga generator
// clk = 25Mhz
module vga_t(input i_clk,
             output reg o_hsync,
             output reg o_vsync,
             output reg [9:0] o_x,
             output reg [9:0] o_y,
             output reg o_blank);

//  Clock Summary 
//    Clock: go_vga|i_Clk | Frequency: 204.60 MHz | Target: 148.15 MHz
// 
//  Device Utilization Summary
//    LogicCells                  : 76/1280
//    PLBs                        : 17/160

  reg x_blank, y_blank;

  always @(posedge i_clk) begin
    if (o_x == 10'd799) begin
      o_x <= 10'd0;
      o_y <= (o_y == 10'd524) ? 10'd0 : (o_y + 10'd1);
    end else begin
      o_x <= o_x + 10'd1;
    end
  end

  always @(posedge i_clk) begin
    x_blank <= (o_x == 10'd639) ? 1 :
               (o_x == 10'd799) ? 0 : x_blank;
  end

  always @(posedge i_clk) begin
    y_blank <= (o_y == 10'd479) ? 1 :
               (o_y == 10'd524) ? 0 : y_blank;
  end

  always @(*) begin
    o_blank = x_blank | y_blank;
  end

  always @(posedge i_clk) begin
    o_hsync <= (o_x == (10'd640 + 10'd18)) ? 0 :
               (o_x == (10'd780 - 10'd50)) ? 1 : o_hsync;
  end

  always @(posedge i_clk) begin
    o_vsync <= (o_y == (10'd480 + 10'd10)) ? 0 :
               (o_y == (10'd525 - 10'd33)) ? 1 : o_vsync;
  end
endmodule


module go_vga(input        i_Clk,
              output       o_VGA_HSync,
              output       o_VGA_VSync,
              output [2:0] o_VGA_R,
              output [2:0] o_VGA_G,
              output [2:0] o_VGA_B,
              input  [3:0] i_Switch);

  wire [9:0] vga_x;
  wire [9:0] vga_y;
  wire vga_blank;

  vga_t vga(i_Clk, o_VGA_HSync, o_VGA_VSync, vga_x, vga_y, vga_blank);

  wire [2:0] rom_x = vga_x[2:0];
  wire [3:0] rom_y = vga_y[3:0];
  wire rom_bit;
  vt100_rom chr_rom(character, rom_x, rom_y, rom_bit);

  assign o_VGA_R = vga_blank ? 3'd0 : (rom_bit ? 3'b111 : 3'b000);
  assign o_VGA_G = vga_blank ? 3'd0 : (rom_bit ? 3'b111 : 3'b000);
  assign o_VGA_B = vga_blank ? 3'd0 : (rom_bit ? 3'b111 : 3'b000);

  reg [6:0] character = 0;
  always @(posedge i_Switch[0]) begin
    character <= character + 7'd1;
  end
endmodule
