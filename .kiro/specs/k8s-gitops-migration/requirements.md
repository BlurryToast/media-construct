# Requirements Document

## Introduction

Migration of an existing Docker Compose-based media server stack to Kubernetes with a GitOps workflow powered by a lightweight Argo CD deployment. The stack includes a Traefik reverse proxy, Gluetun VPN proxy gateway, *arr media management suite (Sonarr, Radarr, Prowlarr, FlareSolverr), qBittorrent download client, Jellyfin media server, Jellyseerr request manager, and Homarr dashboard. The migration preserves all existing functionality and storage paths while introducing Kubernetes-native patterns and declarative GitOps-driven deployment.

Every service is deployed as its own independent Deployment with its own Service and (where applicable) Ingress. VPN routing is achieved via application-level proxy configuration: Gluetun runs as a standalone Deployment exposing SOCKS5 and HTTP proxy endpoints, and VPN-dependent services (qBittorrent, Prowlarr) are configured to route traffic through these proxies. This replaces the Docker Compose `network_mode: service:gluetun` pattern with a cleaner, Kubernetes-idiomatic approach that avoids the "mega-pod" anti-pattern.

A unified Kustomize approach is used: every directory under `k8s/` is a Kustomize application. For services with official Helm charts (Argo CD, Traefik, Jellyfin), Kustomize's built-in `helmCharts` field handles Helm chart inflation with local `values.yaml` files. All other services use standard Kustomize resource composition.

A single ApplicationSet with a Git directory generator auto-discovers all directories under `k8s/` and treats each uniformly as a Kustomize application, eliminating the need for individual Application custom resources or separate Helm/Kustomize handling.

Argo CD sync waves ensure proper deployment ordering: storage and common configuration (wave 0) are synced and healthy before workload applications (wave 1) begin deploying.

## Glossary

- **Cluster**: The target Kubernetes cluster where all workloads are deployed
- **Argo_CD**: The GitOps continuous delivery tool that synchronizes Kubernetes manifests from a Git repository to the Cluster, deployed via Kustomize with Helm chart inflation using the official Argo CD Helm chart
- **ApplicationSet**: An Argo CD custom resource that uses generators to automatically create and manage multiple Application resources from a single template definition
- **Git_Directory_Generator**: An ApplicationSet generator that discovers directories in a Git repository and creates an Argo CD Application for each discovered directory
- **Traefik_Ingress**: The Traefik-based Kubernetes Ingress controller deployed via Kustomize with Helm chart inflation using the official Traefik Helm chart, routing external HTTP traffic to services via Host rules under the `media.home` domain
- **Gluetun_Proxy**: The Gluetun VPN gateway deployed as a standalone Deployment, providing WireGuard connectivity to ProtonVPN and exposing SOCKS5 proxy (port 8388) and HTTP proxy (port 8888) endpoints for VPN-dependent services to route traffic through
- **SOCKS5_Proxy**: The SOCKS5 proxy endpoint exposed by Gluetun on port 8388, used by qBittorrent to route peer connections through the VPN tunnel
- **HTTP_Proxy**: The HTTP proxy endpoint exposed by Gluetun on port 8888, used by Prowlarr to route indexer requests through the VPN tunnel
- **Arr_Stack**: The collection of Sonarr, Radarr, Prowlarr, and FlareSolverr services responsible for media management and indexing, each deployed as independent Deployments
- **Configarr**: A configuration management tool that applies TRaSH-Guides quality profiles to Sonarr and Radarr via declarative YAML configuration, deployed via Kustomize
- **qBittorrent**: The BitTorrent download client, deployed as an independent Deployment configured to use the Gluetun SOCKS5_Proxy for peer connections
- **Jellyfin**: The media playback server deployed via Kustomize with Helm chart inflation using the official `jellyfin/jellyfin` Helm chart from `https://jellyfin.github.io/jellyfin-helm`
- **Jellyseerr**: The media request management service that integrates with Jellyfin, deployed via Kustomize
- **Homarr**: The dashboard service providing a unified view of all media stack services, deployed via Kustomize
- **Host_Path_Volume**: A Kubernetes volume backed by a path on the host node, used to preserve existing `/data/` bind mount storage layout
- **Kubernetes_Secret**: A Kubernetes-native secret resource storing sensitive values such as VPN keys and encryption keys
- **Kustomization**: A Kustomize configuration file that composes Kubernetes manifests, optionally using the `helmCharts` field for Helm chart inflation
- **Kustomize_Helm_Inflation**: A Kustomize feature that pulls and templates Helm charts locally using the `helmCharts` field in `kustomization.yaml`, allowing Helm charts to be managed uniformly as Kustomize applications
- **Argocd_Namespace**: The `argocd` Kubernetes namespace dedicated to Argo CD control plane components
- **Media_Namespace**: The `media` Kubernetes namespace dedicated to all media stack workloads (Traefik, Gluetun, qBittorrent, Sonarr, Radarr, Prowlarr, FlareSolverr, Jellyfin, Jellyseerr, Homarr, Configarr)
- **Sync_Wave**: An Argo CD annotation (`argocd.argoproj.io/sync-wave`) that controls the order in which resources are synced, ensuring dependencies (e.g., storage, ConfigMaps) are created before workloads that depend on them

