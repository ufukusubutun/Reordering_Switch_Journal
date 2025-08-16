# Define an empty array to store the base names
exp_save_names=()

# Loop through cap
for cap in 5000 #500 4500
do
    # Loop through lam 
    for lam in 5 # 9
    do
        # Loop through lam 
        for numgen in 180 # 200 # 9
        do
            # Loop through N 8 100
            for N in 8 #8 100
            do
                # Loop through base delay 10 20
                for RTT in 20 # 20
                do
                    # Loop through algs 1, 2, 3
                    for alg in 1 #2 3
                    do
			for waittime in 20 # 20
			do
                        	# Add each combination of xxxx and the number to the array
                        	exp_save_names+=(exp1-alg${alg}-RTT${RTT}-N${N}-lam${lam}-numgen${numgen}-wait${waittime}-cap${cap}-flowsizecap10000)
			done
                    done
                done
            done
        done
    done
done

# Loop through the list of base names
for exp_save_name in "${exp_save_names[@]}"
do
    # Extract information from the ingress_cap1.pcap file and save it to xxx_incap1.csv
    tshark -r "${exp_save_name}-ingress_cap1.pcap" -T fields -e frame.time_epoch -e ip.src -e ip.dst -e tcp.srcport -e tcp.dstport -e tcp.seq -e tcp.seq_raw -e tcp.ack -e tcp.ack_raw -e tcp.len -e tcp.flags -e ip.id -e ip.len -E header=y -E separator=, -E occurrence=a > ${exp_save_name}_incap1.csv &

    # Extract information from the ingress_cap2.pcap file and save it to xxx_incap2.csv
    tshark -r "${exp_save_name}-ingress_cap2.pcap" -T fields -e frame.time_epoch -e ip.src -e ip.dst -e tcp.srcport -e tcp.dstport -e tcp.seq -e tcp.seq_raw -e tcp.ack -e tcp.ack_raw -e tcp.len -e tcp.flags -e ip.id -e ip.len -E header=y -E separator=, -E occurrence=a > ${exp_save_name}_incap2.csv &

    # Extract information from the ingress_cap3.pcap file and save it to xxx_incap3.csv
    tshark -r "${exp_save_name}-ingress_cap3.pcap" -T fields -e frame.time_epoch -e ip.src -e ip.dst -e tcp.srcport -e tcp.dstport -e tcp.seq -e tcp.seq_raw -e tcp.ack -e tcp.ack_raw -e tcp.len -e tcp.flags -e ip.id -e ip.len -E header=y -E separator=, -E occurrence=a > ${exp_save_name}_incap3.csv &

    # Extract information from the egress_cap1.pcap file and save it to xxx_outcap1.csv
    tshark -r "${exp_save_name}-egress_cap1.pcap" -T fields -e frame.time_epoch -e ip.src -e ip.dst -e tcp.srcport -e tcp.dstport -e tcp.seq -e tcp.seq_raw -e tcp.ack -e tcp.ack_raw -e tcp.len -e tcp.flags -e ip.id -e ip.len -E header=y -E separator=, -E occurrence=a > ${exp_save_name}_outcap1.csv &

    # Extract information from the egress_cap2.pcap file and save it to xxx_outcap2.csv
    tshark -r "${exp_save_name}-egress_cap2.pcap" -T fields -e frame.time_epoch -e ip.src -e ip.dst -e tcp.srcport -e tcp.dstport -e tcp.seq -e tcp.seq_raw -e tcp.ack -e tcp.ack_raw -e tcp.len -e tcp.flags -e ip.id -e ip.len -E header=y -E separator=, -E occurrence=a > ${exp_save_name}_outcap2.csv &
done


# Wait for all background processes to complete
wait

# Zip all of the output files into a single archive
# uncomment below if wanted
#zip output_files.zip *.csv
