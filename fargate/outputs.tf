output "ecs_task_sg_id" {
  value = aws_security_group.ecs_tasks_sg.id
}
output "alb_dns" {
  value = aws_lb.lb.dns_name
}
