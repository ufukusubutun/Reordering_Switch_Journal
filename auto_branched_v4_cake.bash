#!/bin/bash

# author Ufuk Usubutun - usubutun@nyu.edu
# for reordering experiments with branching
# MODIFIED VERSION 3/26/25
# TO HAVE A NON BOTTLENECK CORE SWITCH

# ----------------------------------------------------------- #
# TODO YOU MUST PUT YOUR OWN CLOUDLAB USERNAME HERE 
uname="uu20010"
# ----------------------------------------------------------- #
location="/users/$uname"
# ----------------------------------------------------------- #
# TODO YOU MUST SPECIFY THE PATH TO YOUR OWN SSH KEY 
keyfile="$location/.ssh/ufuk"
# ----------------------------------------------------------- #

# ----------------------------------------------------------- #
# TODO SET THE EXPERIMENT DURATION HERE
exp_time=35 
# try to provide at least 10 more seconds for the exp_time_safe
exp_time_safe=45 
# ----------------------------------------------------------- #


sudo echo sudooo

int2exp_sink="\$(ip route get 10.14.1.2 | grep -oP \"(?<= dev )[^ ]+\")"
int2o_sink="\$(ip route get 10.14.2.2 | grep -oP \"(?<= dev )[^ ]+\")"

int2node_gen ()
{
    int2node="\$(ip route get 10.10.${1}.1 | grep -oP \"(?<= dev )[^ ]+\")"
}


switch_cap[1]=45 # rate should not be smaller than N - (rate/N) intiger division gives 1
switch_cap[2]=450
switch_cap[3]=1000 #1000
switch_cap[4]=2000
switch_cap[5]=4500
switch_cap[6]=5000

algo[1]='sudo sysctl -w net.ipv4.tcp_recovery=1 net.ipv4.tcp_max_reordering=300 net.ipv4.tcp_sack=1 net.ipv4.tcp_dsack=1 net.ipv4.tcp_no_metrics_save=1' # 1 rack
algo[2]='sudo sysctl -w net.ipv4.tcp_recovery=0 net.ipv4.tcp_max_reordering=300 net.ipv4.tcp_sack=1 net.ipv4.tcp_dsack=1 net.ipv4.tcp_no_metrics_save=1' # 2 dupthresh
algo[3]='sudo sysctl -w net.ipv4.tcp_recovery=0 net.ipv4.tcp_max_reordering=3 net.ipv4.tcp_sack=1 net.ipv4.tcp_dsack=1 net.ipv4.tcp_no_metrics_save=1'   # 3 dupack


# changing below parameters MAY NOT (and probably will not) change all parameter automatically, (it will change some)
# before doing so please review loops and calculations in the rest of the code
declare -a sources=("node-0" "node-1" "node-2" "node-3" "node-4" "node-5" "node-6" "node-7" "node-8" "node-9" "node-10" "node-11")
declare -a step1=("agg0" "agg1" "agg2" "agg3" "agg4" "agg5")
declare -a step2=("tor0" "tor1" "tor2")
exp_sink="sink"
o_sink="sink2"


# changing the number of nodes will not change all parameter automatically
N_NODES=12
# ----------------------------------------------------------- #
# TODO YOU CAN SET THE NUMBER OF FLOW GENERATORS HERE:
# This corresponds to quantity x in the article.
N_FLOWS_P_NODE=160 # (values larger than 250 might expreience performance issues at the generating nodes)
# ----------------------------------------------------------- #


kill_senders ()
{
	echo killing source iperf3s
	for host in "${sources[@]}"
	do
		ssh -oStrictHostKeyChecking=no ${uname}@${host} -i $keyfile -f sudo killall iperf3
		ssh -oStrictHostKeyChecking=no ${uname}@${host} -i $keyfile -f sudo killall node_init.sh # this may not kill all scripts
	done
}

kill_sinks ()
{
	echo killing sink iperf3s
	ssh -oStrictHostKeyChecking=no ${uname}@${exp_sink} -i $keyfile -f sudo killall iperf3
	ssh -oStrictHostKeyChecking=no ${uname}@${o_sink} -i $keyfile -f sudo killall iperf3
}

cleanup ()
{
	kill_senders
	kill_sinks
	exit 0
}

trap cleanup SIGINT SIGTERM

# ----------------------------------------------------------- #
# TODO SET BUFFER SIZE AT EACH NODE
buffer_scaler=250 ## value 250 corresponds to 2*BDP buffers, likewise 125 -> BDP, 500 -> 4*BDP etc
# ----------------------------------------------------------- #

