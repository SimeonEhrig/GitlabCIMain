module jobGenerator

import Pkg
import PkgDependency
import YAML

"""
    create_working_env(project_path::AbstractString)

Create an temporary folder, setup a new Project.toml and activate it. Checking the dependencies of
an project only works, if it is a dependency of the jobGenerator.jl. Because the package to analyze
is only a temporary dependency, it should not change permanent the Project.toml of the 
jobGenerator.jl. Therefore, the script generates a temporary Julia environment and adds the package
to analyze as dependency.

# Args
    `project_path::AbstractString`: Absolute path to the project folder of the package to analyse
"""
function create_working_env(project_path::AbstractString)
    tmp_path = mktempdir()
    Pkg.activate(tmp_path)
    # same dependency like in the Project.toml of jobGenerator.jl 
    Pkg.add("Pkg")
    Pkg.add("PkgDependency")
    Pkg.add("YAML")
    # add main project as dependency
    Pkg.develop(path=project_path)
end

"""
Contains all information about a package.

# Fields
- `url`: Git url of the original project.
- `modified_url`: Stores the Git url set by the environment variable.
- `env_var`: Name of the environment variable to set the modified_url. 
"""
mutable struct PackageInfo
    url::String
    modified_url::String
    env_var::String
    PackageInfo(url, env_var) = new(url, "", env_var)
end

package_infos = Dict(
    "GitlabCIMain" => PackageInfo(
        "https://github.com/SimeonEhrig/GitlabCIMain.git",
        "CI_INTG_PKG_URL_GITLABMAINJL"),
    "GitLabCISub1" => PackageInfo(
        "https://github.com/SimeonEhrig/GitLabCISub1.git",
        "CI_INTG_PKG_URL_GITLABCISUB1JL"),
    "GitLabCISub2" => PackageInfo(
        "https://github.com/SimeonEhrig/GitLabCISub2.git",
        "CI_INTG_PKG_URL_GITLABCISUB2JL"),
    "MonteCarloPI" => PackageInfo(
        "https://github.com/SimeonEhrig/GitLabCIPI.jl.git",
        "CI_INTG_PKG_URL_GitLabCIPIJL"),
)

"""
    extract_env_vars_from_git_message!()

Parse the commit message, if set via variable `CI_COMMIT_MESSAGE` and set custom urls.
"""
function extract_env_vars_from_git_message!()
    if haskey(ENV, "CI_COMMIT_MESSAGE")
        for line in split(ENV["CI_COMMIT_MESSAGE"], "\n")
            line = strip(line)
            for pkg_info in values(package_infos)
                if startswith(line, pkg_info.env_var * ": ")
                    ENV[pkg_info.env_var] = SubString(line, length(pkg_info.env_var * ": ") + 1)
                end
            end
        end
    end
end

"""
    set_modified_package_url!()

Iterate over all entries of package_info. If an environment variable exits with the same name like,
the `env_var` entry, set the value of the environment variable to `custom_url`. 
"""
function set_modified_package_url!()
    for package_info in values(package_infos)
        if haskey(ENV, package_info.env_var)
            package_info.modified_url = ENV[package_info.env_var]
        end
    end
end

"""
    get_modified_package()::String

Read the name of the modified (project) package from the environment variable `CI_DEPENDENCY_NAME`.

# Returns
- The name of the modified (project) package
"""
function get_modified_package()::String
    for env_var in ["CI_DEPENDENCY_NAME", "CI_PROJECT_DIR"]
        if !haskey(ENV, env_var)
            @error "Environment variable $env_var is not set."
            exit(1)
        end
    end

    if !haskey(package_infos, ENV["CI_DEPENDENCY_NAME"])
        package_name = ENV["CI_DEPENDENCY_NAME"]
        @error "Error unknown package name $package_name}"
        exit(1)
    else
        return ENV["CI_DEPENDENCY_NAME"]
    end
end

"""
    get_depending_projects(package_name, package_prefix, project_tree)

Returns of a list of packages, which has the package `package_name` as dependency. Ignore all packages, which does not start with `package_prefix`.

# Arguments
- `package_name::String`: Name of the dependency
- `package_prefix::Union{AbstractString,Regex}`: If package name does not start with the prefix, do not check if had the dependency.
- `project_tree=PkgDependency.builddict(Pkg.project().uuid, Pkg.project())`: Project tree, where to search the dependend packages. Needs to be a nested dict. 
                                                                             Each (sub-)project needs to be AbstractDict{String, AbstractDict}

# Returns
- `::AbstractVector{String}`: all packages, which have the search dependency

"""
function get_depending_projects(package_name::String, package_prefix::Union{AbstractString,Regex}, project_tree=PkgDependency.builddict(Pkg.project().uuid, Pkg.project()))::AbstractVector{String}
    packages::AbstractVector{String} = []
    visited_packages::AbstractVector{String} = []
    traverse_tree!(package_name, package_prefix, project_tree, packages, visited_packages)
    return packages
