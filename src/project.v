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
    reg vsync_prev;

    wire hsync, vsync, video_active;
    wire [9:0] pix_x, pix_y;
    wire pattern_out;

    // Pattern counter
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            vsync_prev <= 0;
            pattern_counter <= 0;
        end else begin
            vsync_prev <= vsync;
            if (vsync && !vsync_prev) begin
                pattern_counter <= pattern_counter + 1;
            end
        end
    end

    // Mandala pattern generation
    wire [9:0] delta_x = (pix_x > CENTER_X) ? (pix_x - CENTER_X) : (CENTER_X - pix_x);
    wire [9:0] delta_y = (pix_y > CENTER_Y) ? (pix_y - CENTER_Y) : (CENTER_Y - pix_y);
    wire [19:0] radius = (delta_x * delta_x) + (delta_y * delta_y);
    wire [7:0] angle = (delta_y[7:0] ^ delta_x[7:0]) + pattern_counter[7:0];

    // Mandala layers
    wire layer1 = (radius < 20000) & (angle[4] ^ angle[6]);
    wire layer2 = (radius < 40000 && radius > 20000) & (angle[3] ^ angle[5]);
    wire layer3 = (radius < 60000 && radius > 40000) & (angle[5] ^ angle[7]);
    wire layer4 = (radius < 80000 && radius > 60000) & (angle[2] ^ angle[6]);
    wire layer5 = (radius < 100000 && radius > 80000) & (angle[3] ^ angle[7]);
    wire layer6 = (radius < 120000 && radius > 100000) & (angle[1] ^ angle[6]);
    wire layer7 = (radius < 140000 && radius > 120000) & (angle[4] ^ angle[2]);
    wire layer8 = (radius < 160000 && radius > 140000) & (angle[7] ^ angle[3]);

    // Combine layers into single pattern output
    assign pattern_out = video_active ? (
        layer1 | layer2 | layer3 | layer4 | layer5 | layer6 | layer7 | layer8
    ) : 1'b0;

    // Output assignments - monochrome pattern
    assign uo_out = {hsync, pattern_out, pattern_out, pattern_out, vsync, pattern_out, pattern_out, pattern_out};
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
