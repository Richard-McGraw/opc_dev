#example deployed to devtest namespace


#download helm chart
helm repo add hashicorp https://helm.releases.hashicorp.com
#generate template with modified values
helm template vault hashicorp/vault -n devtest -f my_values.yaml > vault-injector.tmpl.yaml

#login to OCP console
oc login --token=sha256~Xlnb7UHVOGgaTe0S56GLatO7ssRYGzQ44X44zHeSk-Y --server=https://api.hex-ocp.nase.team:6443


#deploy vault injector to OCP
oc apply -n devtest -f  vault-injector.tmpl.yaml

#modify file with metadata.name=VAULT_HELM_SECRET_NAME
#VAULT_HELM_SECRET_NAME=$(oc get secrets --output=json | jq -r '.items[].metadata | select(.name|startswith("vault-token-")).name')
#oc apply -n devtest -f vault-secret.yaml

#prepare vault auth values from ocp
VAULT_HELM_SECRET_NAME=$(oc get secrets -n devtest --output=json | jq -r '.items[].metadata | select(.name|startswith("vault-token-")).name')
TOKEN_REVIEW_JWT=$(oc get secret $VAULT_HELM_SECRET_NAME -n devtest --output='go-template={{ .data.token }}' | base64 --decode)
KUBE_HOST=$(oc config view --raw --minify --flatten -n devtest --output='jsonpath={.clusters[].cluster.server}')
KUBE_CA_CERT=$(cat KUBE_CA_CERT) #certificate from secretaccunt voault-token

#vault setting
export VAULT_ADDR="http://192.168.40.199:8200"

# create vault poicy
vault policy write devwebapp - <<EOF
path "kv/data/devwebapp/config" {
  capabilities = ["read"]
}
EOF

#set kubernetes auth
vault auth enable kubernetes
vault write auth/kubernetes/config      token_reviewer_jwt="$TOKEN_REVIEW_JWT"      kubernetes_host="$KUBE_HOST"      kubernetes_ca_cert="$KUBE_CA_CERT"
vault write auth/kubernetes/role/devweb-app      bound_service_account_names=internal-app      bound_service_account_namespaces=default      policies=devwebapp      ttl=24h

#insert secret to vault kv
vault kv put kv/devwebapp/config username="static-user" password="static-password"

#create application serviceaccount
oc create sa internal-app -n devtest
#deploy application
oc apply -n devtest -f pod-devwebapp-with-annotations.yaml
#check if secret file was generated
oc rsh  -n devtest   devwebapp-with-annotations





