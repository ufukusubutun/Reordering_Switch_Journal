#!/bin/bash

node_id=$1; # should be from 0 to 11
flow_gen_id=$2; # should be from 0 to 199
duration=$3
to_other_sink=$4
port_num=$5 #  $(expr 60000 + $(expr $(expr 10 \* $node_id) + $flow_gen_id))
cap=$6



TO_EXP_SINK=0
TO_SINK_2=1


destination='sink'
if [[ "$TO_SINK_2" == "$to_other_sink"  ]]; then
    destination='sink2'    
fi


#echo "=======================================================================================================";
#echo node_id: $node_id flow_id: $flow_gen_id "Setting up flows at port $port_num to iperf3 servers at $destination."
#echo "This will last $duration seconds."
#echo "======================================================================================================";


# make a new directory and save everything there.
# no modifications
mkdir -p ~/n$node_id-f$flow_gen_id
rm -f ~/n$node_id-f$flow_gen_id/*

rm -f ~/n${node_id}_flowgen.log
touch ~/n${node_id}_flowgen.log


#rand_delay_m=$(expr $(expr 8000 \* 10 ) / $cap ) # 1 MB/cap(mbps) in ms x 10 (8000/cap) 
#rand_delay_m=$(expr $(expr 16000 \* 10 ) / $cap ) # 2 MB/cap(mbps) in ms x 10 (8000/cap)
#rand_delay_m=$(expr $(expr 20000 \* 10 ) / $cap ) # 2.5 MB/cap(mbps) in ms x 10 (8000/cap) 
#rand_delay_m=$(expr $(expr 24000 \* 10 ) / $cap ) # 3 MB/cap(mbps) in ms x 10 (8000/cap)
#rand_delay_m=$(expr $(expr 32000 \* 10 ) / $cap ) # 4 MB/cap(mbps) in ms x 10 (8000/cap)
#rand_delay_m=$(expr $(expr 40000 \* 10 ) / $cap ) # 5 MB/cap(mbps) in ms x 10 (8000/cap) 
#rand_delay_m=$(expr $(expr 80000 \* 10 ) / $cap ) # 10 MB/cap(mbps) in ms x 10 (8000/cap) 
rand_delay_m=$(expr $(expr 160000 \* 10 ) / $cap ) # 20 MB/cap(mbps) in ms x 10 (8000/cap) 
#rand_delay_m=$(expr $(expr 240000 \* 10 ) / $cap ) # 30 MB/cap(mbps) in ms x 10 (8000/cap) 
#rand_delay_m=$(expr $(expr 280000 \* 10 ) / $cap ) # 35 MB/cap(mbps) in ms x 10 (8000/cap) 
#rand_delay_m=$(expr $(expr 320000 \* 10 ) / $cap ) # 40 MB/cap(mbps) in ms x 10 (8000/cap) 


flow_size_cap_bytes=10000000000 # 10GB
#flow_size_cap_bytes=1000000000 # 1GB
#flow_size_cap_bytes=100000000 # 100MB


# random first wait
flwgen_start_time=$(date +%s%N)
# calculate the random wait and record timestamp
random_wait=$(shuf -i 0-$(expr $rand_delay_m \* 3) -n 1) # random wait in ms

							# DO NOT TOUCH THESE ZEROS!!
while [ $(expr $(expr $(date +%s%N) - $flwgen_start_time) / 1000000) -lt $random_wait ]; do
	sleep .001 # sleep 1 ms
done


#echo rand_delay_m= $rand_delay_m

end=$(( SECONDS + $duration))

flow_ind=0
while [ $SECONDS -lt $end ] && read line ; do
    # calculate the random wait and record timestamp
    random_wait=$(shuf -i ${rand_delay_m}-$(expr $rand_delay_m \* 3) -n 1) # random wait in ms 

    payload=$line

    # increase cap to 1 GB		#correct zeros to change
    if [ $payload -ge 2500 ] && [ $payload -le $flow_size_cap_bytes ] # ignore flow sizes larger than 1 GB and smaller than 2500B
    then
        flw_start_time=$(date +%s%N)
        iperf3 -c $destination -p $port_num -n $payload > ~/n$node_id-f$flow_gen_id/n$node_id-f$flow_gen_id-i$flow_ind.json # no longer output json, -J flag can be used
        
        ever_waited=0
        wait_start_time=$(date +%s%N)

        # wait until random wait has elapsed
        while [ $(expr $(expr $(date +%s%N) - $flw_start_time) / 1000000) -lt $random_wait ]; do
            sleep .001 # sleep 1 ms
            ever_waited=1
        done

        time_now=$(date +%s%N)
        wait_in_loop=$(expr $(expr $time_now - $wait_start_time) / 1000000)
        real_total_wait=$(expr $(expr $time_now - $flw_start_time) / 1000000)

        #                                                                                         when it started    random wait                                   real wait
        echo ${node_id}, ${flow_gen_id}, ${duration}, ${to_other_sink}, ${port_num}, ${payload}, ${flw_start_time}, ${random_wait}, $ever_waited, $wait_in_loop, $real_total_wait >> ~/n${node_id}_flowgen.log

        flow_ind=$(expr $flow_ind + 1)

    fi

done < ~/data_gen/trace_n$node_id-f$flow_gen_id.txt

if [[ $flow_gen_id -eq 1 ]]; then
    echo "node $node_id flow_gen_id $flow_gen_id flow_ind $flow_ind just terminated"  
fi




