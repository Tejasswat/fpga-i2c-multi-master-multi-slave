//module SCL_gen(
//    input clk,
//    input rst,
//    input en,
//    input scl_target,
//    output reg scl
//    );

//    parameter divider = 5;
//    reg [15:0] count;
    
//    always @(posedge clk or posedge rst) begin
//        if (rst) begin
//            count <= 0;
//            scl <= 1'b1;
//        end
        
//        else if (!en) begin
//            count <= 0;
//            scl <= 1'b1;
//        end
        
//        else begin
//            if (count == divider - 1) begin
//                count <= 0;
//                scl <= scl_target;
//            end
            
//            else begin
//                count <= count + 1;
//            end
//       end
//    end
//endmodule

module control_master(
    input clk,
    input rst,
    input start,
    input scl,
    input sda,
    input [7:0] target_slave,
    input [7:0] data_value,
    output reg shift_en,
    output reg sda_drive,
    output reg scl_drive
    );

    reg [3:0] state;
    reg [3:0] next_state;
    reg [7:0] tx_data;
    reg [7:0] rx_data;
    reg [3:0] bit_count;
    reg [7:0] data_reg;
    
    reg [2:0] ack_count;
    
    reg ack_received;
    
    reg arb_lost;
    wire tx_bit;
    wire bus_idle;
    
