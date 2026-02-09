# TOOL TO BE USED TO RENAME EXPERIMENT FILE CAPTURES
# use the desired N for LB and 100 for non-LB 
exp_save_name='exp1-alg1-RTT20-N100-lam5-numgen160-wait20-cap1000-flowsizecap10000'

mv -i egress_cap1.pcap $exp_save_name-egress_cap1.pcap
mv -i egress_cap2.pcap $exp_save_name-egress_cap2.pcap
mv -i ingress_cap1.pcap $exp_save_name-ingress_cap1.pcap
mv -i ingress_cap2.pcap $exp_save_name-ingress_cap2.pcap
mv -i ingress_cap3.pcap $exp_save_name-ingress_cap3.pcap
mv -i combined_flowgen.log ${exp_save_name}-combined_flowgen.log
