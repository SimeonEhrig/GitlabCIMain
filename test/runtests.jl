using GitlabCIMain
using Test

@testset "GitlabCIMain.jl" begin
    for (radius, height, area, volume) in [(4, 7, 276.46, 351.858), (3, 4, 131.947, 113.097), (5, 6, 345.575, 471.239)]
        @test isapprox(GitlabCIMain.get_cylinder_area(radius, height), area; atol=1.0)
        @test isapprox(GitlabCIMain.get_cylinder_volume(radius, height), volume; atol=1.0)
    end
end
