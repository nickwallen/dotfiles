eval-browser-prod() {
  aws-vault exec sso-prod-engineering -- eval-browser "$@"
}
