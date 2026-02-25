
## Illustrative experiments (from Section 2)

<img src="https://github.com/ufukusubutun/Reordering_Switch_Journal/blob/main/exps/illustrative/mini_exp_topo_v5.png"  width="60%" >

We want to run a single TCP flow through the line topology above and insert controlled reordering. We then want to measure what goes on at the sender cwnd, packet arrivals at the receiver and packet drops at the bottleneck.

## Setup

Cloudlab profile for the 4 node line topology:
https://www.cloudlab.us/p/nyunetworks/four-server-line

Bring up this cloudlab profile. (You'll need a Cloudlab account!)




at each of the four nodes run the following commands to set them up:

	sudo apt-get update
	sudo apt -y install moreutils

also at each node turn off, segmentation offloading (we do not want to work with jumbo frames.)

	## TURN SEGMENTATION OFFLOADING OFF
	echo TURN SEGMENTATION OFFLOADING OFF
	# Get a list of all experiment interfaces, excluding loopback
	ifs=$(netstat -i | tail -n+3 | grep -Ev "lo" | cut -d' ' -f1 | tr '\n' ' ')
	# Turn off offloading of all kinds, if possible!
	for i in $ifs; do 
	  sudo ethtool -K $i gro off  
	  sudo ethtool -K $i lro off  
	  sudo ethtool -K $i gso off  
	  sudo ethtool -K $i tso off
	  sudo ethtool -K $i ufo off
	done


Let us set up some variables (to capture interface names at each node)
At each of the four nodes run:

	IF=$(ip route get 10.10.3.2 | grep -oP "(?<= dev )[^ ]+")
	IF_BACK=$(ip route get 10.10.1.1 | grep -oP "(?<= dev )[^ ]+")
	IF_P1=$(ifconfig | grep -B 1 "10.10.2.1 " | awk 'NR % 2 == 1' | awk '{print $1}' |  tr -d ':')
	IF_P2=$(ifconfig | grep -B 1 "10.10.2.3 " | awk 'NR % 2 == 1' | awk '{print $1}' |  tr -d ':')
	IF_P1_BACK=$(ifconfig | grep -B 1 "10.10.2.2 " | awk 'NR % 2 == 1' | awk '{print $1}' |  tr -d ':')
	IF_P2_BACK=$(ifconfig | grep -B 1 "10.10.2.4 " | awk 'NR % 2 == 1' | awk '{print $1}' |  tr -d ':')


We will be setting up a 10 Mbps bottleneck rate. At router: 

	sudo tc qdisc del dev $IF root  
	sudo tc qdisc add dev $IF root handle 1: htb default 3  
	sudo tc class add dev $IF parent 1:2 classid 1:3 htb rate 10Mbit  
	sudo tc qdisc add dev $IF parent 1:3 bfifo limit 0.8mbit 

Also set up the 10 ms artificial delay in the reverse direction. Also at router run:

	sudo tc qdisc del dev $IF_BACK root  
	sudo tc qdisc add dev $IF_BACK root netem delay 10ms 



At emulator, we want to set up both queues with different fixed delays (we will handle which packet uses which queue soon), and rate limit the reverse direction. At emulator run:

	sudo tc qdisc del dev $IF root
	sudo tc qdisc add dev $IF root handle 1: htb default 3 
	sudo tc class add dev $IF parent 1: classid 1:1 htb rate 10Mbit quantum 1514
	sudo tc class add dev $IF parent 1:1 classid 1:2 htb rate 10Mbit quantum 1514 
	sudo tc class add dev $IF parent 1:1 classid 1:3 htb rate 10Mbit quantum 1514

	sudo tc qdisc add dev $IF parent 1:2 handle 2: netem delay 40ms
	sudo tc qdisc add dev $IF parent 1:3 handle 3: netem delay 10ms

	sudo tc qdisc del dev $IF_BACK root  
	sudo tc qdisc add dev $IF_BACK root handle 1: htb default 3  
	sudo tc class add dev $IF_BACK parent 1:2 classid 1:3 htb rate 10Mbit  
	sudo tc qdisc add dev $IF_BACK parent 1:3 bfifo limit 0.8mbit


We are done setting up the queues. You can verify that the set up worked using these commands (at any node)

	tc -s -d class show dev $IF
	tc -s -d qdisc show dev $IF
	tc -s -d class show dev $IF_BACK
	tc -s -d qdisc show dev $IF_BACK

We now need to setup tagging and assignment rules to introduce reordering to every 1000th packet. Also at emulator run:

	#let's flush all previous rules
	sudo iptables -t mangle -F
	#then set up our own rule
	sudo iptables -A PREROUTING -m statistic --mode nth --every 1000 --packet 0 -t mangle --destination 10.10.3.2/24 --source 10.10.1.1/1 -j MARK --set-mark 12
	sudo iptables -A PREROUTING -m mark --mark 12 -t mangle -j RETURN

We then want to assign packets internally marked with 12 to go to the higher delay queue we set up earlier. At emulator run:

	sudo tc filter add dev $IF protocol ip parent 1: prio 0 handle 12 fw classid 1:2


To double check, you can display the rules we just set up. At emulator run:
	sudo iptables -L -n -t mangle
	tc -s -d filter show dev $IF

If something seems wrong you can use the following command to remove the rule and start over.

	#sudo iptables -t mangle -F



## Running the experiment

We will need two terminals at the client node.




#rack
sudo sysctl -w net.ipv4.tcp_recovery=1 net.ipv4.tcp_max_reordering=300 net.ipv4.tcp_sack=1 net.ipv4.tcp_dsack=1 net.ipv4.tcp_no_metrics_save=1
#adapthresh
sudo sysctl -w net.ipv4.tcp_recovery=0 net.ipv4.tcp_max_reordering=300 net.ipv4.tcp_sack=1 net.ipv4.tcp_dsack=1 net.ipv4.tcp_no_metrics_save=1
#dupack
sudo sysctl -w net.ipv4.tcp_recovery=0 net.ipv4.tcp_max_reordering=3 net.ipv4.tcp_sack=1 net.ipv4.tcp_dsack=1 net.ipv4.tcp_no_metrics_save=1



——————



at server

	sudo tcpdump -i $IF_BACK -f "tcp and (src 10.10.1.1 or dst 10.10.1.1)" -s 96 -w ~/capture.pcap

at client 



# become root
sudo su

# one time only
apt install trace-cmd

# repeat on each reboot
echo 1 > /sys/kernel/debug/tracing/events/tcp/tcp_probe/enable

# before each connection
trace-cmd record --date -e tcp_probe


iperf3 -c server -t 35

iperf3 -s 



# after flow ends, use Ctrl+C to stop recording
# then play back with
trace-cmd report

trace-cmd report > expname-log.txt





## Post processing

You can now refer to the `illustrative_exp_post_proc.ipynb` in this folder to continue working with the traces we have just captured.
