"""Northwind Platform architecture diagrams, generated as code.

Produces two images in this folder:
  architecture.png     - detailed view for the README and interviews
  architecture-cv.png  - simplified view (about 8 boxes) for the CV

Usage (from repo root):
  make diagram
  # or
  python docs/diagrams/architecture.py

Requires: pip install diagrams, plus Graphviz (`dot`) on PATH.
Keep this file in sync with the real Terraform and GitOps code: when a
component is added or removed, update the diagram in the same pull request.
"""

from pathlib import Path

from diagrams import Cluster, Diagram, Edge
from diagrams.aws.compute import (
    EC2ContainerRegistry,
    EC2SpotInstance,
    ElasticKubernetesService,
)
from diagrams.aws.cost import Budgets
from diagrams.aws.database import Dynamodb
from diagrams.aws.integration import SimpleQueueServiceSqs
from diagrams.aws.management import Cloudtrail, Cloudwatch, Organizations
from diagrams.aws.network import (
    ElbApplicationLoadBalancer,
    Endpoint,
    NATGateway,
    Route53,
)
from diagrams.aws.security import (
    IdentityAndAccessManagementIamRole,
    KeyManagementService,
    SecretsManager,
    SingleSignOn,
)
from diagrams.aws.storage import SimpleStorageServiceS3
from diagrams.k8s.compute import Pod
from diagrams.k8s.group import NS
from diagrams.onprem.ci import GithubActions
from diagrams.onprem.gitops import Argocd
from diagrams.onprem.iac import Terraform
from diagrams.onprem.logging import Loki
from diagrams.onprem.monitoring import Grafana, Prometheus
from diagrams.onprem.security import Trivy
from diagrams.onprem.tracing import Tempo
from diagrams.onprem.vcs import Github
from diagrams.saas.chat import Slack

OUT = Path(__file__).resolve().parent

GRAPH = {
    "fontsize": "22",
    "fontname": "Helvetica",
    "pad": "0.4",
    "nodesep": "0.55",
    "ranksep": "0.9",
    "splines": "spline",
}
NODE = {"fontsize": "12", "fontname": "Helvetica"}
CLUSTER = {"fontsize": "14", "fontname": "Helvetica-Bold"}


# Edge factories: diagrams mutates Edge objects when chained, so every
# connection must get a fresh Edge or labels and arrows leak between lines.
def deploy(label: str = "") -> Edge:
    return Edge(color="#2b6cb0", style="bold", label=label)


def data(label: str = "") -> Edge:
    return Edge(color="#2f855a", label=label)


def signal(label: str = "") -> Edge:
    return Edge(color="#c05621", style="dashed", label=label)


def control(label: str = "") -> Edge:
    return Edge(color="#718096", style="dotted", label=label)


