`default_nettype none

module tt_um_vga_example(
    input  wire [7:0] ui_in,    
    output wire [7:0] uo_out,   
    input  wire [7:0] uio_in,   
    output wire [7:0] uio_out,  
    output wire [7:0] uio_oe,   
    input  wire       ena,      
    input  wire       clk,      
    input  wire       rst_n     
);

// VGA Constants
parameter SCREEN_WIDTH = 640;
parameter SCREEN_HEIGHT = 480;
parameter CENTER_X = SCREEN_WIDTH / 2;
parameter CENTER_Y = SCREEN_HEIGHT / 2;

// Simplified counters
reg [7:0] pattern_counter;
reg [5:0] color_counter;

// Simplified LFSR (8-bit)
reg [7:0] lfsr;
wire [7:0] next_lfsr;
assign next_lfsr = {lfsr[6:0], lfsr[7] ^ lfsr[5] ^ lfsr[4] ^ lfsr[3]};

always @(posedge clk or negedge rst_n) begin
    if (~rst_n)
        lfsr <= 8'hAC;
    else
        lfsr <= next_lfsr;
end

// Simple mode selection
reg mode_select;
always @(posedge vsync or negedge rst_n) begin
    if (~rst_n)
        mode_select <= 0;
    else
        mode_select <= pattern_counter[7];
end

// Counter logic
always @(posedge vsync or negedge rst_n) begin
    if (~rst_n) begin
        pattern_counter <= 0;
        color_counter <= 0;
    end else begin
        pattern_counter <= pattern_counter + 1;
        color_counter <= color_counter + 1;
    end
end

// Simplified calculations
wire [8:0] delta_x = (pix_x > CENTER_X) ? (pix_x - CENTER_X) : (CENTER_X - pix_x);
wire [8:0] delta_y = (pix_y > CENTER_Y) ? (pix_y - CENTER_Y) : (CENTER_Y - pix_y);
wire [17:0] radius = (delta_x * delta_x) + (delta_y * delta_y);
wire [7:0] angle = (delta_y[7:0] ^ delta_x[7:0]) + pattern_counter;

// Base color generation
wire [5:0] base_color = {color_counter[5:4], color_counter[3:2], color_counter[1:0]};

// Simplified radius boundaries
wire [17:0] radius_step = 20000;
wire [17:0] r1 = radius_step + (mode_select ? {lfsr[3:0], 8'b0} : 0);
wire [17:0] r2 = r1 + radius_step;
wire [17:0] r3 = r2 + radius_step;
wire [17:0] r4 = r3 + radius_step;
wire [17:0] r5 = r4 + radius_step;
wire [17:0] r6 = r5 + radius_step;
wire [17:0] r7 = r6 + radius_step;
wire [17:0] r8 = r7 + radius_step;

// Simplified layer patterns
wire layer1 = (radius < r1) & (angle[4] ^ angle[6]);
wire layer2 = (radius < r2 && radius > r1) & (angle[3] ^ angle[5]);
wire layer3 = (radius < r3 && radius > r2) & (angle[5] ^ angle[7]);
wire layer4 = (radius < r4 && radius > r3) & (angle[2] ^ angle[6]);
wire layer5 = (radius < r5 && radius > r4) & (angle[3] ^ angle[7]);
wire layer6 = (radius < r6 && radius > r5) & (angle[1] ^ angle[6]);
wire layer7 = (radius < r7 && radius > r6) & (angle[4] ^ angle[2]);
wire layer8 = (radius < r8 && radius > r7) & (angle[7] ^ angle[3]);

// Simplified color tints
wire [5:0] color_tint = {2'b10, 2'b01, 2'b01};
wire [5:0] color1 = base_color + (1 * color_tint);
wire [5:0] color2 = base_color + (2 * color_tint);
wire [5:0] color3 = base_color + (3 * color_tint);
wire [5:0] color4 = base_color + (4 * color_tint);
wire [5:0] color5 = base_color + (5 * color_tint);
wire [5:0] color6 = base_color + (6 * color_tint);
wire [5:0] color7 = base_color + (7 * color_tint);
wire [5:0] color8 = base_color + (8 * color_tint);

// Combine layers with colors
wire [5:0] rgb;
assign rgb = video_active ? (
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
wire hsync, vsync;
wire [1:0] R, G, B;
wire video_active;
wire [9:0] pix_x, pix_y;

// Output assignments
assign {R, G, B} = rgb;
assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};
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

// VGA Sync Generator module
module hvsync_generator(
    input  wire       clk,
    input  wire       reset,
    output wire       hsync,
    output wire       vsync,
    output wire       display_on,
    output wire [9:0] hpos,
    output wire [9:0] vpos
);

parameter H_DISPLAY = 640;
parameter H_FRONT = 16;
parameter H_SYNC = 96;
parameter H_BACK = 48;
parameter H_TOTAL = H_DISPLAY + H_FRONT + H_SYNC + H_BACK;

parameter V_DISPLAY = 480;
parameter V_FRONT = 10;
parameter V_SYNC = 2;
parameter V_BACK = 33;
parameter V_TOTAL = V_DISPLAY + V_FRONT + V_SYNC + V_BACK;

reg [9:0] h_count;
reg [9:0] v_count;

always @(posedge clk or posedge reset) begin
    if (reset)
        h_count <= 0;
    else if (h_count == H_TOTAL - 1)
        h_count <= 0;
    else
        h_count <= h_count + 1;
end

always @(posedge clk or posedge reset) begin
    if (reset)
        v_count <= 0;
    else if (h_count == H_TOTAL - 1) begin
        if (v_count == V_TOTAL - 1)
            v_count <= 0;
        else
            v_count <= v_count + 1;
    end
end

assign hsync = (h_count >= H_DISPLAY + H_FRONT) && (h_count < H_DISPLAY + H_FRONT + H_SYNC);
assign vsync = (v_count >= V_DISPLAY + V_FRONT) && (v_count < V_DISPLAY + V_FRONT + V_SYNC);
assign display_on = (h_count < H_DISPLAY) && (v_count < V_DISPLAY);
assign hpos = h_count;
assign vpos = v_count;

endmodule