## Requirements

### Requirement 1: Argo CD Lightweight Deployment (Kustomize with Helm Chart Inflation)

**User Story:** As an operator, I want a minimal Argo CD installation deployed via Kustomize with Helm chart inflation using the official Argo CD Helm chart, with Redis disabled but the ApplicationSet controller enabled, so that the GitOps control plane consumes minimal cluster resources while supporting automatic application discovery.

#### Acceptance Criteria

1. THE Argo_CD installation SHALL be deployed via Kustomize with Helm chart inflation using the official Argo CD Helm chart
2. THE Argo_CD Kustomization SHALL configure the Helm chart to disable the Redis component
3. THE Argo_CD Kustomization SHALL configure the Helm chart to enable the ApplicationSet controller component
4. THE Argo_CD installation SHALL include the API server, repo server, application controller, and ApplicationSet controller components
5. WHEN the Argo_CD installation is applied to the Cluster, THE Cluster SHALL contain a functioning Argo CD instance capable of syncing Application resources from a Git repository
6. THE Argo_CD Kustomization and values file SHALL be stored in the Git repository under a dedicated directory so that Argo CD can manage its own configuration
7. THE Argo_CD installation SHALL be deployed into the Argocd_Namespace
8. THE Argo_CD repo server SHALL be configured with the `--enable-helm` flag so that Kustomize_Helm_Inflation works for all applications

### Requirement 2: ApplicationSet with Git Directory Generator

**User Story:** As an operator, I want a single ApplicationSet resource using the Git directory generator pattern, so that Argo CD automatically discovers and deploys all applications based on the repository directory structure, treating every directory uniformly as a Kustomize application.

#### Acceptance Criteria

1. THE Cluster SHALL contain a single ApplicationSet resource that uses the Git_Directory_Generator to discover all application directories under `k8s/` in the Git repository
2. THE ApplicationSet SHALL use a single Git directory generator with no exclusions, since every directory under `k8s/` is a Kustomize application
3. THE ApplicationSet SHALL generate one Argo CD Application for each discovered directory, configured to use Kustomize as the source type
4. WHEN a new application directory is added to the repository and pushed, THE ApplicationSet SHALL automatically create a corresponding Argo CD Application and sync the new application to the Cluster
5. WHEN an application directory is removed from the repository and pushed, THE ApplicationSet SHALL remove the corresponding Argo CD Application from the Cluster
6. THE ApplicationSet template SHALL configure each generated Application with an automated sync policy so that changes pushed to the repository are applied to the Cluster without manual intervention
7. THE ApplicationSet resource SHALL be stored in the Git repository as a bootstrap manifest applied during initial cluster setup
8. THE generated Application resources SHALL deploy workloads into the appropriate namespace (Argocd_Namespace for Argo CD, Media_Namespace for all other workloads)

### Requirement 3: Namespace Strategy

**User Story:** As an operator, I want all workloads organized into two namespaces (argocd and media), so that the Argo CD control plane is isolated from media workloads while avoiding unnecessary cross-namespace complexity on a single-node cluster.

#### Acceptance Criteria

1. THE Cluster SHALL contain an Argocd_Namespace named `argocd` dedicated to Argo CD control plane components
2. THE Cluster SHALL contain a Media_Namespace named `media` dedicated to all media stack workloads
3. THE Traefik_Ingress, Gluetun_Proxy, qBittorrent, Sonarr, Radarr, Prowlarr, FlareSolverr, Jellyfin, Jellyseerr, Homarr, and Configarr deployments SHALL all be deployed into the Media_Namespace
4. THE Argo_CD installation SHALL be deployed into the Argocd_Namespace
5. WHEN a new media workload is added to the stack, THE workload SHALL be deployed into the Media_Namespace

