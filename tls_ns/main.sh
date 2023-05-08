#example deployed to tlstest namespace


#download helm chart
helm repo add hashicorp https://helm.releases.hashicorp.com
#generate template with modified values
helm template vault hashicorp/vault -n tlstest -f my_values.yaml > vault-injector.tmpl.yaml

#login to OCP console
oc login --token=sha256~Xlnb7UHVOGgaTe0S56GLatO7ssRYGzQ44X44zHeSk-Y --server=https://api.hex-ocp.nase.team:6443

#create namespace
oc create ns tlstest

#deploy vault injector to OCP
oc apply -n tlstest -f  vault-injector.tmpl.yaml

#modify file with metadata.name=VAULT_HELM_SECRET_NAME
#VAULT_HELM_SECRET_NAME=$(oc get secrets --output=json | jq -r '.items[].metadata | select(.name|startswith("vault-token-")).name')
#oc apply -n tlstest -f vault-secret.yaml

#prepare vault auth values from ocp
VAULT_HELM_SECRET_NAME=$(oc get secrets -n tlstest --output=json | jq -r '.items[].metadata | select(.name|startswith("vault-token-")).name')
TOKEN_REVIEW_JWT=$(oc get secret $VAULT_HELM_SECRET_NAME -n tlstest --output='go-template={{ .data.token }}' | base64 --decode)
KUBE_HOST=$(oc config view --raw --minify --flatten -n tlstest --output='jsonpath={.clusters[].cluster.server}')
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
vault write auth/kubernetes/role/devweb-app      bound_service_account_names=internal-app      bound_service_account_namespaces=tlstest      policies=devwebapp      ttl=24h

#insert secret to vault kv
vault kv put kv/devwebapp/config username="static-user" password="static-password"

#create application serviceaccount
oc create sa internal-app -n tlstest
#deploy application
oc apply -n tlstest -f pod-devwebapp-with-annotations.yaml
#check if secret file was generated
oc rsh  -n tlstest   devwebapp-with-annotations



#fix certificate issue
kind: Secret
apiVersion: v1
metadata:
  name: client-vault-auth
  namespace: tlstest
  uid: 5eef2d1b-949f-4122-a0f7-dce58c6c6d5e
  resourceVersion: '3141215'
  creationTimestamp: '2023-05-08T09:39:24Z'
  managedFields:
    - manager: Mozilla
      operation: Update
      apiVersion: v1
      time: '2023-05-08T09:41:32Z'
      fieldsType: FieldsV1
      fieldsV1:
        'f:data':
          .: {}
          'f:client.ca': {}
        'f:type': {}
data:
  client.ca: >-
    LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUQ4akNDQXRxZ0F3SUJBZ0lVWnJUZ3BhbndkZnpWdGJtMjdNUWRrYVpTYjRNd0RRWUpLb1pJaHZjTkFRRUwKQlFBd0xURXJNQ2tHQTFVRUF4TWlaWGhoYlhCc1pTNWpiMjBnU1c1MFpYSnRaV1JwWVhSbElFRjFkR2h2Y21sMAplVEFlRncweU16QTFNRGN4TWpRek16WmFGdzB5TXpBMU1EZ3hNalEwTURWYU1COHhIVEFiQmdOVkJBTVRGSFpoCmRXeDBMWFJsYzNRdWJtRnpaUzUwWldGdE1JSUJJakFOQmdrcWhraUc5dzBCQVFFRkFBT0NBUThBTUlJQkNnS0MKQVFFQXdNUlo4SzkvZVR1ZWM1NDFDT0VhbXd3WkEzeFJCMVdqbTVIaUJuRTlTZmtsbExDNkFnOUtVSjNZTzcyNgpoUEdRMVJXUXZxdUdta3FFeitoQVFKeFZTdHBhTWVEZk1HM3FuaEVyYU5vTkxSMlFQbjlWZTA2azJiRWZVNU5DClFRUERSYXB1RjV6RXpXTDFUeHF4OXFtbU5nOEx5R1N5WVpJTnFONEdEczFhTjlqQWlWeEY2dmpFU2V6NXFjN0wKc3h5ZDRYYnBLTWp3Zm5lVnRVaTFlTXIrbXM1VmpnOUNrYWZtOTQ0ZXhwejU5NWlZdllFelNFR0N4aHU1d0FraAp3Q0FSdzJtenNWb1NxOUNNeGU4bHVLMDU5K2JsRjh2b2FJSk1jd2tidnZCM1ZGYkJPTXdEY0RyMlBCN01iQytBCjNaV015cmxlZWthTFBPOTIwYXRzQ0kybVhRSURBUUFCbzRJQkZqQ0NBUkl3RGdZRFZSMFBBUUgvQkFRREFnT28KTUIwR0ExVWRKUVFXTUJRR0NDc0dBUVVGQndNQkJnZ3JCZ0VGQlFjREFqQWRCZ05WSFE0RUZnUVVyOFlYQkQ4awo4amlqYlZPOFNJVXAyVjhoL3dnd0h3WURWUjBqQkJnd0ZvQVVJNXdqSWJLckphbktvWVFyYXg2UTlWUHNOVVV3ClJBWUlLd1lCQlFVSEFRRUVPREEyTURRR0NDc0dBUVVGQnpBQ2hpaG9kSFJ3T2k4dk1Ua3lMakUyT0M0ME1DNHgKT1RrNk9ESXdNQzkyTVM5d2EybGZhVzUwTDJOaE1COEdBMVVkRVFRWU1CYUNGSFpoZFd4MExYUmxjM1F1Ym1GegpaUzUwWldGdE1Eb0dBMVVkSHdRek1ERXdMNkF0b0N1R0tXaDBkSEE2THk4eE9USXVNVFk0TGpRd0xqRTVPVG80Ck1qQXdMM1l4TDNCcmFWOXBiblF2WTNKc01BMEdDU3FHU0liM0RRRUJDd1VBQTRJQkFRQUVVaUlaZmU3ZC8vOU0KeXM4RC85ZFNRbjNUYmxCSkZQeUVCcWoybTFWa3pVc1hkYnRHSm5JSXhBdW1rVEZoRTRYOS80WE9wcDBVbko1KwpOdnZ4N2sreFZubTZjbEtybDNvankzN1MxSXFPOGJUb1FrRXFhR3BKWnJEZ0VMRTN5WUpGMVZUb1FHL2djM1ZECk1DeHVqR0dWeEpzWTIrL0JnR1NMMXFCN0lRRVdzakU0U0pFaUVZckxweDM1VGFsWnpTZEw2WG9DL1ozMi82SEcKMUZXUTlLNzBwY3U0S0l2NUdET3k0M3FqUW1iT1hjQUgvVUtyTStYRkxwNWN5Q0sxMXQzUEJLbEpiOEdHUHJ6VwpneUw4WnJ0Q0NHNWVrVW8xOU42OVFzcnVqelZuYWFTaTdxbnQvbm5VME94Zlp6VlQ1YVZEc3R4WkxocjcxRmdrCm9yUGlXV3BzCi0tLS0tRU5EIENFUlRJRklDQVRFLS0tLS0K
type: Opaque


kubernetes.io/created-by: openshift.io/create-dockercfg-secrets
    kubernetes.io/service-account.name: vault
    kubernetes.io/service-account.uid: 47fc1515-a742-4196-8903-a8268fa20be6


