#!/bin/bash

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    key="$1"

    case $key in
    --generate-config)
        shift
        repos=("$@")
        generate_config=true
        break
        ;;
    --generate-compose)
        shift
        config_file="$1"
        generate_compose=true
        break
        ;;
    *)
        echo "Invalid argument: $key"
        exit 1
        ;;
    esac

    shift
done

# Generate JSON config file if --generate-config flag is provided
if [ "$generate_config" = true ]; then
    # Check if repos are provided
    if [ ${#repos[@]} -eq 0 ]; then
        echo "No repositories specified."
        exit 1
    fi

    # Create an empty array to store project details
    projects=()

    # Loop through specified repositories
    for repo in "${repos[@]}"; do
        # Extract project name from repo URL
        project_name=$(basename "$repo" | sed 's/\.git$//')

        # Build the project details with automatic Postgres credentials using jq
        project=$(jq -n \
            --arg repo "$repo" \
            --arg port 80 \
            --arg project_name "$project_name" \
            '{github_url: $repo, port: $port, host_name: "local.host", project_name: $project_name, postgres_credentials: {DB_NAME: $project_name, DB_USER: $project_name, DB_PASSWORD: "password123"}}')

        # Add the project details to the array
        projects+=("$project")
    done

    # Use jq to generate the JSON file with the array of project details
    echo "${projects[@]}" | jq -s '.' > config.json

    # Display the generated JSON file
    cat config.json
fi

# Generate Docker Compose file if --generate-compose flag is provided
if [ "$generate_compose" = true ]; then
    # Check if config file is provided
    if [ -z "$config_file" ]; then
        echo "No config file specified."
        exit 1
    fi

    # Use jq to extract the services section from the JSON config file
    services=$(jq -r '.[] | .project_name as $project_name | .postgres_credentials.DB_NAME as $db_name | "\($project_name):\n  build: ./\($project_name)\n  ports:\n    - \(.port):80\n  environment:\n    DB_NAME: \($project_name)\n    DB_USER: \($project_name)\n    DB_PASSWORD: password123\n\n\($db_name)-postgres:\n  image: postgres\n  environment:\n    POSTGRES_DB: \($db_name)\n    POSTGRES_USER: \($db_name)\n    POSTGRES_PASSWORD: password123\n\n  # Additional configurations here..."' "$config_file")

    # Generate the Docker Compose file with the extracted services section
    echo "version: '3'" > docker-compose.yml
    echo "services:" >> docker-compose.yml
    echo "$services" >> docker-compose.yml

    # Display the generated Docker Compose file
    cat docker-compose.yml
fi
