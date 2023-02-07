"""
    3_dist_driver.jl

# Description
Runs the l2 condensed scenario specified by the gen_scenario.jl file.

# Authors
- Sasha Petrenko <sap625@mst.edu>
"""

# -----------------------------------------------------------------------------
# SETUP
# -----------------------------------------------------------------------------

using Distributed

# addprocs(24, exeflags="--project=.")
# If we parallelize from the command line
if !isempty(ARGS)
    addprocs(parse(Int, ARGS[1]), exeflags="--project=.")
end

@everywhere begin
    # Load dependencies
    using
        DrWatson,
        AdaptiveResonance

    # Experiment save directory name
    experiment_top = "10_l2m_dist"

    # DCCR project files
    include(projectdir("src", "setup.jl"))

    # Special l2 setup for this experiment (setting the pyenv, etc.)
    include(projectdir("src", "setup_l2.jl"))

    # Load the l2logger PyCall dependency
    l2logger = pyimport("l2logger.l2logger")

    # -----------------------------------------------------------------------------
    # LOAD DATA
    # -----------------------------------------------------------------------------

    # Load the default data configuration
    data, data_indexed, class_labels, data_selection, n_classes = load_default_orbit_data(data_dir)

    # -----------------------------------------------------------------------------
    # EXPERIMENT
    # -----------------------------------------------------------------------------

    function run_scenario_permuation(
        order::Vector{String},
        # config_dir_perm::AbstractString,
        data_indexed::VectoredData,
    )

        # Load the config and scenario
        config = json_load(configs_dir(join(order), "config.json"))
        scenario = json_load(configs_dir(join(order), "scenario.json"))

        # Setup the scenario_info dictionary as a function of the config and scenario
        scenario_info = config["META"]
        scenario_info["input_file"] = scenario

        # Instantiate the data logger
        data_logger = l2logger.DataLogger(
            config["DIR"],
            config["NAME"],
            config["COLS"],
            scenario_info,
        )

        # Create the DDVFA options for both initialization and logging
        ddvfa_opts = opts_DDVFA(
            # DDVFA options
            gamma = 5.0,
            gamma_ref = 1.0,
            # rho=0.45,
            rho_lb = 0.45,
            rho_ub = 0.7,
            similarity = :single,
            display = false,
        )
        # Construct the agent from the scenario
        agent = DDVFAAgent(
            ddvfa_opts,
            scenario,
        )

        # Specify the input data configuration
        agent.agent.config = DataConfig(0, 1, 128)

        # -----------------------------------------------------------------------------
        # TRAIN/TEST
        # -----------------------------------------------------------------------------

        # Run the scenario
        run_scenario(agent, data_indexed, data_logger)
    end

end


# # Parallel map the sims
# pmap(local_sim, dicts)

# # Close the workers after simulation
# # rmprocs(workers())


# Save the data into a binary
# pack_data(experiment_top)

println("--- Simulation complete ---")

# Close the workers after simulation
# rmprocs(workers())

# Close the workers after simulation
if !isempty(ARGS)
    rmprocs(workers())
end




# """
#     6_permuted.jl

# Description:

# Because each process does a lot of work, `pmap`` is used,
# requiring every process to be spawned ahead of time and passed the necessary
# function definitions to run each simulation.

# **NOTE**: You must manually add the processes (run parallelize.jl) and shut
# them down after. This is done to reduce precompilation in each process during
# development.

# Authors:
# - Sasha Petrenko <sap625@mst.edu>

# Timeline:
# - 1/25/2022: Created.
# - 2/17/2022: Documented.
# """

# # Start several processes
# using Distributed
# using Combinatorics     # permutations
# # addprocs(3, exeflags="--project=.")
# # Close the workers after simulation
# # rmprocs(workers())

# orders = collect(1:6)

# # Set the simulation parameters
# sim_params = Dict{String, Any}(
#     "m" => "ddvfa",
#     "order" => collect(permutations(orders))
#     # "seed" => collect(1:1000)
# )

# @everywhere begin
#     # Activate the project in case
#     using Pkg
#     Pkg.activate(".")

#     # Modules
#     using Revise            # Editing this file
#     using DrWatson          # Project directory functions, etc.

#     # Experiment save directory name
#     experiment_top = "6_permuted"

#     # Run the common setup methods (data paths, etc.)
#     include(projectdir("src", "setup.jl"))

#     # Make a path locally just for the sweep results
#     # sweep_results_dir(args...) = results_dir("sweep", args...)
#     # sweep_results_dir(args...) = projectdir("work", "data", experiment_top, "sweep", args...)
#     sweep_results_dir(args...) = unpacked_dir(experiment_top, "sweep", args...)
#     mkpath(sweep_results_dir())

#     # Select which data entries to use for the experiment
#     data_selection = [
#         "dot_dusk",
#         "dot_morning",
#         # "emahigh_dusk",
#         # "emahigh_morning",
#         "emalow_dusk",
#         "emalow_morning",
#         "pr_dusk",
#         "pr_morning",
#     ]

#     # Create the DDVFA options
#     opts = opts_DDVFA(
#         gamma = 5.0,
#         gamma_ref = 1.0,
#         rho_lb = 0.45,
#         rho_ub = 0.7,
#         method = "single"
#     )

#     # Sigmoid input scaling
#     scaling = 2.0

#     # Plotting DPI
#     dpi = 350

#     # Load the data names and class labels from the selection
#     data_dirs, class_labels = get_orbit_names(data_selection)

#     # Number of classes
#     n_classes = length(data_dirs)

#     # Load the orbits
#     @info "Worker $(myid()): loading data"
#     data = load_orbits(data_dir, data_dirs, scaling)

#     # Sort/reload the data as indexed components
#     data_indexed = get_indexed_data(data)

#     # Define a single-parameter function for pmap
#     local_sim(dict) = permuted(dict, data_indexed, opts)

# end

# # Log the simulation scale
# @info "START: $(dict_list_count(sim_params)) simulations across $(nprocs())."

# # Turn the dictionary of lists into a list of dictionaries
# dicts = dict_list(sim_params)

# # Remove impermissible sim options
# # filter!(d -> d["rho_ub"] > d["rho_lb"], dicts)
# # @info "Testing permutations:" dicts

# # Parallel map the sims
# pmap(local_sim, dicts)

# # Close the workers after simulation
# # rmprocs(workers())