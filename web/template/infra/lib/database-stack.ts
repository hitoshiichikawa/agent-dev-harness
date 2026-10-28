import { Duration, RemovalPolicy, Stack, type StackProps } from "aws-cdk-lib";
import * as ec2 from "aws-cdk-lib/aws-ec2";
import * as rds from "aws-cdk-lib/aws-rds";
import type * as secretsmanager from "aws-cdk-lib/aws-secretsmanager";
import type { Construct } from "constructs";

interface Props extends StackProps {
  vpc: ec2.Vpc;
}

/** Aurora Serverless v2 (Postgres)。isolated サブネットに置き、API からのみ到達可能。 */
export class DatabaseStack extends Stack {
  readonly cluster: rds.DatabaseCluster;
  readonly secret: secretsmanager.ISecret;
  constructor(scope: Construct, id: string, props: Props) {
    super(scope, id, props);
    this.cluster = new rds.DatabaseCluster(this, "Cluster", {
      engine: rds.DatabaseClusterEngine.auroraPostgres({ version: rds.AuroraPostgresEngineVersion.VER_17_4 }),
      vpc: props.vpc,
      vpcSubnets: { subnetType: ec2.SubnetType.PRIVATE_ISOLATED },
      serverlessV2MinCapacity: 0.5,
      serverlessV2MaxCapacity: 4,
      writer: rds.ClusterInstance.serverlessV2("writer"),
      defaultDatabaseName: "app",
      backup: { retention: Duration.days(7) },
      removalPolicy: RemovalPolicy.SNAPSHOT,
      storageEncrypted: true,
    });
    if (!this.cluster.secret) throw new Error("cluster secret missing");
    this.secret = this.cluster.secret;
  }
}
