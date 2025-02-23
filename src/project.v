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
    // Core signals
    reg [7:0] pattern_counter;
    reg [7:0] lfsr;
    reg vsync_prev;

    wire hsync, vsync, video_active;
    wire [9:0] pix_x, pix_y;
    wire R, G, B;

    // Simplified LFSR
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            lfsr <= 8'hA5;
        else
            lfsr <= {lfsr[6:0], lfsr[7] ^ lfsr[5]};
    end

    // Frame counter
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pattern_counter <= 8'd0;
            vsync_prev <= 1'b0;
        end else begin
            vsync_prev <= vsync;
            if (vsync && !vsync_prev)
                pattern_counter <= pattern_counter + 1;
        end
    end

    // Mandala pattern generation
    wire [8:0] dx = (pix_x[9:1] > 160) ? (pix_x[9:1] - 160) : (160 - pix_x[9:1]);
    wire [8:0] dy = (pix_y[9:1] > 120) ? (pix_y[9:1] - 120) : (120 - pix_y[9:1]);
    
    // Simplified radius calculation (using sum of absolute differences)
    wire [9:0] radius = dx + dy;
    
    // Angle approximation using XOR
    wire [7:0] angle = dx[7:0] ^ dy[7:0];
    
    // Pattern regions based on radius and angle
    wire [2:0] pattern;
    assign pattern[0] = (radius < 100) & (angle[7:6] == pattern_counter[1:0]);
    assign pattern[1] = (radius < 200 && radius >= 100) & (angle[5:4] == pattern_counter[3:2]);
    assign pattern[2] = (radius >= 200) & (angle[3:2] == pattern_counter[5:4]);

    // Color generation
    assign R = video_active & (pattern[0] | (lfsr[7] & pattern[2]));
    assign G = video_active & (pattern[1] | (lfsr[5] & pattern[0]));
    assign B = video_active & (pattern[2] | (lfsr[3] & pattern[1]));

    // Output assignments
    assign uo_out = {hsync, B, G, R, vsync, 1'b0, 1'b0, 1'b0};
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

// Optimized VGA Sync Generator
module hvsync_generator(
    input  wire       clk,
    input  wire       reset,
    output wire       hsync,
    output wire       vsync,
    output wire       display_on,
    output reg  [9:0] hpos,
    output reg  [9:0] vpos
);
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            hpos <= 10'd0;
            vpos <= 10'd0;
        end else begin
            if (hpos == 799) begin
                hpos <= 10'd0;
                vpos <= (vpos == 524) ? 10'd0 : vpos + 1;
            end else
                hpos <= hpos + 1;
        end
    end

    assign hsync = (hpos >= 656) && (hpos < 752);
    assign vsync = (vpos >= 490) && (vpos < 492);
    assign display_on = (hpos < 640) && (vpos < 480);
endmodule
