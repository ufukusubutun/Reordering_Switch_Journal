
## Experiments

The folder `illustrative` contains instructions, scripts and experiment profile for illustrative experiments presented in Section 2 of our paper. These experiments involve a 4 node line topology, realized using VMs and interconnected with 100 Mbps links and insertion of controlled and deterministic reordering patterns. We use this setup to examine the impact on a single TCP flow and observe the reaction of different TCP loss detection mechanisms.

The folder `large_scale` contains instructions, scripts and experiment profile for illustrative experiments presented in Section 4 of our paper. These large scale experiments involve a 24 node topology of bare metal servers. The emulated switch implements a load balancer which may reorder packets. In these experiments we aim to examine the impact of increasing line rates on the aggregate TCP performance.