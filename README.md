# cert-manager-clusterissuer-policy


# install  GK  and add constraints  
 ```
 helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts
 helm install gatekeeper/gatekeeper --name-template=gatekeeper --namespace gatekeeper-system --create-namespace
```
## 


## notes 
* https://open-policy-agent.github.io/gatekeeper/website/docs/howto/#input-review
*https://pkg.go.dev/k8s.io/kubernetes/pkg/apis/admission#AdmissionRequest
* https://www.danielstechblog.io/evaluating-gatekeeper-policies-with-the-rego-playground/
* https://github.com/Azure/azure-policy/tree/master/samples/KubernetesService
