ROOT := $(shell git rev-parse --show-toplevel 2>/dev/null)

include $(ROOT)/script/kubernetes.mk
include $(ROOT)/script/dependency.mk
include $(ROOT)/script/helm.mk
include $(ROOT)/script/service.mk
include $(ROOT)/script/cd.mk
include $(ROOT)/script/local.mk

.PHONY: build-all-service
build-all-service:
	@make -C ./service/gateway build-service-kube istiosidecar="true" environment="uat prod" local="true"
	@make -C ./service/transaction build-service-kube istiosidecar="true" environment="uat" local="true"
	@make -C ./service/user build-service-kube istiosidecar="true" environment="uat" local="true"
	@make -C ./service/external build-service-kube istiosidecar="false" environment="uat" local="true"

	@kubectl apply -f ./service/cluster

#	@make -C ./service/gateway build-service-argocd local="true"
#	@make -C ./service/transaction build-service-argocd local="true"
#	@make -C ./service/user build-service-argocd local="true"
#	@make -C ./service/external build-service-argocd local="true"

.PHONY: remove-all-service
remove-all-service:
	@make -C ./service/gateway remove-service-kube istiosidecar="true" environment="uat prod"
	@make -C ./service/transaction remove-service-kube istiosidecar="true" environment="uat"
	@make -C ./service/user remove-service-kube istiosidecar="true" environment="uat"
	@make -C ./service/external remove-service-kube istiosidecar="false" environment="uat"

.PHONY: setup-kubernetes
setup-kubernetes: start-kube-cluster install-istio-istioctl install-kiali install-prometheus-helm install-postgres setup-https # install-argocd
