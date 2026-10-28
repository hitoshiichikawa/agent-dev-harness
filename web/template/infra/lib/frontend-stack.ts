import { RemovalPolicy, Stack, type StackProps } from "aws-cdk-lib";
import * as acm from "aws-cdk-lib/aws-certificatemanager";
import * as cloudfront from "aws-cdk-lib/aws-cloudfront";
import * as origins from "aws-cdk-lib/aws-cloudfront-origins";
import * as s3 from "aws-cdk-lib/aws-s3";
import * as deploy from "aws-cdk-lib/aws-s3-deployment";
import type { Construct } from "constructs";

interface Props extends StackProps {
  apiOrigin: string;
  domainName?: string;
  certificateArn?: string;
}

/**
 * SPA を S3 + CloudFront で配信。/api/* は ALB へ、それ以外は S3 へ。
 * SPA ルーティングのため 403/404 は index.html にフォールバック。
 */
export class FrontendStack extends Stack {
  constructor(scope: Construct, id: string, props: Props) {
    super(scope, id, props);
    const bucket = new s3.Bucket(this, "Bucket", {
      blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
      removalPolicy: RemovalPolicy.RETAIN,
      enforceSSL: true,
    });

    const spaOrigin = origins.S3BucketOrigin.withOriginAccessControl(bucket);
    const apiOrigin = new origins.HttpOrigin(props.apiOrigin, { protocolPolicy: cloudfront.OriginProtocolPolicy.HTTP_ONLY });

    const dist = new cloudfront.Distribution(this, "Dist", {
      defaultRootObject: "index.html",
      defaultBehavior: {
        origin: spaOrigin,
        viewerProtocolPolicy: cloudfront.ViewerProtocolPolicy.REDIRECT_TO_HTTPS,
        cachePolicy: cloudfront.CachePolicy.CACHING_OPTIMIZED,
      },
      additionalBehaviors: {
        "/api/*": {
          origin: apiOrigin,
          viewerProtocolPolicy: cloudfront.ViewerProtocolPolicy.REDIRECT_TO_HTTPS,
          cachePolicy: cloudfront.CachePolicy.CACHING_DISABLED,
          originRequestPolicy: cloudfront.OriginRequestPolicy.ALL_VIEWER_EXCEPT_HOST_HEADER,
          allowedMethods: cloudfront.AllowedMethods.ALLOW_ALL,
        },
      },
      errorResponses: [
        { httpStatus: 403, responseHttpStatus: 200, responsePagePath: "/index.html" },
        { httpStatus: 404, responseHttpStatus: 200, responsePagePath: "/index.html" },
      ],
      domainNames: props.domainName ? [props.domainName] : undefined,
      certificate: props.certificateArn ? acm.Certificate.fromCertificateArn(this, "Cert", props.certificateArn) : undefined,
    });

    new deploy.BucketDeployment(this, "Deploy", {
      sources: [deploy.Source.asset("../frontend/dist")],
      destinationBucket: bucket,
      distribution: dist,
      distributionPaths: ["/*"],
    });
  }
}
