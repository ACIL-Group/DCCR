"""
    4_l2metrics.jl

# Description
Runs the l2metrics on the latest logs from within Julia.

# Authors
- Sasha Petrenko <sap625@mst.edu>
"""

# -----------------------------------------------------------------------------
# SETUP
# -----------------------------------------------------------------------------

using
    PyCall,
    Revise,
    DrWatson

# Experiment save directory name
experiment_top = "9_l2metrics"
log_dir_name = "logs"
metrics_dir_name = "l2metrics"
conda_env_name = "l2mmetrics"

# Declare all of the metrics being calculated
metrics = [
    "performance",
    "art_match",
    "art_activation",
]

# DCCR project files
include(projectdir("src", "setup.jl"))

# -----------------------------------------------------------------------------
# GENERATE METRICS
# -----------------------------------------------------------------------------

# Get the most recent log directory name
last_log = readdir(results_dir(log_dir_name))[end]

# Set the full source and output directories
src_dir(args...) = results_dir(log_dir_name, last_log, args...)
out_dir(args...) = results_dir(metrics_dir_name, last_log, args...)

# Iterate over every metric
for metric in metrics
    run(`cmd /c activate $conda_env_name \&\& python -m l2metrics -p $metric -o $metric -O $(out_dir(metric)) -l $(src_dir())`)
end