# Implementation Plan: k8s-gitops-migration

## Overview

Migrate the Docker Compose media server stack to Kubernetes with GitOps delivery via Argo CD. Tasks follow the sync wave strategy: bootstrap infrastructure (wave 0) first, then Argo CD and ingress, then individual workloads (wave 1). Every manifest is sourced from the design document.

## Tasks

- [x] 1. Create bootstrap manifests and directory structure
  - [x] 1.1 Create `bootstrap/namespace.yaml` with `argocd` and `media` namespace definitions
    - _Requirements: 3.1, 3.2_
  - [x] 1.2 Create `bootstrap/applicationset.yaml` with the single ApplicationSet using Git directory generator for `k8s/*`
    - Configure automated sync policy with prune and selfHeal
    - Default destination namespace `media`
    - _Requirements: 2.1, 2.2, 2.3, 2.6, 2.7, 2.8_

- [x] 2. Create sync wave 0 infrastructure — storage and common configuration
  - [x] 2.1 Create `k8s/storage/persistent-volumes.yaml` with all PV/PVC pairs
    - media-pv/pvc (ReadWriteMany, /data/media)
    - torrents-pv/pvc (ReadWriteMany, /data/torrents)
    - Per-service config PV/PVCs: gluetun, bittorrent, sonarr, radarr, prowlarr, jellyfin, jellyfin-cache, jellyseerr, homarr (ReadWriteOnce, /data/appdata/{service})
    - All annotated with `argocd.argoproj.io/sync-wave: "0"`
    - _Requirements: 16.1, 16.2, 16.3, 16.4, 16.5, 4.8_
  - [x] 2.2 Create `k8s/storage/kustomization.yaml` referencing persistent-volumes.yaml
    - _Requirements: 16.6, 4.2_
  - [x] 2.3 Create `k8s/common/configmap-common-env.yaml` with PUID=1000, PGID=1000, TZ=Etc/UTC
    - Annotated with `argocd.argoproj.io/sync-wave: "0"`
    - _Requirements: 18.1, 18.4, 4.8_
  - [x] 2.4 Create `k8s/common/secrets-placeholder.yaml` documenting required manual secrets (wireguard-private-key, homarr-encryption-key, configarr-api-keys)
    - _Requirements: 17.3, 17.4, 17.5_
  - [x] 2.5 Create `k8s/common/kustomization.yaml` referencing configmap and secrets-placeholder
    - _Requirements: 4.2, 4.4_

- [x] 3. Checkpoint — Verify wave 0 manifests
  - Ensure `kustomize build k8s/storage` and `kustomize build k8s/common` render valid YAML. Ask the user if questions arise.

- [x] 4. Create Argo CD Kustomize + Helm inflation manifests
  - [x] 4.1 Create `k8s/argocd/kustomization.yaml` with helmCharts field for argo-cd chart, namespace set to `argocd`
    - _Requirements: 1.1, 1.6, 1.7, 4.2, 4.3_
  - [x] 4.2 Create `k8s/argocd/values.yaml` with Redis disabled, ApplicationSet enabled, --enable-helm on repo server, resource limits
    - _Requirements: 1.2, 1.3, 1.4, 1.8_

- [x] 5. Create Traefik Kustomize + Helm inflation manifests
  - [x] 5.1 Create `k8s/traefik/kustomization.yaml` with helmCharts field for traefik chart
    - _Requirements: 5.1, 4.2, 4.3_
  - [x] 5.2 Create `k8s/traefik/values.yaml` with port 80 listener, Kubernetes Ingress provider enabled, LoadBalancer service type, health check
    - _Requirements: 5.2, 5.3, 5.4, 5.6_

