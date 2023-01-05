"""
    runtests.jl

The entry point to unit tests for the DCCR.jl package.
"""

using SafeTestsets

@safetestset "All Test Sets" begin
    include("test_sets.jl")
end
