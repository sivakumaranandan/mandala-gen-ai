`default_nettype none

module tt_um_vga_example #(
    parameter SCREEN_WIDTH  = 640,
    parameter SCREEN_HEIGHT = 480,
    parameter CENTER_X     = SCREEN_WIDTH/2,
    parameter CENTER_Y     = SCREEN_HEIGHT/2
)(
    input  wire [7:0] ui_in,    
    output wire [7:0] uo_out,   
    input  wire [7:0] uio_in,   
    output wire [7:0] uio_out,  
    output wire [7:0] uio_oe,   
    input  wire       ena,      
    input  wire       clk,      
    input  wire       rst_n     
);

    // Internal Signals
    wire hsync, vsync;
    wire [1:0] R, G, B;
    wire video_active;
    wire [9:0] pix_x, pix_y;

    // Animation counter
    reg [7:0] anim_counter;
    reg vsync_prev;
    
    // Edge detection for vsync
    always @(posedge clk) begin
        if (!rst_n) begin
            vsync_prev <= 0;
            anim_counter <= 0;
        end else begin
            vsync_prev <= vsync;
            if (vsync && !vsync_prev) begin
                anim_counter <= anim_counter + 1'b1;
            end
        end
    end

    // Mandala Pattern Generation
    wire [9:0] dx = (pix_x >= CENTER_X) ? (pix_x - CENTER_X) : (CENTER_X - pix_x);
    wire [9:0] dy = (pix_y >= CENTER_Y) ? (pix_y - CENTER_Y) : (CENTER_Y - pix_y);
    
    // Polar coordinates approximation
    wire [11:0] radius = dx * dx + dy * dy;
    wire [7:0] angle = (dx[7:0] + dy[7:0]) ^ anim_counter;

    // Pattern generation
    wire [5:0] pattern;
    assign pattern = 
        ((radius[11:7] == 5'd8) ? 6'b111111 : 6'b000000) |
        ((radius[11:7] == 5'd6) ? 6'b110110 : 6'b000000) |
        ((radius[11:7] == 5'd4) ? 6'b101101 : 6'b000000) |
        ((radius[11:7] == 5'd2) ? 6'b011011 : 6'b000000);

    // Kaleidoscope effect
    wire [5:0] kaleidoscope = pattern & {3{angle[2:1]}};

    // Color generation
    wire [5:0] color_base = {
        anim_counter[7:6],  // Red component
        anim_counter[5:4],  // Green component
        anim_counter[3:2]   // Blue component
    };

    // Final color with animation
    wire [5:0] final_color;
    assign final_color = video_active ? 
        (kaleidoscope ? (color_base + kaleidoscope) : 
         (pattern ? color_base : 6'b0)) : 6'b0;

    // Color Assignment
    assign {R, G, B} = final_color;

    // Output Assignments
    assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};
    assign uio_out = '0;
    assign uio_oe = '0;

    // Suppress unused signals warning
    wire _unused_ok = &{ena, ui_in, uio_in};

    // VGA Controller Instance
    hvsync_generator hvsync_gen (
        .clk(clk),
        .reset(~rst_n),
        .hsync(hsync),
        .vsync(vsync),
        .display_on(video_active),
        .hpos(pix_x),
        .vpos(pix_y)
    );

endmodule

module hvsync_generator #(
    parameter H_DISPLAY = 640,
    parameter H_FRONT   = 16,
    parameter H_SYNC    = 96,
    parameter H_BACK    = 48,
    parameter H_TOTAL   = H_DISPLAY + H_FRONT + H_SYNC + H_BACK,
    parameter V_DISPLAY = 480,
    parameter V_FRONT   = 10,
    parameter V_SYNC    = 2,
    parameter V_BACK    = 33,
    parameter V_TOTAL   = V_DISPLAY + V_FRONT + V_SYNC + V_BACK
)(
    input  wire clk,
    input  wire reset,
    output reg  hsync,
    output reg  vsync,
    output reg  display_on,
    output reg  [9:0] hpos,
    output reg  [9:0] vpos
);

    always @(posedge clk) begin
        if (reset) begin
            hpos <= '0;
            vpos <= '0;
            hsync <= 0;
            vsync <= 0;
            display_on <= 0;
        end else begin
            // Position counters
            if (hpos == H_TOTAL-1) begin
                hpos <= '0;
                if (vpos == V_TOTAL-1)
                    vpos <= '0;
                else
                    vpos <= vpos + 1'b1;
            end else begin
                hpos <= hpos + 1'b1;
            end

            // Sync signals
            hsync <= (hpos >= H_DISPLAY + H_FRONT) && 
                    (hpos < H_DISPLAY + H_FRONT + H_SYNC);
            vsync <= (vpos >= V_DISPLAY + V_FRONT) && 
                    (vpos < V_DISPLAY + V_FRONT + V_SYNC);
            display_on <= (hpos < H_DISPLAY) && (vpos < V_DISPLAY);
        end
    end

endmodule
