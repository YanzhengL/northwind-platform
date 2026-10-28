# Tag policies fix the spelling and case of tag keys across the org. They don't
# make a tag mandatory: default_tags in every provider and Checkov in CI do that.
# No "enforced_for" block, so this only reports non-compliance and never blocks a create.
resource "aws_organizations_policy" "tags" {
  name        = "nw-mandatory-tags"
  description = "Standard keys for the mandatory tags team, env, service and owner."
  type        = "TAG_POLICY"

  content = jsonencode({
    tags = {
      for key in ["team", "env", "service", "owner"] :
      key => { tag_key = { "@@assign" = key } }
    }
  })

  depends_on = [aws_organizations_organization.this]
}

# Attached at the root: unlike SCPs, tag policies also apply to the management account.
resource "aws_organizations_policy_attachment" "tags" {
  policy_id = aws_organizations_policy.tags.id
  target_id = aws_organizations_organization.this.roots[0].id
}
