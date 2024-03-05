#!/bin/bash

nvidia-smi --query-gpu=uuid --format=csv | grep GPU
