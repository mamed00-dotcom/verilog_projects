module updown_counter (
    input logic clk,
    input logic reset,
    input logic enable,
    input logic up_down,
    output logic [3:0] count
);

    always_ff @(posedge clk) begin
        if (reset)
            count <= 0;
        else if (enable) begin
            if (up_down)
                count <= count + 1;
            else
                count <= count - 1;
        end
    end

endmodule

