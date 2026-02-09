#!/bin/bash

update=$1

# ----------------------------------------------------------- #
# TODO YOU MUST PUT YOUR OWN CLOUDLAB USERNAME HERE 
uname="uu20010"
# ----------------------------------------------------------- #
location=$(eval pwd)
# ----------------------------------------------------------- #
# TODO YOU MUST SPECIFY THE PATH TO YOUR OWN SSH KEY 
keyfile="$location/.ssh/ufuk"
# ----------------------------------------------------------- #


chmod 400 $keyfile

sudo chmod -R a+w /mydata


declare -a sources=("node-0" "node-1" "node-2" "node-3" "node-4" "node-5" "node-6" "node-7" "node-8" "node-9" "node-10" "node-11")
declare -a step1=("agg0" "agg1" "agg2" "agg3" "agg4" "agg5")
declare -a step2=("tor0" "tor1" "tor2")
exp_sink="sink"
o_sink="sink2"




int2exp_sink="\$(ip route get 10.14.1.2 | grep -oP \"(?<= dev )[^ ]+\")"
int2o_sink="\$(ip route get 10.14.2.2 | grep -oP \"(?<= dev )[^ ]+\")"

int2node_gen ()
{
    int2node="\$(ip route get 10.10.${1}.1 | grep -oP \"(?<= dev )[^ ]+\")"
}


for host in "${sources[@]}"
do
	echo PING TEST from ${host} to sink:
	ssh -oStrictHostKeyChecking=no ${uname}@${host} -i $keyfile ping sink -c 1

	ssh -oStrictHostKeyChecking=no ${uname}@${host} -i $keyfile echo "connecting to ${host}"
	scp  -i $keyfile data_gen.zip ${uname}@${host}:/users/${uname}
	ssh -oStrictHostKeyChecking=no ${uname}@${host} -i $keyfile unzip -q -o /users/${uname}/data_gen.zip -d ~/data_gen
	scp  -i $keyfile flow_gen.sh ${uname}@${host}:/users/${uname}
	ssh -oStrictHostKeyChecking=no ${uname}@${host} -i $keyfile sudo chmod a+x /users/${uname}/flow_gen.sh
	scp  -i $keyfile node_init.sh ${uname}@${host}:/users/${uname}
	ssh -oStrictHostKeyChecking=no ${uname}@${host} -i $keyfile sudo chmod a+x /users/${uname}/node_init.sh
	echo "sudo tc qdisc del dev $int2exp_sink root"
	ssh -oStrictHostKeyChecking=no ${uname}@${host} -i $keyfile "sudo tc qdisc del dev $int2exp_sink root"
	ssh -oStrictHostKeyChecking=no ${uname}@${host} -i $keyfile echo "${host} done!"
	if [ "$update" == "u" ];
	then
		ssh -oStrictHostKeyChecking=no ${uname}@${host} -i $keyfile -f "sudo apt -y update; sudo apt-get -y update; sudo apt-get -y install iperf3 moreutils jq"
	fi
done

for host in "${sources[@]}"
do
	echo "Disabling offloading on ${host}..."

	ssh -oStrictHostKeyChecking=no ${uname}@${host} -i $keyfile 'bash -s' <<'EOF'
		# Get list of interfaces, excluding loopback
		ifs=$(netstat -i | tail -n+3 | awk '{print $1}' | grep -v lo | sort -u)

		# Disable all known offloading features
		for i in $ifs; do
			sudo ethtool -K "$i" gro off
			sudo ethtool -K "$i" lro off
			sudo ethtool -K "$i" gso off
			sudo ethtool -K "$i" tso off
			sudo ethtool -K "$i" ufo off
		done
EOF

	echo "${host} done!"
done

index=0
for host in "${step1[@]}"
do
	echo "sudo tc qdisc del dev $int2exp_sink root"
	ssh -oStrictHostKeyChecking=no ${uname}@${host} -i $keyfile "sudo tc qdisc del dev $int2exp_sink root"
	# handle node facing interfaces
	for n in 1 2
	do
		int2node_gen $( expr $index + $n )
		echo "sudo tc qdisc del dev $int2node root"
		ssh -oStrictHostKeyChecking=no ${uname}@${host} -i $keyfile "sudo tc qdisc del dev $int2node root"
	done

	ssh -oStrictHostKeyChecking=no ${uname}@${host} -i $keyfile echo "${host} done!"

	if [ "$update" == "u" ];
	then
		ssh -oStrictHostKeyChecking=no ${uname}@${host} -i $keyfile -f "sudo apt -y update; sudo apt-get -y update; sudo apt-get -y install iperf3 moreutils"
	fi	
	index=$( expr $index + 2 )
done

