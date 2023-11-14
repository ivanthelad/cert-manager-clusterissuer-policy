package main

default is_gatekeeper = false

# Checks whether the policy 'input' has came from Gatekeeper
is_gatekeeper() {
  has_field(input, "review")
  has_field(input.review, "object")
}

# Check the obj contains a field
has_field(obj, field) {
  obj[field]
}

# Get the input, as the input is not Gatekeeper based
object = input {
  not is_gatekeeper
}

# Get the input.review.object, as the input is Gatekeeper based
object = input.review.object {
  is_gatekeeper
}

# Set the .metadata.name of the object we are currently working on
name = object.metadata.name

# Set the .kind of the object we are currently working on
kind = object.kind

issuer = object.spec.issuerRef


# Is the kind a Certififcate ?
is_certificate () {
  lower(kind) == "Certificate"
}
# Get isser config if its a certifcate 
get_issuer {
  is_certificate
  "default2" == issuer.name
  "ClusterIssuer" == issuer.kind
}

allow () {
	get_issuer
    kind == "Certificate"
    "defaul2t" ==  input.request.namespace

}




# Get the format for messages on Gatekeeper
format(msg) = gatekeeper_format {
  is_gatekeeper
  gatekeeper_format = {"msg": msg}
}

# Get msg as ism, when not on Gatekeeper
format(msg) = msg {
  not is_gatekeeper
}

# @title Check a Deployment is not using the latest tag for their image
# @kinds apps/Deployment
violation[msg] {
  is_certificate
   allow
   get_issuer
  ## container := containers[_]

 ## endswith(container.image, ":latest")
  msg := format("Ingress host conflicts with ingress")

 ## msg := format(sprintf("%s/%s: container '%s' is using the latest tag for its image (%s), which is an anti-pattern.", [kind, name, container.name, container.image]))
}