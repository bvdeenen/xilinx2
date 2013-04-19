setMode -bscan
setCable -p auto
addDevice -position 1 -file xilinx2.bit
addDevice -position 2 -part "xcf04s"
program -e -p 1
quit
