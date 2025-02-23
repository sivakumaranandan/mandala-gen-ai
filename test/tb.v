`default_nettype none
`timescale 1ns / 1ps

module tb ();

  // Dump signals to VCD
  initial begin
    $dumpfile("tb.vcd");
    $dumpvars(0, tb);
    #1;
  end

  // Clock generation
  reg clk = 0;
  always #8.33 clk = ~clk; // 60MHz clock (16.67ns period)

  // Test signals
  reg rst_n = 0;
  reg ena = 0;
  reg [7:0] ui_in = 0;
  reg [7:0] uio_in = 0;
  wire [7:0] uo_out;
  wire [7:0] uio_out;
  wire [7:0] uio_oe;

  // Instantiate VGA controller
  tt_um_vga_example vga_test (
    .ui_in(ui_in),
    .uo_out(uo_out),
    .uio_in(uio_in),
    .uio_out(uio_out),
    .uio_oe(uio_oe),
    .ena(ena),
    .clk(clk),
    .rst_n(rst_n)
  );

  // Test stimulus
  initial begin
    // Reset sequence
    #100 rst_n = 0;
    #100 rst_n = 1;
    
    // Enable the module
    #100 ena = 1;
    
    // Let it run for a few frames
    #16_666_667; // Wait for 1 frame (60Hz = 16.67ms)
    
    // Test pattern switching
    ui_in = 8'h01; // Change pattern
    #16_666_667;
    
    ui_in = 8'h02; // Change pattern again
    #16_666_667;
    
    // End simulation
    #1000 $finish;
  end

  // Optional: Monitor outputs
  always @(posedge clk) begin
    if (ena && rst_n) begin
      $display("Time=%0t uo_out=%h", $time, uo_out);
    end
  end

endmodule
