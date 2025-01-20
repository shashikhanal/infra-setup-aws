#!/bin/bash
# Setting Up Network Infrastructure For Your Web Application In AWS

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

# Step 3: Create and Attach Internet Gateway
echo "Setting up Internet Gateway..."
IGW_ID=$(aws ec2 create-internet-gateway \
  --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=ProdIGW}]' \
  --query 'InternetGateway.InternetGatewayId' \
  --output text)

aws ec2 attach-internet-gateway --vpc-id $VPC_ID --internet-gateway-id $IGW_ID

# Step 4: Set up NAT Gateway (for private subnet internet access)
echo "Setting up NAT Gateway..."
# Allocate Elastic IP for NAT Gateway
EIP_ALLOC_ID=$(aws ec2 allocate-address \
  --domain vpc \
  --query 'AllocationId' \
  --output text)

# Create NAT Gateway in first public subnet
NAT_GATEWAY_ID=$(aws ec2 create-nat-gateway \
  --subnet-id $PUBLIC_SUBNET_1 \
  --allocation-id $EIP_ALLOC_ID \
  --tag-specifications 'ResourceType=natgateway,Tags=[{Key=Name,Value=ProdNATGateway}]' \
  --query 'NatGateway.NatGatewayId' \
  --output text)

# Wait for NAT Gateway to be available
echo "Waiting for NAT Gateway to be available..."
aws ec2 wait nat-gateway-available --nat-gateway-ids $NAT_GATEWAY_ID

# Step 5: Set up Route Tables
echo "Configuring route tables..."
# Public Route Table
PUBLIC_RT_ID=$(aws ec2 create-route-table \
  --vpc-id $VPC_ID \
  --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=PublicRouteTable}]' \
  --query 'RouteTable.RouteTableId' \
  --output text)

# Add public route
aws ec2 create-route \
  --route-table-id $PUBLIC_RT_ID \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id $IGW_ID

# Associate public subnets
aws ec2 associate-route-table --subnet-id $PUBLIC_SUBNET_1 --route-table-id $PUBLIC_RT_ID
aws ec2 associate-route-table --subnet-id $PUBLIC_SUBNET_2 --route-table-id $PUBLIC_RT_ID

# Private Route Table
PRIVATE_RT_ID=$(aws ec2 create-route-table \
  --vpc-id $VPC_ID \
  --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=PrivateRouteTable}]' \
  --query 'RouteTable.RouteTableId' \
  --output text)

# Add private route through NAT Gateway
aws ec2 create-route \
  --route-table-id $PRIVATE_RT_ID \
  --destination-cidr-block 0.0.0.0/0 \
  --nat-gateway-id $NAT_GATEWAY_ID

# Associate private subnets
aws ec2 associate-route-table --subnet-id $PRIVATE_SUBNET_1 --route-table-id $PRIVATE_RT_ID
aws ec2 associate-route-table --subnet-id $PRIVATE_SUBNET_2 --route-table-id $PRIVATE_RT_ID

# Step 6: Create Security Groups
echo "Creating security groups..."
# ALB Security Group
ALB_SG_ID=$(aws ec2 create-security-group \
  --group-name ALBSecurityGroup \
  --description "Security group for Application Load Balancer" \
  --vpc-id $VPC_ID \
  --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=ALBSecurityGroup}]' \
  --query 'GroupId' \
  --output text)

# Allow HTTPS inbound to ALB
aws ec2 authorize-security-group-ingress \
  --group-id $ALB_SG_ID \
  --protocol tcp \
  --port 443 \
  --cidr 0.0.0.0/0

# EC2 Security Group
EC2_SG_ID=$(aws ec2 create-security-group \
  --group-name EC2SecurityGroup \
  --description "Security group for EC2 instances" \
  --vpc-id $VPC_ID \
  --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=EC2SecurityGroup}]' \
  --query 'GroupId' \
  --output text)

# Allow SSH from specific IP range
aws ec2 authorize-security-group-ingress \
  --group-id $EC2_SG_ID \
  --protocol tcp \
  --port 22 \
  --cidr YOUR-IP-RANGE/24  # Replace with your IP range

# Allow traffic from ALB security group
aws ec2 authorize-security-group-ingress \
  --group-id $EC2_SG_ID \
  --protocol tcp \
  --port 80 \
  --source-group $ALB_SG_ID

# Step 7: Create Application Load Balancer
echo "Creating Application Load Balancer..."
# Create Target Group first
TARGET_GROUP_ARN=$(aws elbv2 create-target-group \
  --name ProdAppTargetGroup \
  --protocol HTTP \
  --port 80 \
  --vpc-id $VPC_ID \
  --target-type instance \
  --health-check-protocol HTTP \
  --health-check-path /your-health-check-path \
  --health-check-interval-seconds 30 \
  --health-check-timeout-seconds 5 \
  --healthy-threshold-count 2 \
  --unhealthy-threshold-count 2 \
  --query 'TargetGroups[0].TargetGroupArn' \
  --output text)

# Create ALB
ALB_ARN=$(aws elbv2 create-load-balancer \
  --name ProdAppALB \
  --subnets $PUBLIC_SUBNET_1 $PUBLIC_SUBNET_2 \
  --security-groups $ALB_SG_ID \
  --scheme internet-facing \
  --type application \
  --tags Key=Name,Value=ProdAppALB \
  --query 'LoadBalancers[0].LoadBalancerArn' \
  --output text)

# Create HTTPS Listener (assumes you have an SSL certificate in ACM)
aws elbv2 create-listener \
  --load-balancer-arn $ALB_ARN \
  --protocol HTTPS \
  --port 443 \
  --certificates CertificateArn=YOUR-ACM-CERT-ARN \
  --default-actions Type=forward,TargetGroupArn=$TARGET_GROUP_ARN

# Step 8: Enable VPC Flow Logs
echo "Setting up VPC Flow Logs..."
# Create IAM role for flow logs (you need to have the proper IAM role and policy set up)
aws logs create-log-group --log-group-name ProdVPCFlowLogs

aws ec2 create-flow-logs \
  --resource-type VPC \
  --resource-id $VPC_ID \
  --traffic-type ALL \
  --log-group-name ProdVPCFlowLogs \
  --deliver-logs-permission-arn YOUR-IAM-ROLE-ARN

echo "Infrastructure setup complete!"

# Output important IDs for reference
echo "VPC ID: $VPC_ID"
echo "Public Subnet 1 ID: $PUBLIC_SUBNET_1"
echo "Public Subnet 2 ID: $PUBLIC_SUBNET_2"
echo "Private Subnet 1 ID: $PRIVATE_SUBNET_1"
echo "Private Subnet 2 ID: $PRIVATE_SUBNET_2"
echo "ALB Security Group ID: $ALB_SG_ID"
echo "EC2 Security Group ID: $EC2_SG_ID"
echo "Target Group ARN: $TARGET_GROUP_ARN"
echo "ALB ARN: $ALB_ARN"
