#!/bin/bash

read -p "Enter the GitHub URLs of your projects (separated by spaces): " -a urls

for url in "${urls[@]}"; do
    # Extract project name from URL
    project_name=$(basename "$url" .git)

    echo "$project_name"
done

