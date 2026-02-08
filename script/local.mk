.PHONY: expose-kiali
expose-kiali:
	@kubectl -n istio-system port-forward svc/kiali 20001:20001

.PHONY: expose-istio-ingress-gateway
expose-istio-ingress-gateway:
	@kubectl -n istio-system port-forward svc/istio-ingressgateway 8080:80 8443:443

.PHONY: expose-argocd-server
expose-argocd-server:
	@kubectl -n argocd port-forward svc/argocd-server 8888:80

.PHONY: expose-prometheus-helm
expose-prometheus-helm:
	@kubectl -n monitoring port-forward svc/kps-kube-prometheus-stack-prometheus 9090:9090

.PHONY: expose-loki-helm
expose-loki-helm:
	@kubectl -n monitoring port-forward svc/loki 3100:3100

.PHONY: expose-grafana-helm
expose-grafana-helm:
	@kubectl -n monitoring get secret kps-grafana -o jsonpath="{.data.admin-password}"  | base64 --decode ; echo
	@kubectl -n monitoring port-forward svc/kps-grafana 3080:80

.PHONY: expose-jaeger-helm
expose-jaeger-helm:
	@kubectl -n tracing port-forward svc/jaeger 16686:16686

.PHONY: expose-service
expose-service:
	@kubectl port-forward svc/gateway-uat 8001:8000
