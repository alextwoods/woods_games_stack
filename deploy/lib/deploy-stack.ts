import * as cdk from '@aws-cdk/core';
import * as ec2 from "@aws-cdk/aws-ec2";
import * as ecs from "@aws-cdk/aws-ecs";
import * as iam from "@aws-cdk/aws-iam";

import * as ecs_patterns from "@aws-cdk/aws-ecs-patterns";
import * as ddb from "@aws-cdk/aws-dynamodb";
import { DockerImageAsset } from '@aws-cdk/aws-ecr-assets';

export class WoodsGamesStack extends cdk.Stack {
  constructor(scope: cdk.Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    const vpc = new ec2.Vpc(this, "vpc", {
      maxAzs: 3 // Default is all AZs in region
    });

    const cluster = new ecs.Cluster(this, "cluster", {
      vpc: vpc
    });

    const railsImage = new DockerImageAsset(this, 'railsImage', {
      directory: '../woods_games'
    });

    // Create a load-balanced Fargate service and make it public
    const service = new ecs_patterns.ApplicationLoadBalancedFargateService(this, "rails", {
      cluster: cluster, // Required
      cpu: 512, // Default is 256
      desiredCount: 1, // Default is 1
      taskImageOptions: { image: ecs.ContainerImage.fromDockerImageAsset(railsImage) },
      memoryLimitMiB: 2048, // Default is 512
      publicLoadBalancer: true, // Default is false
      loadBalancerName: 'woods-games',
      serviceName: 'woods-games'
    });

    const roomsTable = ddb.Table.fromTableName(this, 'roomsTable', 'woods-games-rooms');
    const ziddlerTable = ddb.Table.fromTableName(this, 'ziddlerTable', 'woods-games-ziddler');
    const chainTable = ddb.Table.fromTableName(this, 'chainTable', 'woods-games-chain');
    const wordListTable = ddb.Table.fromTableName(this, 'wordListTable', 'woods-games-wordlist'); 
    const dictTable = ddb.Table.fromTableName(this, 'dictTable', 'woods-games-dictionary'); 
    const storiesTable = ddb.Table.fromTableName(this, 'storiesTable', 'woods-games-stories'); 

    roomsTable.grantReadWriteData(service.service.taskDefinition.taskRole);
    ziddlerTable.grantReadWriteData(service.service.taskDefinition.taskRole);
    chainTable.grantReadWriteData(service.service.taskDefinition.taskRole);
    wordListTable.grantReadWriteData(service.service.taskDefinition.taskRole);
    dictTable.grantReadWriteData(service.service.taskDefinition.taskRole);
    storiesTable.grantReadWriteData(service.service.taskDefinition.taskRole);


    // grant permissions to query all indexes
    service.service.taskDefinition.taskRole.addToPrincipalPolicy(
      new iam.PolicyStatement({
        actions: ['dynamodb:Query'],
        resources: [`${ziddlerTable.tableArn}/index/*`],
      }),
    );

    chainTable.grantReadWriteData(service.service.taskDefinition.taskRole);
    service.service.taskDefinition.taskRole.addToPrincipalPolicy(
      new iam.PolicyStatement({
        actions: ['dynamodb:Query'],
        resources: [`${chainTable.tableArn}/index/*`],
      }),
    );

    storiesTable.grantReadWriteData(service.service.taskDefinition.taskRole);
    service.service.taskDefinition.taskRole.addToPrincipalPolicy(
      new iam.PolicyStatement({
        actions: ['dynamodb:Query'],
        resources: [`${storiesTable.tableArn}/index/*`],
      }),
    );
  }
}
