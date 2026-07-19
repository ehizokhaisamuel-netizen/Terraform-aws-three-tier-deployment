# This file lives at envs/dev/, two levels below the project root, so every
# module source path climbs back up with ../../ to reach modules/.

module "networking" {
  source       = "../../modules/networking"
  project_name = var.project_name
  vpc_cidr     = var.vpc_cidr
  azs          = var.availability_zones
}

module "security" {
  source       = "../../modules/security"
  project_name = var.project_name
  vpc_id       = module.networking.vpc_id
}

module "load_balancers" {
  source             = "../../modules/load_balancers"
  project_name       = var.project_name
  vpc_id             = module.networking.vpc_id
  public_subnet_ids  = module.networking.public_subnet_ids
  app_subnet_ids     = module.networking.app_private_subnet_ids
  external_alb_sg_id = module.security.external_alb_sg_id
  internal_alb_sg_id = module.security.internal_alb_sg_id
}

module "compute" {
  source                    = "../../modules/compute"
  project_name              = var.project_name
  instance_type             = var.instance_type
  key_name                  = var.key_name
  web_subnet_ids            = module.networking.web_private_subnet_ids
  app_subnet_ids            = module.networking.app_private_subnet_ids
  frontend_sg_id            = module.security.frontend_sg_id
  backend_sg_id             = module.security.backend_sg_id
  frontend_target_group_arn = module.load_balancers.frontend_target_group_arn
  backend_target_group_arn  = module.load_balancers.backend_target_group_arn
}

module "database" {
  source          = "../../modules/database"
  project_name    = var.project_name
  instance_type   = var.instance_type
  key_name        = var.key_name
  data_subnet_ids = module.networking.data_private_subnet_ids
  database_sg_id  = module.security.database_sg_id
}
