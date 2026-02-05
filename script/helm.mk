.PHONY: install-postgres-helm
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

	@kubectl apply -f ./k8s/istio-operator.yaml

.PHONY: install-prometheus-helm
install-prometheus-helm:
	@helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
	@helm repo update

	@helm install kps prometheus-community/kube-prometheus-stack -n monitoring --create-namespace

.PHONY: install-jaeger-helm
install-jaeger-helm:
	@helm repo add jaegertracing https://jaegertracing.github.io/helm-charts
	@helm repo update

	@helm install jaeger jaegertracing/jaeger -n tracing --create-namespace
