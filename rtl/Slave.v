module synchronizer(input clk,
                    input rst, 
                    input ptr, 
                    output reg sync1, 
                    output reg sync2
                    );
                    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sync1 <= 0;
            sync2 <= 0;
        end
        else begin
            sync1 <= ptr;
            sync2 <= sync1;
        end
    end
endmodule

module control_slave #(parameter [7:0] SLAVE_ADDR = 8'h50)
                    (input clk,
                     input rst,
                     input scl,
                     input sda,
                     output reg sda_drive
                     );

    wire scl_sync1, scl_sync2;
    wire sda_sync1, sda_sync2;
    
    synchronizer scl_sync_inst (
        .clk(clk),
        .rst(rst),
        .ptr(scl),
        .sync1(scl_sync1),
        .sync2(scl_sync2)
        );
        
    synchronizer sda_sync_inst (
        .clk(clk),
        .rst(rst),
        .ptr(sda),
        .sync1(sda_sync1),
        .sync2(sda_sync2)
        );
//    wire scl_sync2 = scl;
//    wire sda_sync2 = sda;
    //parameter SLAVE_ADDR = 8'h50;
    
    reg scl_d;
    reg sda_d;
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            scl_d <= 0;
            sda_d <= 0;
        end
        else begin
            scl_d <= scl_sync2;
            sda_d <= sda_sync2;
        end
    end
    
    wire scl_rise = ~scl_d & scl_sync2;
    wire scl_fall = scl_d & ~scl_sync2;
    
    wire sda_rise = ~sda_d & sda_sync2;
    wire sda_fall = sda_d & ~sda_sync2;
    
    reg [2:0] state;
    reg [2:0] next_state;
    
    localparam IDLE     = 3'd0;
    localparam REC_ADDR = 3'd1;
    localparam ADDR_ACK = 3'd2;
    localparam REC_DATA = 3'd3;
    localparam DATA_ACK = 3'd4;
    localparam ACK_WAIT = 3'd5;
    
    wire start_detect;
    
//    assign start_detect = sda_fall && scl_sync2;
    assign start_detect =
        (state == IDLE) &&
        sda_fall &&
        scl_sync2;
        
    wire stop_detect = sda_rise & scl_sync2;
    
    reg [7:0] addr_reg;
    reg [3:0] bit_count;
    wire addr_match;
    reg [7:0] data_reg;
    
    always @(*) begin
        next_state = state;
        
        case(state)
            IDLE : begin
                if (start_detect)
                    next_state = REC_ADDR;
            end
            
            REC_ADDR : begin
                if (stop_detect)
                    next_state = IDLE;
                else if (bit_count == 7 && scl_fall)
                    next_state = ADDR_ACK;
            end
            
            ADDR_ACK : begin
                if (stop_detect)
                    next_state = IDLE;
                else if (scl_fall) begin
                    if (addr_match)
                        next_state = REC_DATA;
                    else
                        next_state = IDLE;
                end
            end
            
            REC_DATA : begin
                if (stop_detect)
                    next_state = IDLE;
                else if (bit_count == 8 && scl_fall)
                    next_state = DATA_ACK;
            end
            
            DATA_ACK : begin
                if (stop_detect)
                    next_state = IDLE;
                else if (scl_fall)
                    next_state = IDLE;
            end
            ACK_WAIT : begin
                if (stop_detect)
                    next_state = IDLE;
                else if (scl_rise)
                    next_state = REC_DATA;
            end
            
            default :
                next_state = IDLE;
        endcase
    end
    
    always @(posedge clk or posedge rst) begin
        if (rst)
            addr_reg <= 8'h00;
        else if (state == IDLE || start_detect)
            addr_reg <= 8'h00;
        else if (state == REC_ADDR && scl_rise) //scl_rise causing issues
            addr_reg <= {addr_reg[6:0], sda_sync2};
    end
    
    always @(posedge clk or posedge rst) begin
        if (rst)
            bit_count <= 0;
        
        else if (state == IDLE || start_detect)
            bit_count <= 0;
            
//        else if (state == ADDR_ACK || state == DATA_ACK || state == ACK_WAIT)
//            bit_count <= 0;
        else if (state == ADDR_ACK)
            bit_count <= 0;
        
        else if ((state == REC_ADDR || state == REC_DATA) && scl_rise)
            bit_count <= bit_count + 1;
            
    end
        
    assign addr_match = (addr_reg == SLAVE_ADDR);
    
    always @(posedge clk or posedge rst) begin
        if (rst)
            data_reg <= 0;
        else if (state == REC_DATA && scl_rise)
            data_reg <= {data_reg[6:0], sda_sync2};
    end
    
    always @(posedge clk or posedge rst) begin
        if (rst)
            state <= IDLE;
        else
            state <= next_state;
    end
    
    always @(*) begin
        sda_drive = 0;
        
        case (state)
            ADDR_ACK : begin
                if (addr_match)
                    sda_drive = 1;
            end
            DATA_ACK : sda_drive = 1;
        endcase
    end
    
endmodule

module slave #(parameter [7:0] SLAVE_ADDR = 8'h50)
            (input clk,
             input rst,
             input scl,
             inout sda
             );

    wire sda_drive;
    
    control_slave #(.SLAVE_ADDR(SLAVE_ADDR))
                  cont_slv_inst (.clk(clk),
                                 .rst(rst),
                                 .scl(scl),
                                 .sda(sda),
                                 .sda_drive(sda_drive)
                                 );
                                 
    assign sda = sda_drive ? 1'b0 : 1'bz;                             
             
endmodule