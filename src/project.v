
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
    // Animation counters
    reg [9:0] pattern_counter;
    reg [7:0] color_counter;
    always @(posedge vsync) begin
        if (~rst_n) begin
            pattern_counter <= 0;
            color_counter <= 0;
        end else begin
            pattern_counter <= pattern_counter + 1;
            color_counter <= color_counter + 1;
        end
    end
    // Calculate radius and angle for mandala
    wire [9:0] delta_x = (pix_x > CENTER_X) ? (pix_x - CENTER_X) : (CENTER_X - pix_x);
    wire [9:0] delta_y = (pix_y > CENTER_Y) ? (pix_y - CENTER_Y) : (CENTER_Y - pix_y);
    wire [19:0] radius = (delta_x * delta_x) + (delta_y * delta_y);
    wire [7:0] angle = (delta_y[7:0] ^ delta_x[7:0]) + pattern_counter[7:0];
    // Generate dynamic color palette
    wire [5:0] base_color = {
        color_counter[7:6],
        color_counter[5:4],
        color_counter[3:2]
    };
    // Define mandala layers with animation
    wire layer1 = (radius < 20000) & (angle[4] ^ angle[6]);
    wire layer2 = (radius < 40000 && radius > 20000) & (angle[3] ^ angle[5]);
    wire layer3 = (radius < 60000 && radius > 40000) & (angle[5] ^ angle[7]);
    wire layer4 = (radius < 80000 && radius > 60000) & (angle[2] ^ angle[6]);
    wire layer5 = (radius < 100000 && radius > 80000) & (angle[3] ^ angle[7]);
    // New layers with unique conditions and color assignments
    wire layer6 = (radius < 120000 && radius > 100000) & (angle[1] ^ angle[6]);
    wire layer7 = (radius < 140000 && radius > 120000) & (angle[4] ^ angle[2]);
    wire layer8 = (radius < 160000 && radius > 140000) & (angle[7] ^ angle[3]);
    // Color assignments for each layer
    wire [5:0] color1 = base_color + 6'b110000;  // Red tint
    wire [5:0] color2 = base_color + 6'b001100;  // Green tint
    wire [5:0] color3 = base_color + 6'b000011;  // Blue tint
    wire [5:0] color4 = base_color + 6'b110011;  // Purple tint
    wire [5:0] color5 = base_color + 6'b111100;  // Yellow tint
    wire [5:0] color6 = base_color + 6'b011001;  // Orange tint
    wire [5:0] color7 = base_color + 6'b101010;  // Teal tint
    wire [5:0] color8 = base_color + 6'b010101;  // Magenta tint
    // Combine layers with colors
    assign {R, G, B} = video_active ? (
        layer1 ? color1 :
        layer2 ? color2 :
        layer3 ? color3 :
        layer4 ? color4 :
        layer5 ? color5 :
        layer6 ? color6 :
        layer7 ? color7 :
        layer8 ? color8 :
        6'b000000
    ) : 6'b000000;
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
