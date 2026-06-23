`timescale 1ns / 1ps

module tb_top;

    reg clk;
    reg rst;

    reg start_1;
    reg [7:0] target_slave_1;
    reg [7:0] data_value_1;

    reg start_2;
    reg [7:0] target_slave_2;
    reg [7:0] data_value_2;

    top dut (
        .clk(clk),
        .rst(rst),

        .start_1(start_1),
        .target_slave_1(target_slave_1),
        .data_value_1(data_value_1),

        .start_2(start_2),
        .target_slave_2(target_slave_2),
        .data_value_2(data_value_2)
    );

    //----------------------------------------
    // Clock Generation (100 MHz)
    //----------------------------------------
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    //----------------------------------------
    // Stimulus
    //----------------------------------------
    initial begin

        // Reset
        rst = 1;

        start_1 = 0;
        start_2 = 0;

        target_slave_1 = 8'hA0;   // slave 0x50 write
        target_slave_2 = 8'hC0;   // slave 0x60 write

        data_value_1 = 8'h55;
        data_value_2 = 8'hAA;

        #20;
        rst = 0;

        #20;

//        //----------------------------------------
//        // Test 1 : Master 1 only
//        //----------------------------------------
//        $display("Master 1 Transaction");

//        start_1 = 1;
//        #10;
//        start_1 = 0;

//        #3000;

//        //----------------------------------------
//        // Test 2 : Master 2 only
//        //----------------------------------------
//        $display("Master 2 Transaction");

//        start_2 = 1;
//        #10;
//        start_2 = 0;

//        #3000;

        //----------------------------------------
        // Test 3 : Arbitration
        //----------------------------------------
        $display("Arbitration Test");

        target_slave_1 = 8'hA0;
        target_slave_2 = 8'hC0;

        data_value_1 = 8'h55;
        data_value_2 = 8'hAA;

        start_1 = 1;
        start_2 = 1;

        #10;

        start_1 = 0;
        start_2 = 0;

        #5000;

        $finish;
    end

    //----------------------------------------
    // Waveform Dump
    //----------------------------------------
    initial begin
        $dumpfile("i2c.vcd");
        $dumpvars(0, tb_top);
    end

endmodule