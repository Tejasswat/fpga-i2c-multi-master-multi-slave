module top(input clk,
           input rst,
           input start_1,
           input [7:0] target_slave_1,
           input [7:0] data_value_1,
           input start_2,
           input [7:0] target_slave_2,
           input [7:0] data_value_2
           );

    wire scl_bus;
    wire sda_bus;
    
    pullup(scl_bus);
    pullup(sda_bus);
        
    master master_1 (
        .clk(clk),
        .rst(rst),
        .start(start_1),
        .target_slave(target_slave_1),
        .data_value(data_value_1),
        .scl(scl_bus),
        .sda(sda_bus)
        );
    
    master master_2 (
        .clk(clk),
        .rst(rst),
        .start(start_2),
        .target_slave(target_slave_2),
        .data_value(data_value_2),
        .scl(scl_bus),
        .sda(sda_bus)
        );
    
    slave #(.SLAVE_ADDR(8'h50))
        slave_1 (
        .clk(clk),
        .rst(rst),
        .scl(scl_bus),
        .sda(sda_bus)
        );
    
    slave #(.SLAVE_ADDR(8'h60))
        slave_2 (
        .clk(clk),
        .rst(rst),
        .scl(scl_bus),
        .sda(sda_bus)
        );
    
endmodule