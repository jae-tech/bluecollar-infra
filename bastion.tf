# Bastion service removed — prod instance SSH port (22) is open to internet.
# Access DB via prod as jump host:
#   ssh -J ubuntu@<prod_public_ip> ubuntu@<db_private_ip>
