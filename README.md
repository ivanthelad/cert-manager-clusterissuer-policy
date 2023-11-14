# cert-manager-clusterissuer-policy


# install  GK  and add constraints  

 installing the oss project as its quick to test rego deployments than via azure policy 
 ```
 helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts
 helm install gatekeeper/gatekeeper --name-template=gatekeeper --namespace gatekeeper-system --create-namespace
```
##  
This deploys the rego rule which should fail on the check ` issuer != "selfsigned-cluster-issuer"`
* deploy tests/constraintTemplate.yaml 
This deploy an instance of the rego rule 
* deploy tests/constraint.yaml 

### To test deploy a certifcate 
the actual cluster issuer is not required to be deployed 
* deploy setup/selfsigned.clusterissuer.yaml

## notes 
* https://open-policy-agent.github.io/gatekeeper/website/docs/howto/#input-review
* https://pkg.go.dev/k8s.io/kubernetes/pkg/apis/admission#AdmissionRequest
* https://www.danielstechblog.io/evaluating-gatekeeper-policies-with-the-rego-playground/
* https://github.com/Azure/azure-policy/tree/master/samples/KubernetesService
* Rego example https://play.openpolicyagent.org/p/7O2UVOvrbN for checking data repo
* https://github.com/open-policy-agent/gatekeeper-library/blob/master/library/general/poddisruptionbudget/template.yaml