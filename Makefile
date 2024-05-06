.PHONY: docker-build
docker-build:
	@if [ ! -d ./build ]; then mkdir ./build; fi

	@cp -r ./.env ./build/.env

	@cp -r ../main.go ./build/main.go

	@cp -r ../go.mod ./build/go.mod
	@cp -r ../go.sum ./build/go.sum
	@cd ./build && go mod tidy

	@cp -r ../Dockerfile ./build/Dockerfile
	@sed -i'' -e 's#appname#$(APP_NAME)#g' ./build/Dockerfile
	@docker buildx build -f ./build/Dockerfile -t $(APP_IMAGE_NAME) --output=type=docker ./build

.PHONY: kubernetes-build
kubernetes-build: docker-build
	@cp -r ../../k8s/deployment.yaml ./build/deployment.yaml
	@sed -i'' -e 's#appname#$(APP_NAME)#g' ./build/deployment.yaml
	@chmod +x ../../script/convert-dotenv-to-kube-env.sh && ../../script/convert-dotenv-to-kube-env.sh ./build/.env ./build/deployment.yaml
	@sed -i'' -e 's#istiosidecarval#$(istiosidecar)#g' ./build/deployment.yaml

	@cp -r ../../k8s/service.yaml ./build/service.yaml
	@sed -i'' -e 's#appname#$(APP_NAME)#g' ./build/service.yaml

	@kubectl delete --ignore-not-found=true -f ./build/deployment.yaml

	@minikube -p istio image load --overwrite=true $(APP_IMAGE_NAME)

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

.PHONY: build-service-all
build-service-all:
	@make -C ./service/gateway kubernetes-build istiosidecar="true"
	@make -C ./service/transaction kubernetes-build istiosidecar="true"
	@make -C ./service/user kubernetes-build istiosidecar="true"
	@make -C ./service/external kubernetes-build istiosidecar="false"
