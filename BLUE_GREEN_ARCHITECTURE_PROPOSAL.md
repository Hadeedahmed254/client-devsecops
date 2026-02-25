The CD repository already contains rollout.yaml defining the Argo Rollout resource

The CD repository already contains active-service.yaml which represents the production service

The CD repository already contains preview-service.yaml which is used for validating new versions

The CD repository already contains ingress.yaml which exposes the active service externally through the load balancer

When a developer pushes code to Git

A CI pipeline runs using GitHub Actions or Jenkins

The application is built into a Docker image

The image is tagged with a unique version such as a semantic version or commit SHA

The image is pushed to Amazon ECR

The CD repository rollout.yaml file is updated with the new image tag

The updated rollout.yaml file is committed to Git which acts as the single source of truth

Argo CD continuously watches the Git repository for changes

Argo CD detects the updated image tag and syncs the desired state to Kubernetes

Argo CD applies the updated Rollout resource to the cluster

The Argo Rollouts controller detects that the Pod template inside the Rollout has changed

Kubernetes creates a new ReplicaSet and generates a new rollouts-pod-template-hash based on the updated Pod template

New pods are created from the new ReplicaSet and automatically receive the new rollouts-pod-template-hash label

The existing ReplicaSet continues running with its previous rollouts-pod-template-hash

The active-service.yaml initially selects pods using the old rollouts-pod-template-hash and continues serving production traffic

The preview-service.yaml is automatically updated by Argo Rollouts to select pods using the new rollouts-pod-template-hash

The preview service now routes traffic only to the newly created pods for validation

The new pods must pass liveness probes to ensure the containers are running correctly

The new pods must pass readiness probes before being added to the preview service endpoints

If autoPromotionEnabled is true Argo Rollouts waits until all new pods are healthy before promoting

If autoPromotionEnabled is false manual promotion is required using the promote command

If validation fails the Rollout can be aborted and the preview service is redirected back to the stable ReplicaSet

If validation succeeds Argo Rollouts updates the active service selector from the old rollouts-pod-template-hash to the new rollouts-pod-template-hash

Traffic instantly shifts from the old ReplicaSet to the new ReplicaSet without downtime

The ingress.yaml routes external traffic to the active service

The cloud load balancer forwards traffic to the Kubernetes active service

The active service forwards traffic to pods based on the rollouts-pod-template-hash selector controlled dynamically by Argo Rollouts

After successful promotion the old ReplicaSet is scaled down but retained for rollback history

If rollback is needed the Rollout can be undone or the Git commit can be reverted

Argo CD detects the revert and syncs the cluster back to the previous desired state

Argo Rollouts then switches the active service selector back to the previous rollouts-pod-template-hash and restores traffic to the stable ReplicaSet
