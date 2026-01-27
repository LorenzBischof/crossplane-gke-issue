# Crossplane GKE Issue

When editing an XR (Composite Resource), the `observedGeneration` field of the status conditions Synced and Ready rapidly change back and forth between the current and previous generation values. This triggers excessive reconciliations and is sometimes only stopped by the circuit breaker.

This only seems to happen on GKE and I could not reproduce it locally in Kind.


```sh
# Create GKE cluster (must be authenticated)
gcloud container clusters create \
    --binauthz-evaluation-mode=PROJECT_SINGLETON_POLICY_ENFORCE \
    --zone europe-west6-a \
    test-cluster

# Install Crossplane
helm repo add crossplane-stable https://charts.crossplane.io/stable
helm repo update
helm install crossplane \
    --namespace crossplane-system \
    --create-namespace crossplane-stable/crossplane

kubectl apply -f function.yaml -f composition.yaml -f xrd.yaml

kubectl apply -f xr.yaml

# In another terminal
kubectl get xrs -w -oyaml | yq '.status.conditions'

kubectl patch xr example-xr --type=merge -p '{"spec":{"widgets":2}}'
```
