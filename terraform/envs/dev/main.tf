# In envs/dev, so `make down` destroys the network after every session.
module "vpc" {
  source = "../../modules/vpc"

  # Built from var.env, so resource names and the env tag can't disagree.
  name               = "nw-${var.env}"
  cidr_block         = var.vpc_cidr
  single_nat_gateway = var.single_nat_gateway

  # Derived from var.env like the name above; Day 5 must give the cluster exactly this name.
  cluster_name = "nw-${var.env}-eks"
}
