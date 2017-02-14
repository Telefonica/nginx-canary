local config = require("/etc/nginx/lua/config")
local versions = require("/etc/nginx/lua/versions")

local module = {}

-- Normalize the probability of partitions to 1
function normalize_partitions(partitions)
  local total_probability = 0
  for deployment_group, probability in pairs(partitions) do
    total_probability = total_probability + probability
  end
  local normalized_partitions = {}
  for deployment_group, probability in pairs(partitions) do
    normalized_partitions[deployment_group] = probability / total_probability
  end
  return normalized_partitions
end

-- Change the versions table to index it by version and the normalized partitions for that version
function normalize_versions(versions, partitions)
  local normalized_versions = {}
  for deployment_group, version in pairs(versions) do
    if not normalized_versions[version] then
      normalized_versions[version] = {}
    end
    local normalized_version = normalized_versions[version]
    normalized_version[deployment_group] = partitions[deployment_group]
  end
  for version, version_partitions in pairs(normalized_versions) do
    normalized_versions[version] = normalize_partitions(version_partitions)
  end
  return normalized_versions
end

-- Normalize the partitions and versions
local normalized_partitions = normalize_partitions(config["partitions"])
local normalized_versions = normalize_versions(versions, config["partitions"])

-- Get a deployment group from value [0, 1) using the normalized partitions
-- (distribution of the deployment groups)
function get_deployment_group_from_value_and_partitions(value, partitions)
  local upper_bound = 0
  local last_deployment_group = nil
  for deployment_group, probability in pairs(partitions) do
    upper_bound = upper_bound + probability
    if value < upper_bound then
      return deployment_group
    end
    last_deployment_group = deployment_group
  end
  return last_deployment_group
end

-- Check if a deployment group is valid
function module.is_valid_deployment_group(deployment_group)
  if normalized_partitions[deployment_group] then
    return true
  else
    return false
  end
end

-- Get the version assigned to a deployment group
function module.get_version_from_deployment_group(deployment_group)
  if not deployment_group then
    return nil
  end
  return versions[deployment_group]
end

-- Get a deployment group with a deployment version
function module.get_deployment_group_from_version(version)
  version_partitions = normalized_versions[version]
  if not version_partitions then
    return nil
  end
  value = math.random()
  return get_deployment_group_from_value_and_partitions(value, version_partitions)
end

-- Get a deployment group with a value [0, 1)
function module.get_deployment_group_from_value(value)
  return get_deployment_group_from_value_and_partitions(value, normalized_partitions)
end

return module
