`default_nettype none
`timescale 1ns/1ps

module tt_um_vga_example_tb;
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

        // Wait for 2 frames (shorter simulation time)
        repeat(525*800*2) @(posedge clk);

        $display("Simulation completed successfully");
        $finish;
    end

    // Monitor and dump waves
    initial begin
        $dumpfile("tb.vcd");
        $dumpvars(0, tt_um_vga_example_tb);
    end

endmodule
