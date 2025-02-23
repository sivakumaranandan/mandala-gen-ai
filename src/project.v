`default_nettype none

module tt_um_vga_example(
    input  wire [7:0] ui_in,    // Unused input
    output wire [7:0] uo_out,   // Output to TinyVGA PMOD
    input  wire [7:0] uio_in,   // Unused input
    output wire [7:0] uio_out,  // Unused output
    output wire [7:0] uio_oe,   // Unused output
    input  wire       ena,      // Unused enable signal
    input  wire       clk,      // 60 MHz clock
    input  wire       rst_n     // Active-low reset
);

// VGA Constants
parameter SCREEN_WIDTH = 640;
parameter SCREEN_HEIGHT = 480;
parameter CENTER_X = SCREEN_WIDTH / 2;
parameter CENTER_Y = SCREEN_HEIGHT / 2;

// Mode switching timer (switches every ~2 seconds at 60Hz refresh)
reg [7:0] mode_counter;
reg mode_select;  // 0 = fixed pattern, 1 = random pattern

// LFSR for random number generation
reg [15:0] lfsr;
wire [15:0] next_lfsr;

// Animation counters
reg [9:0] pattern_counter;
reg [7:0] color_counter;

// Mode switching logic
always @(posedge vsync or negedge rst_n) begin
    if (~rst_n) begin
        mode_counter <= 0;
        mode_select <= 0;
    end else begin
        mode_counter <= mode_counter + 1;
        if (mode_counter == 8'd120) begin  // Switch every 120 frames
            mode_counter <= 0;
            mode_select <= ~mode_select;
        end
    end
end

// LFSR implementation
always @(posedge clk or negedge rst_n) begin
    if (~rst_n)
        lfsr <= 16'hACE1;
    else
        lfsr <= next_lfsr;
end
assign next_lfsr = {lfsr[14:0], lfsr[15] ^ lfsr[14] ^ lfsr[12] ^ lfsr[3]};

// Animation counter logic
always @(posedge vsync) begin
    if (~rst_n) begin
        pattern_counter <= 0;
        color_counter <= 0;
    end else begin
        pattern_counter <= pattern_counter + 1;
        color_counter <= color_counter + 1;
    end
end

// Basic calculations
wire [9:0] delta_x = (pix_x > CENTER_X) ? (pix_x - CENTER_X) : (CENTER_X - pix_x);
wire [9:0] delta_y = (pix_y > CENTER_Y) ? (pix_y - CENTER_Y) : (CENTER_Y - pix_y);
wire [19:0] radius = (delta_x * delta_x) + (delta_y * delta_y);
wire [7:0] angle = (delta_y[7:0] ^ delta_x[7:0]) + pattern_counter[7:0];

// Color palette
wire [5:0] base_color = {
    color_counter[7:6],
    color_counter[5:4],
    color_counter[3:2]
};

// Fixed radius boundaries (Mode 0)
wire [19:0] fixed_r1 = 20000;
wire [19:0] fixed_r2 = 40000;
wire [19:0] fixed_r3 = 60000;
wire [19:0] fixed_r4 = 80000;
wire [19:0] fixed_r5 = 100000;
wire [19:0] fixed_r6 = 120000;
wire [19:0] fixed_r7 = 140000;
wire [19:0] fixed_r8 = 160000;

// Random radius boundaries (Mode 1)
wire [19:0] rand_r1 = 20000 + {lfsr[7:0], 8'b0};
wire [19:0] rand_r2 = rand_r1 + 20000 + {lfsr[15:8], 8'b0};
wire [19:0] rand_r3 = rand_r2 + 20000 + {lfsr[11:4], 8'b0};
wire [19:0] rand_r4 = rand_r3 + 20000 + {lfsr[14:7], 8'b0};
wire [19:0] rand_r5 = rand_r4 + 20000 + {lfsr[10:3], 8'b0};
wire [19:0] rand_r6 = rand_r5 + 20000 + {lfsr[13:6], 8'b0};
wire [19:0] rand_r7 = rand_r6 + 20000 + {lfsr[9:2], 8'b0};
wire [19:0] rand_r8 = rand_r7 + 20000 + {lfsr[12:5], 8'b0};

// Select current radius boundaries based on mode
wire [19:0] r1 = mode_select ? rand_r1 : fixed_r1;
wire [19:0] r2 = mode_select ? rand_r2 : fixed_r2;
wire [19:0] r3 = mode_select ? rand_r3 : fixed_r3;
wire [19:0] r4 = mode_select ? rand_r4 : fixed_r4;
wire [19:0] r5 = mode_select ? rand_r5 : fixed_r5;
wire [19:0] r6 = mode_select ? rand_r6 : fixed_r6;
wire [19:0] r7 = mode_select ? rand_r7 : fixed_r7;
wire [19:0] r8 = mode_select ? rand_r8 : fixed_r8;

// Define mandala layers
wire layer1 = (radius < r1) & (angle[4] ^ angle[6]);
wire layer2 = (radius < r2 && radius > r1) & (angle[3] ^ angle[5]);
wire layer3 = (radius < r3 && radius > r2) & (angle[5] ^ angle[7]);
wire layer4 = (radius < r4 && radius > r3) & (angle[2] ^ angle[6]);
wire layer5 = (radius < r5 && radius > r4) & (angle[3] ^ angle[7]);
wire layer6 = (radius < r6 && radius > r5) & (angle[1] ^ angle[6]);
wire layer7 = (radius < r7 && radius > r6) & (angle[4] ^ angle[2]);
wire layer8 = (radius < r8 && radius > r7) & (angle[7] ^ angle[3]);

// New layers with more complex patterns
wire layer9 = (radius < r1) & (angle[4] ^ angle[6]) & (delta_x[7:0] == delta_y[7:0]);
wire layer10 = (radius < r2 && radius > r1) & (angle[3] ^ angle[5]) & (delta_x[7:0] != delta_y[7:0]);
wire layer11 = (radius < r3 && radius > r2) & (angle[5] ^ angle[7]) & (delta_x[7:0] == delta_y[7:0]);
wire layer12 = (radius < r4 && radius > r3) & (angle[2] ^ angle[6]) & (delta_x[7:0] != delta_y[7:0]);

// Color assignments
wire [5:0] color1 = base_color + 6'b110000;  // Red tint
wire [5:0] color2 = base_color + 6'b001100;  // Green tint
wire [5:0] color3 = base_color + 6'b000011;  // Blue tint
wire [5:0] color4 = base_color + 6'b110011;  // Purple tint
wire [5:0] color5 = base_color + 6'b111100;  // Yellow tint
wire [5:0] color6 = base_color + 6'b011001;  // Orange tint
wire [5:0] color7 = base_color + 6'b101010;  // Teal tint
wire [5:0] color8 = base_color + 6'b010101;  // Magenta tint

// New color assignments
wire [5:0] color9 = base_color + 6'b100100;  // New red tint
wire [5:0] color10 = base_color + 6'b010010;  // New green tint
wire [5:0] color11 = base_color + 6'b001001;  // New blue tint
wire [5:0] color12 = base_color + 6'b110101;  // New purple tint

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
    layer9 ? color9 :
    layer10 ? color10 :
    layer11 ? color11 :
    layer12 ? color12 :
    6'b000000
) : 6'b000000;

// Alternate pattern generation
reg [7:0] alternate_pattern;
reg [7:0] alternate_counter;
always @(posedge vsync or negedge rst_n) begin
    if (~rst_n) begin
        alternate_counter <= 0;
    end else begin
        alternate_counter <= alternate_counter + 1;
        if (alternate_counter == 8'd120) begin  // Alternate pattern every 120 frames
            alternate_counter <= 0;
            alternate_pattern <= ~alternate_pattern;
        end
    end
end

// Alternate pattern color assignments
wire [5:0] alternate_color1 = base_color + 6'b100010;  // Alternate red tint
wire [5:0] alternate_color2 = base_color + 6'b010100;  // Alternate green tint
wire [5:0] alternate_color3 = base_color + 6'b001010;  // Alternate blue tint
wire [5:0] alternate_color4 = base_color + 6'b100101;  // Alternate purple tint
wire [5:0] alternate_color5 = base_color + 6'b110100;  // Alternate yellow tint
wire [5:0] alternate_color6 = base_color + 6'b101001;  // Alternate orange tint
wire [5:0] alternate_color7 = base_color + 6'b010110;  // Alternate teal tint
wire [5:0] alternate_color8 = base_color + 6'b001101;  // Alternate magenta tint
wire [5:0] alternate_color9 = base_color + 6'b100110;  // New alternate red tint
wire [5:0] alternate_color10 = base_color + 6'b010110;  // New alternate green tint
wire [5:0] alternate_color11 = base_color + 6'b001110;  // New alternate blue tint
wire [5:0] alternate_color12 = base_color + 6'b110110;  // New alternate purple tint

// Combine alternate layers with colors
wire [5:0] alternate_rgb;
assign alternate_rgb = video_active ? (
    layer1 ? alternate_color1 :
    layer2 ? alternate_color2 :
    layer3 ? alternate_color3 :
    layer4 ? alternate_color4 :
    layer5 ? alternate_color5 :
    layer6 ? alternate_color6 :
    layer7 ? alternate_color7 :
    layer8 ? alternate_color8 :
    layer9 ? alternate_color9 :
    layer10 ? alternate_color10 :
    layer11 ? alternate_color11 :
    layer12 ? alternate_color12 :
    6'b000000
) : 6'b000000;

// Output selection based on alternate pattern
assign {R, G, B} = alternate_pattern ? alternate_rgb : rgb;

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

// VGA Sync Generator module remains unchanged
module hvsync_generator(
    input  wire       clk,
    input  wire       reset,
    output wire       hsync,
    output wire       vsync,
    output wire       display_on,
    output wire [9:0] hpos,
    output wire [9:0] vpos
);

// Horizontal timing parameters
parameter H_DISPLAY = 640;
parameter H_FRONT = 16;
parameter H_SYNC = 96;
parameter H_BACK = 48;
parameter H_TOTAL = H_DISPLAY + H_FRONT + H_SYNC + H_BACK;

// Vertical timing parameters
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
