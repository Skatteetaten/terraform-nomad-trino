rule "terraform_deprecated_index" {
  enabled = true
}
rule "terraform_unused_declarations" {
  enabled = true
}
rule "terraform_comment_syntax" {
  enabled = true
}
rule "terraform_documented_outputs" {
  enabled = true
}
rule "terraform_documented_variables" {
  enabled = true
}
rule "terraform_typed_variables" {
  enabled = true
}
rule "terraform_naming_convention" {
  enabled = true
}
rule "terraform_required_version" {
  enabled = true
}
// todo: fix required_providers with DRY concept https://github.com/skatteetaten/vagrant-hashistack-template/issues/14
//rule "terraform_required_providers" {
//  enabled = true
//}
rule "terraform_standard_module_structure" {
  enabled = true
}

