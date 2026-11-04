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

## k8s day 20

what happens on `kubectl apply`, then switched parts off to see what stops

1. kubectl sends https to the apiserver
2. apiserver: authn -> rbac -> admission -> validation -> etcd -> `created`. kubectl returns here, nothing runs yet
3. deployment controller makes a replicaset, replicaset controller makes pods with no node
4. scheduler writes a node into the pod
5. kubelet sees the pod, asks containerd via cri: sandbox -> cni gives ip -> pull image -> start. then probes, status goes to the apiserver
6. pod is ready -> its ip goes to the endpointslice -> kube-proxy updates iptables

nobody calls anybody, everyone watches the apiserver. controllers are not created, they always run inside controller-manager and create objects

- sandbox - `pause` process holding the pod's net, ipc and uts namespaces. the ip is its, so a container restart keeps the ip. cni only sets up the network and leaves
- `kubectl get pods -w` prints a line on every object change, not on every status change, so identical lines are fine

### break-1: `late` 0/2

no pods, no replicaset, no events. deployment is in etcd but nobody executes it

`kubectl -n kube-system get pods` - no controller-manager. it's a static pod, its file was moved from `/etc/kubernetes/manifests` to `/root`. moved it back, kubelet started it, `late` went 2/2 by itself

- no pods and no events -> controller-manager
- pods `Pending` with no node -> scheduler

### break-2: `lab-worker2` NotReady

kubelet and containerd were stopped. starting only kubelet gives a crash loop, `journalctl -u kubelet` says it can't reach the containerd socket. started containerd, kubelet came up by itself

- after ~40 s node is `NotReady`
- after ~5 min `podinfo` process is still alive on the node
- after ~5.5 min pod is evicted, replacement starts on `lab-worker`
- node came back - kubelet killed the old pod

why 5 min: node gets the `unreachable` taint, pods tolerate it for 300 s, then eviction. replicaset controller makes a new pod, scheduler places it. leaving the endpoints is a separate thing, it happens because the pod is not ready

both `late` pods stayed on `lab-worker`, k8s doesn't rebalance running pods
