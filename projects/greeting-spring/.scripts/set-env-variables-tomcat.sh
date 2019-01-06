#!/usr/bin/env bash

export RESOURCEGROUP_NAME=tomcat-performance-tests
export WEBAPP_NAME=spring-on-tomcat
export WEBAPP_PLAN_NAME=${WEBAPP_NAME}-appservice-plan
export WEBAPP_PRICING_TIER=P3V2
export REGION=westus
export WEBAPP_RUNTIME="tomcat 9.0-jre8"