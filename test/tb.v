`default_nettype none
`timescale 1ns/1ps

module tb;
    // Testbench signals
    reg clk;
    reg rst_n;
    reg [7:0] ui_in;
    reg [7:0] uio_in;
    reg ena;
    wire [7:0] uo_out;
    wire [7:0] uio_out;
    wire [7:0] uio_oe;

    // Instantiate the VGA module
    tt_um_vga_example dut (
        .clk(clk),
        .rst_n(rst_n),
        .ui_in(ui_in),
        .uio_in(uio_in),
        .ena(ena),
        .uo_out(uo_out),
        .uio_out(uio_out),
        .uio_oe(uio_oe)
    );

    // Clock generation (25MHz - typical VGA clock)
    initial begin
        clk = 0;
        forever #20 clk = ~clk; // 50MHz clock
    end

    // Test stimulus
    initial begin
        // Initialize signals
        rst_n = 0;
        ui_in = 8'h00;
        uio_in = 8'h00;
        ena = 1;

        // Release reset
        #100;
        rst_n = 1;

        // Wait for multiple frames
        #5000000;

        // End simulation
        $finish;
    end

    // Monitor outputs
    initial begin
        $dumpfile("tt_um_vga_example.vcd");
        $dumpvars(0, tb);
        
        // Monitor VGA signals
        $monitor("Time=%0t rst_n=%b hsync=%b vsync=%b",
                 $time, rst_n, uo_out[7], uo_out[4]);
    end

endmodule
