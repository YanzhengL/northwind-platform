# Turns `terraform show -json` into a Markdown table of actions and addresses only.
# PR comments are never masked by GitHub, so this output has to be safe on its own (ADR 0032).

def action:
  .change.actions
  | if . == ["delete", "create"] or . == ["create", "delete"] then "replace"
    else join("+")
    end;

# Identity Center for_each keys are usernames, so they are dropped from the address.
def safe_address:
  if .type | startswith("aws_identitystore")
  then .address | sub("\\[.*\\]$"; "[redacted]")
  else .address
  end;

[ .resource_changes[]?
  | select(.change.actions != ["no-op"] and .change.actions != ["read"]) ] as $changes
| if ($changes | length) == 0 then
    "No changes."
  else
    "| Action | Resource |\n| --- | --- |\n"
    + ($changes | map("| \(action) | `\(safe_address)` |") | join("\n"))
  end