### Requirement 4: GitOps Repository Structure (Unified Kustomize) with Sync Wave Ordering

**User Story:** As an operator, I want all Kubernetes manifests organized in a Git repository with a clear directory structure where every directory is a Kustomize application with sync wave annotations, so that the ApplicationSet Git directory generator can auto-discover and deploy every component of the media stack uniformly, with storage and common configuration synced before workloads.

#### Acceptance Criteria

1. THE Git repository SHALL contain a top-level directory structure that separates Argo CD bootstrap manifests and per-application directories discoverable by the Git_Directory_Generator
2. EVERY directory under the application root SHALL contain a `kustomization.yaml` file, making it a valid Kustomize application
3. THE directories for Helm-based applications (Argo_CD, Traefik_Ingress, Jellyfin) SHALL use the Kustomize `helmCharts` field for Helm chart inflation, with a local `values.yaml` referenced by the `valuesFile` field
4. THE directories for non-Helm applications (Gluetun_Proxy, qBittorrent, Sonarr, Radarr, Prowlarr, FlareSolverr, Homarr, Jellyseerr, Configarr, persistent storage, secrets, ConfigMaps) SHALL use standard Kustomize resource composition
5. WHEN a new application is added to the stack, THE operator SHALL add a new directory with a `kustomization.yaml` to the repository, and the ApplicationSet SHALL automatically discover and deploy the new application
6. WHEN Argo_CD syncs the repository, THE Cluster state SHALL match the declared manifests in the Git repository
7. THE repository SHALL not contain individual Application custom resources per service; the ApplicationSet SHALL generate Application resources from the directory structure
8. THE `k8s/storage/` and `k8s/common/` directories SHALL be annotated with Sync_Wave 0 so that PersistentVolumes, PersistentVolumeClaims, ConfigMaps, and secret placeholders are created and healthy before any workload starts
9. ALL workload application directories (gluetun, qbittorrent, sonarr, radarr, prowlarr, flaresolverr, jellyfin, jellyseerr, homarr, traefik, configarr) SHALL be annotated with Sync_Wave 1 so that they deploy only after wave 0 resources are available

### Requirement 5: Traefik Ingress Controller (Kustomize with Helm Chart Inflation)

**User Story:** As an operator, I want Traefik deployed as the Kubernetes Ingress controller via Kustomize with Helm chart inflation using the official Traefik Helm chart into the media namespace, so that all services are accessible via `*.media.home` Host-based routing consistent with the existing setup.

#### Acceptance Criteria

1. THE Traefik_Ingress SHALL be deployed via Kustomize with Helm chart inflation using the official Traefik Helm chart into the Media_Namespace
2. THE Traefik_Ingress Kustomization SHALL configure the Helm chart to listen on port 80
3. THE Traefik_Ingress SHALL route traffic based on Host rules using the `media.home` domain and its subdomains
4. THE Traefik_Ingress Kustomization SHALL configure the Helm chart to disable the Docker provider and enable the Kubernetes Ingress provider
5. WHEN a new Ingress resource is created with a `*.media.home` Host rule, THE Traefik_Ingress SHALL route traffic to the corresponding backend service
6. THE Traefik_Ingress deployment SHALL include a health check mechanism to verify the controller is operational

### Requirement 6: Gluetun VPN Proxy Gateway

**User Story:** As an operator, I want Gluetun deployed as a standalone Deployment in the media namespace exposing SOCKS5 and HTTP proxy endpoints, so that VPN-dependent services can route traffic through the ProtonVPN WireGuard tunnel via application-level proxy configuration rather than shared network namespaces.

#### Acceptance Criteria

