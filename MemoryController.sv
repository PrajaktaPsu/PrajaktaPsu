//////////////////////////////////////////////////////////////////////////////////
// MemoryController.sv - Memory Controller Simulation
//
// Author:	        Keerthi Venkatraman
//						Prajakta Patil
//						Arjun Preetham Murugesh Ekalaivan
// Version:         	2.0
// Last Modified:	09-DEC-2021
//
// Description:
// ------------
// Simulation of a DRAM Memory Controller to follow Open
// Page Policy - Page empty, Page Hit, Page Miss 
//////////////////////////////////////////////////////////////////////////////////

module MemoryController;

logic [1:0]bank,bank_group;
logic [15:0]row;
logic [9:0]column;
int debug=0;
int file, request;
string TraceFile,input_request;

//DIMM Timing Parameters
	parameter tRCD = 24;
	parameter tCWL = 20;
	parameter tCAS = 24;
	parameter tBURST = 4;  
	parameter tRAS = 52;
	parameter tRTP =12;
	parameter tRP = 24;

//Structure created to store the cputime,opcode and memoryaddress from tracefile
typedef struct packed{
	int cputime;
	int opcode;
	logic[32:0] mem_address;
	longint unsigned counter; 				//Used to keep track of the process time for the request added to the queue
	
} traceFileInfo;

