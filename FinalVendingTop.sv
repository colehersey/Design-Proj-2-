//-------------------------------------------------------------
// FinalVendingTop.sv
// Description:
//    A SystemVerilog design for a vending machine
//    - Accepts nickels, dimes, and quarters
//    - 'Vends' or dispenses an item at 50 cents
//    - Has the ability for a full refund before 50 cents
//    - Returns the change in the highest denomination possible
//    - Designed using simple counters and flags for simplicity
//    
// Author: Cole Hersey
// Date:   5/27/25        
//-------------------------------------------------------------

module VendingMachineTop(
    input logic clk,                                     // clk signal -> slowed for real hardware implementation
    input logic reset,                                   // async reset
    input logic nickel,                                  
    input logic dime,                                    
    input logic quarter,                                 
    input logic refund,                                  // refund request (synchronous)
    output logic vend,                                   // vend signal
    output logic nickel_out,                             
    output logic dime_out,                               
    output logic quarter_out,                            
    output logic [6:0] balance,                          // current balance in cents
    output logic [6:0] refund_amount,                    // amount to be refunded
    output logic refunding                               // refund in progress flag
);
  
    // Logic for the main vending machine 
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            // reset all of the states
            balance <= 0;
            vend <= 0;
            nickel_out <= 0;
            dime_out <= 0;
            quarter_out <= 0;
            refund_amount <= 0;
            refunding <= 0;
        end else begin
            // default outputs are all 0 to begin
            vend <= 0;
            nickel_out <= 0;
            dime_out <= 0;
            quarter_out <= 0;

            // Refund request (starts the process)
            if (refund && balance > 0 && !refunding) begin
                refunding <= 1;
                refund_amount <= balance;
                balance <= 0;
            end

            // Active refunding logic
            // Dispensing one coin (prioritizes quarters, then dimes, then nickels) per clock cycle
            if (refunding) begin
                if (refund_amount >= 25) begin
                    quarter_out <= 1;
                    refund_amount <= refund_amount - 25;
                end else if (refund_amount >= 10) begin
                    dime_out <= 1;
                    refund_amount <= refund_amount - 10;
                end else if (refund_amount >= 5) begin
                    nickel_out <= 1;
                    refund_amount <= refund_amount - 5;
                end else begin
                    refunding <= 0;
                end
            end

            // accepts a coin input (only when refunding not in progress)
            if (!refunding) begin
                if (nickel) begin
                    balance <= balance + 5;
                end else if (dime) begin
                    balance <= balance + 10;
                end else if (quarter) begin
                    balance <= balance + 25;
                end

                // checks to see if the vending balance has been exceeded
                if (balance >= 50) begin
                    vend <= 1;
                    if (balance > 50) begin
                        // refund logic to give change if the current balance exceeds 50 cents
                        refunding <= 1;
                        refund_amount <= balance - 50;
                    end
                    balance <= 0;  // manual reset of balance after vending has occured
                end
            end
        end
    end
endmodule

module SevenSegmentDecode(
    input logic [3:0] digit,
    output logic [6:0] segments
);
    always_comb begin
        case (digit)
            //                   gfe_dcba
            4'h0: segments <= 7'b100_0000; // 0
            4'h1: segments <= 7'b111_1001; // 1
            4'h2: segments <= 7'b010_0100; // 2
            4'h3: segments <= 7'b011_0000; // 3
            4'h4: segments <= 7'b001_1001; // 4
            4'h5: segments <= 7'b001_0010; // 5
            4'h6: segments <= 7'b000_0010; // 6
            4'h7: segments <= 7'b111_1000; // 7
            4'h8: segments <= 7'b000_0000; // 8
            4'h9: segments <= 7'b001_1000; // 9
            4'hA: segments <= 7'b000_1000; // A
            4'hB: segments <= 7'b000_0011; // b
            4'hC: segments <= 7'b100_0110; // C
            4'hD: segments <= 7'b010_0001; // d
            4'hE: segments <= 7'b000_0110; // E
            4'hF: segments <= 7'b000_1110; // F
        endcase
    end