1. THE Gluetun_Proxy SHALL be deployed as a standalone Deployment with its own ClusterIP Service (`gluetun-svc`), NOT as a sidecar container within another pod
2. THE Gluetun_Proxy SHALL establish a WireGuard tunnel to ProtonVPN with port forwarding enabled
3. THE Gluetun_Proxy container SHALL run with the `NET_ADMIN` capability and access to a `/dev/net/tun` device
4. THE Gluetun_Proxy SHALL read the WireGuard private key from a Kubernetes_Secret mounted into the pod
5. THE Gluetun_Proxy SHALL configure firewall outbound subnets to allow traffic to `192.168.1.0/24`
6. THE Gluetun_Proxy Service SHALL expose the SOCKS5_Proxy on port 8388 for use by VPN-dependent services
7. THE Gluetun_Proxy Service SHALL expose the HTTP_Proxy on port 8888 for use by VPN-dependent services
8. THE Gluetun_Proxy Service SHALL expose a health endpoint on port 9999 so that Kubernetes readiness probes and dependent services can verify VPN connectivity
9. THE Gluetun_Proxy manifests SHALL be stored in `k8s/gluetun/` with its own kustomization.yaml, deployment.yaml, and service.yaml
10. THE Gluetun_Proxy SHALL NOT require an Ingress resource (it is an internal-only service)
11. THE Gluetun_Proxy SHALL be deployed into the Media_Namespace

### Requirement 7: qBittorrent Download Client (Standalone Deployment with SOCKS5 Proxy)

**User Story:** As an operator, I want qBittorrent deployed as an independent Deployment configured to route peer connections through the Gluetun SOCKS5 proxy, so that download traffic is VPN-protected without requiring a shared network namespace.

#### Acceptance Criteria

1. THE qBittorrent deployment SHALL be an independent Deployment with its own Service and Ingress, NOT a container within a shared pod
2. THE qBittorrent deployment SHALL be configured at the application level to use the SOCKS5_Proxy at `gluetun-svc.media.svc.cluster.local:8388` for peer connections
3. THE qBittorrent container SHALL expose its WebUI on port 8088, accessible via `bittorrent.media.home` through the Traefik_Ingress
4. THE qBittorrent manifests SHALL be stored in `k8s/qbittorrent/` with its own kustomization.yaml, deployment.yaml, service.yaml, and ingress.yaml
5. THE qBittorrent deployment SHALL be deployed into the Media_Namespace

### Requirement 8: Prowlarr Indexer Manager (Standalone Deployment with HTTP Proxy)

**User Story:** As an operator, I want Prowlarr deployed as an independent Deployment configured to route indexer requests through the Gluetun HTTP proxy, so that indexer traffic is VPN-protected without requiring a shared network namespace.

#### Acceptance Criteria

1. THE Prowlarr deployment SHALL be an independent Deployment with its own Service and Ingress, NOT a container within a shared pod
2. THE Prowlarr deployment SHALL be configured at the application level to use the HTTP_Proxy at `gluetun-svc.media.svc.cluster.local:8888` for indexer requests
3. THE Prowlarr container SHALL be accessible via `prowlarr.media.home` on port 9696 through the Traefik_Ingress
4. THE Prowlarr manifests SHALL be stored in `k8s/prowlarr/` with its own kustomization.yaml, deployment.yaml, service.yaml, and ingress.yaml
5. THE Prowlarr deployment SHALL be deployed into the Media_Namespace

### Requirement 9: FlareSolverr (Standalone Deployment)

**User Story:** As an operator, I want FlareSolverr deployed as an independent internal Deployment, so that Prowlarr can use it to solve browser challenges without requiring a shared network namespace or VPN proxy.

#### Acceptance Criteria

1. THE FlareSolverr deployment SHALL be an independent Deployment with its own ClusterIP Service, NOT a container within a shared pod
2. THE FlareSolverr deployment SHALL NOT require VPN proxy configuration (Prowlarr connects to it directly via the cluster network)
3. THE FlareSolverr deployment SHALL NOT require an Ingress resource (it is an internal-only service accessed by Prowlarr)
4. THE FlareSolverr manifests SHALL be stored in `k8s/flaresolverr/` with its own kustomization.yaml, deployment.yaml, and service.yaml
5. THE FlareSolverr deployment SHALL be deployed into the Media_Namespace

### Requirement 10: Sonarr TV Series Manager (Standalone Deployment)

**User Story:** As an operator, I want Sonarr deployed as an independent Deployment that communicates with qBittorrent and Prowlarr via the Kubernetes service network, so that TV series management works without requiring VPN proxy configuration.

#### Acceptance Criteria

