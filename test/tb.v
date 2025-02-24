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

`ifdef GL_TEST
    wire VPWR = 1'b1;
    wire VGND = 1'b0;
`endif

    // Instantiate the VGA module
    tt_um_vga_example dut (
`ifdef GL_TEST
        .VPWR(VPWR),
        .VGND(VGND),
`endif
        .clk(clk),
        .rst_n(rst_n),
        .ui_in(ui_in),
        .uio_in(uio_in),
        .ena(ena),
        .uo_out(uo_out),
        .uio_out(uio_out),
        .uio_oe(uio_oe)
    );

    // Dump waves
    initial begin
        $dumpfile("tb.vcd");
        $dumpvars(0, tb);
        #1;
    end

    // Clock generation (25MHz)
    initial begin
        clk = 0;
        forever #20 clk = ~clk;
    end

    // Test stimulus
    initial begin
        // Initialize signals
        rst_n = 0;
        ui_in = 8'h00;
        uio_in = 8'h00;
        ena = 1;

        // Wait 10 clock cycles and release reset
        repeat(10) @(posedge clk);
        rst_n = 1;

        // Wait for 2 frames
        repeat(525*800*2) @(posedge clk);

        $display("Simulation completed successfully");
        $finish;
    end

endmodule
