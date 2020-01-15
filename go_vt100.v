`default_nettype none
`timescale 1ns / 1ps


// 8x1280 rom
//    (~3 SB_RAM40_4K)
module rom_8x1280(input i_clk,
                  input [10:0] i_addr,
                  output reg [7:0] o_data);

  reg [7:0] rom_reg [1280];
  initial $readmemh("../vt100_chr.txt", rom_reg);

  always @(posedge i_clk) begin
    o_data <= rom_reg[i_addr];
  end
endmodule


// VT100 character rom
module vt100_rom(input i_clk,
                 input [6:0] i_char,
                 input [2:0] i_x,
                 input [3:0] i_y,
                 output reg o_bit);

  wire [10:0] rom_addr = i_y * 128 + i_char; 
  wire [7:0] rom_cell;
  rom_8x1280 rom(i_clk, rom_addr, rom_cell);

  always @* begin
    o_bit = rom_cell[ ~i_x ];
  end
endmodule


// VT100 screen buffer
// 8x80x24 = 8x1920
//    (~4 SB_RAM40_4K)
module vt100_sbuffer(input i_clk,
                     input [10:0] i_wr_addr,
                     input [7:0]  i_wr_data,
                     input i_wr,
                     input [10:0] i_rd_addr,
                     output reg [7:0] o_rd_data);

  reg [7:0] scr_ram [ 1920 ];
  initial $readmemh("../vt100_scr.txt", scr_ram);

  always @(posedge i_clk) begin
    if (i_wr) begin
      scr_ram[i_wr_addr] <= i_wr_data;
    end
    o_rd_data <= scr_ram[i_rd_addr];
  end
endmodule


// 640x480 vga generator
// clk = 25Mhz
module vga_t(input i_clk,
             output reg o_hsync,
             output reg o_vsync,
             output reg [9:0] o_x,
             output reg [9:0] o_y,
             output reg [4:0] row_y,
             output reg [4:0] chr_y,
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
    row_y <= (o_y   == 10'd479) ? 0 :
             (row_y ==  5'd19)  ? 0 : (row_y + 5'd1);
  end

  always @(posedge i_clk) begin
    chr_y <= (o_y   == 10'd479) ? 0 :
             (row_y ==  5'd19)  ? (chr_y + 4'd1) : chr_y;
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
  wire [4:0] vga_y_row;              // 2x oversampled
  wire [6:0] vga_x_chr = vga_x[9:3]; // 2x oversampled
  wire [4:0] vga_y_chr;
  wire vga_blank;
  vga_t vga(i_Clk, o_VGA_HSync, o_VGA_VSync, vga_x, vga_y, vga_y_row, vga_y_chr, vga_blank);

  reg [10:0] ram_wr_addr;
  reg [7:0] ram_wr_data;
  reg ram_wr;
  wire [10:0] ram_rd_addr = (vga_y_chr * 80) + vga_x_chr;
  wire [7:0] ram_char;
  vt100_sbuffer scr_ram(i_Clk, ram_wr_addr, ram_wr_data, ram_wr, ram_rd_addr, ram_char);

  wire [2:0] rom_x = vga_x[2:0];
  wire [3:0] rom_y = vga_y_row[4:1];  // upscale 2x
  wire rom_bit;
  // note: we add 3'd1 to the rom_x here so that the rom will look-ahead
  // giving us the correct bits when we need it.
  vt100_rom chr_rom(i_Clk, ram_char[6:0], rom_x + 3'd1, rom_y, rom_bit);

  wire [3:0] rgb = vga_blank ? 3'd0 : (rom_bit ? 3'b111 : 3'b000);
  assign o_VGA_R = rgb;
  assign o_VGA_G = rgb;
  assign o_VGA_B = rgb;
endmodule