for host in "${step1[@]}"
do
        echo "Disabling offloading on ${host}..."

        ssh -oStrictHostKeyChecking=no ${uname}@${host} -i $keyfile 'bash -s' <<'EOF'
                # Get list of interfaces, excluding loopback
                ifs=$(netstat -i | tail -n+3 | awk '{print $1}' | grep -v lo | sort -u)

                # Disable all known offloading features
                for i in $ifs; do
                        sudo ethtool -K "$i" gro off
                        sudo ethtool -K "$i" lro off
                        sudo ethtool -K "$i" gso off
                        sudo ethtool -K "$i" tso off
                        sudo ethtool -K "$i" ufo off
                done
EOF

        echo "${host} done!"
done

index=0
for host in "${step2[@]}"
do

	echo "sudo tc qdisc del dev $int2exp_sink root"
	ssh -oStrictHostKeyChecking=no ${uname}@${host} -i $keyfile "sudo tc qdisc del dev $int2exp_sink root"
	# handle node facing interfaces
	for n in 1 3
	do
		int2node_gen $( expr $index + $n )
		echo "sudo tc qdisc del dev $int2node root"
		ssh -oStrictHostKeyChecking=no ${uname}@${host} -i $keyfile "sudo tc qdisc del dev $int2node root"
	done
	ssh -oStrictHostKeyChecking=no ${uname}@${host} -i $keyfile echo "${host} done!"
	if [ "$update" == "u" ];
	then
		ssh -oStrictHostKeyChecking=no ${uname}@${host} -i $keyfile -f "sudo apt -y update; sudo apt-get -y update; sudo apt-get -y install iperf3 moreutils"
	fi
	index=$( expr $index + 4 )
done


for host in "${step2[@]}"
do
        echo "Disabling offloading on ${host}..."

        ssh -oStrictHostKeyChecking=no ${uname}@${host} -i $keyfile 'bash -s' <<'EOF'
                # Get list of interfaces, excluding loopback
                ifs=$(netstat -i | tail -n+3 | awk '{print $1}' | grep -v lo | sort -u)

                # Disable all known offloading features
                for i in $ifs; do
                        sudo ethtool -K "$i" gro off
                        sudo ethtool -K "$i" lro off
                        sudo ethtool -K "$i" gso off
                        sudo ethtool -K "$i" tso off
                        sudo ethtool -K "$i" ufo off
                done
EOF

        echo "${host} done!"
done

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
echo Ignore fragmentation-offload warnings above


if [ "$update" == "u" ];
then
	sudo apt -y update 
	sudo apt-get -y update
	sudo apt-get -y install iperf3 moreutils # jq tshark
fi
# handle node facing interfaces
for n in 1 5 9
do
	int2node_gen $n
	echo "sudo tc qdisc del dev $(eval echo $int2node) root"
	sudo tc qdisc del dev $(eval echo $int2node) root
done


IS_EXP_SINK=1
IS_O_SINK=0

# exp sink
echo PING TEST from sink to emulator:
ssh -oStrictHostKeyChecking=no ${uname}@$exp_sink -i $keyfile ping emulator -c 1
scp  -i $keyfile init_server.sh ${uname}@$exp_sink:/users/${uname}
ssh -oStrictHostKeyChecking=no ${uname}@$exp_sink -i $keyfile sudo chmod a+x /users/${uname}/init_server.sh
int2node_gen 1 # any node would work
echo "sudo tc qdisc del dev $int2node root"
ssh -oStrictHostKeyChecking=no ${uname}@${exp_sink} -i $keyfile "sudo tc qdisc del dev $int2node root"
ssh -oStrictHostKeyChecking=no ${uname}@$exp_sink -i $keyfile echo "${exp_sink} done!"
if [ "$update" == "u" ];
then
	ssh -oStrictHostKeyChecking=no ${uname}@${exp_sink} -i $keyfile -f "sudo apt -y update; sudo apt-get -y update; sudo apt-get -y install iperf3 moreutils jq"
fi

# other sink
echo PING TEST from sink2 to emulator:
ssh -oStrictHostKeyChecking=no ${uname}@$o_sink -i $keyfile ping emulator -c 1
scp  -i $keyfile init_server.sh ${uname}@$o_sink:/users/${uname}
ssh -oStrictHostKeyChecking=no ${uname}@$o_sink -i $keyfile sudo chmod a+x /users/${uname}/init_server.sh
int2node_gen 1 # any node would work
echo "sudo tc qdisc del dev $int2node root"
ssh -oStrictHostKeyChecking=no ${uname}@${o_sink} -i $keyfile "sudo tc qdisc del dev $int2node root"
ssh -oStrictHostKeyChecking=no ${uname}@$o_sink -i $keyfile echo "${o_sink} done!"
if [ "$update" == "u" ];
then
	ssh -oStrictHostKeyChecking=no ${uname}@${o_sink} -i $keyfile -f "sudo apt -y update; sudo apt-get -y update; sudo apt-get -y install iperf3 moreutils jq"
fi