//    assign bus_idle = scl & sda;

    
    reg bus_busy;
    always @(posedge clk or posedge rst) begin
        if (rst)
            bus_busy <= 0;
        else if (start_detect)
            bus_busy <= 1;
        else if (stop_detect)
            bus_busy <= 0;
    end
    
    assign bus_idle = ~bus_busy;
        
    localparam IDLE          = 4'd0;
    localparam START         = 4'd1;
    localparam SEND_ADDR     = 4'd2;
    localparam ADDR_ACK      = 4'd3;
    localparam SEND_DATA     = 4'd4;
    localparam DATA_ACK      = 4'd5;
    localparam STOP          = 4'd6;
    localparam WAIT_BUS_FREE = 4'd7;
    localparam REC_DATA      = 4'd8;
    localparam MASTER_ACK    = 4'd9;
    
    always @(*) begin
        next_state = state;
        
        case(state)
            IDLE : begin
                if (start)
                    next_state = START;
            end
            
            START : begin
                //next_state = SEND_ADDR;
                if (bit_count >= 5)          // <--- FIX 2: Hold START for 50ns
                    next_state = SEND_ADDR;
                else
                    next_state = START;
            end
            
            SEND_ADDR : begin
                if (arb_lost)// && scl_rise)
                    next_state = WAIT_BUS_FREE;
                else if (bit_count == 8)
                    next_state = ADDR_ACK;
            end
            
            ADDR_ACK : begin
                if (scl_fall) begin
                    if(ack_received) begin
                        if (target_slave[0] == 1'b0)
                            next_state = SEND_DATA;
                        else
                            next_state = REC_DATA;
                    end
                    else //if (ack_count >= 5)
                        next_state = STOP;
                end
            end
            
            SEND_DATA : begin
                if (arb_lost)
                    next_state = WAIT_BUS_FREE;
                else if (bit_count == 8)
                    next_state = DATA_ACK;
            end
            
            DATA_ACK : begin
                if (scl_fall) begin
                    if (ack_received)
                        next_state = STOP;
                    else// if (ack_count >= 5)
                        next_state = STOP;
                end
            end
            
            STOP : begin
//                if (scl_fall)
                if (bit_count >= 9)
                    next_state = IDLE;
                else
                    next_state = STOP;
            end
            
            WAIT_BUS_FREE: begin
                if (bus_idle)
                    next_state = START;
                else 
                    next_state = WAIT_BUS_FREE;
            end
            
            REC_DATA: begin
                if (arb_lost)
                    next_state = WAIT_BUS_FREE;
                else if (bit_count == 8)
                    next_state = MASTER_ACK;
            end
            
            MASTER_ACK: begin
                if (scl_fall)
                    next_state = STOP;
            end
                     
        endcase
    end            
    
    always @(posedge clk or posedge rst) begin
        if (rst)
            state <= IDLE;
        else
            state <= next_state;
    end
    
    parameter divider = 5;
    
    reg[15:0] count;
    
    reg scl_phase;
    
    wire scl_fall;
    wire scl_rise;
    
//    always @(posedge clk or posedge rst) begin
//        if (rst) begin
//            count <= 0;
//            scl_phase <= 0;
//        end
        
//        else if (state != IDLE && state != START) begin
//            if (count == divider - 1) begin
//                count <= 0;
//                scl_phase <= ~scl_phase;
//            end
            
//            else 
//                count <= count + 1;
//        end
//    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            count <= 0;
            scl_phase <= 0;
        end
        
        else if (state == IDLE || state == START || state == WAIT_BUS_FREE) begin
            count <= 0;
            scl_phase <= 0;
        end
        
        else begin        
            if (count == divider - 1) begin
                count <= 0;
                scl_phase <= ~scl_phase;
            end
            
            else 
                count <= count + 1;
        end
    end
        assign scl_fall = (count == divider - 1) && (scl_phase == 1);
        assign scl_rise = (count == divider - 1) && (scl_phase == 0);

    reg sda_d;

    always @(posedge clk or posedge rst) begin
        if (rst)
            sda_d <= 1'b1;
        else
            sda_d <= sda;
    end
    
    wire sda_rise = ~sda_d & sda;
    wire sda_fall = sda_d & ~sda;
    
    wire start_detect = sda_fall && scl;
    wire stop_detect  = sda_rise && scl;
    
//    always @(*) begin

//    case(state)

//        IDLE,
//        START:
//            scl_drive = 0;

//        default :
//            scl_drive = ~scl_phase;

//    endcase
//    end

    always @(*) begin
        if (arb_lost || state == WAIT_BUS_FREE) 
            scl_drive = 0;  
        else begin
            case(state)
                IDLE,
                START:
                    scl_drive = 0;
                default :
                    scl_drive = ~scl_phase;
            endcase
        end
    end
    
    always @(posedge clk or posedge rst) begin
        if (rst)
            bit_count <= 0;
        else if (state == IDLE || state ==  WAIT_BUS_FREE) 
            bit_count <= 0;
        else if (state == START) begin
            if (bit_count >= 5)
                bit_count <= 0;
            else
                bit_count <= bit_count + 1;
        end           
        else if ((state == SEND_ADDR || state == SEND_DATA || state == REC_DATA) && scl_fall && !arb_lost)
            bit_count <= bit_count + 1;
        else if (state == ADDR_ACK || state == DATA_ACK || state == MASTER_ACK)
            bit_count <= 0;   
        else if (state == STOP)
            bit_count <= bit_count + 1;
    end
    
    always @(*) begin
        shift_en = 0;
        
        case(state)
            SEND_ADDR,
            ADDR_ACK,
            SEND_DATA,
            DATA_ACK:
                shift_en = 1;
            default:
                shift_en = 0;
        endcase
    end
    
    //slave address
    always @(posedge clk or posedge rst) begin
        if(rst)
            tx_data <= 8'h00;
    
        else if(state == START || state == WAIT_BUS_FREE)
            tx_data <= target_slave;
        else if(state == SEND_ADDR && scl_fall)
            tx_data <= tx_data << 1;
    end
    
    always @(posedge clk or posedge rst) begin
        if (rst)
            rx_data <= 8'h00;
        
        else if (state == REC_DATA && scl_fall)
            rx_data <= {rx_data[6:0], sda};
    end
    
    always @(*) begin
        sda_drive = 0;
        if (arb_lost || state == WAIT_BUS_FREE)
            sda_drive = 0;
        else begin
            case(state)
                START     : sda_drive = 1;
                SEND_ADDR : sda_drive = ~tx_data[7];
                ADDR_ACK  : sda_drive = 0;
                SEND_DATA : sda_drive = ~data_reg[7];
                DATA_ACK  : sda_drive = 0;
                STOP      : sda_drive = (bit_count < 7) ? 1'b1 : 1'b0;

            endcase
        end
    end
    
    always @(posedge clk or posedge rst) begin
        if (rst)
            data_reg <= 8'h00;
        else if (state == ADDR_ACK)
            data_reg <= data_value;
        else if (state == SEND_DATA && scl_fall)
            data_reg <= data_reg << 1;
    end
    
//    always @(posedge clk or posedge rst) begin
//        if(rst)
//            ack_received <= 0;
    
//        else if ((state == ADDR_ACK || state == DATA_ACK)&& scl)
//            ack_received <= ~sda;
//        else ack_received <= 0;
//    end
    
    always @(posedge clk or posedge rst) begin
        if(rst)
            ack_received <= 0;
        else if (state != ADDR_ACK && state != DATA_ACK)
            ack_received <= 0;
        else if (scl_rise)
            ack_received <= ~sda;
    end
    
    always @(posedge clk or posedge rst) begin
        if (rst)
            ack_count <= 0;
        else if (state != ADDR_ACK && state != DATA_ACK)
            ack_count <= 0;
        else if (scl_rise)
            ack_count <= ack_count + 1;
    end
    
//arbitration

    assign tx_bit = 
        (state == SEND_ADDR) ? tx_data[7] :
        (state == SEND_DATA) ? data_reg[7] :
        1'b1;
    
    always @(posedge clk or posedge rst) begin
        if (rst)
            arb_lost <= 0;
        else if (state == START)
            arb_lost <= 0;
        else if (start_detect)// && bus_idle)
            arb_lost <= 0;
        else if ((state == SEND_ADDR || state == SEND_DATA) && scl_rise) begin
            if (tx_bit && !sda)
                arb_lost <= 1;
        end
    end
            
    
endmodule


module master(
    input clk,
    input rst,
    input start,
    input [7:0] target_slave,
    input [7:0] data_value,
    inout scl,
    inout sda
    );

    wire scl_en;
    
    wire sda_drive;
    wire scl_drive;
    
    assign sda = (sda_drive) ? 1'b0 : 1'bz;
    assign scl = scl_drive ? 1'b0 : 1'bz;
    
    control_master ctrl_mas_inst(.clk(clk),
                             .rst(rst),
                             .start(start),
                             .target_slave(target_slave),
                             .data_value(data_value),
                             .shift_en(scl_en),
                             .sda(sda),
                             .scl(scl),
                             .sda_drive(sda_drive),
                             .scl_drive(scl_drive)
                          );
        
endmodule