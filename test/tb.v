`timescale 1ns / 1ps

module tb;
    // Testbench signals
    logic clk;
    logic rst_n;
    logic ena;
    logic [7:0] ui_in;
    logic [7:0] uio_in;
    logic [7:0] uo_out;
    logic [7:0] uio_out;
    logic [7:0] uio_oe;

    // VGA timing parameters
    localparam H_DISPLAY = 640;
    localparam H_FRONT = 16;
    localparam H_SYNC = 96;
    localparam H_BACK = 48;
    localparam H_TOTAL = H_DISPLAY + H_FRONT + H_SYNC + H_BACK;
    
    localparam V_DISPLAY = 480;
    localparam V_FRONT = 10;
    localparam V_SYNC = 2;
    localparam V_BACK = 33;
    localparam V_TOTAL = V_DISPLAY + V_FRONT + V_SYNC + V_BACK;

    // Counters for verification
    int hsync_transitions;
    int vsync_transitions;
    int frame_count;
    int pixel_count;
    time last_hsync_time;
    time last_vsync_time;

    // DUT instantiation
    tt_um_vga_example dut (
        .clk(clk),
        .rst_n(rst_n),
        .ena(ena),
        .ui_in(ui_in),
        .uio_in(uio_in),
        .uo_out(uo_out),
        .uio_out(uio_out),
        .uio_oe(uio_oe)
    );

    // Clock generation - 60MHz
    initial begin
        clk = 0;
        forever #8.33 clk = ~clk;
    end

    // Monitor HSYNC/VSYNC transitions and timing
    logic prev_hsync, prev_vsync;
    always @(posedge clk) begin
        if (!rst_n) begin
            hsync_transitions <= 0;
            vsync_transitions <= 0;
            frame_count <= 0;
            pixel_count <= 0;
            prev_hsync <= 0;
            prev_vsync <= 0;
            last_hsync_time <= 0;
            last_vsync_time <= 0;
        end else begin
            // Monitor HSYNC
            if (prev_hsync != uo_out[7]) begin
                hsync_transitions++;
                if (last_hsync_time != 0) begin
                    time hsync_period = $time - last_hsync_time;
                    if (hsync_period != (H_TOTAL * 16.67)) begin
                        $display("HSYNC period error: %t ns (expected %t ns)", 
                                hsync_period, H_TOTAL * 16.67);
                    end
                end
                last_hsync_time = $time;
                pixel_count = 0;
            end else begin
                pixel_count++;
            end
            prev_hsync <= uo_out[7];

            // Monitor VSYNC
            if (prev_vsync != uo_out[3]) begin
                vsync_transitions++;
                if (uo_out[3]) begin
                    frame_count++;
                    $display("Frame %0d completed at time %0t", frame_count, $time);
                end
                if (last_vsync_time != 0) begin
                    time vsync_period = $time - last_vsync_time;
                    if (vsync_period != (V_TOTAL * H_TOTAL * 16.67)) begin
                        $display("VSYNC period error: %t ns (expected %t ns)", 
                                vsync_period, V_TOTAL * H_TOTAL * 16.67);
                    end
                end
                last_vsync_time = $time;
            end
            prev_vsync <= uo_out[3];
        end
    end

    // Test stimulus
    initial begin
        // Initialize
        rst_n = 0;
        ena = 1;
        ui_in = 0;
        uio_in = 0;

        // Reset
        #100 rst_n = 1;
        $display("Reset released at time %0t", $time);

        // Wait for multiple frames
        repeat(3) @(posedge frame_count);
        
        // Check timing
        assert(hsync_transitions >= 2 * V_TOTAL)
            else $error("HSYNC transitions incorrect: got %0d, expected >= %0d", 
                       hsync_transitions, 2 * V_TOTAL);
        assert(vsync_transitions >= 4)
            else $error("VSYNC transitions incorrect: got %0d, expected >= 4", 
                       vsync_transitions);

        // Additional timing checks
        assert(pixel_count <= H_TOTAL)
            else $error("Pixel count per line exceeded: %0d", pixel_count);

        $display("Test completed successfully:");
        $display("  HSYNC transitions: %0d", hsync_transitions);
        $display("  VSYNC transitions: %0d", vsync_transitions);
        $display("  Frames completed: %0d", frame_count);
        
        // End simulation
        #1000 $finish;
    end

    // Timeout watchdog
    initial begin
        #10_000_000;  // 10ms timeout
        $error("Simulation timeout");
        $finish;
    end

    // Waveform dumping
    initial begin
        $dumpfile("tb.vcd");
        $dumpvars(0, tb);
    end

endmodule
