ROOT := $(shell git rev-parse --show-toplevel 2>/dev/null)

include $(ROOT)/kubernetes.mk
include $(ROOT)/dependency.mk
include $(ROOT)/service.mk
include $(ROOT)/cd.mk

.PHONY: build-all-service
build-all-service:
	@#make -C ./service/gateway build-service-kube istiosidecar="true" environment="uat prod" local="true"
	@make -C ./service/transaction build-service-kube istiosidecar="true" environment="uat" local="true"
	@make -C ./service/user build-service-kube istiosidecar="true" environment="uat" local="true"
	@make -C ./service/external build-service-kube istiosidecar="false" environment="uat" local="true"

#	@make -C ./service/gateway build-service-argocd local="true"
#	@make -C ./service/transaction build-service-argocd local="true"
#	@make -C ./service/user build-service-argocd local="true"
#	@make -C ./service/external build-service-argocd local="true"

.PHONY: remove-all-service
remove-all-service:
	@make -C ./service/gateway remove-service-kube istiosidecar="true" environment="uat prod"
	@make -C ./service/transaction remove-service-kube istiosidecar="true" environment="uat"
	@make -C ./service/user remove-service-kube istiosidecar="true" environment="uat"
	@make -C ./service/external remove-service-kube istiosidecar="true" environment="uat"

.PHONY: expose-service
expose-service:
	@kubectl port-forward svc/gateway 8001:8000

.PHONY: setup-kubernetes
setup-kubernetes: start-kube-cluster install-istio-istioctl install-kiali install-prometheus install-postgres install-argocd setup-https
