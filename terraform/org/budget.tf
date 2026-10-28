# The budget was created in the console on Day 1, before Terraform existed.
# Import brings it under code; the plan should show only the new 80% forecast alert.
# The three Day 1 alerts are copied exactly, otherwise the import would delete them.
import {
  to = aws_budgets_budget.monthly
  id = "${data.aws_caller_identity.current.account_id}:${var.budget_name}"
}

resource "aws_budgets_budget" "monthly" {
  name         = var.budget_name
  budget_type  = "COST"
  limit_amount = var.budget_limit_amount
  limit_unit   = var.budget_limit_unit
  time_unit    = "MONTHLY"

  # Existing Day 1 alert: real spend has crossed the threshold.
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = var.budget_actual_threshold_percent
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.budget_alert_emails
  }

  # Existing Day 1 alert: real spend is close to the limit, time to tear down.
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 85
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.budget_alert_emails
  }

  # Existing Day 1 alert: the month is on course to go over the limit.
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = var.budget_alert_emails
  }

  # New: warns early, while the month's spend is still on course to reach 80% of the limit.
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = var.budget_alert_emails
  }
}