end

"""
    traverse_tree!(package_name::String, package_prefix::Union{AbstractString,Regex}, project_tree, packages::AbstractVector{String}, visited_packages::AbstractVector{String})

Traverse a project tree and add package to `packages`, which has the package `package_name` as dependency. Ignore all packages, which does not start with `package_prefix`.
See [`get_depending_projects`](@ref)

"""
function traverse_tree!(package_name::String, package_prefix::Union{AbstractString,Regex}, project_tree, packages::AbstractVector{String}, visited_packages::AbstractVector{String})
    for project_name_version in keys(project_tree)
        # remove project version from string -> usual shape: `packageName.jl version`
        project_name = split(project_name_version)[1]
        # fullfil the requirements
        # - package starts with the prefix
        # - has dependency
        # - was not already checked
        if startswith(project_name, package_prefix) && !isempty(project_tree[project_name_version]) && !(project_name in visited_packages)
            # only investigate each package one time
            # assumption: package name with it's dependency is unique
            push!(visited_packages, project_name)
            for dependency_name_version in keys(project_tree[project_name_version])
                # dependency matches, add to packages
                if startswith(dependency_name_version, package_name)
                    push!(packages, project_name)
                    break
                end
            end
            # independent of a match, under investigate all dependencies too, because they can also have the package as dependency 
            traverse_tree!(package_name, package_prefix, project_tree[project_name_version], packages, visited_packages)
        end
    end
end

"""
    generate_job_yaml!(package_name::String, job_yaml::Dict)

Generate GitLab CI job yaml for integration test of a give package.

# Args
- `package_name::String`: Name of the package to test.
- `job_yaml::Dict`: Add generated job to this dict. 
"""
function generate_job_yaml!(package_name::String, job_yaml::Dict)
    package_info = package_infos[package_name]
    # if modified_url is empty, use original url
    if package_info.modified_url == ""
        url = package_info.url
    else
        url = package_info.modified_url
    end

    script = [
        "apt update",
        "apt install -y git",
        "cd /"
    ]


    split_url = split(url, "#")
    if length(split_url) > 2
        @error "Ill formed url: $(url)"
        exit(1)
    end

    push!(script, "git clone $(split_url[1]) integration_test")
    push!(script, "cd integration_test")
    
    if length(split_url) == 2
        push!(script, "git checkout $(split_url[2])")
    end

    push!(script, "julia --project=@. -e 'import Pkg; Pkg.Registry.add(Pkg.RegistrySpec(url=\"https://github.com/SimeonEhrig/GitLabCIRegistry.git\"));'")
    ci_project_dir = ENV["CI_PROJECT_DIR"]
    push!(script, "julia --project=@. -e 'import Pkg; Pkg.develop(path=\"$ci_project_dir\");'")
    push!(script, "julia --project=@. -e 'import Pkg; Pkg.test(; coverage = true)'")

    job_yaml["IntegrationTest$package_name"] = Dict(
        "image" => "julia:1.8",
        "interruptible" => true,
        "script" => script)
end

"""
    generate_dummy_job_yaml!(job_yaml::Dict)

Generates a GitLab CI dummy job, if required.

# Args
- `job_yaml::Dict`: Add generated job to this dict.
"""
function generate_dummy_job_yaml!(job_yaml::Dict)
    job_yaml["DummyJob"] = Dict("image" => "alpine:latest",
        "interruptible" => true,
        "script" => ["echo \"This is a dummy job so that the CI does not fail.\""])
end

if abspath(PROGRAM_FILE) == @__FILE__
    extract_env_vars_from_git_message!()
    set_modified_package_url!()
    modified_package = get_modified_package()

    create_working_env(abspath(joinpath((@__DIR__), "../..")))
    depending_projects = get_depending_projects(modified_package, r"(Gitlab|GitLab)")

    job_yaml = Dict()

    if !isempty(depending_projects)
        for p in depending_projects
            generate_job_yaml!(p, job_yaml)
        end
    else
        generate_dummy_job_yaml!(job_yaml)
    end
    println(YAML.write(job_yaml))
end

end # module jobGenerator
