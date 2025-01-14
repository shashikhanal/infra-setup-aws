#!/bin/bash
# Comprehensive AWS Network Infrastructure Setup Guide

# Step 1: Create VPC with DNS support
echo "Creating VPC..."
VPC_ID=$(aws ec2 create-vpc \
  --cidr-block 10.0.0.0/16 \
  --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=ProdVPC},{Key=Environment,Value=Production}]' \
  --query 'Vpc.VpcId' \
  --output text)

# Enable DNS hostname support
aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-hostnames
aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-support
