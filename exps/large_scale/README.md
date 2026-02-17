

## Large Scale experiments (from Section 4)


Cloudlab profile for the 24 node topology:
https://www.cloudlab.us/p/nyunetworks/branch-reord-nonbtlnck-pub


## General description of all scripts in this repo

`set_up.sh` - Connects to all physical servers, tranfers necessary files and sets up the experiment environment

`auto_branched_v3.bash` - The main experiment script that sets up the desired switch configuration at the emulator node, that sets up link capacities, buffer sizes, fixed delays at each of the nodes/links, that sets the desired TCP Recovery algorithm at each of the traffic generating nodes and that simultaneously starts and manages flow generators at the traffic generating nodes

`init_server.sh` - Run locally at the sinks by the auto_branched_v3.bash script, initiallizes and controls iperf3 servers (sinks).

`node_init.sh` - Run locally at each node by the auto_branched_v3.bash script, initiallizes and controls flow_gens at each traffic generating node

`flow_gen.sh` - An instance of a flow generator to be run in bulk at each traffic generator nodes in parallel. Picks TCP flow sizes from the trace and runs those flows. There is a random wait time between the start of one flow to the start of the oher.

`rename.sh` - Renames .pcap packet captures with respect to experiment parameters

`run_v5.sh` - Produces .csv files out of .pcap packet captures
