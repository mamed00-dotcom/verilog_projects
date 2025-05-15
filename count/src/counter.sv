module counter (
	input logic clk,
	input logic reset,
	input logic enable,
	output logic [7:0] count
	);
	
	always_ff @(posedge clk or posedge reset) begin
	if (reset) begin
		count <= 8'd0;
		end 
		else if (enable) begin
		count <= count + 8'd1;
		end
	end
endmodule

