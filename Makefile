.PHONY: build-docker
build-docker:
	@if [ ! -d ./build ]; then mkdir ./build; fi

	@cp -r ./.env ./build/.env

	@cp -r ../main.go ./build/main.go

	@cp -r ../go.mod ./build/go.mod
	@cp -r ../go.sum ./build/go.sum
	@cd ./build && go mod tidy

	@cp -r ../Dockerfile ./build/Dockerfile
	@sed -i'' -e 's#appname#$(APP_NAME)#g' ./build/Dockerfile
	@docker buildx build -f ./build/Dockerfile -t $(APP_IMAGE_NAME) --output=type=docker ./build

.PHONY: build-kubernetes
build-kubernetes: build-docker
	@cp -r ../../k8s/deployment.yaml ./build/deployment.yaml
	@sed -i'' -e 's#appname#$(APP_NAME)#g' ./build/deployment.yaml
	@chmod +x ../../script/convert-dotenv-to-kube-env.sh && ../../script/convert-dotenv-to-kube-env.sh ./build/.env ./build/deployment.yaml
	@sed -i'' -e 's#istiosidecarval#$(istiosidecar)#g' ./build/deployment.yaml

	@cp -r ../../k8s/service.yaml ./build/service.yaml
	@sed -i'' -e 's#appname#$(APP_NAME)#g' ./build/service.yaml

	@kubectl delete --ignore-not-found=true -f ./build/deployment.yaml

	@minikube -p poc image load --overwrite=true $(APP_IMAGE_NAME)

	@kubectl apply -f ./build/deployment.yaml
	@kubectl apply -f ./build/service.yaml

	@if [ $(istiosidecar) = "true" ]; then \
		cp -r ../../k8s/istio.yaml ./build/istio.yaml; \
		sed -i'' -e 's#appname#$(APP_NAME)#g' ./build/istio.yaml; \
		kubectl apply -f ./build/istio.yaml; \
	fi

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

	# provision istio as the ingress gateway
	@curl -kLs -o ./k8s/istio-argocd/install.yaml https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
	@kubectl apply -k ./k8s/istio-argocd -n argocd --wait=true
	@kubectl apply -f ./k8s/istio-argocd.yaml -n argocd

	# install client
	@brew install argocd

.PHONY: setup-argocd-client
setup-argocd-client:
	# print admin password
	@echo "admin username: admin - password:" $(shell kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
	@yes | argocd login localhost:8888 --username admin --password $(shell kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

.PHONY: build-argocd
build-argocd:
	@kubectl config set-context --current --namespace=argocd && \
		argocd app create --upsert $(APP_NAME) --repo https://github.com/hdlproject/kubernetes-poc.git --path service/$(APP_NAME)/build --dest-server https://kubernetes.default.svc --dest-namespace default && \
		argocd app sync $(APP_NAME)

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
setup-kubernetes: install-istio install-postgres
	@minikube start -p poc --driver=docker