1. THE Sonarr deployment SHALL be an independent Deployment with its own Service and Ingress
2. THE Sonarr deployment SHALL NOT require VPN proxy configuration; it communicates with qBittorrent via `qbittorrent-svc.media.svc.cluster.local:8088` and Prowlarr via `prowlarr-svc.media.svc.cluster.local:9696`
3. THE Sonarr container SHALL be accessible via `sonarr.media.home` on port 8989 through the Traefik_Ingress
4. THE Sonarr manifests SHALL be stored in `k8s/sonarr/` with its own kustomization.yaml, deployment.yaml, service.yaml, and ingress.yaml
5. THE Sonarr deployment SHALL be deployed into the Media_Namespace

### Requirement 11: Radarr Movie Manager (Standalone Deployment)

**User Story:** As an operator, I want Radarr deployed as an independent Deployment that communicates with qBittorrent and Prowlarr via the Kubernetes service network, so that movie management works without requiring VPN proxy configuration.

#### Acceptance Criteria

1. THE Radarr deployment SHALL be an independent Deployment with its own Service and Ingress
2. THE Radarr deployment SHALL NOT require VPN proxy configuration; it communicates with qBittorrent via `qbittorrent-svc.media.svc.cluster.local:8088` and Prowlarr via `prowlarr-svc.media.svc.cluster.local:9696`
3. THE Radarr container SHALL be accessible via `radarr.media.home` on port 7878 through the Traefik_Ingress
4. THE Radarr manifests SHALL be stored in `k8s/radarr/` with its own kustomization.yaml, deployment.yaml, service.yaml, and ingress.yaml
5. THE Radarr deployment SHALL be deployed into the Media_Namespace

### Requirement 12: Configarr Quality Profile Management (Kustomize)

**User Story:** As an operator, I want Configarr deployed via Kustomize to manage quality profiles for Sonarr and Radarr using TRaSH-Guides, so that media quality settings are declaratively managed and version-controlled.

#### Acceptance Criteria

1. THE Configarr deployment SHALL run as a Kubernetes CronJob or Job that applies quality profiles to Sonarr and Radarr
2. THE Configarr configuration SHALL be stored in a ConfigMap containing the declarative YAML profile definitions
3. THE Configarr configuration SHALL reference TRaSH-Guides profiles using the include mechanism documented at `https://configarr.de/docs/profiles/`
4. WHEN Configarr executes, THE Configarr job SHALL connect to the Sonarr API endpoint at `sonarr-svc.media.svc.cluster.local:8989` and the Radarr API endpoint at `radarr-svc.media.svc.cluster.local:7878` and apply the configured quality profiles
5. IF Configarr fails to connect to a Sonarr or Radarr instance, THEN THE Configarr job SHALL exit with a non-zero status code and report the error
6. THE Configarr manifests SHALL be managed via Kustomize bases and overlays
7. THE Configarr deployment SHALL be deployed into the Media_Namespace

### Requirement 13: Jellyfin Media Server (Kustomize with Helm Chart Inflation)

**User Story:** As an operator, I want Jellyfin deployed via Kustomize with Helm chart inflation using the official Helm chart from `https://jellyfin.github.io/jellyfin-helm`, so that the media server follows the recommended Kubernetes deployment pattern while being managed uniformly as a Kustomize application.

#### Acceptance Criteria

1. THE Jellyfin deployment SHALL use Kustomize with Helm chart inflation to deploy the `jellyfin` Helm chart from the `https://jellyfin.github.io/jellyfin-helm` repository
2. THE Jellyfin values file SHALL configure the deployment to run as user 1000:1000 to match the existing file ownership on persistent storage
3. THE Jellyfin values file SHALL mount the shared media volume at `/media` using a Host_Path_Volume backed by `/data/media`
4. THE Jellyfin values file SHALL mount a persistent config volume backed by `/data/appdata/jellyfin`
5. THE Jellyfin values file SHALL mount a persistent cache volume backed by `/data/appdata/jellyfin_cache`
6. THE Jellyfin values file SHALL set the `JELLYFIN_PublishedServerUrl` environment variable to `https://jellyfin.media.home`
7. THE Jellyfin deployment SHALL be accessible via `jellyfin.media.home` through the Traefik_Ingress with the Traefik IngressClass
8. THE Jellyfin deployment SHALL include a health check at the `/health` endpoint
9. THE Jellyfin deployment SHALL be deployed into the Media_Namespace

### Requirement 14: Jellyseerr Media Request Service (Kustomize)