def detailed() -> None:
    with Diagram(
        "Northwind Platform - AWS internal developer platform",
        filename=str(OUT / "architecture"),
        outformat="png",
        show=False,
        direction="LR",
        graph_attr=GRAPH,
        node_attr=NODE,
    ):
        with Cluster("Delivery (GitHub)", graph_attr=CLUSTER):
            repo = Github("northwind-platform\nmonorepo")
            gha = GithubActions("Actions\nplan / apply / build")
            tf = Terraform("Terraform\nmodules")
            scan = Trivy("Trivy + Checkov\nscans")
            repo >> deploy("PR") >> gha
            gha >> deploy() >> tf
            gha >> deploy() >> scan

        with Cluster("AWS Organization (eu-west-2)", graph_attr=CLUSTER):
            with Cluster("management account", graph_attr=CLUSTER):
                org = Organizations("OUs + SCPs")
                sso = SingleSignOn("IAM Identity\nCenter")
                trail = Cloudtrail("Org CloudTrail")
                budget = Budgets("Budgets\n£20/month")

            with Cluster("shared-services account", graph_attr=CLUSTER):
                ecr = EC2ContainerRegistry("ECR")
                state = SimpleStorageServiceS3("Terraform state\n(S3, lockfile)")
                dns = Route53("Route 53\nplatform subdomain")

            with Cluster(
                "workloads-dev account (prod mirrors this)", graph_attr=CLUSTER
            ):
                with Cluster("VPC - 3 AZs", graph_attr=CLUSTER):
                    alb = ElbApplicationLoadBalancer("ALB\n(LB controller)")
                    nat = NATGateway("NAT\n(1 in dev)")
                    vpce = Endpoint("VPC endpoints\nECR / S3")

                    with Cluster("EKS cluster", graph_attr=CLUSTER):
                        eks = ElasticKubernetesService("EKS\ncontrol plane")
                        nodes = EC2SpotInstance("Karpenter\nspot nodes")
                        argo = Argocd("Argo CD\napp-of-apps")

                        with Cluster("platform namespaces", graph_attr=CLUSTER):
                            prom = Prometheus("Prometheus\n+ Alertmanager")
                            graf = Grafana("Grafana\nSLO dashboards")
                            loki = Loki("Loki")
                            tempo = Tempo("Tempo")
                            policy = NS("Kyverno, ESO,\nOpenCost")

                        with Cluster("tenant: team-orders", graph_attr=CLUSTER):
                            orders = Pod("orders-api")
                        with Cluster("tenant: team-payments", graph_attr=CLUSTER):
                            worker = Pod("payments-worker")

                ddb = Dynamodb("DynamoDB\norders")
                sqs = SimpleQueueServiceSqs("SQS\npayments")
                secrets = SecretsManager("Secrets\nManager")
                kms = KeyManagementService("KMS")
                podid = IdentityAndAccessManagementIamRole("Pod Identity\nroles")
                cw = Cloudwatch("CloudWatch")

        slack = Slack("Slack\n#alerts-dev")

        # Delivery paths (blue)
        tf >> deploy("provision") >> eks
        tf >> deploy() >> org
        tf >> control("state") >> state
        gha >> deploy("push image") >> ecr
        repo >> deploy("sync gitops/") >> argo
        argo >> deploy() >> orders
        argo >> deploy() >> worker
        argo >> deploy() >> policy

        # Runtime data paths (green)
        dns >> data() >> alb >> data() >> orders
        orders >> data() >> ddb
        orders >> data("publish") >> sqs
        sqs >> data("consume") >> worker
        eks >> control() >> nodes
        ecr >> control("pull via") >> vpce
        orders >> control("AWS creds") >> podid
        policy >> control() >> secrets
        secrets >> control() >> kms

        # Signals (orange)
        orders >> signal("metrics") >> prom
        worker >> signal() >> prom
        orders >> signal("logs") >> loki
        orders >> signal("traces") >> tempo
        cw >> signal() >> graf
        prom >> signal() >> graf
        loki >> signal() >> graf
        tempo >> signal() >> graf
        prom >> signal("burn-rate alerts") >> slack
        budget >> signal("cost alert") >> slack
        _ = (
            sso,
            trail,
            nat,
        )  # shown as account contents; no edges to keep the view readable


def cv() -> None:
    """Simplified view for a CV: readable at small size, about 8 boxes."""
    with Diagram(
        "Northwind Platform (AWS EKS internal developer platform)",
        filename=str(OUT / "architecture-cv"),
        outformat="png",
        show=False,
        direction="LR",
        graph_attr={**GRAPH, "fontsize": "18", "nodesep": "0.7", "ranksep": "1.1"},
        node_attr={**NODE, "fontsize": "13"},
    ):
        gha = GithubActions("GitHub Actions\nOIDC, no keys")
        tf = Terraform("Terraform\nmulti-account")
        with Cluster("AWS (eu-west-2)", graph_attr=CLUSTER):
            org = Organizations("Organization\nSCP guardrails")
            with Cluster("EKS platform", graph_attr=CLUSTER):
                argo = Argocd("Argo CD\nGitOps")
                tenants = NS("Self-service\ntenants (1 PR)")
                obs = Prometheus("Prometheus\nSLO alerts")
            data_store = Dynamodb("DynamoDB + SQS")
        slack = Slack("Slack on-call")

        gha >> deploy("plan / apply") >> tf
        tf >> deploy() >> org
        gha >> deploy("image + tag") >> argo
        argo >> deploy() >> tenants
        tenants >> data() >> data_store
        tenants >> signal() >> obs
        obs >> signal("alerts") >> slack


if __name__ == "__main__":
    detailed()
    cv()
    print(f"Wrote {OUT / 'architecture.png'} and {OUT / 'architecture-cv.png'}")
