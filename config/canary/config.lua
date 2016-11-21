local config = {}
config["domain"] = "localhost"
config["cookies"] = true
config["policy"] = "random"
config["routing_header"] = "Deployment-Group"
config["routing_query_param"] = "deployment_group"
config["partitions"] = {}
return config
