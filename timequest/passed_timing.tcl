#-
# SPDX-License-Identifier: BSD-2-Clause
#
# Copyright (c) 2020 A. Theodore Markettos
# All rights reserved.
#
# This software was developed by SRI International and the University of
# Cambridge Computer Laboratory (Department of Computer Science and
# Technology) under DARPA contract HR0011-18-C-0016 ("ECATS"), as part of the
# DARPA SSITH research programme.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.
#

# Check that the Quartus design meets timing, outputting a list of 
# failing clocks and a warning
# loosely based on
# https://www.intel.com/content/www/us/en/programmable/support/support-resources/design-examples/design-software/timinganalyzer/exm-tq-failing-clocks-operating-condition.html

package require ::quartus::flow
package require struct::matrix
package require report
package require csv

set failure_matrix [::struct::matrix]


proc timequest_init {project_name} {
 project_open $project_name
}

proc generate_netlist {} {
    create_timing_netlist
}


proc evaluate_operating_condition {condition analyses} {
    global failure_matrix
    set operating_conditions_display_name \
        [get_operating_conditions_info -display_name $condition]
    puts $operating_conditions_display_name
    
    foreach analysis_type $analyses {
        set clock_domain_info_list [get_clock_domain_info -${analysis_type}]
        set clock_fmax_list [get_clock_fmax_info]
        foreach domain_info $clock_domain_info_list {
            #puts "$analysis_type $domain_info"
            foreach { clock_name slack endpoint_tns edge_tns } $domain_info \
            { break }
            if { 0 > $slack } {
                set fmax_matching_freq ""
                foreach fmax_clock $clock_fmax_list {
                    set fmax_clock_name [lindex $fmax_clock 0]
                    set fmax_clock_freq [lindex $fmax_clock 1]
                    #puts "$fmax_clock_name $clock_name"
                    if { $fmax_clock_name == $clock_name } {
                        set fmax_matching_freq $fmax_clock_freq
                        break
                    }
                }
                $failure_matrix add row \
			        [list $condition $slack $endpoint_tns $clock_name \
					 $condition $analysis_type $fmax_matching_freq]

                #dict set result condition $condition analysis $analysis_type slack $slack endpoint_tns $endpoint_tns edge_tns $edge_tns
                #lappend results result
                #dict set result condition $condition
            }
        }
    }


}


proc iterate_over_conditions {} {
    global failure_matrix
    set all_operating_conditions_col [get_available_operating_conditions]
    set analysis_list [list "setup" "hold" "recovery" "removal"]

    #set results [list]
    #global results
    $failure_matrix add columns 7

    foreach_in_collection operating_condition_obj $all_operating_conditions_col {
        set_operating_conditions $operating_condition_obj
        update_timing_netlist

        evaluate_operating_condition $operating_condition_obj $analysis_list
    }
    
    set failures [$failure_matrix rows]
    if { [$failure_matrix cells] > 0 } {
        puts "\033\[01;31m****************************"
        puts "FAILED TIMING - $failures failures"
	for {set failure_idx 0} {$failure_idx < $failures} {incr failure_idx} {
		set failure [$failure_matrix get row $failure_idx]
		set clock_name [lindex $failure 3]
		set slack [lindex $failure 1]
		set fmax [lindex $failure 6]
		set condition [lindex $failure 0]
		puts "Failed: clock $clock_name condition $condition Fmax $fmax slack $slack"
	}
        puts "**************************** \033\[;0m\n"
    }
    ::csv::writematrix $failure_matrix stderr

    return $failure_matrix
}

proc write_jmeter {  } {
    global failure_matrix
    set csv_matrix [::struct::matrix]
    $csv_matrix add columns 23


    set timeStamp [clock seconds]
    set elapsed 1
    set testlabel "Test"
    set responseCode 200
    set responseMessage "OK"
    set threadName "bob"
    set dataType "text"
    set success "true"
    set failureMessage ""
    set bytes 0
    set sentBytes 0
    set grpThreads 1
    set allThreads 1
    set URL "http://example.com/"
    set Filename "index.html"
    set latency 123
    set connect 456
    set httpencoding ""
    set SampleCount 1
    set ErrorCount clockFreq
    set Hostname "localhost"
    set IdleTime 0
    set Variables ""

    set failures [$failure_matrix rows]
    for {set failure_idx 0} {$failure_idx < $failures} {incr failure_idx} {
        set failure [$failure_matrix get row $failure_idx]
        set success "false"
        set testlabel [lindex $failure 3]
        set elapsed [lindex $failure 6]
        $csv_matrix add row \
            [list $timeStamp $elapsed $testlabel $responseCode $responseMessage $threadName \
		        $dataType $success $failureMessage $bytes $sentBytes $grpThreads $allThreads \
		        $URL $Filename $latency $connect $httpencoding $SampleCount $ErrorCount $Hostname $IdleTime \
                $Variables ]

    }

    ::csv::writematrix $csv_matrix stderr

}


iterate_over_conditions
write_jmeter

