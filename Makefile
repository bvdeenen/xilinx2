all: pico

.SUFFIXES: .psm .mem .vhd .scr




TEMPLATE:= ./XASM/ROM_form.vhd

%.hex: %.psm
	./pBlazASM -3 -v -x $<

%.mem %.scr %.lst: %.psm
	./pBlazASM -3 -v -l$*.lst -m$*.mem -s$*.scr $<

# -s$*.scr only when we've preloaded data in the scratchpad
%.vhd: %.mem %.scr
	./pBlazMRG -v -s$*.scr -e$* -c$*.mem -t${TEMPLATE} $@

%.svf: %.hex
	dosemu hex2svf.exe $*.hex  $*.svf

%.xsvf: %.svf
	./XASM/svf2xsvf502 -d -i $*.svf -o $*.xsvf
	
pico: picocode.xsvf
	impact -batch update_pb.cmd
	
install: xilinx2.bit
	impact -batch install.cmd

impact:
	impact -ipf jtag-uploader.ipf

clean:
	@-rm picocode.coe picocode.fmt picocode.log picocode.vhd picocode.mem
	@-rm pass*.dat labels.txt constant.txt

distclean:
	git clean -dxf


xilinx2.ngd: picocode.vhd xilinx2.vhd debounce.vhd qdec.vhd
	mkdir -p xst/projnav.tmp
	xst -intstyle ise -ifn xilinx2.xst -ofn xilinx2.syr
	ngdbuild -intstyle ise -dd _ngo -nt timestamp -uc xilinx2.ucf -p xc3s700a-fg484-4 xilinx2.ngc xilinx2.ngd

xilinx2.pcf: xilinx2.ngd
	map -intstyle ise -p xc3s700a-fg484-4 -cm area -ir off -pr off -c 100 -o xilinx2_map.ncd xilinx2.ngd xilinx2.pcf


xilinx2.ncd: xilinx2.pcf
	par -w -intstyle ise -ol high -t 1 xilinx2_map.ncd xilinx2.ncd xilinx2.pcf
	trce -intstyle ise -v 3 -s 4 -n 3 -fastpaths -xml xilinx2.twx xilinx2.ncd -o xilinx2.twr xilinx2.pcf -ucf xilinx2.ucf

xilinx2.bit: xilinx2.ncd
	bitgen -intstyle ise -f xilinx2.ut xilinx2.ncd


