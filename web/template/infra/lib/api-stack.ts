import { Duration, Stack, type StackProps } from "aws-cdk-lib";
import * as ec2 from "aws-cdk-lib/aws-ec2";
import * as ecs from "aws-cdk-lib/aws-ecs";
import * as ecsPatterns from "aws-cdk-lib/aws-ecs-patterns";
import type * as rds from "aws-cdk-lib/aws-rds";
import type * as secretsmanager from "aws-cdk-lib/aws-secretsmanager";
import * as ssm from "aws-cdk-lib/aws-ssm";
import type { Construct } from "constructs";

interface Props extends StackProps {
  vpc: ec2.Vpc;
  dbSecret: secretsmanager.ISecret;
  dbCluster: rds.DatabaseCluster;
}

/** Go API を ECS Fargate で。イメージは api/Dockerfile からビルド。 */
export class ApiStack extends Stack {
  readonly loadBalancerDnsName: string;
  constructor(scope: Construct, id: string, props: Props) {
    super(scope, id, props);
    const cluster = new ecs.Cluster(this, "Cluster", { vpc: props.vpc, containerInsightsV2: ecs.ContainerInsights.ENABLED });

    const service = new ecsPatterns.ApplicationLoadBalancedFargateService(this, "Service", {
      cluster,
      cpu: 256,
      memoryLimitMiB: 512,
      desiredCount: 1,
      publicLoadBalancer: true,
      taskImageOptions: {
        image: ecs.ContainerImage.fromAsset("../api"),
        containerPort: 8080,
        environment: { APP_ENV: "prod", APP_PORT: "8080" },
        secrets: {
          DB_HOST: ecs.Secret.fromSecretsManager(props.dbSecret, "host"),
          DB_USER: ecs.Secret.fromSecretsManager(props.dbSecret, "username"),
          DB_PASSWORD: ecs.Secret.fromSecretsManager(props.dbSecret, "password"),
          AUTH_SIGNING_KEY: ecs.Secret.fromSsmParameter(
            ssm.StringParameter.fromSecureStringParameterAttributes(this, "SigningKey", { parameterName: "/app/auth/signing-key" }),
          ),
        },
      },
      healthCheckGracePeriod: Duration.seconds(30),
    });
    service.targetGroup.configureHealthCheck({ path: "/healthz" });
    props.dbCluster.connections.allowDefaultPortFrom(service.service, "api → aurora");
    service.service.autoScaleTaskCount({ minCapacity: 1, maxCapacity: 4 }).scaleOnCpuUtilization("Cpu", { targetUtilizationPercent: 60 });

    this.loadBalancerDnsName = service.loadBalancer.loadBalancerDnsName;
  }
}
