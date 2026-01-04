.PHONY: build-service-docker
build-service-docker:
	@if [ ! -d ./build ]; then mkdir ./build; fi

	@cp -r ./.env ./build/.env

	@cp -r ../main.go ./build/main.go

	@cp -r ../go.mod ./build/go.mod
	@cp -r ../go.sum ./build/go.sum
	@cd ./build && go mod tidy

	@cp -r ../Dockerfile ./build/Dockerfile
	@sed -i '' -e 's#appname#$(APP_NAME)#g' ./build/Dockerfile
	@docker buildx build -f ./build/Dockerfile -t $(APP_IMAGE_NAME) --output=type=docker ./build

.PHONY: build-service-kube
build-service-kube: build-service-docker
	@cp -r ../../k8s/deployment.yaml ./build/deployment.yaml
	@sed -i '' -e 's#appname#$(APP_NAME)#g' ./build/deployment.yaml
	@chmod +x ../../script/convert-dotenv-to-kube-env.sh && ../../script/convert-dotenv-to-kube-env.sh ./build/.env ./build/deployment.yaml
	@sed -i '' -e 's#istiosidecarval#$(istiosidecar)#g' ./build/deployment.yaml

	@cp -r ../../k8s/service.yaml ./build/service.yaml
	@sed -i '' -e 's#appname#$(APP_NAME)#g' ./build/service.yaml

	@kubectl delete --ignore-not-found=true -f ./build/deployment.yaml

	@minikube -p poc image load --overwrite=true $(APP_IMAGE_NAME)

	# Uncomment if not using argocd
#	@kubectl apply -f ./build/deployment.yaml
#	@kubectl apply -f ./build/service.yaml

	@if [ $(istiosidecar) = "true" ]; then \
		cp -r ../../k8s/istio.yaml ./build/istio.yaml; \
		sed -i '' -e 's#appname#$(APP_NAME)#g' ./build/istio.yaml; \
		kubectl apply -f ./build/istio.yaml; \
	fi

.PHONY: remove-service-kube
remove-service-kube:
	@kubectl delete -f ./build/deployment.yaml
	@kubectl delete -f ./build/service.yaml

.PHONY: build-service-argocd
build-service-argocd:
	@kubectl config set-context --current --namespace=argocd && \
		argocd app create --upsert $(APP_NAME) --repo https://github.com/hdlproject/kubernetes-poc.git --path service/$(APP_NAME)/build --dest-server https://kubernetes.default.svc --dest-namespace default && \
		argocd app sync $(APP_NAME)
