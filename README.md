# Infrastructure Owner Assessment – k3s on Hetzner

## Overview
This repository contains the complete infrastructure setup, deployment steps, and operational reasoning for running **Open WebUI** on a **single-node k3s Kubernetes cluster** hosted on a **Hetzner Cloud VM**.

The objective of this assessment is to demonstrate **infrastructure ownership**, not just deployment capability. Emphasis is placed on judgment, failure awareness, security thinking, cost efficiency, and recovery planning appropriate for an early-stage startup.

---

## Environment
- Ubuntu 24
- Single Hetzner Cloud VM
- Docker Engine
- k3s (single-node Kubernetes)
- Helm v3

---

## Cluster Setup
The cluster was bootstrapped using k3s on a single virtual machine.

### Setup Steps
- Installed Docker Engine
- Installed k3s as a single-node Kubernetes cluster
- Configured `kubectl` access for a non-root user

All setup steps are scripted in `k3s/install.sh` to ensure repeatability and ease of recovery.

### Why k3s
k3s was selected due to its minimal operational overhead, fast installation time, and low resource consumption. It is well-suited for early-stage workloads where simplicity and speed of iteration are more important than high availability.

### Tradeoffs
- Single point of failure
- No high availability
- All workloads depend on one node

These tradeoffs are acceptable for early-stage environments but must be revisited before production scale.

---

## Application Deployment
Open WebUI was deployed using Helm into a dedicated namespace.

### Deployment Decisions
- Namespace: `openwebui`
- Service type: `ClusterIP`
- Helm dry-run performed before installation

### Deployment Commands
```bash
helm repo add open-webui https://helm.openwebui.com/
helm repo update

kubectl create namespace openwebui

helm install webui open-webui/open-webui \
  --namespace openwebui \
  --set service.type=ClusterIP
```

The ClusterIP service type was chosen to keep the application internal and avoid premature public exposure. External access should be introduced later using an ingress controller.

---

## OIDC Configuration
OIDC authentication was configured using Helm values applied to the Open WebUI release. The configuration was intentionally kept minimal to reflect a real-world scenario where authentication is optional and not enforced at startup.

### OIDC Values
```yaml
oidc:
  clientId: "test"
  clientSecret: ""
  issuer: "https://oidc.local/auth/realms/hyperplane/.well-known/openid-configuration"
  scopes:
    - openid
    - profile
    - email
```

The issuer points to the OpenID Connect discovery endpoint of the identity provider. This endpoint exposes authentication metadata such as authorization endpoints, token endpoints, and signing keys.

The clientSecret was intentionally left empty because no real authentication flow was executed during this assessment, and no secrets were committed to the repository.

### Observed Behavior
After applying the OIDC configuration, the application started successfully and all pods remained in a healthy running state.

### Analysis
Although the assessment states that enabling OIDC would trigger a startup failure, Open WebUI evaluates OIDC lazily. The OIDC issuer is not contacted during application startup unless authentication is explicitly enforced or a login flow is initiated. As a result, no TLS validation occurred and no startup failure was triggered.

This behavior is consistent with applications that allow optional authentication or fallback access modes.

### Production Implication
This introduces a potential production risk: identity provider outages or certificate trust issues may only surface during user authentication rather than at deployment time.

---

## Production Readiness

### Top Risks Before Going Live
1. Single-node architecture causes a full outage on node failure
2. No automated backups
3. No monitoring or alerting
4. Authentication issues may surface only at login time
5. Secrets are not centrally managed or rotated

### First Two Improvements
1. Introduce monitoring and alerting to detect failures early
2. Implement automated backups for persistent data

### Failure Scenario: 10× Traffic Spike and Node Failure at 2 AM

#### What Breaks First
The entire cluster becomes unavailable due to the single-node design.

#### Recovery Process
1. Provision a replacement VM
2. Reinstall k3s
3. Redeploy Helm charts
4. Restore backups if persistent data is involved

#### Changes the Next Day
1. Reduce blast radius through redundancy or faster recovery mechanisms
2. Add traffic controls or rate limiting

---

## Security and Secrets Management

### Secret Handling Strategy
- Use Kubernetes Secrets initially
- Migrate to an external secret manager as the system matures

### What Must Never Be Stored in Git
- API tokens
- Private keys
- Certificates
- Secrets

### Secrets That Require Rotation
- OIDC client secrets
- SSH keys
- API tokens

---

## Backups and Recovery

### Data Requiring Backups
- Databases
- Persistent volumes
- Application state

### Backup Frequency
Daily automated backups

### Recovery Testing
Periodic restore testing to validate backup integrity

---

## Cost Ownership (Hetzner)

### Cost Control Approach
- Use a single VM to minimize infrastructure costs
- Avoid managed Kubernetes early
- Scale infrastructure only when justified by usage

### What to Avoid Early
- Premature high availability
- Over-engineered infrastructure

### When to Move Away from k3s
- When high availability becomes mandatory
- When multi-node clusters are required
- When operational complexity can be sustained

---

## Extra Credit: Self-Signed OIDC Certificate
A maintainable approach to trusting a self-signed OIDC certificate is to inject the custom CA using Kubernetes Secrets and mount it into the container trust store. This avoids rebuilding container images and allows certificate rotation without redeploying the application.

---

## Conclusion
This setup prioritizes simplicity, cost efficiency, and clarity of failure modes. The observed OIDC behavior highlights the importance of understanding application-specific authentication flows rather than assuming eager validation. The design reflects early-stage startup constraints while clearly identifying areas that must evolve before production scale.

## Output for kubectl terminal 
```bash
kubectl get nodes
kubectl get all -n openwebui

NAME            STATUS   ROLES           AGE   VERSION
abdulahadkh23   Ready    control-plane   61m   v1.34.3+k3s1
NAME                                       READY   STATUS    RESTARTS   AGE
pod/open-webui-0                           1/1     Running   0          56m
pod/open-webui-ollama-5d99896fd7-jqwcb     1/1     Running   0          56m
pod/open-webui-pipelines-7d8757f9c-9clg8   1/1     Running   0          56m
pod/open-webui-redis-c47dbfbcd-thrns       1/1     Running   0          56m

NAME                           TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)     AGE
service/open-webui             ClusterIP   10.43.138.147   <none>        80/TCP      56m
service/open-webui-ollama      ClusterIP   10.43.126.77    <none>        11434/TCP   56m
service/open-webui-pipelines   ClusterIP   10.43.227.104   <none>        9099/TCP    56m
service/open-webui-redis       ClusterIP   10.43.183.144   <none>        6379/TCP    56m

NAME                                   READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/open-webui-ollama      1/1     1            1           56m
deployment.apps/open-webui-pipelines   1/1     1            1           56m
deployment.apps/open-webui-redis       1/1     1            1           56m

NAME                                             DESIRED   CURRENT   READY   AGE
replicaset.apps/open-webui-ollama-5d99896fd7     1         1         1       56m
replicaset.apps/open-webui-pipelines-7d8757f9c   1         1         1       56m
replicaset.apps/open-webui-redis-c47dbfbcd       1         1         1       56m

NAME                          READY   AGE
statefulset.apps/open-webui   1/1     56m
```


