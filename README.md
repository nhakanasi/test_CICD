# LLM hosting on Kubernetes + Argo CD (GitOps demo)

Serves a small open model (`qwen2.5:0.5b` via [Ollama](https://ollama.com)) on a local
3-node kind cluster, with a browser chat UI, deployed entirely by Argo CD from this repo.
It runs on CPU, so it needs no GPU, but it is set up the way GPU serving is: a dedicated,
tainted "GPU" node, model weights kept outside the image, slow-start probes, and
no-surge rollouts.

## Architecture

```
browser ─► localhost:8080 ─► chat-ui (nginx, 2 pods, general node)
                               ├─ /        static chat page
                               └─ /api/*, /v1/*  streamed proxy ─► Service ollama:11434
                                                            ─► ollama pod (fake-gpu node)
                                                                 └─ PVC: model weights

Git (k8s/) ─► Argo CD ─► cluster
```

| Node | Label | Taint | Runs |
|------|-------|-------|------|
| `argocd-demo-control-plane` | | control-plane | Kubernetes itself |
| `argocd-demo-worker` | `accelerator=fake-gpu` | `dedicated=llm:NoSchedule` | ollama only |
| `argocd-demo-worker2` | `workload=general` | | chat-ui, Argo CD |

## Repository layout

| Path | Purpose |
|------|---------|
| `app/` | Chat UI: `index.html`, `nginx.conf` (streaming proxy to Ollama), `Dockerfile`. Built by CI. |
| `k8s/ollama.yaml` | PVC for weights, Ollama Deployment (init container pulls the model), ClusterIP Service |
| `k8s/chat-ui.yaml` | Chat UI Deployment and NodePort Service (30080) |
| `k8s/kustomization.yaml` | **Model name** (`MODEL=`), Ollama version, chat-ui image tag |
| `argocd/application.yaml` | Argo CD app `llm-host`: watches `k8s/`, auto-sync, self-heal, prune |
| `.github/workflows/ci.yaml` | On `app/` changes: build chat-ui image, push to GHCR, bump tag in `k8s/` |
| `scripts/` | Create and delete the kind cluster with Argo CD |

## Two kinds of deploy

| You change | Who acts | Result |
|------------|----------|--------|
| `app/*` (UI code) | CI builds an image and commits the new tag, then Argo CD syncs | chat-ui pods roll over with no downtime |
| `MODEL=` in `k8s/kustomization.yaml` | Argo CD only, no image build | The ConfigMap name hash changes, the ollama pod restarts and its init container pulls the new model |
| `newTag` of `ollama` | Argo CD only | Ollama server upgraded; the cached model is reused |

The model is configuration, not code: switching models never rebuilds an image.

## Setup

Prerequisites: Docker Desktop (running), kind, kubectl, Git Bash on Windows.

```bash
bash scripts/teardown.sh   # if an older cluster exists
bash scripts/setup.sh
```

The first start downloads the Ollama image and the model (~400MB). Watch it:

```bash
kubectl -n llm get pods -o wide -w
```

The ollama pod goes `Init:0/1` (pulling the model), then `Running 0/1` (starting; the
startup probe allows up to 5 minutes), then `1/1`.

- Chat UI: http://localhost:8080
- Argo CD UI: `kubectl -n argocd port-forward svc/argocd-server 8443:443`, then https://localhost:8443 (user `admin`; `setup.sh` prints the password)

The chat-ui image on GHCR must be public (GitHub, Packages, `test_cicd`, Package settings).

## API

The UI proxies the Ollama API, so you can call it directly:

```bash
curl http://localhost:8080/api/tags
curl -N http://localhost:8080/api/chat -d '{"model":"qwen2.5:0.5b","messages":[{"role":"user","content":"Hi"}]}'
```

`-N` shows tokens as they stream in. Ollama also serves an OpenAI-compatible API at `/v1/chat/completions`.

## Experiments

1. **Scheduling**: `kubectl get pods -A -o wide`. Ollama is on `worker` only; nothing else is.
   Remove the toleration from `k8s/ollama.yaml` and push: the pod stays `Pending`.
2. **Model upgrade via GitOps**: set `MODEL=qwen2.5:1.5b`, commit, and push. Watch the old pod
   stop before the new one starts (`maxSurge: 0`), the init container pull the new model, and
   both models appear in the UI's model list (the cache keeps the old one).
3. **Out of memory**: lower the ollama memory limit to `512Mi`; the pod gets `OOMKilled` when the model loads.
4. **Self-heal**: `kubectl -n llm delete deploy ollama`. Argo CD recreates it; the model is still cached on the PVC, so startup is fast.
5. **Latency**: the UI shows time to first token and tokens per second. Send several prompts
   from different tabs at once and watch latency rise: one server, requests queue.
6. **Streaming**: set `proxy_buffering on;` in `app/nginx.conf` and push. Replies now appear all at once instead of token by token.

## Cleanup

```bash
bash scripts/teardown.sh
```
