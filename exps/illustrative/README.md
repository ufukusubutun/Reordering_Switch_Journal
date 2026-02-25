
## Illustrative experiments (from Section 2)

<img src="https://github.com/ufukusubutun/Reordering_Switch_Journal/blob/main/exps/illustrative/mini_exp_topo_v5.png"  width="60%" >


Cloudlab profile for the 4 node line topology:
https://www.cloudlab.us/p/nyunetworks/four-server-line







sudo apt-get update
sudo apt -y install moreutils





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




IF=$(ip route get 10.10.3.2 | grep -oP "(?<= dev )[^ ]+")
IF_BACK=$(ip route get 10.10.1.1 | grep -oP "(?<= dev )[^ ]+")

IF_P1=$(ifconfig | grep -B 1 "10.10.2.1 " | awk 'NR % 2 == 1' | awk '{print $1}' |  tr -d ':')
IF_P2=$(ifconfig | grep -B 1 "10.10.2.3 " | awk 'NR % 2 == 1' | awk '{print $1}' |  tr -d ':')

IF_P1_BACK=$(ifconfig | grep -B 1 "10.10.2.2 " | awk 'NR % 2 == 1' | awk '{print $1}' |  tr -d ':')
IF_P2_BACK=$(ifconfig | grep -B 1 "10.10.2.4 " | awk 'NR % 2 == 1' | awk '{print $1}' |  tr -d ':')





#rack
sudo sysctl -w net.ipv4.tcp_recovery=1 net.ipv4.tcp_max_reordering=300 net.ipv4.tcp_sack=1 net.ipv4.tcp_dsack=1 net.ipv4.tcp_no_metrics_save=1
#adapthresh
sudo sysctl -w net.ipv4.tcp_recovery=0 net.ipv4.tcp_max_reordering=300 net.ipv4.tcp_sack=1 net.ipv4.tcp_dsack=1 net.ipv4.tcp_no_metrics_save=1
#dupack
sudo sysctl -w net.ipv4.tcp_recovery=0 net.ipv4.tcp_max_reordering=3 net.ipv4.tcp_sack=1 net.ipv4.tcp_dsack=1 net.ipv4.tcp_no_metrics_save=1





# for 10 mbit with larger rtt
# much fewer number of packets reordered
#At router: set the bottlencek

sudo tc qdisc del dev $IF root  
sudo tc qdisc add dev $IF root handle 1: htb default 3  
sudo tc class add dev $IF parent 1:2 classid 1:3 htb rate 10Mbit  
sudo tc qdisc add dev $IF parent 1:3 bfifo limit 0.8mbit 

#sudo tc qdisc del dev $IF_BACK root  
#sudo tc qdisc add dev $IF_BACK root handle 1: htb default 3  
#sudo tc class add dev $IF_BACK parent 1:2 classid 1:3 htb rate 10Mbit  
#sudo tc qdisc add dev $IF_BACK parent 1:3 bfifo limit 0.8mbit 

#or
sudo tc qdisc del dev $IF_BACK root  
sudo tc qdisc add dev $IF_BACK root netem delay 10ms 

tc -s -d class show dev $IF
tc -s -d qdisc show dev $IF
tc -s -d class show dev $IF_BACK
tc -s -d qdisc show dev $IF_BACK


#At emulator:

sudo tc qdisc del dev $IF root
sudo tc qdisc add dev $IF root handle 1: htb default 3 
sudo tc class add dev $IF parent 1: classid 1:1 htb rate 10Mbit quantum 1514
sudo tc class add dev $IF parent 1:1 classid 1:2 htb rate 10Mbit quantum 1514 
sudo tc class add dev $IF parent 1:1 classid 1:3 htb rate 10Mbit quantum 1514

sudo tc qdisc add dev $IF parent 1:2 handle 2: netem delay 20ms    #40ms
sudo tc qdisc add dev $IF parent 1:3 handle 3: netem delay 10ms

sudo tc qdisc del dev $IF_BACK root  
sudo tc qdisc add dev $IF_BACK root handle 1: htb default 3  
sudo tc class add dev $IF_BACK parent 1:2 classid 1:3 htb rate 10Mbit  
sudo tc qdisc add dev $IF_BACK parent 1:3 bfifo limit 0.8mbit


tc -s -d class show dev $IF
tc -s -d qdisc show dev $IF
tc -s -d class show dev $IF_BACK
tc -s -d qdisc show dev $IF_BACK

# set the tagging and forwarding rules

#flush first! 
sudo iptables -t mangle -F
#then set
sudo iptables -A PREROUTING -m statistic --mode nth --every 1000 --packet 0 -t mangle --destination 10.10.3.2/24 --source 10.10.1.1/1 -j MARK --set-mark 12
sudo iptables -A PREROUTING -m mark --mark 12 -t mangle -j RETURN

sudo tc filter add dev $IF protocol ip parent 1: prio 0 handle 12 fw classid 1:2


# to display
sudo iptables -L -n -t mangle
tc -s -d filter show dev $IF

#to clear
sudo iptables -t mangle -F


iperf3 -c server -t 35

iperf3 -s 
——————
# at server
sudo tcpdump -i $IF_BACK -f "tcp and (src 10.10.1.1 or dst 10.10.1.1)" -s 96 -w ~/capture.pcap

# at client

#alternative better method

# become root
sudo su

# one time only
apt install trace-cmd

# repeat on each reboot
echo 1 > /sys/kernel/debug/tracing/events/tcp/tcp_probe/enable

# before each connection
trace-cmd record --date -e tcp_probe

# after flow ends, use Ctrl+C to stop recording
# then play back with
trace-cmd report

trace-cmd report > expname-log.txt