**User Story:** As an operator, I want Jellyseerr deployed via Kustomize alongside Jellyfin, so that users can request media through a web interface.

#### Acceptance Criteria

1. THE Jellyseerr deployment SHALL use the `fallenbagel/jellyseerr:latest` container image
2. THE Jellyseerr deployment SHALL mount a persistent config volume backed by `/data/appdata/jellyseerr`
3. THE Jellyseerr deployment SHALL be accessible via `jellyseerr.media.home` on port 5055 through the Traefik_Ingress
4. WHEN the Jellyfin deployment is not healthy, THE Jellyseerr deployment SHALL not become ready
5. THE Jellyseerr manifests SHALL be managed via Kustomize bases and overlays
6. THE Jellyseerr deployment SHALL be deployed into the Media_Namespace

### Requirement 15: Homarr Dashboard (Kustomize)

**User Story:** As an operator, I want Homarr deployed via Kustomize as a dashboard, so that all media stack services are accessible from a single unified interface.

#### Acceptance Criteria

1. THE Homarr deployment SHALL use the `ghcr.io/homarr-labs/homarr:latest` container image
2. THE Homarr deployment SHALL read the encryption key from a Kubernetes_Secret and inject it as the `SECRET_ENCRYPTION_KEY` environment variable
3. THE Homarr deployment SHALL mount a persistent appdata volume backed by `/data/appdata/homarr`
4. THE Homarr deployment SHALL be accessible via `media.home` (root domain) on port 7575 through the Traefik_Ingress
5. THE Homarr deployment SHALL include a health check that verifies the web interface is responding on port 7575
6. THE Homarr manifests SHALL be managed via Kustomize bases and overlays
7. THE Homarr deployment SHALL be deployed into the Media_Namespace

### Requirement 16: Persistent Storage (Kustomize)

**User Story:** As an operator, I want all Kubernetes workloads to use the existing `/data/` directory structure on the host, so that no data migration is required and existing media libraries are preserved.

#### Acceptance Criteria

1. THE Cluster SHALL define PersistentVolume and PersistentVolumeClaim resources for each storage path: `/data/media`, `/data/torrents`, and each per-service config directory under `/data/appdata/`
2. THE shared media volume (`/data/media`) SHALL be mountable by Jellyfin, Sonarr, Radarr, and Prowlarr simultaneously
3. THE shared torrents volume (`/data/torrents`) SHALL be mountable by qBittorrent, Sonarr, and Radarr simultaneously
4. EACH per-service config volume SHALL be backed by its corresponding `/data/appdata/{service}` host path
5. WHEN a pod is restarted or rescheduled, THE pod SHALL retain access to the same persistent data through the PersistentVolumeClaim
6. THE persistent storage manifests SHALL be managed via Kustomize bases and overlays

### Requirement 17: Secrets Management (Kustomize)

**User Story:** As an operator, I want sensitive values stored as Kubernetes Secrets managed via Kustomize, so that VPN keys and encryption keys are not committed to the Git repository in plaintext.

#### Acceptance Criteria

1. THE WireGuard private key SHALL be stored in a Kubernetes_Secret and mounted into the Gluetun_Proxy pod
2. THE Homarr encryption key SHALL be stored in a Kubernetes_Secret and injected into the Homarr pod
3. THE Git repository SHALL not contain plaintext secret values
4. THE repository SHALL include placeholder or template files indicating which secrets must be created manually before deployment
5. THE secrets manifests SHALL be managed via Kustomize bases and overlays

### Requirement 18: Common Environment Configuration (Kustomize)

**User Story:** As an operator, I want common environment variables (PUID, PGID, TZ) applied consistently across all applicable workloads via Kustomize-managed ConfigMaps, so that file permissions and timezone settings are uniform.

#### Acceptance Criteria

1. THE qBittorrent, Sonarr, Radarr, and Prowlarr deployments SHALL receive environment variables PUID=1000, PGID=1000, and TZ=Etc/UTC from a shared ConfigMap
2. THE Jellyfin deployment SHALL receive the environment variable TZ=Etc/UTC
3. THE FlareSolverr deployment SHALL receive environment variables LOG_LEVEL=info, LOG_HTML=false, CAPTCHA_SOLVER=none, and TZ=UTC
4. WHEN environment variables are shared across multiple deployments, THE configuration SHALL use a shared ConfigMap managed via Kustomize to avoid duplication
