output "bastion_ip" {
  value = aws_instance.bastion.public_ip
}
output "bastion_id" {
  value = aws_instance.bastion.id
}
output "private_bastion_ip" {
  value = aws_instance.private_bastion.private_ip
}
output "private_bastion_id" {
  value = aws_instance.private_bastion.id
}
output bastion_sg {
  value = aws_security_group.bastion_sg.id
}
