import { App } from "aws-cdk-lib";
import { ApiStack } from "../lib/api-stack";
import { DatabaseStack } from "../lib/database-stack";
import { FrontendStack } from "../lib/frontend-stack";
import { NetworkStack } from "../lib/network-stack";

/** スタックは 4 つに分ける。デプロイ単位 = 変更頻度の単位。 */
const app = new App();
const stage = app.node.tryGetContext("stage") ?? "dev";
const stages = app.node.tryGetContext("stages");
const { account, region, domainName, certificateArn } = stages[stage];
const appName: string = app.node.tryGetContext("appName");
const env = { account, region };
const prefix = `${appName}-${stage}`;

const network = new NetworkStack(app, `${prefix}-network`, { env });
const database = new DatabaseStack(app, `${prefix}-database`, { env, vpc: network.vpc });
const api = new ApiStack(app, `${prefix}-api`, { env, vpc: network.vpc, dbSecret: database.secret, dbCluster: database.cluster });
new FrontendStack(app, `${prefix}-frontend`, { env, apiOrigin: api.loadBalancerDnsName, domainName, certificateArn });
