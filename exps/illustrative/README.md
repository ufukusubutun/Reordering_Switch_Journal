
## Illustrative experiments (from Section 2)

<img src="https://github.com/ufukusubutun/Reordering_Switch_Journal/blob/main/exps/illustrative/mini_exp_topo_v5.png"  width="60%" >

We want to run a single TCP flow through the line topology above and insert controlled reordering. We then want to measure what goes on at the sender cwnd, packet arrivals at the receiver and packet drops at the bottleneck.

## Setup

Cloudlab [profile for the 4 node line topology](https://www.cloudlab.us/p/nyunetworks/four-server-line)

Bring up this Cloudlab profile. (You'll need a Cloudlab account!)




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


Let us first set up which loss detection algorithm we want to use. 

(Keep in mind that the `net.ipv4.tcp_recovery` command is constantly evolving. It should produce the outcome we observed if you use the profile which uses Ubuntu 20. Later versions of the kernel removed support for dupthresh. So using the numbers below may produce different outcomes.)

To conduct an experiment with RACK, run the following at the sender:

	sudo sysctl -w net.ipv4.tcp_recovery=1 net.ipv4.tcp_max_reordering=300 net.ipv4.tcp_sack=1 net.ipv4.tcp_dsack=1 net.ipv4.tcp_no_metrics_save=1

To conduct an experiment with adapThresh (dupthresh with Linux adaptive threshold), run the following at the sender:

	sudo sysctl -w net.ipv4.tcp_recovery=0 net.ipv4.tcp_max_reordering=300 net.ipv4.tcp_sack=1 net.ipv4.tcp_dsack=1 net.ipv4.tcp_no_metrics_save=1

To conduct an experiment with dupThresh (dupthresh with a fixed threshold of 3), run the following at the sender:

	sudo sysctl -w net.ipv4.tcp_recovery=0 net.ipv4.tcp_max_reordering=3 net.ipv4.tcp_sack=1 net.ipv4.tcp_dsack=1 net.ipv4.tcp_no_metrics_save=1



Setup the packet capture by running this at server:

	sudo tcpdump -i $IF_BACK -f "tcp and (src 10.10.1.1 or dst 10.10.1.1)" -s 96 -w ~/capture.pcap

Setup high resolution cwnd capture at the sender size by running the following at the sender:

	# become root
	sudo su
	# one time only
	apt install trace-cmd
	# repeat on each reboot
	echo 1 > /sys/kernel/debug/tracing/events/tcp/tcp_probe/enable
	# start capture
	trace-cmd record --date -e tcp_probe

We will setup `iperf` and run our single TCP flow. At server run (and keep it running):

	iperf3 -s 

Now start the TCP flow. At the second terminal window of sender run (this will run for 35 seconds):

	iperf3 -c server -t 35



After flow ends, use Ctrl+C to stop recording the cwnd and packet captures in the corresponding terminals.

Save the output of the cwnd capture to a file:

	trace-cmd report > expname-log.txt


You can repeat the experiment as you like with different loss detection algorithms, more frequent reordering, or different base delays! 

If you would also like to capture packet drops that will happen at the bottleneck node (to compare against instances of reordering misdesignated as loss) you can remove the forward direction qdisc at the bottleneck and reinstantiate it before each experiment

	sudo tc qdisc del dev $IF root  
	sudo tc qdisc add dev $IF root handle 1: htb default 3  
	sudo tc class add dev $IF parent 1:2 classid 1:3 htb rate 10Mbit  
	sudo tc qdisc add dev $IF parent 1:3 bfifo limit 0.8mbit 

And then at the end of the experiment look at the number of packet drops by examining:

	tc -s -d class show dev $IF
	tc -s -d qdisc show dev $IF

## Post processing

You can now refer to the `illustrative_exp_post_proc.ipynb` in this folder to continue working with the traces we have just captured.

You can also find the resulting captures we used in the paper [here](https://drive.google.com/file/d/1yKY2KmC7Pn7kE6ydGtIwCMnrkYPBeWe3/view?usp=drive_link)

And below is some statistics for those traces.

<img src="https://github.com/ufukusubutun/Reordering_Switch_Journal/blob/main/exps/illustrative/illus_exp_results.png"  width="45%" >
