.PHONY: start-kube-cluster
start-kube-cluster:
	@if ! minikube -p poc status >/dev/null 2>&1; then \
	  minikube start -p poc --driver=docker; \
	fi