traceFileInfo queue[$:15]; 									//queue created of length 16
traceFileInfo tdetails = {1'd0, 1'd0, 33'b0};			// initialize the struct with 0 values

logic push_flag=1'b1;														//For entry of last element of file in the queue
longint unsigned sim_time=10'd0; 								//Simulation time
logic open_bank [3:0]= {0, 0, 0, 0};								//Bank values
logic [3:0] [14:0] open_row ;
logic [3:0] [14:0] row_compare;									//to compare the previous row with the current request row
logic open_bank_group [3:0] = {0,0,0,0};
int return_value=0;															// Used in function to return the total time after executing the time
integer outputfile;															
longint unsigned previous_request_process_time=0;
string outputfilename;
int d, scan, f_out;
initial begin
 d = $value$plusargs("debug=%d", debug);
	if($value$plusargs("TraceFile=%s", TraceFile)) begin
	
	file = $fopen(TraceFile, "r");
	f_out = $value$plusargs("outputfilename=%s",outputfilename);
	if(f_out) begin
		outputfile = $fopen(outputfilename,"w"); 
		end
		
	if(file ==0) begin
		if(debug==1) begin
		$display("ERROR:TraceFile is not present");end
		$stop;
	end
	
	else begin
		while(!$feof(file) || queue.size()!=0 || push_flag==1) begin
		
			if (tdetails == 0 && !$feof(file))
			begin
				scan=$fgets(input_request,file);
				request=$sscanf(input_request,"%d %d %h",tdetails.cputime,tdetails.opcode,tdetails.mem_address);
			
			if(queue.size()==0) begin
				sim_time=tdetails.cputime; //for time advancement
			end
			else
				sim_time=sim_time+1;
			end

		if(request!=3 ) begin
			if(debug==1)
			$display("ERROR: The incoming request format is incorrect");
			tdetails={1'd0,1'd0,33'b0};
			request=3;
		end
		
		else if(tdetails.cputime<queue[0].cputime && !$feof(file)) begin
			if(debug==1)
			$display("ERROR: The request format is incorrect please check your cputime %p", tdetails);
			$stop;
		end
		
		else if(tdetails.opcode>2) begin
			if(debug==1)
			$display("ERROR: The opcode is incorrect please check your opcode %p",tdetails);
			$stop;
		end
		
		else begin
		
		if(queue.size() <16 && !$feof(file) && sim_time>=tdetails.cputime) begin
			
			if(queue.size()==0) begin
				sim_time=tdetails.cputime; //for time advancement
			end
				
				queue.push_front(tdetails);
				queue[0].counter=sim_time+Policy_Delay(queue[0],sim_time);
				tdetails= {1'd0, 1'd0, 33'b0};
				if(debug==1)
				$display("Inserting: sim_time=%0d cputime=%0d mem_address=%0h counter=%0d",sim_time,queue[0].cputime,queue[0].mem_address,queue[0].counter);
		
			if (sim_time==(queue[(queue.size())-1].counter)) begin		
															//checking if the elements in queue have completed Appropriate DRAM cycles
				if(debug==1)
				$display("Popping: Simtime=%0d Queue=%0p",sim_time,queue[(queue.size())-1]); 		
				 void'(queue.pop_back());	//Popping the elements
				end
				
				sim_time=sim_time+1;
			end
		
		else begin
			if(queue.size()==0)
			begin
				sim_time=tdetails.cputime;
			end
			
			if (queue.size() <16 && $feof(file) && push_flag == 1 && sim_time>=tdetails.cputime)
			begin
				queue.push_front(tdetails);
				queue[0].counter=sim_time+Policy_Delay(queue[0],sim_time);
				tdetails= {1'd0,1'd0,33'b0};
				push_flag = 0;
				if(debug==1)
				$display("Inserting: sim_time=%0d cputime=%0d mem_address=%0h counter=%0d",sim_time,queue[0].cputime,queue[0].mem_address,queue[0].counter);
			end
			
			if (sim_time>=(queue[(queue.size())-1].counter)) begin
			if(debug==1)
			$display("Popping: Simtime=%0d Queue=%0p",sim_time,queue[(queue.size())-1]); 
			void'(queue.pop_back()); 							//Popping the elements
				
			end
			
			if(queue.size()==0) begin
				sim_time=tdetails.cputime;
			end
			else
				sim_time=sim_time+1;
			end
		end
end
end
end
end


function int Policy_Delay (traceFileInfo queue_details, longint unsigned out_time);
begin
			
			bank_group = queue_details.mem_address[7:6];		
			bank = queue_details.mem_address[9:8];
			column = {queue_details.mem_address[16:10],queue_details.mem_address[5:3]};
			row = queue_details.mem_address[32:17];
			
			if (out_time>=previous_request_process_time)
				return_value = 0;
			else
				return_value = previous_request_process_time-out_time;

			if(open_bank_group[bank_group]==0) begin					
			
				if(open_bank[bank]==0)
					begin
						open_bank_group[bank_group]=1;
						
						open_bank[bank]=1;
						open_row [bank] =row;
					
					//Page Empty Condition
					$fwrite(outputfile,"%0d ACT %0d %0d %0h\n",out_time+return_value,bank_group, bank, row);
					return_value = return_value+tRCD;
					
					//If the request is for write
					if(queue_details.opcode==1) begin
						 		
						$fwrite(outputfile,"%0d WR %0d %0d %0h\n", out_time+return_value, bank_group, bank, column);
						return_value = return_value+tCWL+tBURST;
					end
					//if the request is for read or instruction fetch
					else begin	  
						
						$fwrite(outputfile,"%0d RD %0d %0d %0h\n",out_time+return_value, bank_group, bank, column);
						return_value = return_value+tCAS+tBURST;
						end
				end
				
			end
			
			else if(open_bank_group[bank_group]==1)						
			begin
			
			if (open_bank[bank]==0) begin
				
				open_bank[bank]=1;
				open_row [bank] =row;
				$fwrite(outputfile,"%0d ACT %0d %0d %0h\n",out_time+return_value,bank_group, bank, row);
				return_value = return_value+tRCD;
					
					if(queue_details.opcode==1) begin		
						$fwrite(outputfile,"%0d WR %0d %0d %0h\n", out_time+return_value, bank_group, bank, column);
						return_value = return_value+tCWL+tBURST;
					end
					else begin	  		
						$fwrite(outputfile,"%0d RD %0d %0d %0h\n",out_time+return_value, bank_group, bank, column);
						return_value = return_value+tCAS+tBURST;
					end
			end
			else if (open_bank[bank]==1)
				begin
					row_compare [bank] = row;
					if (open_row[bank]==row_compare[bank]) begin
						if(queue_details.opcode==1) begin
							$fwrite(outputfile,"%0d WR %d %d %h\n",out_time+return_value, bank_group, bank, column);//hit
							return_value = return_value+tCWL+tBURST;
						end
						else begin			  
							$fwrite(outputfile,"%0d RD %0d %0d %0h\n", out_time+return_value,bank_group, bank, column);
							return_value = return_value+tCAS+tBURST;		 //read command is issued
						end
					end 
					else  begin
						
					open_row[bank]=row;
					//Page Miss Condition
					$fwrite(outputfile,"%0d PRE %0d %0d\n", out_time+return_value,bank_group, bank);
					return_value=return_value+tRP;
						
					$fwrite(outputfile,"%0d ACT %0d %0d %0h\n",out_time+return_value,bank_group, bank, row);//miss
					return_value = return_value+tRCD;
							
					if(queue_details.opcode==1) begin			
								$fwrite(outputfile,"%0d WR %0d %0d %0h\n", out_time+return_value,bank_group, bank, column);
								return_value = return_value+tCWL+tBURST; 	//Write command is issued
					end
					else begin			  
						$fwrite(outputfile,"%0d RD %0d %0d %0h\n", out_time+return_value,bank_group, bank, column);
						return_value = return_value+tCAS+tBURST;	//read command is issued
					end
			end
			end
			
			end

	previous_request_process_time=out_time+return_value;
	return (return_value);
end
endfunction

endmodule:MemoryController