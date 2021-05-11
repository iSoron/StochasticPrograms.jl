using Test
using Distributed
include(joinpath(Sys.BINDIR, "..", "share", "julia", "test", "testenv.jl"))

if Sys.iswindows()
    # Test fewer workers on windows to avoid memory issues
    addprocs_with_testenv(1)
    @test nworkers() == 1
else
    addprocs_with_testenv(3)
    @test nworkers() == 3
end

@everywhere using Logging
for w in workers()
    # Do not log on worker nodes
    remotecall(()->global_logger(NullLogger()),w)
end

@everywhere using StochasticPrograms
@everywhere using JuMP
@everywhere using LinearAlgebra
@everywhere using GLPK
@everywhere using Ipopt

@everywhere using Distributions

@everywhere import StochasticPrograms: probability, expected

include("../decisions/decisions.jl")
TestDecisionVariable.run_dtests()
TestDecisionConstraint.run_dtests()
TestDecisionObjective.run_dtests()
include("../problems/problem_load.jl")
include("dfunctional_tests.jl")
include("dsolver_tests.jl")
