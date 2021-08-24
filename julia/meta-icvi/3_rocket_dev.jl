using Base: Int64, Float64
include("rocket.jl")

n_kernels = 5
input_length = 100

rocket = Rocket(input_length, n_kernels)

data = rand(input_length)
apply_kernel(rocket.kernels[1], data)
n_example = 5
t = zeros(n_example, 2)
for i = 1:n_example
    t[i, :] .= apply_kernel(rocket.kernels[1], data)
end

features = apply_kernels(rocket, data)