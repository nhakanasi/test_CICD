# hello-web: Kubernetes + Argo CD GitOps demo

A static HTML page served by nginx, deployed to a local Kubernetes cluster by Argo CD.

## How the pipeline works

```
edit app/index.html ─► git push ─► GitHub Actions
                                    ├─ build image, push ghcr.io/<owner>/<repo>:<sha>
                                    └─ commit new tag into k8s/kustomization.yaml
                                                   │
Argo CD (in cluster) polls repo ◄───────────────────┘
   └─ sees new tag ─► syncs Deployment ─► new pods roll out
```

| Path | Purpose |
|------|---------|
| `app/` | `index.html` + `Dockerfile` (nginx:alpine) |
| `k8s/` | Namespace, Deployment, NodePort Service, Kustomization (image tag lives here) |
| `argocd/application.yaml` | Argo CD Application: watches `k8s/` on `main`, auto-sync + self-heal + prune |
| `.github/workflows/ci.yaml` | Build, push, bump tag |
| `scripts/` | Create/delete a local kind cluster with Argo CD |

## Prerequisites

- Docker Desktop (running)
- [kind](https://kind.sigs.k8s.io/), kubectl
- A GitHub account

On Windows: `winget install Docker.DockerDesktop Kubernetes.kind Kubernetes.kubectl`, then run the scripts from Git Bash.

## Setup

1. **Create a public GitHub repo** and push this folder to `main`.

2. **Replace placeholders** `OWNER/REPO` (lowercase) in:
   - `k8s/kustomization.yaml` → `newName: ghcr.io/<owner>/<repo>`
   - `argocd/application.yaml` → `repoURL: https://github.com/<owner>/<repo>.git`

   Commit and push. The first push touching `app/` (or a manual run via *Actions → build-and-deploy → Run workflow*) builds the image.

3. **Make the image public**: GitHub → your profile → *Packages* → the package → *Package settings* → *Change visibility → Public*. (Otherwise the cluster cannot pull it. Alternative: create an `imagePullSecret`.)

4. **Start cluster + Argo CD**:
   ```bash
   bash scripts/setup.sh
   ```
   It prints the Argo CD admin password.

5. **Open**:
   - App: http://localhost:8080
   - Argo CD UI: `kubectl -n argocd port-forward svc/argocd-server 8443:443` → https://localhost:8443 (user `admin`)

## Test the automation

1. Edit `app/index.html`, change `Version: v1` to `Version: v2`.
2. `git commit -am "v2" && git push`
3. Watch the Actions run finish; it commits `deploy: hello-web <sha>`.
4. Argo CD polls every ~3 minutes (or click *Refresh* in the UI). Pods roll out; reload http://localhost:8080.

Self-heal check: `kubectl -n hello-web scale deploy/hello-web --replicas=5`. Argo CD reverts it to 2.

## Rollback

`git revert` the `deploy: ...` commit and push. Argo CD syncs back to the previous image.

## Cleanup

```bash
bash scripts/teardown.sh
```
