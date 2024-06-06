output "ip" {
    value       = aws_instance.minecraft_server[0].public_ip
    description = "The IPv4 address assigned to the server"
}