# ----------------------------------------------------------- #
# TODO SET THE CONFIGURATION TO USE, FOLLOW THE IF-ELSE STATEMENT TO SEE WHICH ONE IS USED
# the first one is used in an if-else fashion
# eg: if fair_q elif prob else debug mode
fair_q=0 # uses fq with htb - corresponds to the non-LB configuration on the article
prob=1 # uses htb with iptables tagging - corresponds to the LB configuration on the article
# when both are set to 0, a third configuration of dubugging is used,
# This config hashes flows generated at the 3 tor switches to 3 queues
# ----------------------------------------------------------- #

# ALTTHOUGH EXPERIMENTS CAN BE RUN USING THE FOR LOOP BELOW, I SUGGEST RUNNING ONE EXPERIMENT AT A TIME
# AS THERE ARE A LOT OF THINGS GOING ON - SUGGESTED USE: UPDATE THE VALUE GIVEN TO THE LOOP TO PICK PARAMETERS
# ----------------------------------------------------------- #
# TODO SET THE ALGORITHM
for alg_ind in 1 # 2 3 # 1 rack, 2 adapThresh, 3 3Thresh
# ----------------------------------------------------------- #
do

	echo Setting algortihm to = $alg_ind  1 rack, 2 adapThresh, 3 3Thresh
	# runs the sysctl commands above at each traffic generating node
	for host in "${sources[@]}"
	do
		ssh -oStrictHostKeyChecking=no ${uname}@${host} -i $keyfile "${algo[$alg_ind]}"
	done

    sleep 0.1

    # ----------------------------------------------------------- #
	# TODO SET THE BASE DELAY TERMED 'RTT' in milliseconds - This corresponds to the value T in the article.
    for RTT in 20 # 10 
	# ----------------------------------------------------------- #
	do
		RTT_par_us=$(expr $(expr $RTT \* 1000) / 4 )  # Base RTT to be applied per step in microseconds, will be added at 4 separate places
		RTT_us=$(expr $RTT \* 1000)
		echo RTT $RTT ms, RTT_par_us $RTT_par_us us

		# The ratio (lam/10) of flowgens to connect to sink1 as opposed to sink2
		# The results in the article were generated with equal ratio, i.e., lam=5
		for lam in 5 #5 #3 # 5 9 #1 5 9
		do
			echo "lam 0.$lam"
			# ----------------------------------------------------------- #
			# TODO SET SWITCH SIZE N - The article used the parameter N=8
			for N in 8 #1 2 4 8 16 # switch size
			# ----------------------------------------------------------- #
			do
				# ----------------------------------------------------------- #
				# TODO SET SWITCH CAPACITY AS AN INDEX to the array switch_cap above
				for cap_ind in 5 # 4 3 2 1  #4 # switch capacity 4500 2000 1000 500 100
				# ----------------------------------------------------------- #
				do
					echo '************************'
					echo algortihm = $alg_ind '(1 rack, 2 dupthresh, 3 dupack)'
					echo RTT = $RTT ms
					echo N = $N
					echo "lam 0.$lam"
					echo N_FLOWS_P_NODE= $N_FLOWS_P_NODE
					echo network_capacity= ${switch_cap[$cap_ind]} 
					echo '************************'

					network_capacity=${switch_cap[$cap_ind]}
					echo $(expr $(expr $(expr ${network_capacity} \* $buffer_scaler ) \* $RTT_us ) / 1000 )
					echo 'make sure this is not zero'
					echo $(expr $(expr $(expr $(expr ${network_capacity} \* $buffer_scaler ) \* $RTT_us ) / 1000 ) / 1500)
					
		

					# set up switch patterns
					echo ""
					echo "----commands on emulatorg---"
					echo "sudo tc qdisc del dev $(eval echo $int2exp_sink) root"
					sudo tc qdisc del dev $(eval echo $int2exp_sink) root
					echo "sudo tc qdisc add dev $(eval echo $int2exp_sink) root handle 1: htb default $(expr $N + 11)"
					sudo tc qdisc add dev $(eval echo $int2exp_sink) root handle 1: htb default $(expr $N + 11)
					echo "sudo tc class add dev $(eval echo $int2exp_sink) parent 1: classid 1:1 htb rate ${switch_cap[$cap_ind]}mbit ceil ${switch_cap[$cap_ind]}mbit quantum 3028"
					sudo tc class add dev $(eval echo $int2exp_sink) parent 1: classid 1:1 htb rate ${switch_cap[$cap_ind]}mbit ceil ${switch_cap[$cap_ind]}mbit quantum 3028
					echo "sudo iptables -t mangle -F"
					sudo iptables -t mangle -F


					que_cap=$(expr ${switch_cap[$cap_ind]} / $N ) 
					echo "que_cap: $que_cap"
					
					if [[ $fair_q -eq 1 ]] # if non-LB
					then
						echo "----reset root to add fq---"
						echo "sudo tc qdisc del dev $(eval echo $int2exp_sink) root"
						sudo tc qdisc del dev $(eval echo $int2exp_sink) root

						echo "sudo tc qdisc add dev $(eval echo $int2exp_sink) root handle 1: htb default 1" 
						sudo tc qdisc add dev $(eval echo $int2exp_sink) root handle 1: htb default 1 
						echo "sudo tc class add dev $(eval echo $int2exp_sink) parent 1: classid 1:1 htb rate ${switch_cap[$cap_ind]}mbit ceil ${switch_cap[$cap_ind]}mbit quantum 3028"
						sudo tc class add dev $(eval echo $int2exp_sink) parent 1: classid 1:1 htb rate ${switch_cap[$cap_ind]}mbit ceil ${switch_cap[$cap_ind]}mbit quantum 3028
						echo "sudo tc qdisc add dev $(eval echo $int2exp_sink) parent 1:1 fq nopacing maxrate ${switch_cap[$cap_ind]}mbit limit $(expr $(expr $(expr $(expr ${network_capacity} \* $buffer_scaler ) \* $RTT_us ) / 1000 ) / 1500) flow_limit $(expr $(expr $(expr $(expr ${network_capacity} \* $buffer_scaler ) \* $RTT_us ) / 1000 ) / 1500) quantum 3028 initial_quantum 3028 buckets $N" # in packets
						sudo tc qdisc add dev $(eval echo $int2exp_sink) parent 1:1 fq nopacing maxrate ${switch_cap[$cap_ind]}mbit limit $(expr $(expr $(expr $(expr ${network_capacity} \* $buffer_scaler ) \* $RTT_us ) / 1000 ) / 1500) flow_limit $(expr $(expr $(expr $(expr ${network_capacity} \* $buffer_scaler ) \* $RTT_us ) / 1000 ) / 1500) quantum 3028 initial_quantum 3028 buckets $N
						
						
					elif [[ $prob -eq 1 ]] # if LB
					then
						for ind in $(seq 11 1 $(expr $N + 10) )
						do

							echo "sudo tc class add dev $(eval echo $int2exp_sink) parent 1:1 classid 1:$ind htb rate ${que_cap}mbit ceil ${switch_cap[$cap_ind]}mbit quantum 3028"
							sudo tc class add dev $(eval echo $int2exp_sink) parent 1:1 classid 1:$ind htb rate ${que_cap}mbit ceil ${switch_cap[$cap_ind]}mbit quantum 3028
							#BFIFO BUFFERS
							#echo "sudo tc qdisc add dev $(eval echo $int2exp_sink) parent 1:$ind handle ${ind}0: bfifo limit $(expr $(expr $(expr ${que_cap} \* $buffer_scaler ) \* $RTT_us ) / 1000 )" # PLAYING AROUND WITH THE BUFFER CAPACITIES - currently left at 8 times - not adaptive (org value was 250) - CURRENTLY TAILORED TO 2*BDP for N=16 or the equal sum (2*BDP*16/N) for all other cases
							#sudo tc qdisc add dev $(eval echo $int2exp_sink) parent 1:$ind handle ${ind}0: bfifo limit $(expr $(expr $(expr ${que_cap} \* $buffer_scaler ) \* $RTT_us ) / 1000 ) # 2*BDP of that link in in bytes # PLAYING AROUND WITH THE BUFFER CAPACITIES - currently left at 8 times - not adaptive
							#PFIFO BUFFERS
							echo "sudo tc qdisc add dev $(eval echo $int2exp_sink) parent 1:$ind handle ${ind}0: pfifo limit $(expr $(expr $(expr $(expr ${que_cap} \* $buffer_scaler ) \* $RTT_us ) / 1000 ) / 1500)" 
							sudo tc qdisc add dev $(eval echo $int2exp_sink) parent 1:$ind handle ${ind}0: pfifo limit $(expr $(expr $(expr $(expr ${que_cap} \* $buffer_scaler ) \* $RTT_us ) / 1000 ) / 1500)
							echo "sudo iptables -A PREROUTING -m statistic --mode random --probability $(bc <<< "scale=6; 1/$(expr $N - $(expr $ind - 11))")  -t mangle --destination 10.14.0.0/16 --source 10.10.0.0/16 -j MARK --set-mark $ind" 
							sudo iptables -A PREROUTING -m statistic --mode random --probability 0$(bc <<< "scale=6; 1/$(expr $N - $(expr $ind - 11))") -t mangle --destination 10.14.0.0/16 --source 10.10.0.0/16 -j MARK --set-mark $ind
							echo "sudo iptables -A PREROUTING -m mark --mark $ind -t mangle -j RETURN"
							sudo iptables -A PREROUTING -m mark --mark $ind -t mangle -j RETURN

							echo "sudo tc filter add dev $(eval echo $int2exp_sink) protocol ip parent 1: prio 0 handle $ind fw classid 1:$ind"
							sudo tc filter add dev $(eval echo $int2exp_sink) protocol ip parent 1: prio 0 handle $ind fw classid 1:$ind
						done
					else # Implemented to debug changes to queues and rate limiting issues 
					
						for ind in $(seq 11 1 $(expr $N + 10) )
						do
							#FULL CAP
							#echo "sudo tc class add dev $(eval echo $int2exp_sink) parent 1:1 classid 1:$ind htb rate ${switch_cap[$cap_ind]}mbit ceil ${switch_cap[$cap_ind]}mbit quantum 3028"
							#sudo tc class add dev $(eval echo $int2exp_sink) parent 1:1 classid 1:$ind htb rate ${switch_cap[$cap_ind]}mbit ceil ${switch_cap[$cap_ind]}mbit quantum 3028
							#QUEUE CAP
							echo "sudo tc class add dev $(eval echo $int2exp_sink) parent 1:1 classid 1:$ind htb rate ${que_cap}mbit ceil ${switch_cap[$cap_ind]}mbit quantum 3028"
							sudo tc class add dev $(eval echo $int2exp_sink) parent 1:1 classid 1:$ind htb rate ${que_cap}mbit ceil ${switch_cap[$cap_ind]}mbit quantum 3028
							#BFIFO BUFFERS
							#echo "sudo tc qdisc add dev $(eval echo $int2exp_sink) parent 1:$ind handle ${ind}0: bfifo limit $(expr $(expr $(expr ${que_cap} \* $buffer_scaler ) \* $RTT_us ) / 1000 )" # PLAYING AROUND WITH THE BUFFER CAPACITIES - currently left at 8 times - not adaptive (org value was 250) - CURRENTLY TAILORED TO 2*BDP for N=16 or the equal sum (2*BDP*16/N) for all other cases
							#sudo tc qdisc add dev $(eval echo $int2exp_sink) parent 1:$ind handle ${ind}0: bfifo limit $(expr $(expr $(expr ${que_cap} \* $buffer_scaler ) \* $RTT_us ) / 1000 ) # 2*BDP of that link in in bytes # PLAYING AROUND WITH THE BUFFER CAPACITIES - currently left at 8 times - not adaptive
							#PFIFO BUFFERS
							echo "sudo tc qdisc add dev $(eval echo $int2exp_sink) parent 1:$ind handle ${ind}0: pfifo limit $(expr $(expr $(expr $(expr ${que_cap} \* $buffer_scaler ) \* $RTT_us ) / 1000 ) / 1500)" 
							sudo tc qdisc add dev $(eval echo $int2exp_sink) parent 1:$ind handle ${ind}0: pfifo limit $(expr $(expr $(expr $(expr ${que_cap} \* $buffer_scaler ) \* $RTT_us ) / 1000 ) / 1500)


					        echo "sudo iptables -A PREROUTING -s 10.12.$(expr $ind - 10).0/24 -p tcp -t mangle --destination 10.14.0.0/16 -j MARK --set-mark $ind"
							sudo iptables -A PREROUTING -s 10.12.$(expr $ind - 10).0/24 -p tcp -t mangle --destination 10.14.0.0/16 -j MARK --set-mark $ind  				

							echo "sudo tc filter add dev $(eval echo $int2exp_sink) protocol ip parent 1: prio 0 handle $ind fw classid 1:$ind"
							sudo tc filter add dev $(eval echo $int2exp_sink) protocol ip parent 1: prio 0 handle $ind fw classid 1:$ind
						done
							

					fi

					
                    if [[ $fair_q -ne 1 ]] 
                    then
						echo "sudo tc class add dev $(eval echo $int2exp_sink) parent 1:1 classid 1:$(expr $N + 11) htb rate ${que_cap}mbit ceil ${que_cap}mbit"
						sudo tc class add dev $(eval echo $int2exp_sink) parent 1:1 classid 1:$(expr $N + 11) htb rate ${que_cap}mbit ceil ${que_cap}mbit

						echo "sudo tc qdisc add dev $(eval echo $int2exp_sink) parent 1:$(expr $N + 11) handle $(expr $N + 11)0: pfifo limit $(expr $(expr $(expr $(expr ${que_cap} \* $buffer_scaler ) \* $RTT_us ) / 1000 ) / 1500)" # PLAYING AROUND WITH THE BUFFER CAPACITIES - currently left at 8 times - not adaptive (org value was 250) - CURRENTLY TAILORED TO 2*BDP for N=16 or the equal sum (2*BDP*16/N) for all other cases
						sudo tc qdisc add dev $(eval echo $int2exp_sink) parent 1:$(expr $N + 11) handle $(expr $N + 11)0: pfifo limit $(expr $(expr $(expr $(expr ${que_cap} \* $buffer_scaler ) \* $RTT_us ) / 1000 ) / 1500) # 2*BDP of that link in in bytes # PLAYING AROUND WITH THE BUFFER CAPACITIES - currently left at 8 times - not adaptive
					fi

					## second sink
					network_capacity=${switch_cap[$cap_ind]}

					echo "sudo tc qdisc del dev $(eval echo $int2o_sink) root"
					sudo tc qdisc del dev $(eval echo $int2o_sink) root

					echo "sudo tc qdisc add dev $(eval echo $int2o_sink) root handle 1: htb default 19"
					sudo tc qdisc add dev $(eval echo $int2o_sink) root handle 1: htb default 19
					echo "sudo tc class add dev $(eval echo $int2o_sink) parent 1: classid 1:1 htb rate ${network_capacity}mbit ceil ${network_capacity}mbit"
					sudo tc class add dev $(eval echo $int2o_sink) parent 1: classid 1:1 htb rate ${network_capacity}mbit ceil ${network_capacity}mbit 
					echo "sudo tc class add dev $(eval echo $int2o_sink) parent 1:1 classid 1:19 htb rate ${network_capacity}mbit ceil ${network_capacity}mbit"
					sudo tc class add dev $(eval echo $int2o_sink) parent 1:1 classid 1:19 htb rate ${network_capacity}mbit ceil ${network_capacity}mbit
					echo "sudo tc qdisc add dev $(eval echo $int2o_sink) parent 1:19 handle 190: pfifo limit $(expr $(expr $(expr $(expr ${network_capacity} \* $buffer_scaler ) \* $RTT_us ) / 1000 ) / 1500)" 
					sudo tc qdisc add dev $(eval echo $int2o_sink) parent 1:19 handle 190: pfifo limit $(expr $(expr $(expr $(expr ${network_capacity} \* $buffer_scaler ) \* $RTT_us ) / 1000 ) / 1500) 


					echo "Press verify the parameters and the queuing set up above. If correct, press any key to continue setting up all other nodes."
					while [ true ] ; do
						read -t 3 -n 1
						if [ $? = 0 ] ; then
							break ;
						fi
					done

					
					branch_rate=$(expr $(expr $network_capacity \* 1) / 3) #$(expr $(expr $network_capacity \* 5) / 3)

					echo network_capacity = $network_capacity # btlnck_rate = $btlnck_rate\M \n
				       	burst_ceil=3100	


					echo ""
					echo "----commands on sources---"
					
					index=0
					for host in "${sources[@]}"
					do
						echo ------ at $host -------
						echo "echo $int2exp_sink"
						ssh -oStrictHostKeyChecking=no ${uname}@${host} -i $keyfile "echo $int2exp_sink" 
						echo "sudo tc qdisc del dev $int2exp_sink root"
						ssh -oStrictHostKeyChecking=no ${uname}@${host} -i $keyfile "sudo tc qdisc del dev $int2exp_sink root"
						sleep 0.1

						echo "sudo tc qdisc add dev $int2exp_sink root handle 1: htb default 3"
						ssh ${uname}@${host} -i $keyfile "sudo tc qdisc add dev $int2exp_sink root handle 1: htb default 3"
						sleep 0.01
						echo "sudo tc class add dev $int2exp_sink parent 1: classid 1:3 htb rate ${branch_rate}mbit ceil ${branch_rate}mbit burst $burst_ceil cburst $burst_ceil"
						ssh ${uname}@${host} -i $keyfile "sudo tc class add dev $int2exp_sink parent 1: classid 1:3 htb rate ${branch_rate}mbit ceil ${branch_rate}mbit burst $burst_ceil cburst $burst_ceil" # limit $(expr ${branch_rate} \* 500 )" # in bytes
						sleep 0.01
						echo "sudo tc qdisc add dev $int2exp_sink parent 1:3 bfifo limit $(expr $(expr $(expr ${branch_rate} \* 250 ) \* $RTT_us ) / 1000 )"
						ssh ${uname}@${host} -i $keyfile "sudo tc qdisc add dev $int2exp_sink parent 1:3 bfifo limit $(expr $(expr $(expr ${branch_rate} \* 250 ) \* $RTT_us ) / 1000 )" # 2*BDP of that link in in bytes
						sleep 0.01
						# logging
						echo "sudo tc -s -d qdisc show dev $int2exp_sink >> shaping_log_bottleneck_${host}.log"
						ssh ${uname}@${host} -i $keyfile "sudo tc -s -d qdisc show dev $int2exp_sink >> shaping_log_${host}.log"
						sleep 0.01
						echo "sudo tc -s -d class show dev $int2exp_sink >> shaping_log_bottleneck_${host}.log"
						ssh ${uname}@${host} -i $keyfile "sudo tc -s -d class show dev $int2exp_sink >> shaping_log_${host}.log" 
						index=$( expr $index + 2 )
					done
					
					echo ""
					echo "----commands on step1---"

					# ADDED for Non bottleneck
					branch_rate=$(expr $(expr $network_capacity \* 1) / 5) #$(expr $(expr $network_capacity \* 5) / 3)
					
					index=0
					for host in "${step1[@]}"
					do
						echo ------ at $host -------
						echo "echo $int2exp_sink"
						ssh -oStrictHostKeyChecking=no ${uname}@${host} -i $keyfile "echo $int2exp_sink" 
						echo "sudo tc qdisc del dev $int2exp_sink root"
						ssh -oStrictHostKeyChecking=no ${uname}@${host} -i $keyfile "sudo tc qdisc del dev $int2exp_sink root"
						sleep 0.1

						echo "sudo tc qdisc add dev $int2exp_sink root cake bandwidth ${branch_rate}mbit rtt $(expr $RTT_us / 1000 )ms flows"
						ssh ${uname}@${host} -i $keyfile "sudo tc qdisc add dev $int2exp_sink root cake bandwidth ${branch_rate}mbit rtt $(expr $RTT_us / 1000 )ms flows"
						#echo "sudo tc qdisc add dev $int2exp_sink root handle 1: htb default 3"
						#ssh ${uname}@${host} -i $keyfile "sudo tc qdisc add dev $int2exp_sink root handle 1: htb default 3"
						sleep 0.01
						#echo "sudo tc class add dev $int2exp_sink parent 1: classid 1:3 htb rate ${branch_rate}mbit ceil ${branch_rate}mbit burst $burst_ceil cburst $burst_ceil"
						#ssh ${uname}@${host} -i $keyfile "sudo tc class add dev $int2exp_sink parent 1: classid 1:3 htb rate ${branch_rate}mbit ceil ${branch_rate}mbit burst $burst_ceil cburst $burst_ceil" # limit $(expr ${branch_rate} \* 500 )" # in bytes
						#sleep 0.01
						#echo "sudo tc qdisc add dev $int2exp_sink parent 1:3 bfifo limit $(expr $(expr $(expr ${branch_rate} \* 250 ) \* $RTT_us ) / 1000 )"
						#ssh ${uname}@${host} -i $keyfile "sudo tc qdisc add dev $int2exp_sink parent 1:3 bfifo limit $(expr $(expr $(expr ${branch_rate} \* 250 ) \* $RTT_us ) / 1000 )" # 2*BDP of that link in in bytes
						#sleep 0.01
						# handle node facing interfaces
						for n in 1 2
						do
							int2node_gen $( expr $index + $n )
							RTT_node_us=$(expr $( expr $index + $n ) \* 1000)
							echo "sudo tc qdisc del dev $int2node root"
							ssh -oStrictHostKeyChecking=no ${uname}@${host} -i $keyfile "sudo tc qdisc del dev $int2node root"
							echo "sudo tc qdisc add dev $int2node root netem delay ${RTT_node_us}us"
							ssh -oStrictHostKeyChecking=no ${uname}@${host} -i $keyfile "sudo tc qdisc add dev $int2node root netem delay ${RTT_node_us}us"
							# logging
							echo "sudo tc -s -d qdisc show dev $int2node >> shaping_log_bottleneck_${host}.log"
							ssh ${uname}@${host} -i $keyfile "sudo tc -s -d qdisc show dev $int2node >> shaping_log_${host}.log"
						done
						# logging
						echo "sudo tc -s -d qdisc show dev $int2exp_sink >> shaping_log_bottleneck_${host}.log"
						ssh ${uname}@${host} -i $keyfile "sudo tc -s -d qdisc show dev $int2exp_sink >> shaping_log_${host}.log"
						sleep 0.01
						echo "sudo tc -s -d class show dev $int2exp_sink >> shaping_log_bottleneck_${host}.log"
						ssh ${uname}@${host} -i $keyfile "sudo tc -s -d class show dev $int2exp_sink >> shaping_log_${host}.log" 
						index=$( expr $index + 2 )
					done
					
					
					index=0
					for host in "${step2[@]}"
					do
						echo ------ at $host -------
						echo "echo $int2exp_sink"
						ssh -oStrictHostKeyChecking=no ${uname}@${host} -i $keyfile "echo $int2exp_sink"
						echo "sudo tc qdisc del dev $int2exp_sink root"
						ssh -oStrictHostKeyChecking=no ${uname}@${host} -i $keyfile "sudo tc qdisc del dev $int2exp_sink root"
						sleep 0.1

						echo "sudo tc qdisc add dev $int2exp_sink root handle 1: htb default 3"
						ssh ${uname}@${host} -i $keyfile "sudo tc qdisc add dev $int2exp_sink root handle 1: htb default 3"
						sleep 0.01
						echo "sudo tc class add dev $int2exp_sink parent 1: classid 1:3 htb rate ${network_capacity}mbit ceil ${network_capacity}mbit burst $burst_ceil cburst $burst_ceil"
						ssh ${uname}@${host} -i $keyfile "sudo tc class add dev $int2exp_sink parent 1: classid 1:3 htb rate ${network_capacity}mbit ceil ${network_capacity}mbit burst $burst_ceil cburst $burst_ceil" # limit $(expr ${network_capacity} \* 500 )" # in bytes
						sleep 0.01
						echo "sudo tc qdisc add dev $int2exp_sink parent 1:3 bfifo limit $(expr $(expr $(expr ${network_capacity} \* 250 ) \* $RTT_us ) / 1000 )"
						ssh ${uname}@${host} -i $keyfile "sudo tc qdisc add dev $int2exp_sink parent 1:3 bfifo limit $(expr $(expr $(expr ${network_capacity} \* 250 ) \* $RTT_us ) / 1000 )" # 2*BDP of that link in in bytes
						sleep 0.01
						# handle node facing interfaces
						for n in 1 3
						do
							int2node_gen $( expr $index + $n )
							echo "sudo tc qdisc del dev $int2node root"
							ssh -oStrictHostKeyChecking=no ${uname}@${host} -i $keyfile "sudo tc qdisc del dev $int2node root"
							echo "sudo tc qdisc add dev $int2node root netem delay ${RTT_par_us}us"
							ssh -oStrictHostKeyChecking=no ${uname}@${host} -i $keyfile "sudo tc qdisc add dev $int2node root netem delay ${RTT_par_us}us"
							# logging
							echo "sudo tc -s -d qdisc show dev $int2node >> shaping_log_bottleneck_${host}.log"
							ssh ${uname}@${host} -i $keyfile "sudo tc -s -d qdisc show dev $int2node >> shaping_log_${host}.log"
						done
						# logging
						echo "sudo tc -s -d qdisc show dev $int2exp_sink >> shaping_log_bottleneck_${host}.log"
						ssh ${uname}@${host} -i $keyfile "sudo tc -s -d qdisc show dev $int2exp_sink >> shaping_log_${host}.log"
						sleep 0.01
						echo "sudo tc -s -d class show dev $int2exp_sink >> shaping_log_bottleneck_${host}.log"
						ssh ${uname}@${host} -i $keyfile "sudo tc -s -d class show dev $int2exp_sink >> shaping_log_${host}.log" 
						index=$( expr $index + 4 )
					done


					# handle node facing interfaces on emulator
					echo ------ at emulator -------
					for n in 1 5 9
					do
						int2node_gen $n
						echo "sudo tc qdisc del dev $(eval echo $int2node) root" 
						sudo tc qdisc del dev $(eval echo $int2node) root

						echo "sudo tc qdisc add dev $(eval echo $int2node) root netem delay ${RTT_par_us}us"
						sudo tc qdisc add dev $(eval echo $int2node) root netem delay ${RTT_par_us}us
						### logging
						#echo "sudo tc -s -d qdisc show dev $(eval echo $int2node) >> shaping_log_bottleneck_${host}.log"
						#sudo tc -s -d qdisc show dev $(eval echo $int2node) >> shaping_log_bottleneck_emulator.log
						#ssh ${uname}@${host} -i $keyfile "sudo tc -s -d qdisc show dev $int2node >> shaping_log_${host}.log"
					done


					# handle node facing interfaces on two servers
					int2node_gen 1 # any node would work
					echo "sudo tc qdisc del dev $int2node root"
					ssh -oStrictHostKeyChecking=no ${uname}@${exp_sink} -i $keyfile "sudo tc qdisc del dev $int2node root"
					echo "sudo tc qdisc add dev $int2node root netem delay ${RTT_par_us}us"
					ssh -oStrictHostKeyChecking=no ${uname}@${exp_sink} -i $keyfile "sudo tc qdisc add dev $int2node root netem delay ${RTT_par_us}us"
					int2node_gen 1 # any node would work
					echo "sudo tc qdisc del dev $int2node root"
					ssh -oStrictHostKeyChecking=no ${uname}@${o_sink} -i $keyfile "sudo tc qdisc del dev $int2node root"
					echo "sudo tc qdisc add dev $int2node root netem delay ${RTT_par_us}us"
					ssh -oStrictHostKeyChecking=no ${uname}@${o_sink} -i $keyfile "sudo tc qdisc add dev $int2node root netem delay ${RTT_par_us}us"


					echo "Done setting up. Make sure the log above contains no errors. Press any key to start the experiment"
                                        while [ true ] ; do
                                                read -t 3 -n 1
                                                if [ $? = 0 ] ; then
                                                        break ;
                                                fi
                                        done
					# From this point on call individual scripts located at end nodes with proper arguments to run the experiments					
					num_serv=$(expr $N_NODES \* $N_FLOWS_P_NODE)

					echo 'setting up sink servers'
					ssh ${uname}@${exp_sink} -i $keyfile bash $location/init_server.sh $num_serv
					echo 'setting up sink2 servers'
					ssh ${uname}@${o_sink} -i $keyfile bash $location/init_server.sh $num_serv
					sleep 1

					# Can be used to make multiple experiments - not tested recently
					for trial in 1 #2 3 4 5
					do
						echo '************'
						echo trial num=$trial
						echo '************'

						exp_save_name="exp$trial-alg$alg_ind-RTT$RTT-N$N-swcap${switch_cap[$cap_ind]}-lam$lam"
						sleep 0.1


						echo starting Exps!
						exp_params_rec="$alg_ind, $RTT, $lam, $N, ${switch_cap[$cap_ind]}, $trial,"
						node_id=0 # should be a number from 0 to n
						for host in "${sources[@]}"
						do
							echo "starting up $host flows"
							ssh ${uname}@${host} -i $keyfile -f bash $location/node_init.sh $node_id $N_FLOWS_P_NODE $exp_time $lam ${switch_cap[$cap_ind]} &
							node_id=$(expr $node_id + 1)
						done

						
						sleep $exp_time_safe

						# print tc output for the experiment queue
						echo "tc -s -d qdisc show dev $(eval echo $int2exp_sink)"
						sudo tc -s -d qdisc show dev $(eval echo $int2exp_sink)

						kill_senders
						sleep 2

						# transfer flowgen logs and merge
						mkdir -p $location/flowgen_logs
						node_id=0 # should be a number from 0 to n
						for host in "${sources[@]}"
						do
							echo "transferring flowgen logs from $host"
							scp  -i $keyfile ${uname}@${host}:/users/${uname}/n${node_id}_flowgen.log $location/flowgen_logs
							node_id=$(expr $node_id + 1)
						done
						rm -f /mydata/combined_flowgen.log
						touch /mydata/combined_flowgen.log
						# header 
        				echo "node_id, flowgen_id, to_other_sink, port_num, payload, flw_start_time, random_wait, ever_waited_after_flow_completed, wait_in_loop, real_total_wait " > /mydata/combined_flowgen.log
						# Concatenate the log files for node IDs 0 to 11
						for i in {0..11}; do
						    cat "${location}/flowgen_logs/n${i}_flowgen.log" >> /mydata/combined_flowgen.log
						done


						# THE 'dev' branch has iperf capture and transfer code that is located here
						# as they were not used in the final work, they are removed from the main branch
						echo "experiment done"


						echo "Press any key to move to next experiment"
						while [ true ] ; do
							read -t 3 -n 1
							if [ $? = 0 ] ; then
								break ;
							fi
						done
						

					done # trials loop ends
					kill_sinks # sinks are killed here!!! after the trials loop ends
				done # cap_ind loop ends
			done # N loop ends
		done # lam loop ends
	done # RTT loop ends
done #alg_ind loop ends



