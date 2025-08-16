#!/bin/bash

n_serv=$1;
i_serv=$(expr $n_serv - 1)

base_port=50000

echo "===================================";
echo "Setting up $n_serv iperf3 servers."
echo "==================================";

echo "n_serv: $1";
echo "From port:$base_port to $(expr $base_port + $i_serv)";

for i in $(seq 0 1 $i_serv)
do
   port_num=$(expr $base_port + $i)
   iperf3 -s -p $port_num -D &
done

