.PHONY: start-kube-cluster
start-kube-cluster:
	@if ! minikube -p poc status >/dev/null 2>&1; then \
	  minikube start -p poc --driver=docker; \
	fi

	## Install metrics server for HPA
	@minikube -p poc addons enable metrics-server

	## Wait for metrics-server to be ready
	@echo "Waiting for metrics-server to collect metrics..."
	@kubectl wait --for=condition=ready pod -l k8s-app=metrics-server -n kube-system --timeout=120s || true
	@sleep 30
	@echo "Metrics-server is ready"
