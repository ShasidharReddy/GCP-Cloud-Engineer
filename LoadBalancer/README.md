# LoadBalancer

Overview: examples for setting up different types of Google Cloud Load Balancers.

Types covered in this folder:
- Network LB (Layer 4) — low-latency TCP/UDP
- HTTP(S) LB (Layer 7) — global HTTP(S) with CDN

How to use:
- Review ver1/ and ver2/ directories for configs and terraform examples.
- For quick testing, create backends (instance groups or NEGs) then follow steps in V2/ or scripts in LoadBalancer/ver2.

Suggested workflow:
1. Create instance groups (or NEGs) for backends
2. Configure health checks
3. Create backend services and forwarding rules
4. Test with curl and check health status

Files:
- LoadBalancer/ver1/ and ver2/ — sample configs
- V2 contains canonical LB guides; consult it for production-ready setups.

Security:
- Lock down backend instances via firewall rules and IAM.
