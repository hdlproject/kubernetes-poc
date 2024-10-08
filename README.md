# Proof of Concept Kubernetes Deployment

This repository is supposed to contains any code that is necessary to do proof of concept of deployment on Kubernetes
platform.
Here are some components involved in this project:

- Minikube: tool to deploy a Kubernetes cluster in the local environment.
- Istio: kubernetes resource to handle traffic management.
- Kiali: console to visualize, configure, and troubleshoot Istio.
- ArgoCD: a GitHub-integrated continuous delivery tool.
  This tool will deploy all kubenetes manifests in the target path to the provided destination.

## How to Operate

All the functionalities this repository has are delivered by the `Makefile`.
Here are the list:

- `build-docker`: build the Docker image of a service.
  The `Dockerfile` of a service is built using [this template](service/Dockerfile).
  The result is placed on `build` dir under each service dir.
- `build-kubernetes`: construct Kubernetes manifests needed for the deployment of a service and deploy all of them on
  Kubernetes.
  The `deployment.yaml` and `service.yaml` of a service are built using [this template](k8s/deployment.yaml)
  and [this template](k8s/service.yaml) respectively.
  Environment variable as a config of the service is written in `.env` file and is supplied to the service through the
  container env in `deployment.yaml`.
  The container env section is generated by the [`convert-dotenv-to-kube-env.sh`](script/convert-dotenv-to-kube-env.sh)
  script using supplied `.env` file.
  If the `istiosidecar` flag is set, an Istio virtual service will be generated using [this template](k8s/istio.yaml)
  for that service.
- `install-postgres`: deploy PostgreSQL on Kubernetes using the Helm chart.
- `install-istio`: deploy Istio on Kubernetes using the helm chart.
  This includes the installation of the Istio-related tools such as Kiali and Prometheus.
- `setup-kubernetes`: setup all tools needed to run a Kubernetes cluster (e.g. Minikube).
- `install-argocd`: deploy ArgoCD to Kubernetes cluster and install the needed client to interact with it.
- `setup-argocd-client`: setup necessary config and authentication to communicate with the deployed ArgoCD.
- `build-argocd`: create an ArgoCD app for a service and do sync with the latest code from GitHub.
- `build-all-service`: do `build-kubernetes` and `build-argocd` on all services.
