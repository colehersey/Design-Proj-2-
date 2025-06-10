# Clear any current simulations
restart -force -nowave
delete wave *

# Add in waveforms
add wave sim:/VendingMachineTop/clk
add wave sim:/VendingMachineTop/reset
add wave sim:/VendingMachineTop/nickel
add wave sim:/VendingMachineTop/dime
add wave sim:/VendingMachineTop/quarter
add wave sim:/VendingMachineTop/refund
add wave sim:/VendingMachineTop/vend
add wave sim:/VendingMachineTop/nickel_out
add wave sim:/VendingMachineTop/dime_out
add wave sim:/VendingMachineTop/quarter_out

#Create a repeating clock of 1S
force sim:/VendingMachineTop/clk 0 0, 1 500ms -repeat 1000ms

#Set initial input values
force sim:/VendingMachineTop/nickel 0
force sim:/VendingMachineTop/dime 0
force sim:/VendingMachineTop/quarter 0
force sim:/VendingMachineTop/refund 0

# Force asynchronous reset for 10pS and run for 100ps more. 
# This should be wait for 3 cycles before moving to TB direction
force sim:/VendingMachineTop/reset 1
run 250 mS
force sim:/VendingMachineTop/reset 0
run 1000ms

# This sequence deposits 10 nickels so we should see a vend activation at the end
force sim:/VendingMachineTop/nickel 1
run 10000ms
force sim:/VendingMachineTop/nickel 0
run 1000ms
run 1000ms
run 1000ms

# This sequence deposits 5 nickels then a refund activation. We should see a refund totaling $0.25
force sim:/VendingMachineTop/nickel 1
run 1000ms
force sim:/VendingMachineTop/nickel 0
run 1000ms
force sim:/VendingMachineTop/nickel 1
run 1000ms
force sim:/VendingMachineTop/nickel 0
run 1000ms
force sim:/VendingMachineTop/nickel 1
run 1000ms
force sim:/VendingMachineTop/nickel 0
run 1000ms
force sim:/VendingMachineTop/nickel 1
run 1000ms
force sim:/VendingMachineTop/nickel 0
run 1000ms
force sim:/VendingMachineTop/nickel 1
run 1000ms
force sim:/VendingMachineTop/nickel 0
run 1000ms

force sim:/VendingMachineTop/refund 1
run 1000ms
force sim:/VendingMachineTop/refund 0
run 6000ms 