# The dedicated cascade uses the counter's cascade output, rather than its
# fabric divclk. Declare the reference at the downstream PLL input so older
# TimeQuest versions do not have to infer that internal reference clock.
set capture_reference_pin [get_pins -compatibility_mode {*|video_pll*|refclkin}]
if {[get_collection_size $capture_reference_pin] != 1} { error "Expected one capture PLL reference pin" }
create_clock -name native_reference -period 10.416667 $capture_reference_pin

derive_pll_clocks
derive_clock_uncertainty

# Cascaded fractional PLLs require an explicit output clock in older
# TimeQuest releases (Altera's PLL cascading application note). Replace
# only capture's derived clock, retaining its interface name for CDC cuts.
set native_source_clock [get_clocks {*|video_pll*|divclk}]
if {[get_collection_size $native_source_clock] != 1} { error "Expected one native capture clock" }
foreach_in_collection clock_id $native_source_clock {
	set native_source_name [get_clock_info -name $clock_id]
	set native_source_pin [get_clock_info -targets $clock_id]
	if {[get_collection_size $native_source_pin] != 1} { error "Expected one native capture output pin" }
}
create_clock -name $native_source_name -period 22.145 $native_source_pin
set_clock_uncertainty -setup -from [get_clocks $native_source_name] -to [get_clocks $native_source_name] 0.500
set_clock_uncertainty -hold -from [get_clocks $native_source_name] -to [get_clocks $native_source_name] 0.060

# The output PLL is reconfigured, not clock-muxed. Keep its derived startup
# native clock and add the exact CRT operating period at the same output pin.
# Only these two operating modes are exclusive; source video/SYS run together.
set output_native_clock [get_clocks {*|output_pll*|divclk}]
if {[get_collection_size $output_native_clock] != 1} { error "Expected one output PLL clock" }
foreach_in_collection clock_id $output_native_clock {
	set output_clock_pin [get_clock_info -targets $clock_id]
	if {[get_collection_size $output_clock_pin] != 1} { error "Expected one transport output pin" }
}
create_clock -name output_crt -period 23.666894537 -add $output_clock_pin
set_clock_groups -logically_exclusive -group $output_native_clock -group [get_clocks output_crt]
# Explicit guard for the manually declared reconfigured clock. Startup native
# retains the vendor-derived PLL uncertainty. These are conservative analysis
# margins, not a measured hardware jitter specification.
set_clock_uncertainty -setup -from [get_clocks output_crt] -to [get_clocks output_crt] 0.500
set_clock_uncertainty -hold -from [get_clocks output_crt] -to [get_clocks output_crt] 0.060
# Entire inactive transport legs remain reset in the opposite operating mode.
set_false_path -from [get_registers {*|native_output_bridge|*}] -to [get_clocks output_crt]
set_false_path -from [get_registers {*|crt_stream|*}] -to $output_native_clock
# Mode selection settles for 64 SYS clocks before releasing transport reset.
set_false_path -from [get_registers {*output_control|selected_crt}] -to [get_clocks {*|output_pll*|divclk output_crt}]
set_false_path -to [get_registers {*output_control|native_lock_meta *output_control|output_lock_meta *output_control|warm_done_meta}]
set_false_path -from [get_registers {*output_control|transport_reset}] -to [get_registers {*output_control|warm_reset_pipe[*]}]
set_false_path -from [get_clocks {*|pll|pll_inst|altera_pll_i|*[*].*|divclk}] -to [get_registers {*output_control|warm_reset_pipe[*]}]

# Completed-row Gray counter settles within one native source-clock period.
# First-row sequence is a held bundled payload qualified by request/ack.
set_max_delay 22.146 -from [get_registers {*|crt_stream|committed_gray[*]}] -to [get_registers {*|crt_stream|rows_meta[*]}]
set_false_path -hold -to [get_registers {*|crt_stream|rows_meta[*]}]
set_false_path -to [get_registers {*|crt_stream|ack_meta *|crt_stream|request_meta *|crt_stream|fault_meta}]
set_max_delay 22.146 -from [get_registers {*|crt_stream|first_row_sequence[*]}] -to [get_registers {*|crt_stream|first_sequence_local[*]}]
set_false_path -hold -from [get_registers {*|crt_stream|first_row_sequence[*]}] -to [get_registers {*|crt_stream|first_sequence_local[*]}]
# Asynchronous assertions originate in the SYS/reset network; do not cut the
# native/CRT synchronizers' local release data paths.
set_false_path -from [get_clocks {*|pll|pll_inst|altera_pll_i|*[*].*|divclk}] -to [get_registers {*|crt_stream|reset_native_pipe[*] *|crt_stream|reset_crt_pipe[*]}]

