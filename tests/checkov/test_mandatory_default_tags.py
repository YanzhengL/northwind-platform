"""Tests for the CKV2_NW_1 Checkov policy: every aws provider sets mandatory default_tags."""

from pathlib import Path

import pytest
from checkov.runner_filter import RunnerFilter
from checkov.terraform.runner import Runner

REPO_ROOT = Path(__file__).resolve().parents[2]
POLICIES_DIR = REPO_ROOT / ".checkov" / "policies"
CHECK_ID = "CKV2_NW_1"

ALL_TAGS = """
provider "aws" {
  region = "eu-west-2"
  default_tags {
    tags = { team = "platform", env = "dev", service = "nw", owner = "platform" }
  }
}
"""

TWO_TAGS_MISSING = """
provider "aws" {
  region = "eu-west-2"
  default_tags {
    tags = { team = "platform", env = "dev" }
  }
}
"""

NO_DEFAULT_TAGS = """
provider "aws" {
  region = "eu-west-2"
}
"""

# Step 6 adds an aliased provider; its tags don't inherit from the default provider.
ALIAS_WITHOUT_TAGS = (
    ALL_TAGS
    + """
provider "aws" {
  alias  = "dev"
  region = "eu-west-2"
}
"""
)


def run_check(tmp_path: Path, hcl: str) -> dict[str, str]:
    """Scan one Terraform snippet and return {provider resource: PASSED|FAILED} for CKV2_NW_1."""
    # Fixtures live in tmp_path, not the repo, so pre-commit's terraform hooks never lint
    # the deliberately failing .tf files.
    (tmp_path / "main.tf").write_text(hcl)
    report = Runner().run(
        root_folder=str(tmp_path),
        external_checks_dir=[str(POLICIES_DIR)],
        # Only our check, so built-in results can't make the assertions pass by accident.
        runner_filter=RunnerFilter(framework=["terraform"], checks=[CHECK_ID]),
    )
    results = {
        r.resource: "PASSED" for r in report.passed_checks if r.check_id == CHECK_ID
    }
    results |= {
        r.resource: "FAILED" for r in report.failed_checks if r.check_id == CHECK_ID
    }
    return results


@pytest.mark.parametrize(
    ("hcl", "expected"),
    [
        pytest.param(ALL_TAGS, {"aws.default": "PASSED"}, id="all-four-tags"),
        pytest.param(
            TWO_TAGS_MISSING, {"aws.default": "FAILED"}, id="two-tags-missing"
        ),
        pytest.param(NO_DEFAULT_TAGS, {"aws.default": "FAILED"}, id="no-default-tags"),
        pytest.param(
            ALIAS_WITHOUT_TAGS,
            {"aws.default": "PASSED", "aws.dev": "FAILED"},
            id="alias-without-tags",
        ),
    ],
)
def test_mandatory_default_tags(
    tmp_path: Path, hcl: str, expected: dict[str, str]
) -> None:
    # An empty result means the policy wasn't loaded; comparing the full dict catches that too.
    assert run_check(tmp_path, hcl) == expected
