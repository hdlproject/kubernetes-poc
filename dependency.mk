.PHONY: install-postgres
install-postgres:
	@helm repo add bitnami https://charts.bitnami.com/bitnami
	@helm upgrade postgresql bitnami/postgresql --install -f ./k8s/postgresql-config.yaml

.PHONY: install-istio-helm
install-istio-helm:
	@helm repo add istio https://istio-release.storage.googleapis.com/charts
	@helm repo update

	@helm upgrade istio-base istio/base -n istio-system --install --set defaultRevision=default --create-namespace
	@helm upgrade istiod istio/istiod -n istio-system --install --wait
	@helm upgrade istio-ingressgateway istio/gateway -n istio-system --install

	@kubectl label namespace default istio-injection=enabled --overwrite

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

.PHONY: setup-https
setup-https:
	@bash script/setup-https.sh

.PHONY: expose-kiali
expose-kiali:
	@kubectl -n istio-system port-forward svc/kiali 20001:20001

.PHONY: expose-ingress-gateway
expose-ingress-gateway:
	@kubectl -n istio-system port-forward svc/istio-ingressgateway 8080:80 8443:443
