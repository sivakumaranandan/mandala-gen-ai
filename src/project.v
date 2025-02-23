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

    // Unified counter for pattern and color
    reg [9:0] unified_counter;
    always @(posedge vsync or negedge rst_n) begin
        unified_counter <= (~rst_n) ? '0 : unified_counter + 1'b1;
    end

    // Simplified Mandala Calculations
    wire [19:0] radius = (pix_x - CENTER_X) * (pix_x - CENTER_X) + 
                        (pix_y - CENTER_Y) * (pix_y - CENTER_Y);
    wire [7:0] angle = pix_x[7:0] ^ pix_y[7:0] ^ unified_counter[7:0];

    // Optimized Layer and Color Generation
    wire [7:0] layer_select;
    assign layer_select = (radius[18:15] < 4'h8) ? (1'b1 << radius[17:15]) : 8'h0;

    wire [5:0] base_color = unified_counter[7:2];
    wire [5:0] final_color = video_active ? 
        (layer_select ? (base_color + {layer_select[2:0], 3'b0}) : 6'b0) : 6'b0;

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
                vpos <= (vpos == V_TOTAL-1) ? '0 : vpos + 1'b1;
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
