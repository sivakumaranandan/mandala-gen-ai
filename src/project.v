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
    parameter CENTER_X = SCREEN_WIDTH/2;
    parameter CENTER_Y = SCREEN_HEIGHT/2;

    // Core signals
    reg [9:0] pattern_counter;
    reg [7:0] color_counter;
    reg vsync_prev;
    wire hsync, vsync, video_active;
    wire [9:0] pix_x, pix_y;
    wire [1:0] R, G, B;

    // Pattern and color counters
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            vsync_prev <= 0;
            pattern_counter <= 0;
            color_counter <= 0;
        end else begin
            vsync_prev <= vsync;
            if (vsync && !vsync_prev) begin
                pattern_counter <= pattern_counter + 1;
                color_counter <= color_counter + 1;
            end
        end
    end

    // Optimized radius calculation using octagonal approximation
    wire [9:0] delta_x = (pix_x > CENTER_X) ? (pix_x - CENTER_X) : (CENTER_X - pix_x);
    wire [9:0] delta_y = (pix_y > CENTER_Y) ? (pix_y - CENTER_Y) : (CENTER_Y - pix_y);
    wire [9:0] radius = (delta_x > delta_y) ? 
                       (delta_x + (delta_y >> 1)) : 
                       (delta_y + (delta_x >> 1));

    // Enhanced angle calculation for more complex patterns
    wire [7:0] angle = (delta_y[7:0] ^ delta_x[7:0]) + 
                       pattern_counter[7:0] + 
                       ((delta_x[6:0] + delta_y[6:0]) >> 1);

    // Enhanced layer patterns with more complexity
    wire layer1 = (radius < 50) & (angle[4] ^ angle[6] ^ (radius[4:2] == pattern_counter[2:0]));
    wire layer2 = (radius < 100 && radius >= 50) & (angle[3] ^ angle[5] ^ (delta_x[3] & delta_y[3]));
    wire layer3 = (radius < 150 && radius >= 100) & (angle[5] ^ angle[7] ^ (radius[5:3] == 3'b101));
    wire layer4 = (radius < 200 && radius >= 150) & (angle[2] ^ angle[6] ^ (delta_x[4] ^ delta_y[4]));
    wire layer5 = (radius < 250 && radius >= 200) & (angle[3] ^ angle[7] ^ (radius[6:4] == pattern_counter[3:1]));
    wire layer6 = (radius < 300 && radius >= 250) & (angle[1] ^ angle[6] ^ (delta_x[5] | delta_y[5]));
    wire layer7 = (radius < 350 && radius >= 300) & (angle[4] ^ angle[2] ^ (radius[3:1] == 3'b011));
    wire layer8 = (radius < 400 && radius >= 350) & (angle[7] ^ angle[3] ^ (delta_x[6] ^ delta_y[6]));

    // Color generation
    wire [5:0] base_color = {
        color_counter[7:6],
        color_counter[5:4],
        color_counter[3:2]
    };

    // Layer colors
    wire [5:0] color1 = base_color + 6'b110000;  // Red tint
    wire [5:0] color2 = base_color + 6'b001100;  // Green tint
    wire [5:0] color3 = base_color + 6'b000011;  // Blue tint
    wire [5:0] color4 = base_color + 6'b110011;  // Purple tint
    wire [5:0] color5 = base_color + 6'b111100;  // Yellow tint
    wire [5:0] color6 = base_color + 6'b011001;  // Orange tint
    wire [5:0] color7 = base_color + 6'b101010;  // Teal tint
    wire [5:0] color8 = base_color + 6'b010101;  // Magenta tint

    // Color assignment
    wire [5:0] final_color = video_active ? (
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

    // Split final color into RGB components
    assign {R, G, B} = final_color;

    // Output assignments
    assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};
    assign uio_out = 8'b0;
    assign uio_oe = 8'b0;

    wire _unused_ok = &{ena, ui_in, uio_in};

    // VGA sync generator instantiation
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

// VGA Sync Generator
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

    assign hsync = (h_count >= H_DISPLAY + H_FRONT) && 
                  (h_count < H_DISPLAY + H_FRONT + H_SYNC);
    assign vsync = (v_count >= V_DISPLAY + V_FRONT) && 
                  (v_count < V_DISPLAY + V_FRONT + V_SYNC);
    assign display_on = (h_count < H_DISPLAY) && (v_count < V_DISPLAY);
    assign hpos = h_count;
    assign vpos = v_count;
endmodule
