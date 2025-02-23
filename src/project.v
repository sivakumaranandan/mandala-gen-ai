`default_nettype none

//------------------------------------------------------------------------------
// VGA Display Parameters
//------------------------------------------------------------------------------
module tt_um_vga_example #(
    parameter SCREEN_WIDTH  = 640,
    parameter SCREEN_HEIGHT = 480,
    parameter CENTER_X     = SCREEN_WIDTH/2,
    parameter CENTER_Y     = SCREEN_HEIGHT/2
)(
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path
    input  wire       ena,      // always 1
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

    //--------------------------------------------------------------------------
    // Internal Signals
    //--------------------------------------------------------------------------
    wire hsync, vsync;
    wire [1:0] R, G, B;
    wire video_active;
    wire [9:0] pix_x, pix_y;

    //--------------------------------------------------------------------------
    // Animation and Pattern Generation
    //--------------------------------------------------------------------------
    reg [9:0] pattern_counter;
    reg [7:0] color_counter;

    always @(posedge vsync) begin
        if (~rst_n) begin
            pattern_counter <= '0;
            color_counter  <= '0;
        end else begin
            pattern_counter <= pattern_counter + 1'b1;
            color_counter  <= color_counter + 1'b1;
        end
    end

    //--------------------------------------------------------------------------
    // Mandala Calculations
    //--------------------------------------------------------------------------
    wire [9:0] delta_x = (pix_x > CENTER_X) ? (pix_x - CENTER_X) : (CENTER_X - pix_x);
    wire [9:0] delta_y = (pix_y > CENTER_Y) ? (pix_y - CENTER_Y) : (CENTER_Y - pix_y);
    wire [19:0] radius = (delta_x * delta_x) + (delta_y * delta_y);
    wire [7:0] angle = (delta_y[7:0] ^ delta_x[7:0]) + pattern_counter[7:0];

    //--------------------------------------------------------------------------
    // Color Generation
    //--------------------------------------------------------------------------
    wire [5:0] base_color = {color_counter[7:6], color_counter[5:4], color_counter[3:2]};

    // Layer definitions
    wire [7:0] layers;
    assign layers[0] = (radius < 20000) & (angle[4] ^ angle[6]);
    assign layers[1] = (radius < 40000 && radius > 20000) & (angle[3] ^ angle[5]);
    assign layers[2] = (radius < 60000 && radius > 40000) & (angle[5] ^ angle[7]);
    assign layers[3] = (radius < 80000 && radius > 60000) & (angle[2] ^ angle[6]);
    assign layers[4] = (radius < 100000 && radius > 80000) & (angle[3] ^ angle[7]);
    assign layers[5] = (radius < 120000 && radius > 100000) & (angle[1] ^ angle[6]);
    assign layers[6] = (radius < 140000 && radius > 120000) & (angle[4] ^ angle[2]);
    assign layers[7] = (radius < 160000 && radius > 140000) & (angle[7] ^ angle[3]);

    // Color palette
    wire [5:0] colors [7:0];
    assign colors[0] = base_color + 6'b110000;  // Red tint
    assign colors[1] = base_color + 6'b001100;  // Green tint
    assign colors[2] = base_color + 6'b000011;  // Blue tint
    assign colors[3] = base_color + 6'b110011;  // Purple tint
    assign colors[4] = base_color + 6'b111100;  // Yellow tint
    assign colors[5] = base_color + 6'b011001;  // Orange tint
    assign colors[6] = base_color + 6'b101010;  // Teal tint
    assign colors[7] = base_color + 6'b010101;  // Magenta tint

    //--------------------------------------------------------------------------
    // Color Assignment Logic
    //--------------------------------------------------------------------------
    wire [5:0] final_color;
    assign final_color = (!video_active) ? 6'b000000 :
                        (layers[0]) ? colors[0] :
                        (layers[1]) ? colors[1] :
                        (layers[2]) ? colors[2] :
                        (layers[3]) ? colors[3] :
                        (layers[4]) ? colors[4] :
                        (layers[5]) ? colors[5] :
                        (layers[6]) ? colors[6] :
                        (layers[7]) ? colors[7] :
                        6'b000000;

    assign {R, G, B} = final_color;

    //--------------------------------------------------------------------------
    // Output Assignments
    //--------------------------------------------------------------------------
    assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};
    assign uio_out = '0;
    assign uio_oe = '0;

    // Suppress unused signals warning
    wire _unused_ok = &{ena, ui_in, uio_in};

    //--------------------------------------------------------------------------
    // VGA Controller Instance
    //--------------------------------------------------------------------------
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

//------------------------------------------------------------------------------
// VGA Sync Generator Module
//------------------------------------------------------------------------------
module hvsync_generator #(
    // Horizontal timing parameters
    parameter H_DISPLAY = 640,
    parameter H_FRONT   = 16,
    parameter H_SYNC    = 96,
    parameter H_BACK    = 48,
    parameter H_TOTAL   = H_DISPLAY + H_FRONT + H_SYNC + H_BACK,
    // Vertical timing parameters
    parameter V_DISPLAY = 480,
    parameter V_FRONT   = 10,
    parameter V_SYNC    = 2,
    parameter V_BACK    = 33,
    parameter V_TOTAL   = V_DISPLAY + V_FRONT + V_SYNC + V_BACK
)(
    input  wire       clk,
    input  wire       reset,
    output wire       hsync,
    output wire       vsync,
    output wire       display_on,
    output wire [9:0] hpos,
    output wire [9:0] vpos
);

    reg [9:0] h_count;
    reg [9:0] v_count;

    always @(posedge clk or posedge reset) begin
        if (reset)
            h_count <= '0;
        else if (h_count == H_TOTAL - 1)
            h_count <= '0;
        else
            h_count <= h_count + 1'b1;
    end

    always @(posedge clk or posedge reset) begin
        if (reset)
            v_count <= '0;
        else if (h_count == H_TOTAL - 1) begin
            if (v_count == V_TOTAL - 1)
                v_count <= '0;
            else
                v_count <= v_count + 1'b1;
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