- [x] 6. Create Gluetun VPN proxy manifests
  - [x] 6.1 Create `k8s/gluetun/deployment.yaml` with ProtonVPN WireGuard config, NET_ADMIN capability, /dev/net/tun, secret ref, health probes on port 9999
    - Sync wave 1 annotation
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.8, 6.11, 4.9_
  - [x] 6.2 Create `k8s/gluetun/service.yaml` exposing SOCKS5 (8388), HTTP proxy (8888), and health (9999) ports
    - _Requirements: 6.6, 6.7, 6.8, 6.10_
  - [x] 6.3 Create `k8s/gluetun/kustomization.yaml` referencing deployment and service
    - _Requirements: 6.9, 4.2_

- [x] 7. Create qBittorrent manifests
  - [x] 7.1 Create `k8s/qbittorrent/deployment.yaml` with common-env ConfigMap, config and torrents PVC mounts, health probes, sync wave 1
    - _Requirements: 7.1, 7.3, 7.5, 18.1, 4.9_
  - [x] 7.2 Create `k8s/qbittorrent/service.yaml` exposing WebUI port 8088
    - _Requirements: 7.1, 7.3_
  - [x] 7.3 Create `k8s/qbittorrent/ingress.yaml` routing `bittorrent.media.home` to qbittorrent-svc
    - _Requirements: 7.3_
  - [x] 7.4 Create `k8s/qbittorrent/kustomization.yaml` referencing all manifests
    - _Requirements: 7.4, 4.2_

- [x] 8. Create Sonarr manifests
  - [x] 8.1 Create `k8s/sonarr/deployment.yaml` with common-env ConfigMap, config/media/torrents PVC mounts, health probes on /ping, sync wave 1
    - _Requirements: 10.1, 10.2, 10.5, 18.1, 4.9_
  - [x] 8.2 Create `k8s/sonarr/service.yaml` exposing port 8989
    - _Requirements: 10.1, 10.3_
  - [x] 8.3 Create `k8s/sonarr/ingress.yaml` routing `sonarr.media.home` to sonarr-svc
    - _Requirements: 10.3_
  - [x] 8.4 Create `k8s/sonarr/kustomization.yaml` referencing all manifests
    - _Requirements: 10.4, 4.2_

- [x] 9. Create Radarr manifests
  - [x] 9.1 Create `k8s/radarr/deployment.yaml` with common-env ConfigMap, config/media/torrents PVC mounts, health probes on /ping, sync wave 1
    - _Requirements: 11.1, 11.2, 11.5, 18.1, 4.9_
  - [x] 9.2 Create `k8s/radarr/service.yaml` exposing port 7878
    - _Requirements: 11.1, 11.3_
  - [x] 9.3 Create `k8s/radarr/ingress.yaml` routing `radarr.media.home` to radarr-svc
    - _Requirements: 11.3_
  - [x] 9.4 Create `k8s/radarr/kustomization.yaml` referencing all manifests
    - _Requirements: 11.4, 4.2_

- [x] 10. Create Prowlarr manifests
  - [x] 10.1 Create `k8s/prowlarr/deployment.yaml` with common-env ConfigMap, config PVC mount, health probes on /ping, sync wave 1
    - _Requirements: 8.1, 8.5, 18.1, 4.9_
  - [x] 10.2 Create `k8s/prowlarr/service.yaml` exposing port 9696
    - _Requirements: 8.1, 8.3_
  - [x] 10.3 Create `k8s/prowlarr/ingress.yaml` routing `prowlarr.media.home` to prowlarr-svc
    - _Requirements: 8.3_
  - [x] 10.4 Create `k8s/prowlarr/kustomization.yaml` referencing all manifests
    - _Requirements: 8.4, 4.2_

- [x] 11. Create FlareSolverr manifests
  - [x] 11.1 Create `k8s/flaresolverr/deployment.yaml` with inline env vars (LOG_LEVEL, LOG_HTML, CAPTCHA_SOLVER, TZ), health probes on /health, sync wave 1
    - _Requirements: 9.1, 9.2, 9.5, 18.3, 4.9_
  - [x] 11.2 Create `k8s/flaresolverr/service.yaml` exposing port 8191
    - _Requirements: 9.1, 9.3_
  - [x] 11.3 Create `k8s/flaresolverr/kustomization.yaml` referencing deployment and service (no ingress)
    - _Requirements: 9.3, 9.4, 4.2_