endmodule

module Parser #(
    parameter N = 8  // big enough to handle all inputs
) (
    input  logic [N-1:0] value,
    output logic [3:0] tens,
    output logic [3:0] ones
);
    always_comb begin
        tens = value / 10;
        ones = value % 10;
    end
endmodule

module ClockDivider(
    input logic clk_in,       // 50 MHz board clock (20 ns period)
    input logic reset,        // async reset
    output logic clk_out      // Output: ~1 Hz clock (1-second period)
);
    // We need a total period of 1 second.
    // At 50 million cycles/s, 1 second = 50,000,000 clock cycles.
    // We'll toggle clk_out every 25 million cycles -> one full cycle every 50 million cycles.
    logic [26:0] counter;  

    always_ff @(posedge clk_in or posedge reset) begin
        if (reset) begin
            // On reset: clear counter and clock
            counter <= 0;
            clk_out <= 0;
        end else if (counter == 24_999_999) begin
            // when the counter reaches 25 million:
            // - resest counter to 0
            // - then toggle clk_out
            counter <= 0;
            clk_out <= ~clk_out;
        end else begin
            counter <= counter + 1;
        end
    end
endmodule

module FinalVendingMachine(
    input  logic CLOCK_50,             // 50 MHz board clock
    input  logic reset,                // Reset switch
    input  logic refund_button,        // Refund switch
    input  logic nickel_switch,        // Nickel input switch
    input  logic dime_switch,          // Dime input switch
    input  logic quarter_switch,       // Quarter input switch

    output logic [6:0] balance_ones_display,      // Balance ones digit 
    output logic [6:0] balance_tens_display,      // Balance tens digit 
    output logic [6:0] refund_ones_display,       // Refund ones digit 
    output logic [6:0] refund_tens_display,       // Refund tens digit 

    output logic vend_led,              // vend in progress indicator (high for 1 clock cycle when vending)
    output logic refunding_led          // refund indicator (high during the entire refund process)
);
    // internal slowed clock signal
    logic clk_slow;

    // vending machince core logic signals
    logic [6:0] balance, refund_amount;
    logic vend, nickel_out, dime_out, quarter_out;
    logic refunding;

    // clock divider to slow the fpga clock to 1Hz
    ClockDivider clkdiv (
        .clk_in(CLOCK_50),
        .reset(~reset),
        .clk_out(clk_slow)
    );

    // vending machine logic
    VendingMachineTop vending_logic (
        .clk(clk_slow),
        .reset(~reset),
        .nickel(nickel_switch),
        .dime(dime_switch),
        .quarter(quarter_switch),
        .refund(~refund_button),
        .vend(vend),
        .nickel_out(nickel_out),
        .dime_out(dime_out),
        .quarter_out(quarter_out),
        .balance(balance),
        .refund_amount(refund_amount),
        .refunding(refunding)
    );

    // Parser to split the balance into decimal digits
    logic [3:0] balance_tens, balance_ones;
    Parser #(7) parse_balance (
        .value(balance),
        .tens(balance_tens),
        .ones(balance_ones)
    );

    // Parser to split the refund amount into decimal digits
    logic [3:0] refund_tens, refund_ones;
    Parser #(7) parse_refund (
        .value(refund_amount),
        .tens(refund_tens),
        .ones(refund_ones)
    );

    // Seven segment display decoders
    SevenSegmentDecode seg0 (.digit(balance_ones), .segments(balance_ones_display));
    SevenSegmentDecode seg1 (.digit(balance_tens), .segments(balance_tens_display));
    SevenSegmentDecode seg2 (.digit(refund_ones),  .segments(refund_ones_display));
    SevenSegmentDecode seg3 (.digit(refund_tens),  .segments(refund_tens_display));

    // assign the vend and refund indicators
    assign vend_led = vend;
    assign refunding_led = refunding;
endmodule
