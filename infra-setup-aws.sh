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

# Step 2: Create Subnets
echo "Creating subnets..."
# Public Subnet 1
PUBLIC_SUBNET_1=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block 10.0.1.0/24 \
  --availability-zone us-east-1a \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=PublicSubnet1},{Key=Type,Value=Public}]' \
  --query 'Subnet.SubnetId' \
  --output text)

# Public Subnet 2 (for high availability)
PUBLIC_SUBNET_2=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block 10.0.2.0/24 \
  --availability-zone us-east-1b \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=PublicSubnet2},{Key=Type,Value=Public}]' \
  --query 'Subnet.SubnetId' \
  --output text)

# Private Subnet 1
PRIVATE_SUBNET_1=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block 10.0.3.0/24 \
  --availability-zone us-east-1a \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=PrivateSubnet1},{Key=Type,Value=Private}]' \
  --query 'Subnet.SubnetId' \
  --output text)

# Private Subnet 2 (for high availability)
PRIVATE_SUBNET_2=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block 10.0.4.0/24 \
  --availability-zone us-east-1b \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=PrivateSubnet2},{Key=Type,Value=Private}]' \
  --query 'Subnet.SubnetId' \
  --output text)
