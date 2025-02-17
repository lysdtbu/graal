local common_json = import "../../common.json";
local labsjdk_ce = common_json.jdks["labsjdk-ce-latest"];
local labsjdk_ee = common_json.jdks["labsjdk-ee-latest"];
local galahad_jdk = common_json.jdks["galahad-jdk"];
local utils = import "common-utils.libsonnet";
{
  local GALAHAD_PROPERTY = "_galahad_include",
  # Return true if this is a gate job.
  local is_gate(b) =
    std.find("gate", b.targets) != []
  ,
  local finalize(b) = std.parseJson(std.manifestJson(b)),
  # Converts a gate job into an ondemand job.
  local convert_gate_to_ondemand(jsonnetBuildObject) =
    # We finalize (manifest json string and parse it again) the build object before
    # modifying it because modification could have side effects, e.g., if a job
    # uses the "name" property to change other properties. At the current level,
    # everything should be ready to finalize. If we mess up, we don't care too much
    # because these ondemand jobs are not really used in the galahad CI.
    local b = finalize(jsonnetBuildObject) +
      if std.objectHasAll(jsonnetBuildObject, "notify_groups") then
        {
          # notify_groups might be hidden, but is still read later on.
          # Thus, we restore it. This could be generalized to all hidden properties,
          # but it is not really necessary.
          notify_groups:: finalize(jsonnetBuildObject.notify_groups),
        }
      else
        {}
      ;
    assert is_gate(b) : "Not a gate job: " + b.name;
    b + {
      name: std.strReplace(b.name, "gate", "ondemand"),
      targets: [if t == "gate" then "ondemand" else t for t in b.targets],
    }
  ,
  # Replaces labsjdk-ce-latest and labsjdk-ee-latest with galahad-jdk
  local replace_labsjdk(b) =
    if b.downloads.JAVA_HOME == labsjdk_ce || b.downloads.JAVA_HOME == labsjdk_ee then
      b + {
        downloads+: {
          JAVA_HOME: galahad_jdk,
        }
      }
    else
      b
  ,
  # Transforms a job if it is not relevant for galahad.
  # Only gate jobs are touched.
  # Gate jobs that are not relevant for galahad are turned into ondemand jobs.
  # This is preferred over removing irrelevant jobs because it does not introduce problems
  # with respect to dependent jobs (artifacts).
  local transform_galahad_job(b) =
    if !is_gate(b) then
      b
    else
      local include = std.foldr(function(x, y) x && y, utils.std_get(b, GALAHAD_PROPERTY, [false]), true);
      assert std.type(include) == "boolean" : "Not a boolean: " + std.type(include);
      if include then
        replace_labsjdk(b)
      else
        convert_gate_to_ondemand(b)
  ,
  # Verify that a job really makes sense for galahad
  local verify_galahad_job(b) =
    if !is_gate(b) then
      # we only care about gate jobs
      b
    else
      assert utils.contains(b.name, "style") || b.downloads.JAVA_HOME.name == "jpg-jdk" : "Job %s is not using a jpg-jdk: %s" % [b.name, b.downloads];
      b
  ,
  local replace_mx(b) =
    # Use the `galahad` branch of mx to ensure that it is sufficiently up to date.
    if std.objectHas(b, "packages") then
      if std.objectHas(b.packages, "mx") then
        b + {
          packages+: {
            mx: "galahad"
          }
        }
      else
        b
    else
      b
  ,

  ####### Public API

  # Return true if this is a gate job.
  is_gate(b):: is_gate(b),
  # Converts a gate job into an ondemand job.
  convert_gate_to_ondemand(b):: convert_gate_to_ondemand(b),

  # Include a jobs in the galahad gate
  include:: {
    # There seems to be a problem with sjsonnet when merging boolean fields.
    # Working a round by using arrays.
    [GALAHAD_PROPERTY]:: [true]
  },
  # Exclude a job in the galahad gate
  exclude:: {
    [GALAHAD_PROPERTY]:: [false]
  },

  # only returns jobs that are relevant for galahad
  filter_builds(builds):: [verify_galahad_job(replace_mx(transform_galahad_job(b))) for b in builds],
}
