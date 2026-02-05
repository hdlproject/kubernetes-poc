.PHONY: build-service-docker
build-service-docker:
	@for env in $(environment); do \
		if [ ! -d ./build ]; then mkdir ./build; fi; \
		\
		cp -r ./.env.$$env ./build/.env.$$env; \
		\
		cp -r ../main.go ./build/main.go; \
		\
		cp -r ../go.mod ./build/go.mod; \
		cp -r ../go.sum ./build/go.sum; \
		cd ./build && go mod tidy && cd ..; \
		\
		cp -r ../Dockerfile ./build/Dockerfile; \
		sed -i '' -e 's#appname#$(APP_NAME)#g' ./build/Dockerfile; \
		docker buildx build -f ./build/Dockerfile -t $(APP_IMAGE_NAME):$$env --output=type=docker ./build; \
	done

.PHONY: build-service-kube
build-service-kube: build-service-docker
	@for env in $(environment); do \
		minikube -p poc image load --overwrite=true $(APP_IMAGE_NAME):$$env; \
		\
		cp -r ../../k8s/deployment.yaml ./build/deployment-$$env.yaml; \
		sed -i '' -e "s#appname#$(APP_NAME)-$$env#g" ./build/deployment-$$env.yaml; \
		sed -i '' -e "s#namenoenv#$(APP_NAME)#g" ./build/deployment-$$env.yaml; \
		sed -i '' -e "s#envname#$$env#g" ./build/deployment-$$env.yaml; \
		chmod +x ../../script/convert-dotenv-to-kube-env.sh && ../../script/convert-dotenv-to-kube-env.sh ./build/.env.$$env ./build/deployment-$$env.yaml; \
		sed -i '' -e 's#istiosidecarval#$(istiosidecar)#g' ./build/deployment-$$env.yaml; \
		\
		cp -r ../../k8s/service.yaml ./build/service-$$env.yaml; \
		sed -i '' -e "s#appname#$(APP_NAME)-$$env#g" ./build/service-$$env.yaml; \
		sed -i '' -e "s#namenoenv#$(APP_NAME)#g" ./build/service-$$env.yaml; \
		sed -i '' -e "s#envname#$$env#g" ./build/service-$$env.yaml; \
		\
		if [ "$(local)" = "true" ]; then \
			kubectl delete --ignore-not-found=true -f ./build/deployment-$$env.yaml; \
  			kubectl apply -f ./build/deployment-$$env.yaml; \
			kubectl apply -f ./build/service-$$env.yaml; \
		fi; \
		\
		if [ "$(istiosidecar)" = "true" ]; then \
			cp -r ../../k8s/istio.yaml ./build/istio-$$env.yaml; \
			sed -i '' -e "s#appname#$(APP_NAME)-$$env#g" ./build/istio-$$env.yaml; \
			\
			if [ "$(local)" = "true" ]; then \
				kubectl apply -f ./build/istio-$$env.yaml; \
			fi; \
		else \
			cp -r ../../k8s/service-entry.yaml ./build/service-entry-$$env.yaml; \
			sed -i '' -e "s#appname#$(APP_NAME)-$$env#g" ./build/service-entry-$$env.yaml; \
			\
			if [ "$(local)" = "true" ]; then \
				kubectl apply -f ./build/service-entry-$$env.yaml; \
			fi; \
		fi; \
	done

.PHONY: remove-service-kube
remove-service-kube:
	@for env in $(environment); do \
		kubectl delete -f ./build/deployment-$$env.yaml; \
		kubectl delete -f ./build/service-$$env.yaml; \
		\
		if [ "$(istiosidecar)" = "true" ]; then \
			kubectl delete -f ./build/istio-$$env.yaml; \
		else \
			kubectl delete -f ./build/service-entry-$$env.yaml; \
		fi; \
	done

.PHONY: build-service-argocd
build-service-argocd:
	if [ "$(local)" = "true" ]; then \
		kubectl config set-context --current --namespace=argocd && \
			argocd app create --upsert $(APP_NAME) --repo https://github.com/hdlproject/kubernetes-poc.git --path service/$(APP_NAME)/build --dest-server https://kubernetes.default.svc --dest-namespace default && \
			argocd app sync $(APP_NAME)
	fi;
