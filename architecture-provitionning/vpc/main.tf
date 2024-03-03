resource "aws_vpc" "thales-vpc" {

  cidr_block           = "192.168.0.0/16"
  instance_tenancy     = "default"
  enable_dns_support   = true
  enable_dns_hostnames = true
  assign_generated_ipv6_cidr_block=false


  tags = {
    Name = "thales-vpc"
  }

}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.thales-vpc.id

  tags = {
    Name = "thales-gateway"
  }
}

resource "aws_subnet" "public_1" {
  vpc_id     = aws_vpc.thales-vpc.id
  cidr_block = "192.168.0.0/18"
  availability_zone = "eu-west-3a"
  map_public_ip_on_launch=true
  tags = {
    Name = "public-eu-paris-3a"
    "kubernetes.io/cluster/eks_cluster_role"="shared"
    "kubernetes.io/role/elb"=1
  }
}

resource "aws_subnet" "public_2" {
  vpc_id     = aws_vpc.thales-vpc.id
  cidr_block = "192.168.64.0/18"
  availability_zone = "eu-west-3b"
  map_public_ip_on_launch=true
  tags = {
    Name = "public-eu-paris-3b"
    "kubernetes.io/cluster/eks_cluster_role"="shared"
    "kubernetes.io/role/elb"=1
  }
}

resource "aws_subnet" "private_1" {
  vpc_id     = aws_vpc.thales-vpc.id
  cidr_block = "192.168.128.0/18"
  availability_zone = "eu-west-3a"

  tags = {
    Name = "public-eu-paris-3a"
    "kubernetes.io/cluster/eks_cluster_role"="shared"
    "kubernetes.io/role/elb"=1
  }
}
resource "aws_subnet" "private_2" {
  vpc_id     = aws_vpc.thales-vpc.id
  cidr_block = "192.168.192.0/18"
  availability_zone = "eu-west-3b"
  tags = {
    Name = "public-eu-paris-3b"
    "kubernetes.io/cluster/eks_cluster_role`"="shared"
    "kubernetes.io/role/elb"=1
  }
}


resource "aws_eip" "nat1" {
  depends_on = [ aws_internet_gateway.gw ]
  # instance = aws_instance.web.id
  
}

resource "aws_eip" "nat2" {
  depends_on = [ aws_internet_gateway.gw ]
  # instance = aws_instance.web.id
  
}
resource "aws_nat_gateway" "gw1" {
  allocation_id = aws_eip.nat1.id
  subnet_id     = aws_subnet.public_1.id

  tags = {
    Name = "gw NAT 1"
  }
}

resource "aws_nat_gateway" "gw2" {
  allocation_id = aws_eip.nat2.id
  subnet_id     = aws_subnet.public_2.id

  tags = {
    Name = "gw NAT 2"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.thales-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "public"
  }
}


resource "aws_route_table" "private_1" {
  vpc_id = aws_vpc.thales-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.gw1.id
  }

  tags = {
    Name = "private1"
  }
}

resource "aws_route_table" "private_2" {
  vpc_id = aws_vpc.thales-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.gw2.id
  }


  tags = {
    Name = "private2"
  }
}


# route table association

resource "aws_route_table_association" "public1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}
resource "aws_route_table_association" "public2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}
resource "aws_route_table_association" "private1" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private_1.id
}
resource "aws_route_table_association" "private2" {
  subnet_id      = aws_subnet.private_2.id
  route_table_id = aws_route_table.private_2.id
}


# iam role for the eks cluster 
resource "aws_iam_role" "eks_cluster_role" {
name = "eks-cluster-role-thales"
assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}


# attach policies to this aim role 
resource "aws_iam_role_policy_attachment" "role_policy_attach_thales" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}




#create aws eks cluster 
resource "aws_eks_cluster" "thales_eks_cluster" {
  name     = "thatles-cluster"
  role_arn = aws_iam_role.eks_cluster_role.arn




  vpc_config {

    endpoint_private_access=false

    endpoint_public_access =true

    subnet_ids = [
      aws_subnet.private_1.id,
      aws_subnet.private_2.id,
      aws_subnet.public_1.id,
      aws_subnet.public_2.id
    ]
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Cluster handling.
  # Otherwise, EKS will not be able to properly delete EKS managed EC2 infrastructure such as Security Groups.
  depends_on = [
    aws_iam_role_policy_attachment.role_policy_attach_thales
    
  ]
}




# create eks node groups 

#---------------------

# iam role for the eks cluster node groups
resource "aws_iam_role" "eks_cluster_node_group_role" {
name = "eks-cluster-role-node-group-thales"
assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

# IAM policy attachment to nodegroup

resource "aws_iam_role_policy_attachment" "nodes-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_cluster_node_group_role.name
}

resource "aws_iam_role_policy_attachment" "nodes-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_cluster_node_group_role.name
}

resource "aws_iam_role_policy_attachment" "nodes-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_cluster_node_group_role.name
}




# aws node group 

resource "aws_eks_node_group" "node-group-nodes-thales" {
  cluster_name    = aws_eks_cluster.thales_eks_cluster.name
  node_group_name = "private-thales-nodes"
  node_role_arn   = aws_iam_role.eks_cluster_node_group_role.arn

  subnet_ids = [
    aws_subnet.private_1.id,
    aws_subnet.private_2.id,
  ]

  capacity_type  = "ON_DEMAND"
  disk_size = 15
  
  instance_types = ["t2.small"]

  scaling_config {
    desired_size = 1
    max_size     = 2
    min_size     = 1
  }

  update_config {
    max_unavailable = 1
  }

  labels = {
    node = "kubenode02"
  }

  # taint {
  #   key    = "team"
  #   value  = "devops"
  #   effect = "NO_SCHEDULE"
  # }

  # launch_template {
  #   name    = aws_launch_template.eks-with-disks.name
  #   version = aws_launch_template.eks-with-disks.latest_version
  # }

  depends_on = [
    aws_iam_role_policy_attachment.nodes-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.nodes-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.nodes-AmazonEC2ContainerRegistryReadOnly,
  ]
}
