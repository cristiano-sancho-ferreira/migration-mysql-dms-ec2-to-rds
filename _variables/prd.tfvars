region             = "us-east-1"
organization_name  = "beholder"
environment        = "prd"
common_tags = {
  "Name"    = "SDLF"
  "Projeto" = "AWS with Terraform"
  "Fase"    = "CICD"
}
mysql_username = "sancho"
mysql_password = "qwerty123"
vpc_id = "vpc-039ffaa0cf5d4c063"
dump_files = [
    "./scripts_dump/banco_categorias.sql",
    "./scripts_dump/banco_clientes.sql",
    "./scripts_dump/banco_locais.sql",
    "./scripts_dump/banco_lojas.sql",
    "./scripts_dump/banco_pedidos.sql",
    "./scripts_dump/banco_produtos.sql"
  ]