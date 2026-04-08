# Crossplane Condition Cleanup Repro

This branch reproduces both condition write paths discussed in
https://github.com/crossplane/crossplane/issues/7062#issuecomment-4067764618:
when a composition function only sometimes sets a custom composite condition,
the condition written via `ClaimConditions` may remain forever instead of being
removed when the function stops emitting it. The composition now emits two
custom conditions on the same toggle:

- `DirectReady` by writing directly to `XR.status.conditions`
- `ClaimConditionReady` via `ClaimConditions`

```sh
# Create GKE cluster (must be authenticated)
gcloud container clusters create \
    --binauthz-evaluation-mode=PROJECT_SINGLETON_POLICY_ENFORCE \
    --zone europe-west6-a \
    test-cluster

# Install Crossplane
helm repo add crossplane-stable https://charts.crossplane.io/stable
helm repo update

# Upstream image
helm install crossplane \
    --namespace crossplane-system \
    --create-namespace \
    --wait \
    crossplane-stable/crossplane

# Alternatively, install Crossplane with our patched image
helm install crossplane \
    --namespace crossplane-system \
    --create-namespace crossplane-stable/crossplane \
    --set image.repository=ghcr.io/lorenzbischof/crossplane-gke-issue \
    --set image.tag=v2.2.0 \
    --set image.pullPolicy=Always

kubectl apply -f function.yaml -f composition.yaml -f xrd.yaml

kubectl apply -f xr.yaml

# In another terminal
kubectl get xrs -w -oyaml | yq '.status.conditions'

# The composition only emits both custom conditions when widgets > 1.
kubectl patch xr example-xr --type=merge -p '{"spec":{"widgets":2}}'
kubectl patch xr example-xr --type=merge -p '{"spec":{"widgets":1}}'
```

Expected behavior:
- `DirectReady` appears when `widgets=2`
- `ClaimConditionReady` appears when `widgets=2`
- both disappear again when `widgets=1`

Buggy behavior:
- `DirectReady` appears when `widgets=2`
- `ClaimConditionReady` appears when `widgets=2`
- `DirectReady` disappears again when `widgets=1`
- `ClaimConditionReady` remains even after patching back to `widgets=1`
