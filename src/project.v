`default_nettype none

// Main VGA Display Module
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
    // Display parameters
    localparam SCREEN_WIDTH = 640;
    localparam SCREEN_HEIGHT = 480;
    localparam CENTER_X = SCREEN_WIDTH/2;
    localparam CENTER_Y = SCREEN_HEIGHT/2;

    // Pattern generation registers
    reg [9:0] pattern_counter;
    reg [15:0] lfsr;
    reg vsync_prev;  // Added to detect vsync edge

    // VGA signals
    wire hsync, vsync, video_active;
    wire [9:0] pix_x, pix_y;
    wire [1:0] R, G, B;

    // LFSR for random colors
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            lfsr <= 16'hACE1;
        else
            lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[14] ^ lfsr[12] ^ lfsr[3]};
    end

    // Vsync edge detection and pattern counter update
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pattern_counter <= 10'd0;
            vsync_prev <= 1'b0;
        end else begin
            vsync_prev <= vsync;
            if (vsync && !vsync_prev)  // Rising edge of vsync
                pattern_counter <= pattern_counter + 1;
        end
    end

    // Pattern generation logic
    wire [9:0] delta_x = (pix_x > CENTER_X) ? (pix_x - CENTER_X) : (CENTER_X - pix_x);
    wire [9:0] delta_y = (pix_y > CENTER_Y) ? (pix_y - CENTER_Y) : (CENTER_Y - pix_y);
    wire [19:0] radius = (delta_x * delta_x) + (delta_y * delta_y);
    wire [7:0] angle = (delta_y[7:0] ^ delta_x[7:0]) + pattern_counter[7:0];

    // Pattern regions
    wire [3:0] pattern = {
        (radius >= 60000) & angle[7],
        (radius < 60000 && radius >= 40000) & angle[6],
        (radius < 40000 && radius >= 20000) & angle[5],
        (radius < 20000) & angle[4]
    };

    // Color generation from LFSR
    wire [5:0] colors [3:0];
    assign colors[0] = {lfsr[15:14], lfsr[13:12], lfsr[11:10]};
    assign colors[1] = {lfsr[9:8], lfsr[7:6], lfsr[5:4]};
    assign colors[2] = {lfsr[3:2], lfsr[1:0], lfsr[15:14]};
    assign colors[3] = {lfsr[13:12], lfsr[11:10], lfsr[9:8]};

    // Color selection logic
    wire [5:0] selected_color = 
        pattern[0] ? colors[0] :
        pattern[1] ? colors[1] :
        pattern[2] ? colors[2] :
        pattern[3] ? colors[3] : 6'b0;

    // Final color output
    assign {R, G, B} = video_active ? selected_color : 6'b0;

    // Output assignments
    assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};
    assign uio_out = 8'b0;
    assign uio_oe = 8'b0;

    // Unused signals
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

// VGA Sync Generator Module
module hvsync_generator(
    input  wire       clk,
    input  wire       reset,
    output wire       hsync,
    output wire       vsync,
    output wire       display_on,
    output wire [9:0] hpos,
    output wire [9:0] vpos
);
    // Timing parameters
    localparam H_DISPLAY = 640;
    localparam H_FRONT   = 16;
    localparam H_SYNC    = 96;
    localparam H_BACK    = 48;
    localparam H_TOTAL   = H_DISPLAY + H_FRONT + H_SYNC + H_BACK;

    localparam V_DISPLAY = 480;
    localparam V_FRONT   = 10;
    localparam V_SYNC    = 2;
    localparam V_BACK    = 33;
    localparam V_TOTAL   = V_DISPLAY + V_FRONT + V_SYNC + V_BACK;

    // Counter registers
    reg [9:0] h_count;
    reg [9:0] v_count;

    // Horizontal counter
    always @(posedge clk or posedge reset) begin
        if (reset)
            h_count <= 10'd0;
        else
            h_count <= (h_count == H_TOTAL - 1) ? 10'd0 : h_count + 1;
    end

    // Vertical counter
    always @(posedge clk or posedge reset) begin
        if (reset)
            v_count <= 10'd0;
        else if (h_count == H_TOTAL - 1)
            v_count <= (v_count == V_TOTAL - 1) ? 10'd0 : v_count + 1;
    end

    // Output assignments
    assign hsync = (h_count >= H_DISPLAY + H_FRONT) && 
                  (h_count < H_DISPLAY + H_FRONT + H_SYNC);
    assign vsync = (v_count >= V_DISPLAY + V_FRONT) && 
                  (v_count < V_DISPLAY + V_FRONT + V_SYNC);
    assign display_on = (h_count < H_DISPLAY) && (v_count < V_DISPLAY);
    assign hpos = h_count;
    assign vpos = v_count;
endmodule
