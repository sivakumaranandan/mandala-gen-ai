`default_nettype none
module tt_um_vga_example(
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path
    input  wire       ena,      // always 1
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);
    // VGA Constants
    parameter SCREEN_WIDTH = 640;
    parameter SCREEN_HEIGHT = 480;
    parameter CENTER_X = SCREEN_WIDTH/2;
    parameter CENTER_Y = SCREEN_HEIGHT/2;

    // Animation counter
    reg [9:0] pattern_counter;
    
    always @(posedge vsync) begin
        if (~rst_n)
            pattern_counter <= 0;
        else
            pattern_counter <= pattern_counter + 1;
    end

    // Calculate radius and angle for simple pattern
    wire [9:0] delta_x = (pix_x > CENTER_X) ? (pix_x - CENTER_X) : (CENTER_X - pix_x);
    wire [9:0] delta_y = (pix_y > CENTER_Y) ? (pix_y - CENTER_Y) : (CENTER_Y - pix_y);
    wire [19:0] radius = (delta_x * delta_x) + (delta_y * delta_y);
    wire [7:0] angle = (delta_y[7:0] ^ delta_x[7:0]) + pattern_counter[7:0];

    // Simple black and white pattern
    wire pattern = (radius < 40000) & angle[4];

    // Assign black or white (all RGB bits either 0 or 1)
    assign {R, G, B} = video_active ? (pattern ? 6'b111111 : 6'b000000) : 6'b000000;

    // VGA signals
    wire hsync;
    wire vsync;
    wire [1:0] R;
    wire [1:0] G;
    wire [1:0] B;
    wire video_active;
    wire [9:0] pix_x;
    wire [9:0] pix_y;

    // TinyVGA PMOD output
    assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};

    // Unused outputs
    assign uio_out = 0;
    assign uio_oe = 0;

    // Suppress unused signals warning
    wire _unused_ok = &{ena, ui_in, uio_in};

    // VGA sync generator instance
    hvsync_generator hvsync_gen(
        .clk(clk),
        .reset(~rst_n),
        .hsync(hsync),
        .vsync(vsync),
        .display_on(video_active),
        .hpos(pix_x),
        .vpos(pix_y)
    );
endmodule
