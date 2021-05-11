module "ecr" {
  source  = "genstackio/ecr/aws"
  version = "0.1.0"
  env     = var.env
  name    = local.name
}

module "codebuild-project-publish-front" {
  source         = "genstackio/codebuild/aws"
  version        = "0.1.0"
  env            = var.env
  name           = local.name
  image          = module.ecr.image_latest
  buildspec_file = "${path.module}/buildspec.yml"
  build_timeout  = var.build_timeout
  variables      = {
    env                                  = var.env
    "AWS_CLOUDFRONT_DISTRIBUTION_ID_${upper(var.name)}" = var.cloudfront_id
  }
}

module "codepipeline-publish-front" {
  source  = "genstackio/codepipeline/aws"
  version = "0.1.0"
  env     = var.env
  name    = local.name
  stages  = [
    {name = "Source", type = "Source", provider = "ECR", inputs = [], outputs = ["SourceArtifact"], config = {ImageTag = "latest", RepositoryName = module.ecr.name}},
    {name = "Publish", type = "Build", provider = "CodeBuild", inputs = ["SourceArtifact"], outputs = [], config = {ProjectName = module.codebuild-project-publish-front.name}},
  ]
  policy_statements = [
    {actions = ["ecr:DescribeImages"], resources = [module.ecr.arn], effect = "Allow"}
  ]
}

module "codepipeline-publish-front-artifacts-policy-for-codebuild-project-publish-front" {
  source          = "genstackio/codepipeline/aws//modules/artifacts-policy"
  version         = "0.1.0"
  role_name       = module.codebuild-project-publish-front.role_name
  pipeline_bucket = module.codepipeline-publish-front.artifacts_bucket_arn
}

module "codepipeline-publish-front-ecr-trigger" {
  source        = "genstackio/codepipeline/aws//modules/trigger-ecr"
  version       = "0.1.0"
  ecr_name      = module.ecr.name
  ecr_tag       = "latest"
  pipeline_arn  = module.codepipeline-publish-front.arn
  pipeline_name = module.codepipeline-publish-front.name
}