# core specific constraints

# Isolate the new video PLL from the framework's unrelated HDMI/audio/host
# domains. Board-to-video paths below retain explicit CDC constraints.
set victory_video_clock [get_clocks {*|video_pll|altera_pll_i|*[*].*|divclk *|output_pll|altera_pll_i|*[*].*|divclk output_crt}]
set_clock_groups -asynchronous \
	-group $victory_video_clock \
	-group [get_clocks {pll_hdmi|pll_hdmi_inst|altera_pll_i|*[0].*|divclk pll_audio|pll_audio_inst|altera_pll_i|*[0].*|divclk spi_sck hdmi_sck *|h2f_user0_clk FPGA_CLK1_50 FPGA_CLK2_50 FPGA_CLK3_50}]

# Single-bit synchronizers and slow OSD configuration: only their first
# stages are asynchronous. The second-stage paths remain fully timed.
set_false_path -to [get_registers {*|video_bridge|request_meta *|video_bridge|master_meta *|video_bridge|underflow_meta *|native_output_bridge|request_meta *|native_output_bridge|master_meta *|native_output_bridge|underflow_meta *|video_options_meta[*] *|gamma_enable_meta}]
set_false_path -from [get_clocks {*|pll|pll_inst|altera_pll_i|*[*].*|divclk}] -to [get_registers {*|video_bridge|reset_video_pipe[*] *|native_output_bridge|reset_video_pipe[*]}]

# Pointer Gray transitions must settle in less than one source-clock period.
# Relax hold only on the metastability-catching first stages.
set_max_delay 20.833 -from [get_registers {*|video_bridge|write_gray[*]}] -to [get_registers {*|video_bridge|write_gray_meta[*]}]
set_max_delay 22.146 -from [get_registers {*|video_bridge|read_gray[*]}] -to [get_registers {*|video_bridge|read_gray_meta[*]}]
set_false_path -hold -to [get_registers {*|video_bridge|write_gray_meta[*] *|video_bridge|read_gray_meta[*]}]
set_max_delay 20.833 -from [get_registers {*|native_output_bridge|write_gray[*]}] -to [get_registers {*|native_output_bridge|write_gray_meta[*]}]
set_max_delay 22.146 -from [get_registers {*|native_output_bridge|read_gray[*]}] -to [get_registers {*|native_output_bridge|read_gray_meta[*]}]
set_false_path -hold -to [get_registers {*|native_output_bridge|write_gray_meta[*] *|native_output_bridge|read_gray_meta[*]}]

# Packets are held stable until synchronized pointers qualify their read;
# the asynchronous-read register store is a deliberate FIFO data crossing.
set_false_path -from [get_registers {*|video_bridge|pixels* *|native_output_bridge|pixels*}]

# Existing framework interfaces accept slow host configuration independently
# of the raster clock: analog OSD layout, scaler mode/PLL tracking controls,
# and composite subcarrier configuration. Cut only these sources into video.
# Do not group board/video clocks globally: the FIFO Gray paths must be timed.
set_false_path -from [get_registers {
	*vga_osd|info *vga_osd|infoh[*] *vga_osd|infow[*]
	*vga_osd|infox[*] *vga_osd|infoy[*] *vga_osd|osd_enable
	*vga_osd|osd_h[*] *vga_osd|osd_t[*] *vga_osd|osd_w[*]
	cfg_done FREESCALE HDMI_PR LFB_EN LFB_FLT lowlat subcarrier
}] -to $victory_video_clock

# Framework VS first stages and slow scanline selection accept core-video
# inputs. video_calc exposes frame-held measurements to host reads; it is
# the unchanged upstream reporting interface, not a game-pixel data path.
set_false_path -from $victory_video_clock -to [get_registers {
	vs_old vs_r vs_d0 vs_d1 vsd sl_r[*] *|host_io|video_calc|dout[*]
}]
