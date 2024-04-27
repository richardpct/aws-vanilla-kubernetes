resource "aws_efs_file_system" "efs" {
  tags = {
    Name = "efs"
  }
}

resource "aws_efs_mount_target" "mount_target" {
  count           = length(data.terraform_remote_state.network.outputs.subnet_private)
  file_system_id  = aws_efs_file_system.efs.id
  subnet_id       = data.terraform_remote_state.network.outputs.subnet_private[count.index]
  security_groups = [aws_security_group.efs.id]
}
