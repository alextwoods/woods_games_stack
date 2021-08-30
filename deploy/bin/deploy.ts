#!/usr/bin/env node
import 'source-map-support/register';
import * as cdk from '@aws-cdk/core';
import { WoodsGamesStack } from '../lib/deploy-stack';

const app = new cdk.App();
new WoodsGamesStack(app, 'WoodsGamesStack');
