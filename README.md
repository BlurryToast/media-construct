# Media Server Stack — Kubernetes GitOps

A Kubernetes-native media server stack managed via GitOps with Argo CD. Migrated from Docker Compose, preserving the existing `/data/` storage layout and `*.zion.home` routing.

## Architecture

Every service runs as its own independent Deployment. A single Argo CD ApplicationSet with a Git directory generator auto-discovers all directories under `argocd/` and deploys them uniformly as Kustomize applications.

VPN routing uses an application-level proxy pattern instead of shared network namespaces: Gluetun runs standalone and exposes SOCKS5/HTTP proxy endpoints. Services that need VPN (qBittorrent, Prowlarr) point at Gluetun's ClusterIP Service.

```
                         ┌─────────────────────────────────┐
                         │        Argo CD (argocd ns)       │
                         │   ApplicationSet → Git Dir Gen   │
                         └──────────────┬──────────────────┘
                                        │ auto-discovers argocd/*
                         ┌──────────────▼──────────────────┐
                         │         media namespace          │
                         │                                  │
  *.zion.home ──────────►│  Traefik (Ingress Controller)    │
                         │       │                          │
       ┌─────────────────┼───────┼──────────────────────────┤
       │  VPN-routed     │       │    Direct cluster net    │
       │                 │       │                          │
       │  qBittorrent ───┼─SOCKS5─► Gluetun ──► ProtonVPN  │
       │  Prowlarr ──────┼─HTTP────►   │                    │
       │                 │       │     │                    │
       │                 │  Sonarr ◄───┼──► qBittorrent     │
       │                 │  Radarr ◄───┼──► Prowlarr        │
       │                 │  Prowlarr ──┼──► FlareSolverr    │
       │                 │  Configarr ─┼──► Sonarr/Radarr   │
       │                 │             │                    │
       │                 │  Jellyfin   Jellyseerr   Homarr  │
       └─────────────────┴─────────────────────────────────┘
```

## Services

| Service | Type | URL | Port | VPN |
|---|---|---|---|---|
| Traefik | Helm (Kustomize inflation) | — | 80/443 | No |
| Gluetun | Kustomize | Internal only | 8388/8888/9999 | WireGuard |
| qBittorrent | Kustomize | `bittorrent.zion.home` | 8088 | SOCKS5 → Gluetun |
| Sonarr | Kustomize | `sonarr.zion.home` | 8989 | No |
| Radarr | Kustomize | `radarr.zion.home` | 7878 | No |
| Prowlarr | Kustomize | `prowlarr.zion.home` | 9696 | HTTP → Gluetun |
| FlareSolverr | Kustomize | Internal only | 8191 | No |
| Jellyfin | Helm (Kustomize inflation) | `jellyfin.zion.home` | 8096 | No |
| Jellyseerr | Kustomize | `jellyseerr.zion.home` | 5055 | No |
| Homarr | Kustomize | `zion.home` | 7575 | No |
| Configarr | Kustomize (CronJob) | — | — | No |

## Repository Structure

```
├── bootstrap/                     # Applied manually once during initial setup
│   ├── namespace.yaml             # Creates argocd + media namespaces
│   └── applicationset.yaml        # Single ApplicationSet (Git directory generator)
│
├── argocd/                        # Each subdirectory = one Argo CD Application
│   ├── argocd/                    # Argo CD itself (Kustomize + Helm inflation)
│   ├── traefik/                   # Traefik ingress (Kustomize + Helm inflation)
│   ├── jellyfin/                  # Jellyfin (Kustomize + Helm inflation)
│   ├── gluetun/                   # Gluetun VPN proxy
│   ├── qbittorrent/               # qBittorrent download client
│   ├── sonarr/                    # Sonarr TV series manager
│   ├── radarr/                    # Radarr movie manager
│   ├── prowlarr/                  # Prowlarr indexer manager
│   ├── flaresolverr/              # FlareSolverr (internal, no ingress)
│   ├── jellyseerr/                # Jellyseerr media requests
│   ├── homarr/                    # Homarr dashboard
│   ├── configarr/                 # Configarr TRaSH-Guides profiles (CronJob)
│   ├── storage/                   # PVs and PVCs (sync wave 0)
│   └── common/                    # Shared ConfigMap + secrets placeholder (sync wave 0)
```

