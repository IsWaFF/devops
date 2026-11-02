# week 20

## k8s day 19

architecture. every word of the diagram is a process or a file on a node, no new yaml. exercises skipped, crictl and etcdctl are not for now

main idea: we describe the state, components make it true. they all talk only through the api server, never directly to each other

**control plane:**

- apiserver - the only door, only it talks to etcd
- etcd - cluster state
- scheduler - picks a node for a new pod
- controller-manager - makes the actual state match the desired one

**worker:**

- kubelet - runs pods, probes, reports status
- containerd - runs containers
- kube-proxy - service rules
- cni - pod ips and routes

### what if a component dies

| down | still works | breaks |
| --- | --- | --- |
| apiserver | running pods and services | `kubectl`, no changes, other components are blind |
| etcd | same as apiserver | apiserver can't read or write |
| scheduler | running pods | new pods stay `Pending`, without events |
| controller-manager | running pods | no new pods for deployments/jobs, no self-healing, no rollouts |
| kubelet (one node) | its containers keep running | node `NotReady`, no restarts, no probes, after ~5 min pods are replaced on other nodes |
| kube-proxy (one node) | existing rules | new services and endpoint changes don't reach this node |
| coredns | connections by ip | every name |

### cni vs kube-proxy

- cni gives a pod its ip and routes, so any pod reaches any pod, even on another node
- kube-proxy writes iptables rules: service ip -> one of the pods. traffic doesn't go through it, the kernel does it

checked from `client` without any service:

- `ping 10.244.1.7` - web-1 on another node, 0% loss
- `ping 10.96.0.1` - clusterip, 100% loss. it exists only in the rules, so check a service with curl, not ping

pod ip is unique in the cluster, except `hostNetwork: true` pods (kube-proxy, kindnet, control plane) - they use the node ip. containers in one pod share one ip

- more control plane nodes is not always better. odd number, 3 or 5, etcd needs quorum. 4 survive losing 1 like 3, 2 survive losing 0
