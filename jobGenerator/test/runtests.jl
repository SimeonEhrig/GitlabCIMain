using jobGenerator
using Test

import Term.Trees: Tree

# set environment variable PRINTTREE=on to visualize the project trees of the testsets
printTree::Bool = haskey(ENV, "PRINTTREE")

@testset "direct dependency to main" begin
    project_tree = Dict("MyMainProject.jl 1.0.0" =>
        Dict("MyDep1.jl 1.0.0" => Dict())
    )

    if printTree
        print(Tree(project_tree; name="direct dependency to main"))
    end

    # dependency exist and prefix is correct   
    @test jobGenerator.get_depending_projects("MyDep1.jl", "My", project_tree) == ["MyMainProject.jl"]
    # dependency does not exist and prefix is correct   
    @test isempty(jobGenerator.get_depending_projects("MyDep2.jl", "My", project_tree))
    # dependency exist and prefix is incorrect
    @test isempty(jobGenerator.get_depending_projects("MyDep1.jl", "Extern", project_tree))
    # dependency does not exist and prefix is incorrect   
    @test isempty(jobGenerator.get_depending_projects("MyDep2.jl", "Extern", project_tree))
end


@testset "complex dependencies" begin
    #! format: off
    project_tree = Dict("MyMainProject.jl 1.0.0" =>
                        Dict("MyDep1.jl 1.0.0"      => Dict(),
                             "MyDep2.jl 1.0.0"      => Dict("MyDep3.jl 1.0.0" => Dict(), 
                                                            "ForeignDep1.jl 1.0.0" => Dict()),
                             "ForeignDep2.jl 1.0.0" => Dict("ForeignDep3.jl 1.0.0" => Dict(),  
                                                            "ForeignDep4.jl 1.0.0" => Dict()),
                             "MyDep4.jl 1.0.0"      => Dict("MyDep5.jl 1.0.0" => Dict("MyDep3.jl 1.0.0" => Dict())),
                             "ForeignDep2.jl 1.0.0" => Dict("MyDep5.jl 1.0.0" => Dict("MyDep3.jl 1.0.0" => Dict()),  
                                                            "MyDep3.jl 1.0.0" => Dict(),
                                                            "MyDep6.jl 1.0.0" => Dict("MyDep3.jl 1.0.0" => Dict())),
                             "MyDep7.jl 1.0.0"      => Dict("MyDep5.jl 1.0.0" => Dict("MyDep3.jl 1.0.0" => Dict()),  
                                                            "MyDep3.jl 1.0.0" => Dict()),
                            )
                        )
    #! format: on
    if printTree
        print(Tree(project_tree; name="complex dependencies"))
    end

    # sort all vectors to guaranty the same order -> guaranty is not important for the actual result, onyl for comparison
    @test sort(jobGenerator.get_depending_projects("MyDep1.jl", "My", project_tree)) == sort(["MyMainProject.jl"])
    @test sort(jobGenerator.get_depending_projects("MyDep2.jl", "My", project_tree)) == sort(["MyMainProject.jl"])
    # MyDep5.jl should only appears one time -> MyDep4.jl and MyDep7.jl has the same MyDep5.jl dependency
    @test sort(jobGenerator.get_depending_projects("MyDep3.jl", "My", project_tree)) == sort(["MyDep2.jl", "MyDep5.jl", "MyDep7.jl"])
    @test sort(jobGenerator.get_depending_projects("MyDep5.jl", "My", project_tree)) == sort(["MyDep4.jl", "MyDep7.jl"])
    # cannot find MyDep6.jl, because it is only a dependency of a foreign package
    @test isempty(jobGenerator.get_depending_projects("MyDep6.jl", "My", project_tree))
    @test isempty(jobGenerator.get_depending_projects("MyDep3.jl", "Foo", project_tree))
end

@testset "circular dependency" begin
    # I cannot create a real circular dependency with this data structur, but if Circulation appears in an output, we passed MyDep1.jl and MyDep2.jl two times, which means it is a circle
    project_tree = Dict("MyMainProject.jl 1.0.0" => Dict("MyDep1.jl 1.0.0" => Dict("MyDep2.jl 1.0.0" => Dict("MyDep1.jl 1.0.0" => Dict("MyDep2.jl 1.0.0" => Dict("Circulation" => Dict()))))))

    if printTree
        print(Tree(project_tree; name="circular dependencies"))
    end

    @test sort(jobGenerator.get_depending_projects("MyDep1.jl", "My", project_tree)) == sort(["MyMainProject.jl", "MyDep2.jl"])
    @test sort(jobGenerator.get_depending_projects("MyDep2.jl", "My", project_tree)) == sort(["MyDep1.jl"])
    @test isempty(jobGenerator.get_depending_projects("MyDep2.jl", "Foo", project_tree))
    @test isempty(jobGenerator.get_depending_projects("Circulation", "My", project_tree))
end