## Sync Wave Strategy

| Wave | What | Why |
|------|------|-----|
| 0 | `storage/`, `common/` | PVs, PVCs, ConfigMaps, and secret placeholders must exist before workloads start |
| 1 | Everything else | Workloads that depend on wave 0 resources |

## Namespaces

- `argocd` — Argo CD control plane
- `media` — All media stack workloads

## Prerequisites

- A running Kubernetes cluster
- `kubectl` configured with cluster access
- `kustomize` (v5+) installed locally (for the Argo CD bootstrap step)

## Deployment

### 1. Create namespaces

```bash
kubectl apply -f bootstrap/namespace.yaml
```

### 2. Create secrets

Secrets are never committed to the repo. Create them manually:

```bash
# Gluetun WireGuard key
kubectl create secret generic wireguard-private-key -n media \
  --from-file=WIREGUARD_PRIVATE_KEY=./secrets/wireguard-private-key.secret

# Homarr encryption key
kubectl create secret generic homarr-encryption-key -n media \
  --from-file=SECRET_ENCRYPTION_KEY=./secrets/homarr-encryption-key.secret

# Configarr API keys (get these from Sonarr/Radarr after first launch)
kubectl create secret generic configarr-api-keys -n media \
  --from-literal=SONARR_API_KEY=<your-sonarr-api-key> \
  --from-literal=RADARR_API_KEY=<your-radarr-api-key>
```

### 3. Bootstrap Argo CD

```bash
kustomize build --enable-helm argocd/argocd | kubectl apply --server-side -n argocd -f -
```

### 4. Deploy the ApplicationSet

```bash
kubectl apply -f bootstrap/applicationset.yaml
```

Argo CD will now auto-discover all directories under `argocd/`, sync wave 0 first (storage + common), then deploy all workloads.

### 5. Post-deployment configuration

These settings are configured via each service's web UI after first launch — not in Kubernetes manifests:

- **qBittorrent** — Set SOCKS5 proxy to `gluetun-svc.media.svc.cluster.local:8388`
- **Prowlarr** — Set HTTP proxy to `gluetun-svc.media.svc.cluster.local:8888` under Settings → General → Proxy
- **Prowlarr** — Add FlareSolverr as indexer proxy at `flaresolverr-svc.media.svc.cluster.local:8191`
- **Sonarr/Radarr** — Configure download client pointing to `qbittorrent-svc.media.svc.cluster.local:8088` and indexer to `prowlarr-svc.media.svc.cluster.local:9696`

## Storage

All data lives on the host under `/data/` using hostPath volumes — no data migration needed from the Docker Compose setup:

| Path | Used by | Access mode |
|------|---------|-------------|
| `/data/media` | Jellyfin, Sonarr, Radarr | ReadWriteMany |
| `/data/torrents` | qBittorrent, Sonarr, Radarr | ReadWriteMany |
| `/data/appdata/{service}` | Per-service config | ReadWriteOnce |

## Adding a New Service

1. Create a new directory under `argocd/` with a `kustomization.yaml`
2. Push to the repo
3. The ApplicationSet automatically discovers and deploys it

## Key Design Decisions

- **Proxy over sidecar** — VPN-dependent services use Gluetun's SOCKS5/HTTP proxy endpoints instead of sharing a network namespace. This avoids the "mega-pod" anti-pattern and lets each service scale independently.
- **Unified Kustomize** — Every directory is a Kustomize application. Helm charts (Argo CD, Traefik, Jellyfin) use Kustomize's `helmCharts` field for inflation. No special handling needed in the ApplicationSet.
- **Single ApplicationSet** — One Git directory generator, no exclusions. Adding a service = adding a directory.
- **Lightweight Argo CD** — Redis is disabled and resource limits are tuned down for a single-node, single-repo setup. The ApplicationSet controller is enabled for auto-discovery.
- **Argo CD `--enable-helm`** — The repo server runs with this flag so Kustomize Helm chart inflation works for all apps.
