.PHONY: install-istio-istioctl
install-istio-istioctl:
	@bash script/istioctl-install.sh

	@kubectl label namespace default istio-injection=enabled --overwrite

.PHONY: install-kiali
install-kiali:
	@kubectl apply -f ./k8s/kiali.yaml

.PHONY: install-prometheus
install-prometheus:
	@kubectl apply -f ./k8s/prometheus.yaml
