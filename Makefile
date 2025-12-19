include kubernetes.mk
include dependency.mk
include service.mk

.PHONY: build-all-service
build-all-service: setup-argocd-client
	@make -C ./service/gateway build-kubernetes istiosidecar="true"
	@make -C ./service/transaction build-kubernetes istiosidecar="true"
	@make -C ./service/user build-kubernetes istiosidecar="true"
	@make -C ./service/external build-kubernetes istiosidecar="false"

	@make -C ./service/gateway build-argocd
	@make -C ./service/transaction build-argocd
	@make -C ./service/user build-argocd
	@make -C ./service/external build-argocd

.PHONY: setup-kubernetes
setup-kubernetes: start-kube-cluster install-istio install-postgres
