resource "aws_efs_file_system" "efs" {
  tags = {
    Name = "efs"
  }
}

resource "aws_efs_mount_target" "mount_target" {
  count           = length(data.terraform_remote_state.network.outputs.subnet_private_efs)
  file_system_id  = aws_efs_file_system.efs.id
  subnet_id       = data.terraform_remote_state.network.outputs.subnet_private_efs[count.index]
  security_groups = [data.terraform_remote_state.network.outputs.aws_security_group_efs_id]
}
