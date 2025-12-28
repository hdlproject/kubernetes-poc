.PHONY: install-postgres
install-postgres:
	@helm repo add bitnami https://charts.bitnami.com/bitnami
	@helm upgrade postgresql bitnami/postgresql --install -f ./k8s/postgresql-config.yaml

.PHONY: install-istio
install-istio:
	@helm repo add istio https://istio-release.storage.googleapis.com/charts
	@helm repo update

	@helm upgrade istio-base istio/base -n istio-system --install --set defaultRevision=default --create-namespace
	@helm upgrade istiod istio/istiod -n istio-system --install --wait

	@kubectl apply -f ./k8s/kiali.yaml
	@kubectl apply -f ./k8s/prometheus.yaml

.PHONY: install-argocd
install-argocd:
	# install argocd
ifeq (1,$(shell kubectl get namespace argocd >/dev/null 2>&1; echo $$?))
	@kubectl create namespace argocd
endif
	@kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
	@kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

	# provision istio as an ingress gateway
	@curl -kLs -o ./k8s/istio-argocd/install.yaml https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
	@kubectl apply -k ./k8s/istio-argocd -n argocd --wait=true
	@kubectl apply -f ./k8s/istio-argocd.yaml -n argocd

.PHONY: setup-argocd-client
setup-argocd-client:
	@brew install argocd

	# print admin password
	@echo "admin username: admin - password:" $(shell kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
	@yes | argocd login localhost:8888 --username admin --password $(shell kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

.PHONY: expose-argocd-server
expose-argocd-server:
	@kubectl port-forward svc/argocd-server 8888:80
