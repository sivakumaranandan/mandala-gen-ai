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
    localparam H_TOTAL = 800;
    localparam V_TOTAL = 525;

    // Counters for verification
    int hsync_transitions;
    int vsync_transitions;
    int frame_count;

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

    // Monitor HSYNC/VSYNC transitions
    logic prev_hsync, prev_vsync;
    always @(posedge clk) begin
        if (!rst_n) begin
            hsync_transitions <= 0;
            vsync_transitions <= 0;
            frame_count <= 0;
            prev_hsync <= 0;
            prev_vsync <= 0;
        end else begin
            // Monitor HSYNC
            if (prev_hsync != uo_out[7]) begin
                hsync_transitions++;
            end
            prev_hsync <= uo_out[7];

            // Monitor VSYNC
            if (prev_vsync != uo_out[3]) begin
                vsync_transitions++;
                if (uo_out[3]) frame_count++;
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

        // Wait for multiple frames
        repeat(3) @(posedge frame_count);

        // Check timing
        assert(hsync_transitions >= 2 * V_TOTAL)
            else $error("HSYNC transitions incorrect");
        assert(vsync_transitions >= 4)
            else $error("VSYNC transitions incorrect");

        // Test pattern generation
        repeat(1000) @(posedge clk);

        // End simulation
        $finish;
    end

    // Timeout watchdog
    initial begin
        #10_000_000;  // 10ms timeout
        $error("Simulation timeout");
        $finish;
    end

    // Optional: Dump waveforms
    initial begin
        $dumpfile("tb.vcd");
        $dumpvars(0, tb);
    end

endmodule
