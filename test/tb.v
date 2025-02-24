`default_nettype none
`timescale 1ns / 1ps

module tb;
    // Test signals
    reg clk = 0;
    reg rst_n = 0;
    reg ena = 0;
    reg [7:0] ui_in = 0;
    reg [7:0] uio_in = 0;
    wire [7:0] uo_out;
    wire [7:0] uio_out;
    wire [7:0] uio_oe;

    // Monitoring signals
    reg [31:0] frame_count = 0;
    reg [31:0] hsync_count = 0;
    reg prev_vsync = 0;
    reg prev_hsync = 0;

    // Extract VGA signals from output
    wire hsync = uo_out[7];
    wire vsync = uo_out[3];
    wire [1:0] red = {uo_out[0], uo_out[4]};
    wire [1:0] green = {uo_out[1], uo_out[5]};
    wire [1:0] blue = {uo_out[2], uo_out[6]};

    // Clock generation - 60MHz (16.67ns period)
    always #8.33 clk = ~clk;

    // DUT instantiation
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

    // VCD dump
    initial begin
        $dumpfile("tb.vcd");
        $dumpvars(0, tb);
    end

    // Frame and sync counting
    always @(posedge clk) begin
        prev_vsync <= vsync;
        prev_hsync <= hsync;

        // Count frames
        if (vsync && !prev_vsync) begin
            frame_count <= frame_count + 1;
            $display("Frame %d completed", frame_count);
        end

        // Count horizontal syncs
        if (hsync && !prev_hsync) begin
            hsync_count <= hsync_count + 1;
        end
    end

    // Sanity checks
    reg [31:0] expected_hsync_per_frame = 525; // For 640x480@60Hz
    
    // Test sequence
    initial begin
        // Initial state
        rst_n = 0;
        ena = 0;
        ui_in = 0;
        uio_in = 0;

        // Reset sequence
        #100;
        rst_n = 1;
        #100;
        ena = 1;

        // Wait for 5 frames
        wait(frame_count == 5);
        
        // Basic timing checks
        if (hsync_count/frame_count != expected_hsync_per_frame) begin
            $display("ERROR: Incorrect number of hsync pulses per frame");
            $display("Expected: %d, Got: %d", expected_hsync_per_frame, hsync_count/frame_count);
        end else begin
            $display("PASS: Correct number of hsync pulses per frame");
        end

        // Test different patterns
        ui_in = 8'h55;
        #16_666_667; // Wait one frame

        ui_in = 8'hAA;
        #16_666_667; // Wait one frame

        // Check if colors are changing
        if (red == 2'b00 && green == 2'b00 && blue == 2'b00) begin
            $display("WARNING: All colors are black, possible pattern generation issue");
        end

        // Final checks
        $display("Test completed:");
        $display("Total frames: %d", frame_count);
        $display("Total hsync pulses: %d", hsync_count);
        
        // End simulation
        #1000;
        $finish;
    end

    // Timeout watchdog
    initial begin
        #100_000_000; // 100ms timeout
        $display("ERROR: Simulation timeout");
        $finish;
    end

    // Optional: Color pattern monitoring
    reg [5:0] prev_color = 0;
    reg [5:0] current_color;
    
    always @(posedge clk) begin
        if (ena && rst_n) begin
            current_color = {red, green, blue};
            if (current_color != prev_color) begin
                prev_color <= current_color;
                // Uncomment for detailed color change monitoring
                // $display("Time=%0t Color changed to %b", $time, current_color);
            end
        end
    end

endmodule
