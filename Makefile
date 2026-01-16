ROOT := $(shell git rev-parse --show-toplevel 2>/dev/null)

include $(ROOT)/kubernetes.mk
include $(ROOT)/dependency.mk
include $(ROOT)/service.mk

.PHONY: build-all-service
build-all-service:
	@make -C ./service/gateway build-service-kube istiosidecar="true"
	@make -C ./service/transaction build-service-kube istiosidecar="true"
	@make -C ./service/user build-service-kube istiosidecar="true"
	@make -C ./service/external build-service-kube istiosidecar="false"

	@make -C ./service/gateway build-service-argocd
	@make -C ./service/transaction build-service-argocd
	@make -C ./service/user build-service-argocd
	@make -C ./service/external build-service-argocd

.PHONY: remove-all-service
remove-all-service:
	@make -C ./service/gateway remove-service-kube
	@make -C ./service/transaction remove-service-kube
	@make -C ./service/user remove-service-kube
	@make -C ./service/external remove-service-kube

.PHONY: expose-service
expose-service:
	@kubectl port-forward svc/gateway 8001:8000

.PHONY: setup-kubernetes
setup-kubernetes: start-kube-cluster install-istio-istioctl install-kiali install-prometheus install-postgres install-argocd
