#!/usr/bin/env bash

export RESOURCEGROUP_NAME=spring-on-wildfly-performance-tests
export WEBAPP_NAME=spring-on-wildfly
export WEBAPP_PLAN_NAME=${WEBAPP_NAME}-appservice-plan
export WEBAPP_PRICING_TIER=P3V2
export REGION=westus
export WEBAPP_RUNTIME="wildfly 14-jre8"