- [x] 12. Checkpoint — Verify wave 1 core services
  - Ensure `kustomize build` renders valid YAML for gluetun, qbittorrent, sonarr, radarr, prowlarr, and flaresolverr. Ask the user if questions arise.

- [x] 13. Create Jellyfin Kustomize + Helm inflation manifests
  - [x] 13.1 Create `k8s/jellyfin/kustomization.yaml` with helmCharts field for jellyfin chart from `https://jellyfin.github.io/jellyfin-helm`
    - _Requirements: 13.1, 13.9, 4.2, 4.3_
  - [x] 13.2 Create `k8s/jellyfin/values.yaml` with user 1000:1000, media/config/cache volume mounts via existing PVCs, JELLYFIN_PublishedServerUrl, ingress for jellyfin.media.home, health checks
    - _Requirements: 13.2, 13.3, 13.4, 13.5, 13.6, 13.7, 13.8, 18.2_

- [x] 14. Create Jellyseerr manifests
  - [x] 14.1 Create `k8s/jellyseerr/deployment.yaml` with config PVC mount, init container waiting for Jellyfin health, sync wave 1
    - _Requirements: 14.1, 14.2, 14.4, 14.6, 4.9_
  - [x] 14.2 Create `k8s/jellyseerr/service.yaml` exposing port 5055
    - _Requirements: 14.3_
  - [x] 14.3 Create `k8s/jellyseerr/ingress.yaml` routing `jellyseerr.media.home` to jellyseerr-svc
    - _Requirements: 14.3_
  - [x] 14.4 Create `k8s/jellyseerr/kustomization.yaml` referencing all manifests
    - _Requirements: 14.5, 4.2_

- [x] 15. Create Homarr manifests
  - [x] 15.1 Create `k8s/homarr/deployment.yaml` with encryption key secret ref, appdata PVC mount, health probes, sync wave 1
    - _Requirements: 15.1, 15.2, 15.3, 15.5, 15.7, 17.2, 4.9_
  - [x] 15.2 Create `k8s/homarr/service.yaml` exposing port 7575
    - _Requirements: 15.4_
  - [x] 15.3 Create `k8s/homarr/ingress.yaml` routing `media.home` (root domain) to homarr-svc
    - _Requirements: 15.4_
  - [x] 15.4 Create `k8s/homarr/kustomization.yaml` referencing all manifests
    - _Requirements: 15.6, 4.2_

- [x] 16. Create Configarr CronJob manifests
  - [x] 16.1 Create `k8s/configarr/cronjob.yaml` with schedule, Sonarr/Radarr API env vars from secret, config volume from ConfigMap, restartPolicy OnFailure, sync wave 1
    - _Requirements: 12.1, 12.4, 12.5, 12.7, 4.9_
  - [x] 16.2 Create `k8s/configarr/configmap.yaml` with placeholder TRaSH-Guides profile configuration referencing `https://configarr.de/docs/profiles/`
    - _Requirements: 12.2, 12.3_
  - [x] 16.3 Create `k8s/configarr/kustomization.yaml` referencing cronjob and configmap
    - _Requirements: 12.6, 4.2_

- [x] 17. Final checkpoint — Full manifest validation
  - Run `kustomize build` (and `kustomize build --enable-helm` for argocd, traefik, jellyfin) on every `k8s/` subdirectory to verify all manifests render correctly. Ensure all tests pass, ask the user if questions arise.

## Notes

- All manifest content is defined in the design document — use it as the source of truth for every YAML file
- PBT is not applicable (this is Infrastructure as Code with no custom application logic)
- Secrets must be created manually before deployment per the bootstrap process in the design
- Application-level proxy configuration (qBittorrent SOCKS5, Prowlarr HTTP proxy) is done via each service's UI after deployment, not in Kubernetes manifests
- Checkpoints verify Kustomize rendering; post-deployment smoke/integration tests are described in the design's Testing Strategy section
