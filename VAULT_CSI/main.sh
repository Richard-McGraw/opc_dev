#example deployed to tlstest namespace

#create namespace
oc create ns vault-auth-csi

#install vault csi provider
helm repo add hashicorp https://helm.releases.hashicorp.com
helm template vault hashicorp/vault -n vault-auth-csi -f my_values.yaml > vault-csi.tmpl.yaml
oc apply -n vault-auth-csi -f vault-csi.tmpl.yaml

#instaLL CSI DRIVER
helm repo add secrets-store-csi-driver https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts
helm template csi secrets-store-csi-driver/secrets-store-csi-driver --set syncSecret.enabled=true -n vault-auth-csi > csi-driver.tmpl.yaml
oc apply -n vault-auth-csi -f csi-driver.tmpl.yaml

#patch adm
oc apply -n vault-auth-csi -f application-scc.yaml
oc patch daemonset vault-csi-provider -n vault-auth-csi   --type='json'   --patch='[{"op": "add", "path": "/spec/template/spec/containers/0/securityContext", "value": {"privileged": true} }]'
oc adm policy -n vault-auth-csi add-scc-to-user privileged system:serviceaccount:vault-auth-csi:vault-csi-provider
oc adm policy -n vault-auth-csi add-scc-to-user privileged system:serviceaccount:vault-auth-csi:secrets-store-csi-driver





#prepare vault auth values from ocp vault-auth-csi
VAULT_HELM_SECRET_NAME=$(oc get secrets -n vault-auth-csi --output=json | jq -r '.items[].metadata | select(.name|startswith("vault-token-")).name')
TOKEN_REVIEW_JWT=$(oc get secret $VAULT_HELM_SECRET_NAME -n vault-auth-csi --output='go-template={{ .data.token }}' | base64 --decode)
KUBE_HOST=$(oc config view --raw --minify --flatten -n vault-auth-csi --output='jsonpath={.clusters[].cluster.server}')
KUBE_CA_CERT=$(cat KUBE_CA_CERT) #certificate from secretaccunt voault-token


# create vault poicy
vault policy write webapp - <<EOF
path "kv/data/webapp/config" {
  capabilities = ["read"]
}
EOF

#set kubernetes auth
vault auth enable --path=kubernetes_csi kubernetes
vault write auth/kubernetes_csi/config      token_reviewer_jwt="$TOKEN_REVIEW_JWT"      kubernetes_host="$KUBE_HOST"      kubernetes_ca_cert="$KUBE_CA_CERT"
vault write auth/kubernetes_csi/role/devweb-app      bound_service_account_names=internal-app      bound_service_account_namespaces=vault-auth-csi      policies=webapp      ttl=24h

#insert secret to vault kv
vault kv put kv/webapp/config username="static-user-csi" password="static-password-csi"




#create service account
oc create sa webapp-sa

#create secret with vault ca
oc apply -n vault-auth-csi -f vault-server-tls-secrets.yaml

#deploy secret provider
oc apply -n vault-auth-csi -f webapp-secret-provider-class.yml
#deploy app
oc apply -n vault-auth-csi -f webapp-pod.yaml

#check mounted file
oc exec -it pod/webapp -- /bin/sh


