# Experiments

## Overview

### Exp0

Simulator and agent running in the same instance with only one GPU.

Experiment | Instance type
--- | --- 
0 | `g5.4xlarge`

### Exp1

Simulator and agent running in different instances with one GPU each one.

Experiment | Simulator instance type | Agent instance type
--- | --- | ---
1.1 | `g5.4xlarge` | `g5.4xlarge`
1.2 | `g5.4xlarge` | `g4dn.2xlarge`


### Exp2

Simulator and agent running in the same instance with 4 GPUs. We split the submission in two (i.e., 2 simulators and 2 agents running at the same time).

Experiment | Instance type
--- | --- 
2 | `g4dn.12xlarge`


## Results

Experiment | Ratio | Real time [s] | Game time [s] | Route completion
--- | --- | --- | --- |--- |
0 | 0.26 | - | - | -
1.1 | 0.296 | - | - | -
1.2 | 0.222 | - | - | -
2 | 0.29 | - | - | -
