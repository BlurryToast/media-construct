apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  creationTimestamp: "2026-04-06T08:26:14Z"
  finalizers:
  - resources-finalizer.argocd.argoproj.io
  generation: 78
  name: radarr
  namespace: argocd
  ownerReferences:
  - apiVersion: argoproj.io/v1alpha1
    blockOwnerDeletion: true
    controller: true
    kind: ApplicationSet
    name: cluster-apps
    uid: f3738b7f-ca79-4214-ba47-7ab821aec264
  resourceVersion: "9485"
  uid: 340eb8f5-a576-4776-a381-eb11be809bd1
operation:
  initiatedBy:
    automated: true
  retry:
    limit: 5
  sync:
    prune: true
    revision: 2444b147fcda72dbc040a631f2e7b095a5197480
    source:
      path: argocd/radarr
      repoURL: https://github.com/BlurryToast/media-construct.git
      targetRevision: HEAD
    syncOptions:
    - CreateNamespace=false
spec:
  destination:
    namespace: media
    server: https://kubernetes.default.svc
  project: default
  source:
    path: argocd/radarr
    repoURL: https://github.com/BlurryToast/media-construct.git
    targetRevision: HEAD
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=false
status:
  controllerNamespace: argocd
  health:
    lastTransitionTime: "2026-04-06T08:26:19Z"
    status: Missing
  operationState:
    message: waiting for healthy state of networking.k8s.io/Ingress/radarr-ingress
    operation:
      initiatedBy:
        automated: true
      retry:
        limit: 5
      sync:
        prune: true
        revision: 2444b147fcda72dbc040a631f2e7b095a5197480
        source:
          path: argocd/radarr
          repoURL: https://github.com/BlurryToast/media-construct.git
          targetRevision: HEAD
        syncOptions:
        - CreateNamespace=false
    phase: Running
    startedAt: "2026-04-06T08:26:19Z"
    syncResult:
      resources:
      - group: ""
        hookPhase: Succeeded
        kind: Service
        message: service/radarr-svc created
        name: radarr-svc
        namespace: media
        status: Synced
        syncPhase: Sync
        version: v1
      - group: networking.k8s.io
        hookPhase: Running
        kind: Ingress
        message: ingress.networking.k8s.io/radarr-ingress created
        name: radarr-ingress
        namespace: media
        status: Synced
        syncPhase: Sync
        version: v1
      revision: 2444b147fcda72dbc040a631f2e7b095a5197480
      source:
        path: argocd/radarr
        repoURL: https://github.com/BlurryToast/media-construct.git
        targetRevision: HEAD
  reconciledAt: "2026-04-06T11:56:09Z"
  resourceHealthSource: appTree
  resources:
  - kind: Service
    name: radarr-svc
    namespace: media
    status: Synced
    version: v1
  - group: apps
    kind: Deployment
    name: radarr
    namespace: media
    status: OutOfSync
    syncWave: 1
    version: v1
  - group: networking.k8s.io
    kind: Ingress
    name: radarr-ingress
    namespace: media
    status: Synced
    version: v1
  sourceHydrator: {}
  sourceType: Kustomize
  summary:
    externalURLs:
    - http://radarr.zion.home/
  sync:
    comparedTo:
      destination:
        namespace: media
        server: https://kubernetes.default.svc
      source:
        path: argocd/radarr
        repoURL: https://github.com/BlurryToast/media-construct.git
        targetRevision: HEAD
    revision: 6342d89e6bc526800cb4be2845437e756440eb96
    status: OutOfSync
