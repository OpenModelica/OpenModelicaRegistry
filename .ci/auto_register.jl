#=
Auto-registration driver. Run from the registry repository root:

    julia .ci/auto_register.jl

For each package listed in .ci/packages.toml:
  1. Shallow-clone the configured branch into a temp dir.
  2. Read the working copy's Project.toml version.
  3. Compare against the highest version already in <L>/<name>/Versions.toml.
  4. If the working copy is newer, call LocalRegistry.register(...; push=false)
     so a single commit lands in the registry working tree. The workflow does
     the actual git push.

Packages whose cloned Project.toml still contains a [sources] block are
skipped with a warning. This script is the wrong tool for those.
=#

using Pkg
using TOML

const REGISTRY_PATH = pwd()
const CONFIG_PATH = joinpath(REGISTRY_PATH, ".ci", "packages.toml")

Pkg.add("LocalRegistry")
using LocalRegistry

function latest_registered(regdir::AbstractString, name::AbstractString)
    L = uppercase(string(name[1]))
    vfile = joinpath(regdir, L, name, "Versions.toml")
    isfile(vfile) || return nothing
    parsed = TOML.parsefile(vfile)
    isempty(parsed) && return nothing
    return maximum(VersionNumber.(keys(parsed)))
end

function clone_at(repo::AbstractString, branch::AbstractString)
    dir = mktempdir(; prefix = "regsync_")
    run(`git clone --depth 1 --branch $branch $repo $dir`)
    return dir
end

function process(pkg)
    name   = pkg["name"]
    repo   = pkg["repo"]
    branch = get(pkg, "branch", "master")
    println("[check] $name @ $branch ($repo)")

    clonedir = clone_at(repo, branch)
    proj = TOML.parsefile(joinpath(clonedir, "Project.toml"))

    if haskey(proj, "sources")
        @warn "Skipping $name: cloned Project.toml has a [sources] block"
        return
    end

    wcver = VersionNumber(proj["version"])
    regver = latest_registered(REGISTRY_PATH, name)

    if regver !== nothing && wcver <= regver
        println("[skip]  $name v$wcver already covered (registered: v$regver)")
        return
    end

    println("[register] $name v$wcver (previous: $(regver === nothing ? "none" : "v$regver"))")
    register(clonedir; registry = REGISTRY_PATH, push = false)
end

function main()
    cfg = TOML.parsefile(CONFIG_PATH)
    packages = get(cfg, "package", Any[])
    isempty(packages) && (println("No packages configured."); return)
    for pkg in packages
        try
            process(pkg)
        catch err
            @error "Failed to process $(get(pkg, "name", "?"))" exception = (err, catch_backtrace())
        end
    end
end

main()
