output "vpc_id" {
  description = "The ID of the VPC"
  value       = concat(aws_vpc.this.*.id, [""])[0]
}

output "public_subnet_ids" {
  description = "The id of the public frontend subnet"
  value       = aws_subnet.public.*.id
}

output "frontend_subnet_ids" {
  description = "The id of the private frontend subnet"
  value       = aws_subnet.frontend.*.id
}

output "app_subnet_ids" {
  description = "The id of the app subnet"
  value       = aws_subnet.app.*.id
}

output "db_subnet_ids" {
  description = "The id of the database subnet"
  value       = aws_subnet.db.*.id
}

output "internal_subnet_ids" {
  description = "The id of the internal subnet"
  value       = aws_subnet.internal.*.id
}

output "ecs_subnet_ids" {
  description = "The id of the ECS subnet"
  value       = aws_subnet.ecs.*.id
}

output "eks_subnet_ids" {
  description = "The id of the EKS subnet"
  value       = aws_subnet.eks.*.id
}

output "ocp3_subnet_ids" {
  description = "The id of the OCP3 subnet"
  value       = aws_subnet.ocp3.*.id
}
